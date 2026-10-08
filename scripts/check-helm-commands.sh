#!/usr/bin/env bash
#
# check-helm-commands.sh - every `helm ...` command in the chapters, examples and
# decks must use a subcommand and --flags that exist in Helm 4's --help.
#
# Scans (relative to the repo root, or to ROOT_DIR if set):
#   _docs/*.md   examples/**/demo.sh   examples/**/README.md   presentation/*/deck.js
# Extracts lines whose first word is `helm` (after an optional `[host]$ `, `$ `,
# or list/indent prefix), including lines inside fenced code blocks and
# backslash-continued commands. Lines marked `<!-- helm3-reference -->` are
# skipped. Exit 1 on any unknown subcommand or flag.
#
# Plugin subcommands (diff, unittest, ...) are checked through the installed
# plugin's own --help. An empty tree passes.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh" || exit 1
ROOT="${ROOT_DIR:-$HFD_ROOT}"

files=()
while IFS= read -r f; do files+=("$f"); done < <(
    cd "$ROOT" && {
        ls _docs/*.md 2>/dev/null
        find examples -type f \( -name demo.sh -o -name README.md \) 2>/dev/null | sort
        ls presentation/*/deck.js 2>/dev/null
    } | sed "s|^|$ROOT/|")

if [[ ${#files[@]} -eq 0 ]]; then
    echo "check-helm-commands: no chapters, examples or decks yet; nothing to check"
    exit 0
fi

CACHE="$(mktemp -d)"; trap 'rm -rf "$CACHE"' EXIT
fail=0; checked=0

# help_for "<sub path>" -> prints help text (cached); empty + rc 1 if unknown
help_for() {
    local key="${1// /_}"; [[ -z "$key" ]] && key="_top"
    if [[ ! -f "$CACHE/$key" ]]; then
        # shellcheck disable=SC2086
        if helm $1 --help >"$CACHE/$key" 2>&1 && ! grep -qE '^Error: unknown command' "$CACHE/$key"; then :; else : >"$CACHE/$key.bad"; fi
    fi
    [[ ! -f "$CACHE/$key.bad" ]] && cat "$CACHE/$key"
}

check_cmd() { # <file> <lineno> <command text>
    local file="$1" ln="$2" cmd="$3"
    # drop shell tails: pipes, redirects, && ; and anything after
    cmd="$(sed -E 's/[|;&<>].*$//; s/\$\(.*$//; s/#.*$//' <<<"$cmd")"
    local -a w; read -ra w <<<"$cmd"
    [[ "${w[0]:-}" == "helm" ]] || return 0
    checked=$((checked + 1))
    # subcommand path: leading non-flag words, up to 2 levels, validated greedily
    local sub="" depth=0 i=1 tok
    local -a rest=()
    while (( i < ${#w[@]} )); do
        tok="${w[$i]}"
        if [[ "$tok" == -* ]]; then break; fi
        if (( depth < 2 )) && [[ "$tok" =~ ^[a-z][a-z0-9-]*$ ]] && help_for "${sub:+$sub }$tok" >/dev/null \
           && { [[ -z "$sub" ]] || help_for "$sub" | sed -n '/^Available Commands:/,/^$/p' | grep -qE "^[[:space:]]+${tok}[[:space:]]"; }; then
            sub="${sub:+$sub }$tok"; depth=$((depth + 1))
        else
            break
        fi
        i=$((i + 1))
    done
    if [[ -z "$sub" ]]; then
        if [[ -n "${w[1]:-}" && "${w[1]}" != -* ]]; then
            printf '%s:%s: unknown helm subcommand "%s"  (%s)\n' "${file#$ROOT/}" "$ln" "${w[1]}" "$cmd"; fail=1
        fi
        # bare `helm --flag` (e.g. helm --help/--version): validate against top-level help
    fi
    local helptext; helptext="$(help_for "${sub:-}")"
    [[ -z "$helptext" && -z "$sub" ]] && helptext="$(helm --help 2>&1)"
    local j flag
    for (( j = i; j < ${#w[@]}; j++ )); do
        tok="${w[$j]}"
        [[ "$tok" == -- ]] && break
        [[ "$tok" == --* ]] || continue
        flag="${tok%%=*}"
        [[ "$flag" =~ ^--[a-z][a-z0-9-]*$ ]] || continue
        [[ "$flag" == --help ]] && continue
        # allow the full-flag form anywhere in the command's own help, or its global flags
        if ! grep -qE -- "(^|[[:space:],])${flag}([[:space:]=,\[]|\$)" <<<"$helptext"; then
            printf '%s:%s: flag %s not in "helm %s --help"  (%s)\n' "${file#$ROOT/}" "$ln" "$flag" "${sub:-}" "$cmd"; fail=1
        fi
    done
}

for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    ln=0; buf=""; bufln=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ln=$((ln + 1))
        if [[ -n "$buf" ]]; then
            # continuation of a backslash command
            part="${line#"${line%%[![:space:]]*}"}"
            if [[ "$buf" == *"\\" ]]; then buf="${buf%\\} $part"; else check_cmd "$f" "$bufln" "$buf"; buf=""; fi
            if [[ -n "$buf" && "$buf" != *"\\" ]]; then check_cmd "$f" "$bufln" "$buf"; buf=""; fi
            [[ -n "$buf" ]] && continue
            continue
        fi
        [[ "$line" == *"<!-- helm3-reference -->"* ]] && continue
        # normalise prompt/list prefixes: "[host]$ ", "[crc-host]$ ", "$ ", "- ", "  ", "> ", "run ", "`"
        norm="$(sed -E 's/^[[:space:]]*([-*>]|[0-9]+\.)?[[:space:]]*`?(\[[a-z-]+\]\$ |\$ )?//; s/^(run|log|echo|step|"|'"'"'|`)[[:space:]]+(helm )/\2/' <<<"$line")"
        if [[ "$norm" =~ ^helm[[:space:]] ]]; then
            if [[ "$norm" == *"\\" ]]; then buf="$norm"; bufln=$ln; else check_cmd "$f" "$ln" "$norm"; fi
        fi
    done < "$f"
    [[ -n "$buf" ]] && check_cmd "$f" "$bufln" "${buf%\\}"
done

if (( fail )); then
    echo "check-helm-commands: FAILED ($checked helm commands checked)"
    exit 1
fi
echo "check-helm-commands: OK ($checked helm commands checked in ${#files[@]} files)"
