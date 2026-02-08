# ZapUI Agent Guidelines

## General Rules
* Go phase by phase
* Each phase has to successfully build and be approved by the maintainer
* Use the `playground/` folder to try out and test the library during development

## GPUI Example Porting Workflow

When porting a GPUI example to ZapUI, follow these steps:

### 1. Generate Skeleton
```bash
make port-gpui EXAMPLE=<name>
```
This creates:
- `examples/gpui_ports/<name>/<name>.zig` - Skeleton to fill in
- `examples/gpui_ports/<name>/<name>.rs` - Original Rust source
- `examples/gpui_ports/<name>/REPORT.md` - Comparison report
- `examples/gpui_ports/<name>/screenshots/` - For visual comparison

### 2. Implement the Port
Edit `examples/gpui_ports/<name>/<name>.zig`:
- Fix the auto-generated skeleton (it's a rough translation)
- Key differences from Rust:
  - Text children need wrapper: `.child(div().child_text("text"))` not `.child("text")`
  - Format strings: use `std.fmt.bufPrint` not `format!()`
  - Colors: use `zapui.rgb(0x...)` or `zapui.hsla(...)`
  - GPUI's `green()` is `zapui.hsla(0.333, 1.0, 0.25, 1.0)`

### 3. Add Build Target (if not auto-added)
Add to `build.zig` if needed - check existing hello_world example for pattern.

### 4. Build for Windows
```bash
make windows
```

### 5. Capture Screenshots
```bash
# Capture ZapUI (OpenGL) screenshot
make capture EXAMPLE=<name>

# Capture GPUI (Rust) screenshot (requires Zed repo at C:\src\zed)
make capture-gpui EXAMPLE=<name>

# Or capture both
make capture-both EXAMPLE=<name>
```

### 6. Generate Comparison
```bash
make compare EXAMPLE=<name>
```
This creates:
- `screenshots/diff.png` - Pixel differences (red = different)
- `screenshots/toggle.gif` - Animated toggle between both

### 7. Review and Iterate
- Check `REPORT.md` for side-by-side API comparison
- Look at `diff.png` to identify visual differences
- Iterate until the output matches GPUI closely

## File Structure for Ported Examples

```
examples/gpui_ports/<name>/
├── <name>.zig           # Main ZapUI implementation (OpenGL)
├── <name>_win32.zig     # Optional: Win32+D3D11 version
├── <name>.rs            # Original GPUI source (reference)
├── REPORT.md            # Comparison report
├── LiberationSans-Regular.ttf  # Font (if needed for D3D11)
└── screenshots/
    ├── zapui.png        # ZapUI screenshot
    ├── gpui.png         # GPUI screenshot
    ├── diff.png         # Pixel difference
    └── toggle.gif       # Animated comparison
```

## D3D11/Win32 Version (Optional)

For native Windows without GLFW/OpenGL:
1. Create `<name>_win32.zig` alongside the main file
2. Use `zapui.platform.Win32Backend` for windowing
3. Use `zapui.renderer.d3d11_renderer.D3D11Renderer` for rendering
4. Embed fonts with `@embedFile("LiberationSans-Regular.ttf")`
5. Copy font file to the example directory

## Prerequisites

- **WSL2** with Zig installed
- **ShareX** on Windows (for screenshot capture)
- **Zed repo** at `C:\src\zed` (for GPUI screenshots)
- **ImageMagick** in WSL (for diff/toggle generation)

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make list-gpui` | List available GPUI examples |
| `make port-gpui EXAMPLE=<name>` | Generate skeleton from GPUI |
| `make windows` | Build all examples for Windows |
| `make capture EXAMPLE=<name>` | Capture ZapUI screenshot |
| `make capture-gpui EXAMPLE=<name>` | Capture GPUI screenshot |
| `make capture-both EXAMPLE=<name>` | Capture both screenshots |
| `make compare EXAMPLE=<name>` | Generate diff and toggle images |
| `make hello-world` | Run hello_world example |
