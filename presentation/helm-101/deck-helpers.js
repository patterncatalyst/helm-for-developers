// deck-helpers.js — design system & helpers for the REST deck
// Carries the visual conventions from the existing Python deck:
//   - 13.333 x 7.5 LAYOUT_WIDE
//   - Eyebrow 12pt bold red EE0000, charSpacing 4
//   - Title 30pt Overpass SemiBold #151515
//   - Content 17pt Red Hat Text #242424
//   - Code box fill #151515, code 11pt Red Hat Mono, fg #E6E6E6, comments #8FB98F
//   - Section dividers: bg #AB0000 with section-panel.png on left and white logo
//   - Caption 13pt italic #5A5A5A; page number 10pt #8A8A8A

"use strict";

const PptxGenJS = require("pptxgenjs");
const path = require("path");

const PNG = process.env.DECK_PNG || "./png";
const ASSETS = process.env.DECK_ASSETS || "./assets";

const COLOR = {
  red:        "EE0000",
  redDark:    "AB0000",
  redDeep:    "B71C1C",
  ink:        "151515",
  body:       "242424",
  caption:    "5A5A5A",
  pageNum:    "8A8A8A",
  grid:       "D2D2D2",
  panel:      "F4F4F4",
  codeBg:     "151515",
  codeFg:     "E6E6E6",
  codeComment:"8FB98F",
  codeKey:    "FFC36C",
  codeStr:    "E2CFA2",
  codeDecor:  "97C0FF",
  white:      "FFFFFF",
  rule:       "EE0000",
  // accent palette for callouts
  svc:        "0066CC",
  data:       "6A1B9A",
  platform:   "006E6E",
  govern:     "B36B00",
  amber:      "FFA000",
  // perf callout accent
  perfBg:     "FFF7E6",
  perfBorder: "B36B00",
};

const FONT = {
  title:   "Red Hat Display",
  titleFb: "Calibri",
  body:    "Red Hat Text",
  bodyFb:  "Calibri",
  mono:    "Red Hat Mono",
  monoFb:  "Consolas",
};

// Slide dimensions in inches (LAYOUT_WIDE)
const W = 13.333;
const H = 7.5;

// ----- helpers -----
function newDeck() {
  const pres = new PptxGenJS();
  pres.layout = "LAYOUT_WIDE";
  pres.title = "Designing Cloud-Native REST APIs — Python";
  pres.author = "Robert Sedor";
  pres.company = "Red Hat";
  return pres;
}

// Footer: red Hat-style page number + small logo on every content slide.
function addFooter(slide, pageNum) {
  // page number (bottom-left)
  slide.addText(String(pageNum), {
    x: 0.62, y: 6.96, w: 1.0, h: 0.30,
    fontFace: FONT.body, fontSize: 10, color: COLOR.pageNum,
    align: "left", valign: "middle",
  });
  // Red Hat color logo, bottom-right — present on every content slide
  // (the cover and section dividers carry their own logo separately).
  try {
    slide.addImage({
      path: `${ASSETS}/logo-candidate-2.png`,
      x: 11.55, y: 6.95, w: 1.13, h: 0.27,
    });
  } catch (e) { /* ok if missing */ }
}

function addContentTitle(slide, eyebrow, title, opts = {}) {
  slide.addText(eyebrow, {
    x: 0.62, y: 0.42, w: opts.eyebrowW ?? 12.09, h: 0.32,
    fontFace: FONT.title, fontSize: 12, bold: true, color: COLOR.red,
    charSpacing: 4,
    align: "left", valign: "middle",
  });
  slide.addText(title, {
    x: 0.62, y: 0.74, w: opts.w ?? 12.09, h: opts.h ?? 1.10,
    fontFace: FONT.title, fontSize: opts.fontSize ?? 30, bold: true, color: COLOR.ink,
    align: "left", valign: "top",
  });
}

function addBullets(slide, lines, opts = {}) {
  const x = opts.x ?? 0.62;
  const y = opts.y ?? 1.85;
  const w = opts.w ?? 12.09;
  const h = opts.h ?? 4.85;
  const fontSize = opts.fontSize ?? 17;
  const indentSize = 8;
  // pptxgenjs accepts an array of {text, options:{bullet}} objects
  const items = lines.map((ln) => {
    if (typeof ln === "string") {
      return { text: ln, options: { bullet: { code: "25CF" }, paraSpaceAfter: 6, breakLine: true } };
    }
    // already a structured object; pass through with reasonable defaults
    return {
      text: ln.text,
      options: {
        bullet: ln.sub ? { indent: indentSize, code: "25E6" } : { code: "25CF" },
        paraSpaceAfter: 4,
        breakLine: true,
        indentLevel: ln.sub ? 1 : 0,
        ...(ln.options || {}),
      },
    };
  });
  slide.addText(items, {
    x, y, w, h,
    fontFace: FONT.body, fontSize, color: COLOR.body,
    align: "left", valign: "top",
    paraSpaceAfter: 6,
    lineSpacingMultiple: 1.15,
  });
}

// Two-column bullets — matches the reference deck's agenda layout.
// `left` and `right` are arrays of strings (or {text, options} objects).
// `muted` indicates items to render in muted italic style (e.g. appendices).
function addTwoColBullets(slide, left, right, opts = {}) {
  const y = opts.y ?? 1.85;
  const h = opts.h ?? 4.85;
  const fontSize = opts.fontSize ?? 17;

  function mk(items) {
    return items.map((ln) => {
      if (typeof ln === "string") {
        return { text: ln, options: { bullet: { code: "25CF" }, paraSpaceAfter: 8, breakLine: true } };
      }
      return {
        text: ln.text,
        options: {
          bullet: { code: "25CF" },
          paraSpaceAfter: 8,
          breakLine: true,
          italic: !!ln.muted,
          color: ln.muted ? COLOR.caption : COLOR.body,
          ...(ln.options || {}),
        },
      };
    });
  }

  slide.addText(mk(left), {
    x: 0.62, y, w: 6.00, h,
    fontFace: FONT.body, fontSize, color: COLOR.body,
    align: "left", valign: "top",
    paraSpaceAfter: 8, lineSpacingMultiple: 1.20,
  });
  slide.addText(mk(right), {
    x: 7.02, y, w: 6.00, h,
    fontFace: FONT.body, fontSize, color: COLOR.body,
    align: "left", valign: "top",
    paraSpaceAfter: 8, lineSpacingMultiple: 1.20,
  });
}

// Status-code table: 3-column layout — code | name | purpose
// Designed for the 2xx/4xx/5xx slides so the bullets-as-prose pattern can be retired.
function addStatusTable(slide, rows, opts = {}) {
  const y = opts.y ?? 1.85;
  const h = opts.h ?? (opts.withCallout ? 3.55 : 4.85);

  const tableRows = rows.map((r) => [
    {
      text: r.code,
      options: {
        bold: true, color: r.codeColor || COLOR.red,
        fontFace: FONT.mono, fontSize: opts.fs ? opts.fs[0] : 15,
        align: "left", valign: "middle",
      },
    },
    {
      text: r.name,
      options: {
        bold: true, color: COLOR.ink,
        fontFace: FONT.body, fontSize: opts.fs ? opts.fs[1] : 14,
        align: "left", valign: "middle",
      },
    },
    {
      text: r.purpose,
      options: {
        color: COLOR.body,
        fontFace: FONT.body, fontSize: opts.fs ? opts.fs[2] : 13,
        align: "left", valign: "middle",
      },
    },
  ]);

  slide.addTable(tableRows, {
    x: 0.62, y, w: 12.09, h,
    fontFace: FONT.body,
    color: COLOR.body,
    border: { type: "solid", color: COLOR.grid, pt: 0.5 },
    valign: "middle",
    // Default 3-column widths suit short status codes in column 1. Reference
    // tables (Appendix A/B) pass a wider colW so long labels (e.g. test-type
    // names, CLI names) don't wrap. Widths should sum to ~12.09 (the table w).
    colW: opts.colW ?? [1.10, 2.40, 8.59],
    rowH: opts.rowH ?? 0.45,
  });
}

function addCaption(slide, text, y, w) {
  slide.addText(text, {
    x: 0.62, y: y ?? 6.50, w: w ?? 12.09, h: 0.34,
    fontFace: FONT.body, fontSize: 13, italic: true, color: COLOR.caption,
    align: "center", valign: "middle",
  });
}

function addPerfCallout(slide, text, opts = {}) {
  // Distinctive "perf" sidebar — amber tint, left bar, eyebrow "⚡ PERFORMANCE"
  const x = opts.x ?? 0.62;
  const y = opts.y ?? 5.65;
  const w = opts.w ?? 12.09;
  const h = opts.h ?? 0.80;
  // background panel
  slide.addShape("rect", {
    x, y, w, h,
    fill: { color: COLOR.perfBg },
    line: { color: COLOR.perfBorder, width: 0 },
  });
  // left accent bar
  slide.addShape("rect", {
    x, y, w: 0.06, h,
    fill: { color: COLOR.perfBorder },
    line: { color: COLOR.perfBorder, width: 0 },
  });
  // eyebrow text + body, stacked
  slide.addText([
    { text: "⚡  PERFORMANCE", options: {
        fontFace: FONT.title, fontSize: 10, bold: true, color: COLOR.perfBorder,
        charSpacing: 3, breakLine: true,
    }},
    { text: text, options: {
        fontFace: FONT.body, fontSize: 13, color: COLOR.body,
    }},
  ], {
    x: x + 0.20, y: y + 0.04, w: w - 0.30, h: h - 0.08,
    align: "left", valign: "middle",
  });
}

function addDiagramSlide(slide, eyebrow, title, pngName, caption, opts = {}) {
  addContentTitle(slide, eyebrow, title);
  const x = opts.x ?? 1.80;
  const y = opts.y ?? 1.75;
  const w = opts.w ?? 9.74;
  const h = opts.h ?? 4.75;
  slide.addImage({
    path: `${PNG}/${pngName}.png`,
    x, y, w, h,
    sizing: { type: "contain", w, h },
  });
  if (caption) addCaption(slide, caption);
}

// language eyebrow chip (right-aligned, above the code box)
function addLangChip(slide, label) {
  // Right-aligned, on the same vertical band as the title row
  slide.addText(label, {
    x: 8.62, y: 1.06, w: 4.09, h: 0.30,
    fontFace: FONT.mono, fontSize: 11, bold: true, color: COLOR.caption,
    charSpacing: 2,
    align: "right", valign: "middle",
  });
}

function addCodeSlide(slide, eyebrow, title, lang, codeLines, caption, opts = {}) {
  // If a language chip is present, narrow the title so it doesn't run under the chip.
  addContentTitle(slide, eyebrow, title, lang ? { w: 7.90 } : {});
  if (lang) addLangChip(slide, lang);
  // dark code box
  const x = opts.x ?? 0.62;
  const y = opts.y ?? 1.55;
  const w = opts.w ?? 12.09;
  const h = opts.h ?? 4.85;
  // Largest mono size (11..18 pt) at which the longest line fits the box width and
  // every line fits its height (Red Hat Mono advance is 0.6 em; line pitch ~1.1 x 1.19 em).
  if (opts.fontSize === undefined) {
    const longest = Math.max(...codeLines.map((l) => l.length));
    const usableW = w - 0.40 - 0.30, usableH = h - 0.20;
    let fs = 20;
    while (fs > 11 && (longest * 0.603 * fs / 72 > usableW || codeLines.length * fs * 1.1 * 1.19 / 72 > usableH)) fs -= 0.5;
    opts = { ...opts, fontSize: fs };
  }
  // Snug box: height follows the text so short snippets do not leave a black void.
  const needH = codeLines.length * opts.fontSize * 1.1 * 1.19 / 72 + 0.45;
  const boxH = opts.h === undefined ? Math.min(h, Math.max(2.6, needH)) : h;
  slide.addShape("rect", {
    x, y, w, h: boxH,
    fill: { color: COLOR.codeBg },
    line: { color: COLOR.codeBg, width: 0 },
  });
  // code text — render each line with simple syntax coloring (comments green)
  const items = codeLines.map((ln) => {
    const trimmed = ln.replace(/^\s+/, "");
    const isComment = trimmed.startsWith("#") || trimmed.startsWith("//");
    return {
      text: ln + "\n",
      options: {
        fontFace: FONT.mono,
        fontSize: opts.fontSize ?? 11,
        color: isComment ? COLOR.codeComment : COLOR.codeFg,
        breakLine: false,
      },
    };
  });
  slide.addText(items, {
    x: x + 0.20, y: y + 0.10, w: w - 0.40, h: boxH - 0.20,
    fontFace: FONT.mono, fontSize: opts.fontSize ?? 11, color: COLOR.codeFg,
    align: "left", valign: "top",
    paraSpaceAfter: 0,
    lineSpacingMultiple: 1.10,
  });
  if (caption) {
    // When the code box is taller than default, push the caption below it.
    const codeBottom = y + boxH;
    const captionY = Math.min(6.50, codeBottom + 0.10);
    addCaption(slide, caption, captionY, opts.captionW);
  }
}

function addSectionDivider(slide, code, title, subtitle) {
  // background — solid red, matches Python deck
  slide.background = { color: COLOR.redDark };
  // section-panel.png covers full slide (textured red)
  try {
    slide.addImage({
      path: `${ASSETS}/section-panel.png`,
      x: 0, y: 0, w: W, h: H,
    });
  } catch (e) { /* ok if missing */ }
  // section code (e.g. "00")
  slide.addText(code, {
    x: 6.27, y: 2.32, w: 6.40, h: 0.50,
    fontFace: FONT.title, fontSize: 22, bold: true, color: COLOR.white,
    charSpacing: 6,
    align: "left", valign: "middle",
  });
  // title
  slide.addText(title, {
    x: 6.24, y: 2.84, w: 6.70, h: 1.60,
    fontFace: FONT.title, fontSize: 44, bold: true, color: COLOR.white,
    align: "left", valign: "top",
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: 6.27, y: 4.55, w: 6.60, h: 0.80,
      fontFace: FONT.body, fontSize: 16, italic: true, color: "FFD9D9",
      align: "left", valign: "top",
    });
  }
  // white logo bottom right
  try {
    slide.addImage({
      path: `${ASSETS}/redhat-logo-white.png`,
      x: 11.42, y: 6.88, w: 1.33, h: 0.31,
    });
  } catch (e) { /* ok */ }
}


// ---- flags and tool names as code runs -------------------------------------
// Command-line flags (--wait, -f) and hyphenated tool names (helm-unittest) are set as
// Red Hat Mono runs inside body text, so a line break never lands inside them and a
// copied flag pastes as plain ASCII. patchSlide(slide) applies this to every addText
// and addTable call; runs that already use the mono face are left alone.
const MONO_SRC = "(?<![\\w-])--?[A-Za-z](?:[\\w.=|-]*[\\w=|])?|\\b(?:helm-unittest|helm-diff|chart-testing|Wasm-hello)\\b";
const MONO_SPLIT = new RegExp("(" + MONO_SRC + ")");
const MONO_HAS = new RegExp(MONO_SRC);
const MONO_WHOLE = new RegExp("^(?:" + MONO_SRC + ")$");
const PARA_KEYS = ["bullet", "indentLevel", "paraSpaceBefore", "paraSpaceAfter", "align", "valign"];

function monoRuns(runs, baseSize) {
  const out = [];
  runs.forEach((r) => {
    const o = r.options || {};
    if (o.fontFace === FONT.mono || typeof r.text !== "string" || !MONO_HAS.test(r.text)) { out.push(r); return; }
    const parts = r.text.split(MONO_SPLIT).filter((x) => x !== "");
    const size = (o.fontSize ?? baseSize ?? 18) - 1;
    const inner = { ...o };
    PARA_KEYS.forEach((k) => delete inner[k]);
    parts.forEach((part, i) => {
      const opt = i === 0 ? { ...o } : { ...inner };
      delete opt.breakLine;
      if (i === parts.length - 1 && o.breakLine) opt.breakLine = true;
      if (MONO_WHOLE.test(part)) Object.assign(opt, { fontFace: FONT.mono, fontSize: size, bold: false, italic: false, color: COLOR.ink });
      out.push({ text: part, options: opt });
    });
  });
  return out;
}

function patchSlide(slide) {
  const at = slide.addText.bind(slide);
  slide.addText = (t, o) => {
    if (o && o.fontFace === FONT.mono) return at(t, o);
    const base = o && o.fontSize;
    if (typeof t === "string") return MONO_HAS.test(t) ? at(monoRuns([{ text: t, options: {} }], base), o) : at(t, o);
    if (Array.isArray(t)) return at(monoRuns(t, base), o);
    return at(t, o);
  };
  const atb = slide.addTable.bind(slide);
  slide.addTable = (rows, o) => atb(rows.map((r) => r.map((c) => {
    if (!c || typeof c.text !== "string" || !MONO_HAS.test(c.text)) return c;
    return { ...c, text: monoRuns([{ text: c.text, options: { ...(c.options || {}) } }]) };
  })), o);
  return slide;
}

// pptxgenjs writes a paragraph-properties element before every run of a paragraph. Only the
// first is valid inside <a:p>; PowerPoint ignores or repairs the rest and LibreOffice lets the
// last one win (dropping bullets). Strip every pPr that follows a run, in place.
async function finalizePptx(file) {
  const fs = require("fs");
  const JSZip = require(require.resolve("jszip", { paths: [path.dirname(require.resolve("pptxgenjs"))] }));
  const zip = await JSZip.loadAsync(fs.readFileSync(file));
  for (const name of Object.keys(zip.files)) {
    if (!/^ppt\/slides\/slide\d+\.xml$/.test(name)) continue;
    const xml = await zip.file(name).async("string");
    const out = xml.replace(/(<\/a:r>)<a:pPr\b[^>]*?(?:\/>|>[\s\S]*?<\/a:pPr>)/g, "$1");
    if (out !== xml) zip.file(name, out);
  }
  fs.writeFileSync(file, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
}

function addNotes(slide, text) {
  slide.addNotes(text);
}

module.exports = {
  PptxGenJS, COLOR, FONT, W, H, PNG, ASSETS,
  newDeck,
  addFooter, addContentTitle, addBullets, addTwoColBullets, addStatusTable,
  addCaption, addPerfCallout, patchSlide, monoRuns, finalizePptx,
  addDiagramSlide, addCodeSlide, addLangChip, addSectionDivider, addNotes,
};
