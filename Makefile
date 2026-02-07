.PHONY: help build test run clean

# Default target
all: help

# Build the library
build:
	zig build

# Run unit tests
test:
	zig build test

# Run the playground
run:
	zig build run

# Run playground with arguments
run-args:
	zig build run -- $(ARGS)

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
	@echo "  make build      - Build the library"
	@echo "  make test       - Run unit tests"
	@echo "  make run        - Run the playground"
	@echo "  make run-args ARGS='...' - Run playground with arguments"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make watch-test - Watch files and run tests on change"
	@echo "  make watch-run  - Watch files and run playground on change"
	@echo "  make help       - Show this help"
