# ZapUI Tools

Tools for porting GPUI examples and comparing rendered output.

## Directory Structure

```
examples/gpui_ports/
├── hello_world/
│   ├── hello_world.zig    # ZapUI port
│   ├── hello_world.rs     # Original GPUI source
│   ├── REPORT.md          # Comparison report with embedded screenshots
│   └── screenshots/
│       ├── zapui.png      # ZapUI screenshot
│       ├── gpui.png       # GPUI screenshot
│       ├── diff.png       # Pixel differences
│       └── toggle.gif     # Animated toggle
├── gradient/
│   └── ...
└── shadow/
    └── ...
```

## Quick Start (Windows + WSL)

```bash
# 1. Port an example
make port-gpui EXAMPLE=hello_world

# 2. Build for Windows
make windows

# 3. On Windows, run comparison script (uses ShareX)
tools\compare_windows.bat hello_world

# 4. Back in WSL, generate comparison images
./tools/create_comparison.sh hello_world
```

## Tools

### port_gpui_example.py

Generates a complete example directory from a GPUI example.

```bash
# List available GPUI examples
make list-gpui

# Generate example directory with Zig skeleton
make port-gpui EXAMPLE=shadow
```

Creates:
- `shadow.zig` - ZapUI skeleton
- `shadow.rs` - Original Rust source
- `REPORT.md` - API comparison report
- `screenshots/` - For visual comparisons

### compare_windows.bat (Windows)

Runs both GPUI and ZapUI examples on Windows for screenshot capture.

```batch
REM On Windows (cmd or PowerShell)
cd zapui\tools
compare_windows.bat hello_world
```

Prerequisites:
- [ShareX](https://getsharex.com/) installed and running
- Rust/Cargo installed
- Zed repository cloned (for GPUI)
- ZapUI built for Windows (`make windows`)

ShareX hotkeys:
- `Ctrl+Shift+PrintScreen` - Capture active window
- Save to `examples\gpui_ports\<name>\screenshots\`

### create_comparison.sh (WSL/Linux)

Creates comparison images from captured screenshots.

```bash
./tools/create_comparison.sh hello_world
```

Generates:
- `diff.png` - Pixel differences highlighted
- `toggle.gif` - Animated toggle between both

Also updates REPORT.md with embedded screenshot links.

Requires: ImageMagick (`sudo apt install imagemagick`)

## Complete Workflow

### 1. Port a GPUI Example

```bash
# See available examples
make list-gpui

# Generate skeleton
make port-gpui EXAMPLE=gradient

# Edit the generated Zig file
vim examples/gpui_ports/gradient/gradient.zig
```

### 2. Build for Windows

```bash
# Build specific example
zig build gradient -Dtarget=x86_64-windows

# Or build all examples
make windows
```

### 3. Capture Screenshots (Windows)

```batch
REM In Windows terminal
cd C:\path\to\zapui\tools
compare_windows.bat gradient
```

Follow the prompts:
1. ZapUI window opens → Capture with ShareX → Save as `zapui.png`
2. GPUI window opens → Capture with ShareX → Save as `gpui.png`

### 4. Generate Comparison (WSL)

```bash
./tools/create_comparison.sh gradient
```

### 5. Review Results

Check `examples/gpui_ports/gradient/screenshots/`:
- `comparison.png` - Side-by-side view
- `diff.png` - See pixel differences
- `toggle.gif` - Flip between both versions

## ShareX Setup

For best results, configure ShareX:

1. **Capture settings:**
   - Task settings → Capture → Screenshot delay: 0.5s
   - Include cursor: No

2. **Hotkeys:**
   - Capture active window: `Ctrl+Shift+PrintScreen`

3. **After capture:**
   - Task settings → Actions → Save to file
   - Navigate to `zapui/examples/gpui_ports/<name>/screenshots/`

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
