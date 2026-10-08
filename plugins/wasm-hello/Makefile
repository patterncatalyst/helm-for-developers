.PHONY: build clean
build: plugin.wasm

plugin.wasm: main.go go.mod
	GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared -o plugin.wasm .

clean:
	rm -f plugin.wasm
