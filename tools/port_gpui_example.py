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
    """Generate a D3D11 Zig skeleton matching the Rust structure"""
    
    width, height = analysis['window_size']
    title = name.replace('_', ' ').title()
    class_name = ''.join(word.capitalize() for word in name.split('_'))
    
    # Generate color definitions
    color_defs = []
    for color in sorted(analysis['colors']):
        if color == 'red':
            color_defs.append("const red = [4]f32{ 1, 0, 0, 1 };")
        elif color == 'green':
            color_defs.append("const green = [4]f32{ 0, 0.5, 0, 1 }; // gpui::green()")
        elif color == 'blue':
            color_defs.append("const blue = [4]f32{ 0, 0, 1, 1 };")
        elif color == 'yellow':
            color_defs.append("const yellow = [4]f32{ 1, 1, 0, 1 };")
        elif color == 'black':
            color_defs.append("const black = [4]f32{ 0, 0, 0, 1 };")
        elif color == 'white':
            color_defs.append("const white = [4]f32{ 1, 1, 1, 1 };")
        else:
            try:
                r = int(color[0:2], 16) / 255.0
                g = int(color[2:4], 16) / 255.0
                b = int(color[4:6], 16) / 255.0
                color_defs.append(f"// rgb(0x{color})")
            except:
                pass
    
    colors_section = '\n'.join(color_defs) if color_defs else "// Define colors as needed"
    
    return f'''//! {title} - Port of GPUI's {name}.rs example

const std = @import("std");
const zapui = @import("zapui");
const freetype = @import("freetype");

const d3d11 = zapui.renderer.d3d11_renderer.d3d11;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;
const SpriteInstance = zapui.renderer.d3d11_renderer.SpriteInstance;
const Win32 = zapui.platform.Win32Backend;

// Colors
fn rgb(hex: u24) [4]f32 {{
    return .{{
        @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0,
        @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0,
        @as(f32, @floatFromInt(hex & 0xFF)) / 255.0,
        1.0,
    }};
}}
{colors_section}

// ============================================================================
// {class_name}
// ============================================================================

const {class_name} = struct {{
    // TODO: Add state fields from Rust struct

    fn render(self: *{class_name}, renderer: *D3D11Renderer, text_renderer: anytype) void {{
        _ = self;
        _ = text_renderer;
        
        // TODO: Port the render() implementation from {name}.rs
        // 
        // GPUI patterns -> ZapUI:
        //   div().bg(rgb(0xNNNNNN))     -> renderer.clear(rgb(0xNNNNNN))
        //   div().size_8().bg(color)   -> quad(x, y, 32, color, border)
        //   .child("text")             -> text_renderer.draw(renderer, "text", x, y, color)
        //   format!("...", val)        -> std.fmt.bufPrint(&buf, "...", .{{val}})
        
        renderer.clear(0.2, 0.2, 0.2, 1.0);
        
        // Example quad:
        // const quads = [_]QuadInstance{{
        //     quad(100, 100, 32, red, white),
        // }};
        // renderer.drawQuads(&quads);
    }}
}};

// Helper: div().size(s).bg(bg).border_1().border_dashed().rounded_md().border_color(border)
fn quad(x: f32, y: f32, size: f32, bg: [4]f32, border: [4]f32) QuadInstance {{
    return .{{
        .bounds = .{{ x, y, size, size }},
        .background_color = bg,
        .border_color = border,
        .border_widths = .{{ 1, 1, 1, 1 }},
        .corner_radii = .{{ 6, 6, 6, 6 }},
        .border_style = .{{ 1, 0, 0, 0 }}, // dashed
        .content_mask = .{{ 0, 0, 0, 0 }},
    }};
}}

// ============================================================================
// Text Rendering (GPUI handles this internally)
// ============================================================================

const TextRenderer = struct {{
    srv: *d3d11.ID3D11ShaderResourceView,
    glyphs: [128]Glyph,
    atlas_size: f32,

    const Glyph = struct {{ x: u32, y: u32, w: u32, h: u32, bx: i32, by: i32, adv: i32 }};

    fn init(alloc: std.mem.Allocator, renderer: *D3D11Renderer) !TextRenderer {{
        const ft = try freetype.Library.init();
        defer ft.deinit();
        const face = try ft.initMemoryFace(@embedFile("LiberationSans-Regular.ttf"), 0);
        defer face.deinit();
        try face.setPixelSizes(0, 20);

        const size: u32 = 512;
        var data = try alloc.alloc(u8, size * size);
        defer alloc.free(data);
        @memset(data, 0);

        var glyphs = [_]Glyph{{.{{ .x = 0, .y = 0, .w = 0, .h = 0, .bx = 0, .by = 0, .adv = 0 }}}} ** 128;
        var px: u32 = 2;
        const py: u32 = 2;
        for (32..127) |c| {{
            const idx = face.getCharIndex(@intCast(c)) orelse continue;
            face.loadGlyph(idx, .{{ .render = true }}) catch continue;
            const g = face.handle.*.glyph;
            const bmp = &g.*.bitmap;
            if (bmp.width > 0 and bmp.rows > 0) {{
                const src: [*]const u8 = @ptrCast(bmp.buffer);
                const pitch: u32 = @intCast(if (bmp.pitch < 0) -bmp.pitch else bmp.pitch);
                for (0..bmp.rows) |row| {{
                    for (0..bmp.width) |col| {{
                        data[(py + row) * size + px + col] = src[row * pitch + col];
                    }}
                }}
                glyphs[c] = .{{
                    .x = px,
                    .y = py,
                    .w = bmp.width,
                    .h = bmp.rows,
                    .bx = g.*.bitmap_left,
                    .by = g.*.bitmap_top,
                    .adv = @intCast(g.*.advance.x >> 6),
                }};
                px += bmp.width + 2;
            }} else {{
                glyphs[c] = .{{ .x = 0, .y = 0, .w = 0, .h = 0, .bx = 0, .by = 0, .adv = @intCast(g.*.advance.x >> 6) }};
            }}
        }}

        var desc = std.mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
        desc.Width = size;
        desc.Height = size;
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Format = .R8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.Usage = .DEFAULT;
        desc.BindFlags = .{{ .SHADER_RESOURCE = 1 }};
        var sub = std.mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
        sub.pSysMem = data.ptr;
        sub.SysMemPitch = size;
        var tex: ?*d3d11.ID3D11Texture2D = null;
        _ = renderer.device.vtable.CreateTexture2D(renderer.device, &desc, &sub, @ptrCast(&tex));
        var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
        srv_desc.Format = .R8_UNORM;
        srv_desc.ViewDimension = ._SRV_DIMENSION_TEXTURE2D;
        srv_desc.Anonymous.Texture2D.MipLevels = 1;
        var srv: ?*d3d11.ID3D11ShaderResourceView = null;
        _ = renderer.device.vtable.CreateShaderResourceView(renderer.device, @ptrCast(tex), &srv_desc, @ptrCast(&srv));

        return .{{ .srv = srv.?, .glyphs = glyphs, .atlas_size = @floatFromInt(size) }};
    }}

    fn draw(self: *TextRenderer, renderer: *D3D11Renderer, str: []const u8, cx: f32, baseline: f32, color: [4]f32) void {{
        var w: f32 = 0;
        for (str) |c| {{
            if (c < 128) w += @floatFromInt(self.glyphs[c].adv);
        }}

        var sprites: [64]SpriteInstance = undefined;
        var n: usize = 0;
        var x = cx - w / 2;
        for (str) |c| {{
            if (c >= 128) continue;
            const g = self.glyphs[c];
            if (g.w > 0) {{
                const gw: f32 = @floatFromInt(g.w);
                const gh: f32 = @floatFromInt(g.h);
                sprites[n] = .{{
                    .bounds = .{{ x + @as(f32, @floatFromInt(g.bx)), baseline - @as(f32, @floatFromInt(g.by)), gw, gh }},
                    .uv_bounds = .{{
                        @as(f32, @floatFromInt(g.x)) / self.atlas_size,
                        @as(f32, @floatFromInt(g.y)) / self.atlas_size,
                        gw / self.atlas_size,
                        gh / self.atlas_size,
                    }},
                    .color = color,
                    .content_mask = .{{ 0, 0, 0, 0 }},
                }};
                n += 1;
            }}
            x += @floatFromInt(g.adv);
        }}
        if (n > 0) renderer.drawSprites(sprites[0..n], self.srv, true);
    }}
}};

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {{
    var platform = try Win32.init();
    defer platform.deinit();

    const window = try Win32.createWindow(&platform, .{{
        .width = {width},
        .height = {height},
        .title = "{title}",
    }});
    defer window.destroy();

    var renderer = try D3D11Renderer.init(std.heap.page_allocator, window.hwnd.?, {width}, {height});
    defer renderer.deinit();

    var text_renderer = try TextRenderer.init(std.heap.page_allocator, &renderer);

    var state = {class_name}{{}};

    while (!window.shouldClose()) {{
        for (window.pollEvents()) |e| {{
            switch (e) {{
                .key => |k| if (k.key == .escape) return,
                .resize => |r| renderer.resize(r.width, r.height) catch {{}},
                else => {{}},
            }}
        }}

        renderer.beginFrame();
        state.render(&renderer, &text_renderer);
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
    print(f"\n   Next steps:")
    print(f"   1. Add build target to build.zig")
    print(f"   2. Implement render() in {name}.zig")
    print(f"   3. make windows")
    print(f"   4. make capture-both EXAMPLE={name}")
    print(f"   5. make compare EXAMPLE={name}")


if __name__ == '__main__':
    main()
