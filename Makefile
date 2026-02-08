.PHONY: help build test run run-release clean zaffy-demo zaffy-visual playground hello-world windows windows-release list-gpui port-gpui

# Default target
all: help

# Build the library
build:
	zig build

# Run unit tests
test:
	zig build test

# Run the playground (Div API demo)
run:
	zig build run

# Alias for playground
playground:
	zig build run

# Run playground in release mode
run-release:
	zig build run -Doptimize=ReleaseFast

# Run playground with arguments
run-args:
	zig build run -- $(ARGS)

# Run Zaffy console demo (prints layout tree)
zaffy-demo:
	zig build zaffy-demo

# Run Zaffy visual demo (renders dashboard layout)
zaffy-visual:
	zig build zaffy-visual

# Run Hello World example (GPUI port)
hello-world:
	zig build hello-world

# Build all examples for Windows (cross-compile from Linux/WSL)
windows:
	zig build hello-world -Dtarget=x86_64-windows
	zig build run -Dtarget=x86_64-windows
	zig build zaffy-visual -Dtarget=x86_64-windows
	@echo ""
	@echo "Windows executables built in zig-out/bin/"
	@echo "  - hello_world.exe"
	@echo "  - playground.exe"
	@echo "  - zaffy_visual.exe"

# Build all examples for Windows (release mode)
windows-release:
	zig build hello-world -Dtarget=x86_64-windows -Doptimize=ReleaseFast
	zig build run -Dtarget=x86_64-windows -Doptimize=ReleaseFast
	zig build zaffy-visual -Dtarget=x86_64-windows -Doptimize=ReleaseFast
	@echo ""
	@echo "Windows release executables built in zig-out/bin/"
	@echo "  - hello_world.exe"
	@echo "  - playground.exe"
	@echo "  - zaffy_visual.exe"

# Clean build artifacts
clean:
	rm -rf zig-out .zig-cache

# Watch and run tests (requires entr: sudo apt install entr)
watch-test:
	find src playground -name '*.zig' | entr -c zig build test

# Watch and run playground (requires entr)
watch-run:
	find src playground -name '*.zig' | entr -c zig build run

# List GPUI examples
list-gpui:
	@/usr/bin/python3 tools/port_gpui_example.py --list

# Port a GPUI example (usage: make port-gpui EXAMPLE=hello_world)
port-gpui:
	@/usr/bin/python3 tools/port_gpui_example.py $(EXAMPLE)

# Show help
help:
	@echo "zapui Makefile targets:"
	@echo ""
	@echo "Build & Run:"
	@echo "  make build          - Build the library"
	@echo "  make test           - Run unit tests"
	@echo "  make run            - Run the Div API playground"
	@echo "  make playground     - Alias for 'make run'"
	@echo "  make run-release    - Run playground (release build)"
	@echo "  make hello-world    - Run Hello World example (GPUI port)"
	@echo "  make zaffy-demo     - Run Zaffy console demo"
	@echo "  make zaffy-visual   - Run Zaffy visual demo"
	@echo ""
	@echo "Cross-compilation:"
	@echo "  make windows        - Cross-compile all examples for Windows"
	@echo "  make windows-release- Cross-compile for Windows (release)"
	@echo ""
	@echo "GPUI Porting Tools:"
	@echo "  make list-gpui      - List available GPUI examples"
	@echo "  make port-gpui EXAMPLE=<name> - Generate Zig skeleton from GPUI example"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean          - Remove build artifacts"
	@echo "  make watch-test     - Watch files and run tests on change"
	@echo "  make watch-run      - Watch files and run playground on change"
	@echo "  make help           - Show this help"
