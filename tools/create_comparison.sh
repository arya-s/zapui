#!/bin/bash
# Create comparison images and regenerate HTML report
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

# Regenerate HTML report with actual code
echo ""
echo "Regenerating report.html..."

ZIG_FILE="$EXAMPLE_DIR/$EXAMPLE.zig"
RS_FILE="$EXAMPLE_DIR/$EXAMPLE.rs"
REPORT_FILE="$EXAMPLE_DIR/report.html"

if [ -f "$ZIG_FILE" ] && [ -f "$RS_FILE" ]; then
    /usr/bin/python3 - "$EXAMPLE" "$RS_FILE" "$ZIG_FILE" "$REPORT_FILE" << 'PYTHON_SCRIPT'
import sys
import html

name = sys.argv[1]
rs_file = sys.argv[2]
zig_file = sys.argv[3]
report_file = sys.argv[4]

with open(rs_file, 'r') as f:
    rust_code = f.read()

with open(zig_file, 'r') as f:
    zig_code = f.read()

title = name.replace('_', ' ').title()
rust_escaped = html.escape(rust_code)
zig_escaped = html.escape(zig_code)

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
        code {{ font-family: 'Fira Code', 'Consolas', monospace; }}
        
        .rust {{ border-left: 3px solid #dea584; }}
        .zig {{ border-left: 3px solid #f7a41d; }}
        
        .stats {{ display: flex; gap: 20px; flex-wrap: wrap; }}
        .stat {{ background: #333; padding: 10px 20px; border-radius: 4px; }}
        .stat-value {{ font-size: 24px; font-weight: bold; color: #3b82f6; }}
        .stat-label {{ font-size: 12px; color: #888; }}
        
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
PYTHON_SCRIPT
fi

echo ""
echo "=== Results ==="
ls -la "$SCREENSHOTS_DIR/"

echo ""
echo "Open report.html in browser to view comparison"
