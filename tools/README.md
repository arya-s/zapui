# ZapUI Tools

Tools for porting GPUI examples and comparing rendered output.

## Directory Structure

```
examples/gpui_ports/
├── hello_world/
│   ├── hello_world.zig    # ZapUI port
│   ├── hello_world.rs     # Original GPUI source
│   ├── README.md          # Status & notes
│   └── screenshots/
│       ├── zapui.png      # ZapUI screenshot
│       ├── gpui.png       # GPUI screenshot
│       └── comparison.png # Side-by-side
├── gradient/
│   └── ...
└── shadow/
    └── ...
```

## port_gpui_example.py

Generates a complete example directory from a GPUI example.

```bash
# List available GPUI examples
make list-gpui

# Generate example directory with Zig skeleton
make port-gpui EXAMPLE=shadow
# Creates: examples/gpui_ports/shadow/
#   - shadow.zig (ZapUI skeleton)
#   - shadow.rs (original Rust)
#   - README.md (status & warnings)
#   - screenshots/ (empty, for comparisons)
```

### What it does

1. Fetches the GPUI example source code
2. Analyzes complexity and warns about unsupported features
3. Translates div() method chains to Zig
4. Extracts colors used
5. Generates working main() boilerplate
6. Creates README with status

## compare_screenshots.sh

Captures screenshots for visual comparison.

```bash
# Capture ZapUI screenshot
./tools/compare_screenshots.sh hello_world

# Screenshots saved to:
# examples/gpui_ports/hello_world/screenshots/
```

### Usage

1. Run the script - it builds and launches the ZapUI version
2. Press Enter when the window is visible to capture
3. For GPUI, manually capture on Windows/macOS and save as `gpui.png`
4. If both exist, creates `comparison.png` (side-by-side)

## Workflow

### Porting a New Example

```bash
# 1. See what's available
make list-gpui

# 2. Generate skeleton
make port-gpui EXAMPLE=gradient

# 3. Edit the generated Zig file
vim examples/gpui_ports/gradient/gradient.zig

# 4. Add build target to build.zig (copy from hello_world pattern)

# 5. Build and test
zig build gradient
./zig-out/bin/gradient

# 6. Capture screenshots
./tools/compare_screenshots.sh gradient
```

### Comparing with GPUI

```bash
# 1. Capture ZapUI screenshot
./tools/compare_screenshots.sh hello_world

# 2. On Windows, run GPUI and screenshot manually:
#    cd zed && cargo run --example hello_world -p gpui

# 3. Save GPUI screenshot to:
#    examples/gpui_ports/hello_world/screenshots/gpui.png

# 4. Re-run to generate comparison:
./tools/compare_screenshots.sh hello_world
```

## Translation Status

| Feature | GPUI | ZapUI | Notes |
|---------|:----:|:-----:|-------|
| div() fluent API | ✅ | ✅ | Nearly identical |
| Flexbox layout | ✅ | ✅ | Full support |
| Text rendering | ✅ | ✅ | Needs wrapper div |
| Borders (solid) | ✅ | ✅ | Full support |
| Borders (dashed) | ✅ | ✅ | Full support |
| Rounded corners | ✅ | ✅ | Full support |
| Box shadows | ✅ | ✅ | Full support |
| Colors (rgb/hsla) | ✅ | ✅ | Full support |
| Gradients | ✅ | ❌ | Not yet |
| Images | ✅ | ❌ | Not yet |
| SVG | ✅ | ❌ | Not yet |
| Animations | ✅ | ❌ | Not yet |
| Event handlers | ✅ | ⚠️ | Basic only |
| Scrolling | ✅ | ❌ | Not yet |
| Canvas/painting | ✅ | ❌ | Not yet |

## Ported Examples

| Example | Status | Notes |
|---------|--------|-------|
| hello_world | ✅ Complete | Matches GPUI output |
| *others* | 🚧 | Run `make list-gpui` to see available |
