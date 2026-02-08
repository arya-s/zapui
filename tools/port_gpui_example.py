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
3. Creates an HTML comparison report
"""

import sys
import re
import urllib.request
import json
import os
import shutil
import html

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
        'window_size': (500, 500),
        'title': 'ZapUI',
    }
    
    for pattern, message in UNSUPPORTED_FEATURES:
        if re.search(pattern, rust_code):
            analysis['warnings'].append(message)
    
    color_pattern = r'rgb\(0x([0-9a-fA-F]+)\)'
    for match in re.finditer(color_pattern, rust_code):
        analysis['colors'].add(match.group(1))
    
    gpui_colors = r'gpui::(\w+)\(\)'
    for match in re.finditer(gpui_colors, rust_code):
        color = match.group(1)
        if color in ['red', 'green', 'blue', 'yellow', 'black', 'white']:
            analysis['colors'].add(color)
    
    size_match = re.search(r'size\(px\((\d+\.?\d*).*?px\((\d+\.?\d*)\)', rust_code)
    if size_match:
        analysis['window_size'] = (int(float(size_match.group(1))), int(float(size_match.group(2))))
    
    return analysis


def generate_html_report(name: str, rust_code: str, zig_code: str, analysis: dict) -> str:
    """Generate an HTML comparison report"""
    
    title = name.replace('_', ' ').title()
    warnings_html = ''.join(f'<li>{html.escape(w)}</li>' for w in set(analysis['warnings']))
    if not warnings_html:
        warnings_html = '<li class="success">None - straightforward port!</li>'
    
    rust_escaped = html.escape(rust_code)
    zig_escaped = html.escape(zig_code)
    
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - GPUI Port Comparison</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #1a1a1a;
            color: #e0e0e0;
        }}
        h1, h2, h3 {{ color: #fff; }}
        h1 {{ border-bottom: 2px solid #3b82f6; padding-bottom: 10px; }}
        h2 {{ border-bottom: 1px solid #333; padding-bottom: 8px; margin-top: 30px; }}
        
        .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
        .grid-3 {{ display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; }}
        
        .card {{
            background: #252525;
            border-radius: 8px;
            padding: 15px;
            border: 1px solid #333;
        }}
        .card h3 {{ margin-top: 0; color: #3b82f6; }}
        
        .screenshot {{
            max-width: 100%;
            border-radius: 4px;
            border: 1px solid #444;
        }}
        .screenshot-container {{
            text-align: center;
        }}
        .screenshot-container img {{
            max-height: 400px;
            object-fit: contain;
        }}
        
        pre {{
            background: #1e1e1e;
            border: 1px solid #333;
            border-radius: 4px;
            padding: 15px;
            overflow-x: auto;
            font-size: 13px;
            line-height: 1.4;
            max-height: 600px;
            overflow-y: auto;
        }}
        code {{ font-family: 'Fira Code', 'Consolas', monospace; }}
        
        .rust {{ border-left: 3px solid #dea584; }}
        .zig {{ border-left: 3px solid #f7a41d; }}
        
        .warnings {{ background: #3a2a00; border-color: #5a4a00; }}
        .warnings li {{ margin: 5px 0; }}
        .warnings .success {{ color: #4ade80; }}
        
        .stats {{
            display: flex;
            gap: 20px;
            flex-wrap: wrap;
        }}
        .stat {{
            background: #333;
            padding: 10px 20px;
            border-radius: 4px;
        }}
        .stat-value {{ font-size: 24px; font-weight: bold; color: #3b82f6; }}
        .stat-label {{ font-size: 12px; color: #888; }}
        
        .commands {{
            background: #1e1e1e;
            padding: 15px;
            border-radius: 4px;
            font-family: monospace;
        }}
        .commands code {{
            display: block;
            padding: 5px 0;
            color: #4ade80;
        }}
        
        a {{ color: #3b82f6; }}
        
        @media (max-width: 900px) {{
            .grid, .grid-3 {{ grid-template-columns: 1fr; }}
        }}
    </style>
</head>
<body>
    <h1>{title} - GPUI Port Comparison</h1>
    
    <div class="stats">
        <div class="stat">
            <div class="stat-value">{len(rust_code.splitlines())}</div>
            <div class="stat-label">Rust LOC</div>
        </div>
        <div class="stat">
            <div class="stat-value">{len(zig_code.splitlines())}</div>
            <div class="stat-label">Zig LOC</div>
        </div>
        <div class="stat">
            <div class="stat-value">{len(analysis['colors'])}</div>
            <div class="stat-label">Colors</div>
        </div>
        <div class="stat">
            <div class="stat-value">{analysis['window_size'][0]}x{analysis['window_size'][1]}</div>
            <div class="stat-label">Window Size</div>
        </div>
    </div>
    
    <h2>⚠️ Translation Warnings</h2>
    <div class="card warnings">
        <ul>{warnings_html}</ul>
    </div>
    
    <h2>📸 Screenshots</h2>
    <div class="grid-3">
        <div class="card screenshot-container">
            <h3>GPUI (Rust)</h3>
            <img src="screenshots/gpui.png" alt="GPUI Screenshot" class="screenshot">
        </div>
        <div class="card screenshot-container">
            <h3>ZapUI (Zig)</h3>
            <img src="screenshots/zapui.png" alt="ZapUI Screenshot" class="screenshot">
        </div>
        <div class="card screenshot-container">
            <h3>Difference</h3>
            <img src="screenshots/diff.png" alt="Diff" class="screenshot">
        </div>
    </div>
    
    <h2>🔄 Animated Comparison</h2>
    <div class="card screenshot-container">
        <img src="screenshots/toggle.gif" alt="Toggle Animation" class="screenshot">
    </div>
    
    <h2>📝 Source Code</h2>
    <div class="grid">
        <div class="card">
            <h3>Rust (GPUI) - {name}.rs</h3>
            <pre class="rust"><code>{rust_escaped}</code></pre>
        </div>
        <div class="card">
            <h3>Zig (ZapUI) - {name}.zig</h3>
            <pre class="zig"><code>{zig_escaped}</code></pre>
        </div>
    </div>
    
    <h2>🛠️ Build Commands</h2>
    <div class="commands">
        <code># Build for Windows</code>
        <code>make windows</code>
        <code></code>
        <code># Capture screenshots</code>
        <code>make capture-both EXAMPLE={name}</code>
        <code></code>
        <code># Generate comparison</code>
        <code>make compare EXAMPLE={name}</code>
    </div>
    
    <h2>🔗 Links</h2>
    <ul>
        <li><a href="https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/{name}.rs" target="_blank">Original GPUI Source</a></li>
        <li><a href="{name}.zig">ZapUI Port Source</a></li>
        <li><a href="{name}.rs">Local GPUI Copy</a></li>
    </ul>
</body>
</html>
'''


def generate_zig_skeleton(name: str, rust_code: str, analysis: dict) -> str:
    """Generate a D3D11 Zig skeleton"""
    
    width, height = analysis['window_size']
    title = name.replace('_', ' ').title()
    
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
            try:
                r = int(color[0:2], 16) / 255.0
                g = int(color[2:4], 16) / 255.0
                b = int(color[4:6], 16) / 255.0
                color_defs.append(f"const color_{color} = [4]f32{{ {r:.3f}, {g:.3f}, {b:.3f}, 1.0 }};")
            except:
                color_defs.append(f"// const color_{color} = ... // TODO: parse this color")
    
    colors_section = '\n'.join(color_defs) if color_defs else "// No colors extracted"
    
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
    
    # Save original Rust source
    rust_file = f"{example_dir}/{name}.rs"
    with open(rust_file, 'w') as f:
        f.write(rust_code)
    
    # Generate HTML report
    report_html = generate_html_report(name, rust_code, zig_code, analysis)
    report_file = f"{example_dir}/report.html"
    with open(report_file, 'w') as f:
        f.write(report_html)
    
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
    print(f"   - report.html (comparison report)")
    print(f"   - LiberationSans-Regular.ttf (embedded font)")
    print(f"   - screenshots/ (for visual comparisons)")
    print(f"\n   Next steps:")
    print(f"   1. Add build target to build.zig (copy from hello_world)")
    print(f"   2. Implement rendering in {name}.zig")
    print(f"   3. make windows")
    print(f"   4. make capture-both EXAMPLE={name}")
    print(f"   5. make compare EXAMPLE={name}")
    print(f"   6. Open report.html to view comparison")
    print(f"\n   Reference: examples/gpui_ports/hello_world/hello_world.zig")


if __name__ == '__main__':
    main()
