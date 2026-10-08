// wasm-hello is a Helm 4 cli/v1 plugin that runs in the Extism (Wasm) runtime.
// Helm passes {"extraArgs": [...]} on the plugin input. The plugin writes its
// text to WASI stdout, which Helm forwards to the terminal, and returns "{}" as
// the (empty) cli/v1 output message.
package main

import (
	"fmt"

	pdk "github.com/extism/go-pdk"
)

type input struct {
	ExtraArgs []string `json:"extraArgs"`
}

//go:wasmexport helm_plugin_main
func helmPluginMain() uint32 {
	var in input
	if err := pdk.InputJSON(&in); err != nil {
		pdk.SetError(fmt.Errorf("parse input: %w", err))
		return 1
	}

	name := "world"
	if len(in.ExtraArgs) > 0 {
		name = in.ExtraArgs[0]
	}
	fmt.Printf("Hello, %s! (from a Wasm Helm plugin)\n", name)

	if err := pdk.OutputJSON(struct{}{}); err != nil {
		pdk.SetError(fmt.Errorf("write output: %w", err))
		return 1
	}
	return 0
}

func main() {}
