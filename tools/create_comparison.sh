#!/bin/bash
# Create comparison images and regenerate HTML report with code analysis
#
# Usage:
#   ./create_comparison.sh <example_name>
#   ./create_comparison.sh hello_world

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"

echo "=== Creating Comparison for: $EXAMPLE ==="
echo ""

ZAPUI_IMG="$SCREENSHOTS_DIR/zapui.png"
GPUI_IMG="$SCREENSHOTS_DIR/gpui.png"

# Check for screenshots
if [ ! -f "$ZAPUI_IMG" ]; then
    echo "❌ Missing: zapui.png"
    echo "   Run: make capture EXAMPLE=$EXAMPLE"
    exit 1
fi

if [ ! -f "$GPUI_IMG" ]; then
    echo "❌ Missing: gpui.png"
    echo "   Run: make capture-gpui EXAMPLE=$EXAMPLE"
    exit 1
fi

echo "✅ Found: zapui.png"
echo "✅ Found: gpui.png"
echo ""

# Create comparison images with ImageMagick
if command -v convert &> /dev/null; then
    echo "Creating comparison images..."
    
    # Diff image
    DIFF_IMG="$SCREENSHOTS_DIR/diff.png"
    compare "$GPUI_IMG" "$ZAPUI_IMG" "$DIFF_IMG" 2>/dev/null && \
        echo "✅ Created: diff.png" || \
        echo "⚠️  Could not create diff (images may be different sizes)"
    
    # Animated GIF toggle
    GIF_IMG="$SCREENSHOTS_DIR/toggle.gif"
    convert -delay 100 "$GPUI_IMG" "$ZAPUI_IMG" -loop 0 "$GIF_IMG" 2>/dev/null && \
        echo "✅ Created: toggle.gif" || \
        echo "⚠️  Could not create toggle GIF"
else
    echo "⚠️  ImageMagick not installed (sudo apt install imagemagick)"
fi

# Regenerate HTML report with actual code and analysis
echo ""
echo "Regenerating report.html with code analysis..."

ZIG_FILE="$EXAMPLE_DIR/$EXAMPLE.zig"
RS_FILE="$EXAMPLE_DIR/$EXAMPLE.rs"
REPORT_FILE="$EXAMPLE_DIR/report.html"

if [ -f "$ZIG_FILE" ] && [ -f "$RS_FILE" ]; then
    /usr/bin/python3 - "$EXAMPLE" "$RS_FILE" "$ZIG_FILE" "$REPORT_FILE" << 'PYTHON_SCRIPT'
import sys
import html
import re

name = sys.argv[1]
rs_file = sys.argv[2]
zig_file = sys.argv[3]
report_file = sys.argv[4]

with open(rs_file, 'r') as f:
    rust_code = f.read()

with open(zig_file, 'r') as f:
    zig_code = f.read()

# =============================================================================
# UI Code Analysis
# =============================================================================

def extract_ui_methods(code, lang):
    """Extract UI method calls from code"""
    # Common div/styling methods
    methods = set()
    
    # Pattern for method calls like .method() or .method(args)
    if lang == 'rust':
        pattern = r'\.([a-z_][a-z_0-9]*)\s*\('
    else:  # zig
        pattern = r'\.([a-z_][a-z_0-9]*)\s*\('
    
    for match in re.finditer(pattern, code, re.IGNORECASE):
        method = match.group(1)
        # Filter to UI-related methods
        ui_methods = [
            'div', 'flex', 'flex_col', 'flex_row', 'gap', 'gap_1', 'gap_2', 'gap_3', 'gap_4',
            'bg', 'size', 'size_full', 'size_8', 'w', 'h', 'w_full', 'h_full',
            'justify_center', 'justify_start', 'justify_end', 'justify_between',
            'items_center', 'items_start', 'items_end',
            'text_xl', 'text_lg', 'text_sm', 'text_xs', 'text_color', 'text_size',
            'child', 'child_text', 'children',
            'border', 'border_1', 'border_2', 'border_color', 'border_dashed',
            'rounded', 'rounded_md', 'rounded_lg', 'rounded_full',
            'p', 'px', 'py', 'pt', 'pb', 'pl', 'pr', 'padding',
            'm', 'mx', 'my', 'mt', 'mb', 'ml', 'mr', 'margin',
            'shadow', 'shadow_lg', 'shadow_md',
            'overflow_hidden', 'overflow_visible',
            'absolute', 'relative', 'top', 'left', 'right', 'bottom',
        ]
        if method in ui_methods:
            methods.add(method)
    
    return methods

def extract_colors(code, lang):
    """Extract color usage from code"""
    colors = set()
    
    # Hex colors
    hex_pattern = r'rgb\(0x([0-9a-fA-F]+)\)'
    for match in re.finditer(hex_pattern, code):
        colors.add(f"0x{match.group(1)}")
    
    # Named colors
    if lang == 'rust':
        named_pattern = r'gpui::(\w+)\(\)'
    else:
        named_pattern = r'\b(red|green|blue|yellow|black|white|transparent)\(\)'
    
    for match in re.finditer(named_pattern, code):
        color = match.group(1)
        if color in ['red', 'green', 'blue', 'yellow', 'black', 'white', 'transparent']:
            colors.add(color)
    
    return colors

def extract_render_code(code, lang):
    """Extract just the render/UI building code"""
    lines = []
    in_render = False
    brace_depth = 0
    
    for line in code.split('\n'):
        # Detect start of render function
        if lang == 'rust' and 'fn render(' in line:
            in_render = True
        elif lang == 'zig' and 'fn render(' in line:
            in_render = True
        
        if in_render:
            lines.append(line)
            brace_depth += line.count('{') - line.count('}')
            if brace_depth <= 0 and len(lines) > 1:
                break
    
    return '\n'.join(lines)

def normalize_method_chain(code):
    """Normalize a method chain for comparison"""
    # Remove whitespace and newlines
    code = re.sub(r'\s+', '', code)
    # Normalize parentheses content
    code = re.sub(r'\([^)]*\)', '()', code)
    return code

def find_method_chains(code):
    """Find div() method chains"""
    chains = []
    # Find div() followed by chained methods
    pattern = r'div\(\)(?:\.[a-z_0-9]+\([^)]*\))*'
    for match in re.finditer(pattern, code, re.IGNORECASE | re.DOTALL):
        chain = match.group(0)
        # Count methods in chain
        methods = re.findall(r'\.([a-z_0-9]+)\(', chain)
        if methods:
            chains.append({
                'raw': chain[:100] + '...' if len(chain) > 100 else chain,
                'methods': methods,
                'count': len(methods)
            })
    return chains

# Extract UI code
rust_render = extract_render_code(rust_code, 'rust')
zig_render = extract_render_code(zig_code, 'zig')

rust_methods = extract_ui_methods(rust_code, 'rust')
zig_methods = extract_ui_methods(zig_code, 'zig')

rust_colors = extract_colors(rust_code, 'rust')
zig_colors = extract_colors(zig_code, 'zig')

# Calculate overlap
common_methods = rust_methods & zig_methods
rust_only = rust_methods - zig_methods
zig_only = zig_methods - rust_methods

common_colors = rust_colors & zig_colors

# Method chains analysis
rust_chains = find_method_chains(rust_code)
zig_chains = find_method_chains(zig_code)

# Calculate similarity score
if rust_methods or zig_methods:
    method_similarity = len(common_methods) / len(rust_methods | zig_methods) * 100
else:
    method_similarity = 100

if rust_colors or zig_colors:
    color_similarity = len(common_colors) / len(rust_colors | zig_colors) * 100
else:
    color_similarity = 100

overall_similarity = (method_similarity + color_similarity) / 2

# =============================================================================
# Generate HTML
# =============================================================================

title = name.replace('_', ' ').title()
rust_escaped = html.escape(rust_code)
zig_escaped = html.escape(zig_code)
rust_render_escaped = html.escape(rust_render)
zig_render_escaped = html.escape(zig_render)

# Format method lists
def format_method_list(methods):
    if not methods:
        return '<em>None</em>'
    return ', '.join(f'<code>.{m}()</code>' for m in sorted(methods))

def format_color_list(colors):
    if not colors:
        return '<em>None</em>'
    result = []
    for c in sorted(colors):
        if c.startswith('0x'):
            hex_val = c[2:].zfill(6)
            result.append(f'<span style="display:inline-block;width:12px;height:12px;background:#{hex_val};border:1px solid #666;vertical-align:middle;margin-right:4px;"></span><code>{c}</code>')
        else:
            color_map = {'red':'#ff0000','green':'#00ff00','blue':'#0000ff','yellow':'#ffff00','black':'#000000','white':'#ffffff'}
            hex_val = color_map.get(c, '#888888')
            result.append(f'<span style="display:inline-block;width:12px;height:12px;background:{hex_val};border:1px solid #666;vertical-align:middle;margin-right:4px;"></span><code>{c}()</code>')
    return ', '.join(result)

report = f'''<!DOCTYPE html>
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
        
        .screenshot {{ max-width: 100%; border-radius: 4px; border: 1px solid #444; }}
        .screenshot-container {{ text-align: center; }}
        .screenshot-container img {{ max-height: 400px; object-fit: contain; }}
        
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
        code {{ font-family: 'Fira Code', 'Consolas', monospace; background: #333; padding: 2px 6px; border-radius: 3px; }}
        pre code {{ background: none; padding: 0; }}
        
        .rust {{ border-left: 3px solid #dea584; }}
        .zig {{ border-left: 3px solid #f7a41d; }}
        
        .stats {{ display: flex; gap: 20px; flex-wrap: wrap; }}
        .stat {{ background: #333; padding: 10px 20px; border-radius: 4px; }}
        .stat-value {{ font-size: 24px; font-weight: bold; color: #3b82f6; }}
        .stat-label {{ font-size: 12px; color: #888; }}
        .stat-value.green {{ color: #4ade80; }}
        .stat-value.yellow {{ color: #facc15; }}
        .stat-value.red {{ color: #f87171; }}
        
        .analysis-table {{ width: 100%; border-collapse: collapse; }}
        .analysis-table th, .analysis-table td {{ padding: 10px; text-align: left; border-bottom: 1px solid #333; }}
        .analysis-table th {{ color: #888; font-weight: normal; }}
        .analysis-table td {{ color: #e0e0e0; }}
        
        .method-list {{ line-height: 2; }}
        .match {{ color: #4ade80; }}
        .mismatch {{ color: #f87171; }}
        
        .progress-bar {{ 
            background: #333; 
            border-radius: 4px; 
            height: 8px; 
            overflow: hidden;
            margin-top: 5px;
        }}
        .progress-fill {{ 
            height: 100%; 
            background: linear-gradient(90deg, #4ade80, #3b82f6);
            transition: width 0.3s;
        }}
        
        a {{ color: #3b82f6; }}
        
        @media (max-width: 900px) {{ .grid, .grid-3 {{ grid-template-columns: 1fr; }} }}
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
            <div class="stat-value {'green' if overall_similarity >= 80 else 'yellow' if overall_similarity >= 50 else 'red'}">{overall_similarity:.0f}%</div>
            <div class="stat-label">API Similarity</div>
        </div>
        <div class="stat">
            <div class="stat-value">{len(common_methods)}/{len(rust_methods | zig_methods)}</div>
            <div class="stat-label">Shared Methods</div>
        </div>
    </div>
    
    <h2>📸 Screenshots</h2>
    <div class="grid-3">
        <div class="card screenshot-container">
            <h3>GPUI (Rust)</h3>
            <img src="screenshots/gpui.png" alt="GPUI" class="screenshot">
        </div>
        <div class="card screenshot-container">
            <h3>ZapUI (Zig)</h3>
            <img src="screenshots/zapui.png" alt="ZapUI" class="screenshot">
        </div>
        <div class="card screenshot-container">
            <h3>Difference</h3>
            <img src="screenshots/diff.png" alt="Diff" class="screenshot">
        </div>
    </div>
    
    <h2>🔄 Animated Comparison</h2>
    <div class="card screenshot-container">
        <img src="screenshots/toggle.gif" alt="Toggle" class="screenshot">
    </div>
    
    <h2>🔍 UI Code Analysis</h2>
    
    <div class="grid">
        <div class="card">
            <h3>Method Similarity: {method_similarity:.0f}%</h3>
            <div class="progress-bar"><div class="progress-fill" style="width:{method_similarity}%"></div></div>
            <table class="analysis-table" style="margin-top:15px">
                <tr>
                    <th>Category</th>
                    <th>Methods</th>
                </tr>
                <tr>
                    <td class="match">✓ Both use</td>
                    <td class="method-list">{format_method_list(common_methods)}</td>
                </tr>
                <tr>
                    <td class="mismatch">Rust only</td>
                    <td class="method-list">{format_method_list(rust_only)}</td>
                </tr>
                <tr>
                    <td class="mismatch">Zig only</td>
                    <td class="method-list">{format_method_list(zig_only)}</td>
                </tr>
            </table>
        </div>
        
        <div class="card">
            <h3>Color Similarity: {color_similarity:.0f}%</h3>
            <div class="progress-bar"><div class="progress-fill" style="width:{color_similarity}%"></div></div>
            <table class="analysis-table" style="margin-top:15px">
                <tr>
                    <th>Category</th>
                    <th>Colors</th>
                </tr>
                <tr>
                    <td class="match">✓ Both use</td>
                    <td class="method-list">{format_color_list(common_colors)}</td>
                </tr>
                <tr>
                    <td>Rust colors</td>
                    <td class="method-list">{format_color_list(rust_colors)}</td>
                </tr>
                <tr>
                    <td>Zig colors</td>
                    <td class="method-list">{format_color_list(zig_colors)}</td>
                </tr>
            </table>
        </div>
    </div>
    
    <h2>🎯 Render Function Comparison</h2>
    <div class="grid">
        <div class="card">
            <h3>Rust render()</h3>
            <pre class="rust"><code>{rust_render_escaped}</code></pre>
        </div>
        <div class="card">
            <h3>Zig render()</h3>
            <pre class="zig"><code>{zig_render_escaped}</code></pre>
        </div>
    </div>
    
    <h2>📝 Full Source Code</h2>
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
    
    <h2>🔗 Links</h2>
    <ul>
        <li><a href="https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/{name}.rs" target="_blank">Original GPUI Source</a></li>
        <li><a href="{name}.zig">ZapUI Port Source</a></li>
    </ul>
</body>
</html>
'''

with open(report_file, 'w') as f:
    f.write(report)

print(f"✅ Generated: report.html")
print(f"   API Similarity: {overall_similarity:.0f}%")
print(f"   Methods: {len(common_methods)} shared, {len(rust_only)} Rust-only, {len(zig_only)} Zig-only")
print(f"   Colors: {len(common_colors)} shared")
PYTHON_SCRIPT
fi

echo ""
echo "=== Results ==="
ls -la "$SCREENSHOTS_DIR/"

echo ""
echo "Open report.html in browser to view comparison"
