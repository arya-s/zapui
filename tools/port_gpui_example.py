#!/usr/bin/env python3
"""
GPUI Example Porter - Helps port GPUI Rust examples to ZapUI Zig

Usage:
    ./port_gpui_example.py <example_name>
    ./port_gpui_example.py hello_world
    ./port_gpui_example.py --list

This tool:
1. Downloads the GPUI example source
2. Generates a Zig translation skeleton
3. Highlights areas needing manual translation
"""

import sys
import re
import urllib.request
import json

GPUI_EXAMPLES_URL = "https://raw.githubusercontent.com/zed-industries/zed/main/crates/gpui/examples"
GPUI_API_URL = "https://api.github.com/repos/zed-industries/zed/contents/crates/gpui/examples"

# Translation patterns from Rust to Zig
TRANSLATIONS = {
    # Method calls
    r'\.flex\(\)': '.flex()',
    r'\.flex_col\(\)': '.flex_col()',
    r'\.flex_row\(\)': '.flex_row()',
    r'\.gap_(\d+)\(\)': r'.gap_\1()',
    r'\.gap\(px\(([^)]+)\)\)': r'.gap(px(\1))',
    r'\.bg\(rgb\(0x([0-9a-fA-F]+)\)\)': r'.bg(zapui.rgb(0x\1))',
    r'\.bg\(gpui::(\w+)\(\)\)': r'.bg(\1)',
    r'\.size\(px\(([^)]+)\)\)': r'.size(px(\1))',
    r'\.size_(\d+)\(\)': r'.size_\1()',
    r'\.w\(px\(([^)]+)\)\)': r'.w(px(\1))',
    r'\.h\(px\(([^)]+)\)\)': r'.h(px(\1))',
    r'\.w_full\(\)': '.w_full()',
    r'\.h_full\(\)': '.h_full()',
    r'\.justify_center\(\)': '.justify_center()',
    r'\.items_center\(\)': '.items_center()',
    r'\.shadow_lg\(\)': '.shadow_lg()',
    r'\.shadow_md\(\)': '.shadow_md()',
    r'\.shadow_sm\(\)': '.shadow_sm()',
    r'\.border_(\d+)\(\)': r'.border_\1()',
    r'\.border_color\(rgb\(0x([0-9a-fA-F]+)\)\)': r'.border_color(zapui.rgb(0x\1))',
    r'\.border_color\(gpui::(\w+)\(\)\)': r'.border_color(\1)',
    r'\.border_dashed\(\)': '.border_dashed()',
    r'\.rounded_md\(\)': '.rounded_md()',
    r'\.rounded_lg\(\)': '.rounded_lg()',
    r'\.rounded_full\(\)': '.rounded_full()',
    r'\.rounded\(px\(([^)]+)\)\)': r'.rounded(px(\1))',
    r'\.text_xl\(\)': '.text_xl()',
    r'\.text_lg\(\)': '.text_lg()',
    r'\.text_sm\(\)': '.text_sm()',
    r'\.text_color\(rgb\(0x([0-9a-fA-F]+)\)\)': r'.text_color(zapui.rgb(0x\1))',
    r'\.text_color\(gpui::(\w+)\(\)\)': r'.text_color(\1)',
    r'\.p_(\d+)\(\)': r'.p_\1()',
    r'\.px_(\d+)\(\)': r'.px_\1()',
    r'\.py_(\d+)\(\)': r'.py_\1()',
    r'\.m_(\d+)\(\)': r'.m_\1()',
    r'\.overflow_hidden\(\)': '.overflow_hidden()',
    
    # GPUI colors to constants
    r'gpui::red\(\)': 'red',
    r'gpui::green\(\)': 'green', 
    r'gpui::blue\(\)': 'blue',
    r'gpui::yellow\(\)': 'yellow',
    r'gpui::black\(\)': 'black',
    r'gpui::white\(\)': 'white',
    
    # div() calls
    r'\bdiv\(\)': 'div()',
}

# Features that need manual attention
UNSUPPORTED_FEATURES = [
    (r'\.on_click\(', 'Event handlers need manual implementation'),
    (r'\.on_mouse_', 'Mouse events need manual implementation'),
    (r'\.child\([^)]*format!', 'Format strings: use std.fmt.bufPrint'),
    (r'\.child\("([^"]+)"\)', 'String children: wrap with div().child_text()'),
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
        'div_chains': [],
        'colors': set(),
        'features_used': set(),
    }
    
    # Find unsupported features
    for pattern, message in UNSUPPORTED_FEATURES:
        if re.search(pattern, rust_code):
            analysis['warnings'].append(message)
            analysis['features_used'].add(pattern)
    
    # Extract div() chains
    div_pattern = r'div\(\)[^;{]+(?=[\s;{])'
    for match in re.finditer(div_pattern, rust_code, re.DOTALL):
        analysis['div_chains'].append(match.group(0))
    
    # Extract colors
    color_pattern = r'rgb\(0x([0-9a-fA-F]+)\)'
    for match in re.finditer(color_pattern, rust_code):
        analysis['colors'].add(match.group(1))
    
    gpui_colors = r'gpui::(\w+)\(\)'
    for match in re.finditer(gpui_colors, rust_code):
        analysis['colors'].add(match.group(1))
    
    return analysis


def translate_div_chain(rust_chain: str) -> str:
    """Translate a Rust div() chain to Zig"""
    zig_chain = rust_chain
    
    for pattern, replacement in TRANSLATIONS.items():
        zig_chain = re.sub(pattern, replacement, zig_chain)
    
    # Handle .child() calls - these need special attention
    # Simple string children need wrapping
    zig_chain = re.sub(
        r'\.child\("([^"]+)"\)',
        r'.child(div().child_text("\1"))',
        zig_chain
    )
    
    return zig_chain


def generate_zig_skeleton(name: str, rust_code: str, analysis: dict) -> str:
    """Generate a Zig skeleton from analyzed Rust code"""
    
    # Extract colors used
    color_defs = []
    for color in sorted(analysis['colors']):
        if color in ['red', 'green', 'blue', 'yellow', 'black', 'white']:
            if color == 'green':
                color_defs.append(f"const {color} = zapui.hsla(0.333, 1.0, 0.25, 1.0);  // GPUI's {color}()")
            else:
                color_defs.append(f"const {color} = zapui.{color}();")
        else:
            color_defs.append(f"const color_{color} = zapui.rgb(0x{color});")
    
    colors_section = '\n'.join(color_defs) if color_defs else "// No colors extracted"
    
    # Translate div chains
    translated_chains = []
    for chain in analysis['div_chains'][:5]:  # Limit to first 5 for skeleton
        translated = translate_div_chain(chain)
        translated_chains.append(f"    // Translated from Rust:\n    // {chain[:80]}...\n    const elem = {translated};")
    
    chains_section = '\n\n'.join(translated_chains) if translated_chains else "    // No div chains extracted"
    
    # Warnings section
    if analysis['warnings']:
        warnings = '\n'.join(f"//   - {w}" for w in set(analysis['warnings']))
    else:
        warnings = "//   None - this example should be straightforward to port!"
    
    return f'''//! {name.replace('_', ' ').title()} - Port of GPUI's {name}.rs example
//!
//! Auto-generated skeleton by port_gpui_example.py
//! Manual adjustments needed - see warnings below.

const std = @import("std");
const zapui = @import("zapui");
const zglfw = @import("zglfw");

const GlRenderer = zapui.GlRenderer;
const TextSystem = zapui.TextSystem;
const Scene = zapui.Scene;
const zaffy = zapui.zaffy;
const Pixels = zapui.Pixels;

// GPUI-style API
const div = zapui.elements.div.div;
const v_flex = zapui.elements.div.v_flex;
const h_flex = zapui.elements.div.h_flex;
const reset = zapui.elements.div.reset;
const px = zapui.elements.div.px;

// ============================================================================
// Colors extracted from GPUI example
// ============================================================================

{colors_section}

// ============================================================================
// WARNINGS - Features needing manual implementation:
// ============================================================================
{warnings}

// ============================================================================
// Render Function
// ============================================================================

fn render(tree: *zaffy.Zaffy, scene: *Scene, text_system: *TextSystem) !void {{
    reset();
    const rem: Pixels = 16.0;

    // TODO: Translate the render logic from Rust
    // Original div chains (auto-translated, may need fixes):
    
{chains_section}

    // Build and paint
    // try root.buildWithTextSystem(tree, rem, text_system);
    // tree.computeLayoutWithSize(root.node_id.?, WIDTH, HEIGHT);
    // root.paint(scene, text_system, 0, 0, tree, null, null);
}}

// ============================================================================
// Main
// ============================================================================

const WIDTH: f32 = 800;
const HEIGHT: f32 = 600;

pub fn main() !void {{
    zglfw.init() catch return;
    defer zglfw.terminate();

    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);

    const window = zglfw.Window.create(@intFromFloat(WIDTH), @intFromFloat(HEIGHT), "{name.replace('_', ' ').title()} - ZapUI", null, null) catch return;
    defer window.destroy();

    zglfw.makeContextCurrent(window);
    zglfw.swapInterval(1);

    zapui.renderer.gl.loadGlFunctions(zglfw.getProcAddress) catch return;

    const allocator = std.heap.page_allocator;
    var renderer = try GlRenderer.init(allocator);
    defer renderer.deinit();

    var text_system = TextSystem.init(allocator) catch return;
    defer text_system.deinit();
    _ = text_system.loadFontFile("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf") catch return;
    text_system.setAtlas(renderer.getGlyphAtlas());
    text_system.setColorAtlas(renderer.getColorAtlas());

    while (!window.shouldClose()) {{
        zglfw.pollEvents();
        if (window.getKey(.escape) == .press) break;

        const fb_size = window.getFramebufferSize();
        renderer.setViewport(@floatFromInt(fb_size[0]), @floatFromInt(fb_size[1]), 1.0);
        renderer.clear(zapui.rgb(0x1a1a1a));

        var scene = Scene.init(allocator);
        defer scene.deinit();

        var tree = zaffy.Zaffy.init(allocator);
        defer tree.deinit();

        render(&tree, &scene, &text_system) catch |err| {{
            std.debug.print("Render error: {{}}\\n", .{{err}});
        }};

        renderer.drawScene(&scene) catch {{}};
        window.swapBuffers();
    }}
}}

// ============================================================================
// Original Rust Source (for reference)
// ============================================================================
//
// View the original at:
// https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/{name}.rs
//
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
    print(f"  - Div chains found: {len(analysis['div_chains'])}")
    print(f"  - Colors used: {len(analysis['colors'])}")
    print(f"  - Warnings: {len(analysis['warnings'])}")
    
    if analysis['warnings']:
        print("\nWarnings (features needing manual work):")
        for w in set(analysis['warnings']):
            print(f"  ⚠️  {w}")
    
    zig_code = generate_zig_skeleton(name, rust_code, analysis)
    
    output_file = f"playground/{name}.zig"
    print(f"\nGenerating: {output_file}")
    
    with open(output_file, 'w') as f:
        f.write(zig_code)
    
    print(f"\n✅ Generated {output_file}")
    print(f"   Edit the file and add to build.zig to compile.")
    print(f"\n   View original Rust: https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/{name}.rs")


if __name__ == '__main__':
    main()
