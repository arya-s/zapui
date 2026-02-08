#!/usr/bin/env python3
"""
GPUI Example Porter - Helps port GPUI Rust examples to ZapUI Zig

Usage:
    ./port_gpui_example.py <example_name>
    ./port_gpui_example.py hello_world
    ./port_gpui_example.py --list

This tool:
1. Downloads the GPUI example source
2. Generates a Zig translation skeleton (Win32 + D3D11)
3. Highlights areas needing manual translation
"""

import sys
import re
import urllib.request
import json
import os
import shutil

GPUI_EXAMPLES_URL = "https://raw.githubusercontent.com/zed-industries/zed/main/crates/gpui/examples"
GPUI_API_URL = "https://api.github.com/repos/zed-industries/zed/contents/crates/gpui/examples"

# Features that need manual attention
UNSUPPORTED_FEATURES = [
    (r'\.on_click\(', 'Event handlers need manual implementation'),
    (r'\.on_mouse_', 'Mouse events need manual implementation'),
    (r'\.child\([^)]*format!', 'Format strings: use std.fmt.bufPrint'),
    (r'impl Render', 'Render trait: convert to render function'),
    (r'cx\.new\(', 'Context/state: needs manual conversion'),
    (r'\.when\(', 'Conditional rendering: use if/else'),
    (r'\.map\(', 'Iterator mapping: use Zig for loop'),
    (r'uniform_list', 'List virtualization: not yet implemented'),
    (r'canvas\(', 'Canvas/custom painting: not yet implemented'),
    (r'img\(', 'Image loading: not yet implemented'),
    (r'svg\(', 'SVG rendering: not yet implemented'),
    (r'Animation', 'Animations: not yet implemented'),
]


def list_examples():
    """List available GPUI examples"""
    try:
        with urllib.request.urlopen(GPUI_API_URL) as response:
            data = json.loads(response.read().decode())
            examples = [item['name'].replace('.rs', '') 
                       for item in data 
                       if item['type'] == 'file' and item['name'].endswith('.rs')]
            print("Available GPUI examples:")
            for ex in sorted(examples):
                print(f"  {ex}")
            return examples
    except Exception as e:
        print(f"Error fetching examples: {e}")
        return []


def fetch_example(name: str) -> str:
    """Fetch GPUI example source code"""
    url = f"{GPUI_EXAMPLES_URL}/{name}.rs"
    try:
        with urllib.request.urlopen(url) as response:
            return response.read().decode()
    except Exception as e:
        print(f"Error fetching {name}: {e}")
        return ""


def analyze_example(rust_code: str) -> dict:
    """Analyze Rust code for translation complexity"""
    analysis = {
        'warnings': [],
        'colors': set(),
        'window_size': (500, 500),  # Default
        'title': 'ZapUI',
    }
    
    # Find unsupported features
    for pattern, message in UNSUPPORTED_FEATURES:
        if re.search(pattern, rust_code):
            analysis['warnings'].append(message)
    
    # Extract colors
    color_pattern = r'rgb\(0x([0-9a-fA-F]+)\)'
    for match in re.finditer(color_pattern, rust_code):
        analysis['colors'].add(match.group(1))
    
    gpui_colors = r'gpui::(\w+)\(\)'
    for match in re.finditer(gpui_colors, rust_code):
        color = match.group(1)
        if color in ['red', 'green', 'blue', 'yellow', 'black', 'white']:
            analysis['colors'].add(color)
    
    # Try to extract window size from Rust code
    size_match = re.search(r'size\(px\((\d+\.?\d*).*?px\((\d+\.?\d*)\)', rust_code)
    if size_match:
        analysis['window_size'] = (int(float(size_match.group(1))), int(float(size_match.group(2))))
    
    return analysis


def generate_comparison_report(name: str, rust_code: str, analysis: dict) -> str:
    """Generate a comparison report"""
    
    warnings_list = '\n'.join(f'- {w}' for w in set(analysis['warnings'])) if analysis['warnings'] else 'None - straightforward port!'
    
    # Extract the main div chain from Rust for display
    render_match = re.search(r'fn render\([^)]*\)[^{]*\{(.*?)\n    \}', rust_code, re.DOTALL)
    rust_render = render_match.group(1).strip() if render_match else ""
    div_match = re.search(r'(div\(\)[^;]+)', rust_render, re.DOTALL)
    rust_div_chain = div_match.group(1).strip()[:1500] if div_match else "// Could not extract"
    
    return f'''# {name.replace('_', ' ').title()} - Comparison Report

## Overview

| Metric | Value |
|--------|-------|
| Example | `{name}` |
| Rust LOC | {len(rust_code.splitlines())} |
| Colors used | {len(analysis['colors'])} |
| Warnings | {len(analysis['warnings'])} |

## Translation Warnings

{warnings_list}

## Rust (GPUI) Source

```rust
{rust_div_chain}
```

## Screenshots

### GPUI (Rust)

![GPUI](screenshots/gpui.png)

### ZapUI (Zig)

![ZapUI](screenshots/zapui.png)

### Animated Toggle

![Toggle](screenshots/toggle.gif)

### Pixel Diff

![Diff](screenshots/diff.png)

## Build & Capture

```bash
# Build
make windows

# Capture both screenshots
make capture-both EXAMPLE={name}

# Generate comparison
make compare EXAMPLE={name}
```

## Links

- [Original GPUI source](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/{name}.rs)
'''


def generate_zig_skeleton(name: str, rust_code: str, analysis: dict) -> str:
    """Generate a D3D11 Zig skeleton"""
    
    width, height = analysis['window_size']
    title = name.replace('_', ' ').title()
    
    # Generate color definitions
    color_defs = []
    for color in sorted(analysis['colors']):
        if color == 'red':
            color_defs.append("const red_color = [4]f32{ 1.0, 0.0, 0.0, 1.0 };")
        elif color == 'green':
            color_defs.append("const green_color = [4]f32{ 0.0, 0.5, 0.0, 1.0 }; // GPUI's green")
        elif color == 'blue':
            color_defs.append("const blue_color = [4]f32{ 0.0, 0.0, 1.0, 1.0 };")
        elif color == 'yellow':
            color_defs.append("const yellow_color = [4]f32{ 1.0, 1.0, 0.0, 1.0 };")
        elif color == 'black':
            color_defs.append("const black_color = [4]f32{ 0.0, 0.0, 0.0, 1.0 };")
        elif color == 'white':
            color_defs.append("const white_color = [4]f32{ 1.0, 1.0, 1.0, 1.0 };")
        else:
            # Convert hex to float
            try:
                r = int(color[0:2], 16) / 255.0
                g = int(color[2:4], 16) / 255.0
                b = int(color[4:6], 16) / 255.0
                color_defs.append(f"const color_{color} = [4]f32{{ {r:.3f}, {g:.3f}, {b:.3f}, 1.0 }};")
            except:
                color_defs.append(f"// const color_{color} = ... // TODO: parse this color")
    
    colors_section = '\n'.join(color_defs) if color_defs else "// No colors extracted"
    
    # Warnings section
    if analysis['warnings']:
        warnings = '\n'.join(f'//   - {w}' for w in set(analysis['warnings']))
    else:
        warnings = "//   None - this example should be straightforward to port!"
    
    return f'''//! {title} - Port of GPUI's {name}.rs example
//!
//! Win32 + D3D11 implementation.
//! See {name}.rs for original GPUI source.

const std = @import("std");
const zapui = @import("zapui");
const freetype = @import("freetype");

const d3d11 = zapui.renderer.d3d11_renderer.d3d11;
const S_OK = zapui.renderer.d3d11_renderer.S_OK;

const win32_platform = zapui.platform.Win32Backend;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;
const SpriteInstance = zapui.renderer.d3d11_renderer.SpriteInstance;

fn release(comptime T: type, obj: *T) void {{
    _ = obj.IUnknown.vtable.Release(&obj.IUnknown);
}}

// Embedded font
const font_data = @embedFile("LiberationSans-Regular.ttf");

// ============================================================================
// Colors extracted from GPUI example
// ============================================================================

{colors_section}

// ============================================================================
// WARNINGS - Features needing manual implementation:
// ============================================================================
{warnings}

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {{
    const allocator = std.heap.page_allocator;

    // Initialize FreeType for text rendering
    const ft_lib = freetype.Library.init() catch {{
        std.debug.print("Failed to initialize FreeType\\n", .{{}});
        return error.FreeTypeInitFailed;
    }};
    defer ft_lib.deinit();

    const face = ft_lib.initMemoryFace(font_data, 0) catch {{
        std.debug.print("Failed to load font\\n", .{{}});
        return error.FontLoadFailed;
    }};
    defer face.deinit();

    face.setPixelSizes(0, 20) catch {{
        std.debug.print("Failed to set font size\\n", .{{}});
        return error.FontSizeFailed;
    }};

    // Initialize Win32 platform
    var plat = try win32_platform.init();
    defer plat.deinit();

    // Create window (size from GPUI example)
    const window = try win32_platform.createWindow(&plat, .{{
        .width = {width},
        .height = {height},
        .title = "{title} - ZapUI (Win32 + D3D11)",
    }});
    defer window.destroy();

    std.debug.print("{title} - ZapUI (Win32 + D3D11)\\n", .{{}});
    std.debug.print("Press ESC to exit\\n", .{{}});

    // Initialize D3D11 renderer
    var renderer = D3D11Renderer.init(allocator, window.hwnd.?, {width}, {height}) catch |err| {{
        std.debug.print("Failed to initialize D3D11: {{}}\\n", .{{err}});
        return err;
    }};
    defer renderer.deinit();

    // TODO: Create glyph atlas for text rendering (see hello_world.zig for example)

    // Main loop
    while (!window.shouldClose()) {{
        const events = window.pollEvents();

        for (events) |event| {{
            switch (event) {{
                .key => |k| {{
                    if (k.key == .escape and k.action == .press) {{
                        return;
                    }}
                }},
                .resize => |r| {{
                    renderer.resize(r.width, r.height) catch {{}};
                }},
                else => {{}},
            }}
        }}

        // Render frame
        renderer.beginFrame();
        renderer.clear(0.314, 0.314, 0.314, 1.0); // bg color 0x505050

        // TODO: Implement rendering
        // Use renderer.drawQuads() for rectangles
        // Use renderer.drawSprites() for text
        // See hello_world.zig for complete example

        renderer.present(true);
    }}
}}
'''


def main():
    if len(sys.argv) < 2:
        print("Usage: ./port_gpui_example.py <example_name>")
        print("       ./port_gpui_example.py --list")
        sys.exit(1)
    
    if sys.argv[1] == '--list':
        list_examples()
        return
    
    name = sys.argv[1].replace('.rs', '')
    print(f"Fetching GPUI example: {name}")
    
    rust_code = fetch_example(name)
    if not rust_code:
        print(f"Could not fetch example: {name}")
        sys.exit(1)
    
    print(f"Analyzing {len(rust_code)} bytes of Rust code...")
    analysis = analyze_example(rust_code)
    
    print(f"\nAnalysis:")
    print(f"  - Colors used: {len(analysis['colors'])}")
    print(f"  - Window size: {analysis['window_size']}")
    print(f"  - Warnings: {len(analysis['warnings'])}")
    
    if analysis['warnings']:
        print("\nWarnings (features needing manual work):")
        for w in set(analysis['warnings']):
            print(f"  ⚠️  {w}")
    
    zig_code = generate_zig_skeleton(name, rust_code, analysis)
    
    # Create example directory structure
    example_dir = f"examples/gpui_ports/{name}"
    os.makedirs(example_dir, exist_ok=True)
    os.makedirs(f"{example_dir}/screenshots", exist_ok=True)
    
    # Write Zig skeleton
    output_file = f"{example_dir}/{name}.zig"
    print(f"\nGenerating: {output_file}")
    with open(output_file, 'w') as f:
        f.write(zig_code)
    
    # Save original Rust source for reference
    rust_file = f"{example_dir}/{name}.rs"
    with open(rust_file, 'w') as f:
        f.write(rust_code)
    
    # Generate comparison report
    report = generate_comparison_report(name, rust_code, analysis)
    report_file = f"{example_dir}/REPORT.md"
    with open(report_file, 'w') as f:
        f.write(report)
    
    # Copy font file
    font_src = "assets/fonts/LiberationSans-Regular.ttf"
    font_dst = f"{example_dir}/LiberationSans-Regular.ttf"
    if os.path.exists(font_src):
        shutil.copy(font_src, font_dst)
        print(f"   Copied font: {font_dst}")
    else:
        print(f"   ⚠️  Font not found: {font_src}")
        print(f"   Copy LiberationSans-Regular.ttf to {example_dir}/")
    
    print(f"\n✅ Generated example in {example_dir}/")
    print(f"   - {name}.zig (D3D11 skeleton)")
    print(f"   - {name}.rs (original Rust source)")
    print(f"   - REPORT.md (comparison report)")
    print(f"   - LiberationSans-Regular.ttf (embedded font)")
    print(f"   - screenshots/ (for visual comparisons)")
    print(f"\n   Next steps:")
    print(f"   1. Add build target to build.zig (copy from hello_world)")
    print(f"   2. Implement rendering in {name}.zig")
    print(f"   3. make windows")
    print(f"   4. make capture-both EXAMPLE={name}")
    print(f"   5. make compare EXAMPLE={name}")
    print(f"\n   Reference: examples/gpui_ports/hello_world/hello_world.zig")


if __name__ == '__main__':
    main()
