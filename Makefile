.PHONY: help build test run run-release clean taffy-demo taffy-visual playground

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

# Run Taffy console demo (prints layout tree)
taffy-demo:
	zig build taffy-demo

# Run Taffy visual demo (renders dashboard layout)
taffy-visual:
	zig build taffy-visual

# Clean build artifacts
clean:
	rm -rf zig-out .zig-cache

# Watch and run tests (requires entr: sudo apt install entr)
watch-test:
	find src playground -name '*.zig' | entr -c zig build test

# Watch and run playground (requires entr)
watch-run:
	find src playground -name '*.zig' | entr -c zig build run

# Show help
help:
	@echo "zapui Makefile targets:"
	@echo "  make build        - Build the library"
	@echo "  make test         - Run unit tests"
	@echo "  make run          - Run the Div API playground"
	@echo "  make playground   - Alias for 'make run'"
	@echo "  make run-release  - Run playground (release build)"
	@echo "  make run-args ARGS='...' - Run playground with arguments"
	@echo "  make taffy-demo   - Run Taffy console demo"
	@echo "  make taffy-visual - Run Taffy visual demo"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make watch-test   - Watch files and run tests on change"
	@echo "  make watch-run    - Watch files and run playground on change"
	@echo "  make help         - Show this help"
