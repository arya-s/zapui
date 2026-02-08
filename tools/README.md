# ZapUI Tools

Tools for porting GPUI examples and comparing rendered output.

## port_gpui_example.py

Helps port GPUI Rust examples to ZapUI Zig.

```bash
# List available GPUI examples
python3 tools/port_gpui_example.py --list

# Generate a Zig skeleton from a GPUI example
python3 tools/port_gpui_example.py hello_world
python3 tools/port_gpui_example.py gradient
```

This will:
1. Fetch the GPUI example source code
2. Analyze it for complexity/warnings
3. Generate a `playground/<name>.zig` skeleton
4. Highlight features that need manual translation

### Translation Status

| Feature | GPUI | ZapUI | Status |
|---------|------|-------|--------|
| div() fluent API | ✅ | ✅ | Fully supported |
| Flexbox layout | ✅ | ✅ | Fully supported |
| Text rendering | ✅ | ✅ | Supported (need wrapper div) |
| Borders | ✅ | ✅ | Including dashed |
| Rounded corners | ✅ | ✅ | Fully supported |
| Shadows | ✅ | ✅ | box-shadow supported |
| Colors (rgb/hsla) | ✅ | ✅ | Fully supported |
| Gradients | ✅ | ❌ | Not yet |
| Images | ✅ | ❌ | Not yet |
| SVG | ✅ | ❌ | Not yet |
| Animations | ✅ | ❌ | Not yet |
| Event handlers | ✅ | ⚠️ | Basic support |
| Scrolling | ✅ | ❌ | Not yet |

## compare_screenshots.sh

Captures screenshots of both GPUI and ZapUI examples for visual comparison.

```bash
# Compare hello_world example
./tools/compare_screenshots.sh hello_world

# Screenshots saved to screenshots/ directory
```

Prerequisites:
- Rust/Cargo (for GPUI)
- Zig (for ZapUI)
- scrot or gnome-screenshot (for capturing)
- ImageMagick (for diff/comparison images)

## Workflow

1. **Port an example:**
   ```bash
   python3 tools/port_gpui_example.py <example_name>
   ```

2. **Edit the generated file:**
   ```bash
   vim playground/<example_name>.zig
   ```

3. **Add build target** to `build.zig` if needed

4. **Build and test:**
   ```bash
   zig build <example_name>
   ./zig-out/bin/<example_name>
   ```

5. **Compare screenshots:**
   ```bash
   ./tools/compare_screenshots.sh <example_name>
   ```
