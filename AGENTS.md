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
- `examples/gpui_ports/<name>/<name>.zig` - D3D11 skeleton
- `examples/gpui_ports/<name>/<name>.rs` - Original Rust source
- `examples/gpui_ports/<name>/REPORT.md` - Comparison report
- `examples/gpui_ports/<name>/LiberationSans-Regular.ttf` - Embedded font
- `examples/gpui_ports/<name>/screenshots/` - For visual comparison

### 2. Add Build Target
Add to `build.zig` - copy the hello_world pattern:
```zig
const <name>_mod = b.createModule(.{
    .root_source_file = b.path("examples/gpui_ports/<name>/<name>.zig"),
    .target = target,
    .optimize = optimize,
});
<name>_mod.addImport("zapui", zapui_mod);
<name>_mod.addImport("freetype", freetype_dep.module("freetype"));
// ... see hello_world for full pattern
```

### 3. Implement the Port
The generated skeleton has the boilerplate. Fill in the rendering:
- Use `renderer.drawQuads()` for rectangles/boxes
- Use `renderer.drawSprites()` for text (after rasterizing with FreeType)
- See `examples/gpui_ports/hello_world/hello_world.zig` for complete example

### 4. Build and Capture
```bash
make windows
make capture EXAMPLE=<name>
make capture-gpui EXAMPLE=<name>
make compare EXAMPLE=<name>
```

### 5. Review
- Check `screenshots/diff.png` for pixel differences
- Check `screenshots/toggle.gif` for animated comparison
- Iterate until output matches GPUI

## File Structure for Ported Examples

```
examples/gpui_ports/<name>/
├── <name>.zig                  # Win32 + D3D11 implementation
├── <name>.rs                   # Original GPUI source (reference)
├── REPORT.md                   # Comparison report
├── LiberationSans-Regular.ttf  # Embedded font
└── screenshots/
    ├── zapui.png        # ZapUI screenshot
    ├── gpui.png         # GPUI screenshot
    ├── diff.png         # Pixel difference
    └── toggle.gif       # Animated comparison
```

## Renderer: Win32 + D3D11

All GPUI ports use native Win32 windowing and D3D11 rendering:
- Uses `zapui.platform.Win32Backend` for windowing
- Uses `zapui.renderer.d3d11_renderer.D3D11Renderer` for rendering
- Embeds fonts with `@embedFile("LiberationSans-Regular.ttf")`

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
| `make hello-world` | Build hello_world (Win32 + D3D11) |
