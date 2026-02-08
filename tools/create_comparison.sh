#!/bin/bash
# Create comparison image from captured screenshots
#
# Usage:
#   ./create_comparison.sh <example_name>
#   ./create_comparison.sh hello_world
#
# Run this after capturing screenshots with ShareX on Windows

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"

echo "=== Creating Comparison for: $EXAMPLE ==="
echo "Screenshots dir: $SCREENSHOTS_DIR"
echo ""

ZAPUI_IMG="$SCREENSHOTS_DIR/zapui.png"
GPUI_IMG="$SCREENSHOTS_DIR/gpui.png"

# Check for screenshots
if [ ! -f "$ZAPUI_IMG" ]; then
    echo "❌ Missing: zapui.png"
    echo "   Run compare_windows.bat on Windows first"
    exit 1
fi

if [ ! -f "$GPUI_IMG" ]; then
    echo "❌ Missing: gpui.png"
    echo "   Capture GPUI screenshot with ShareX and save as gpui.png"
    exit 1
fi

echo "✅ Found: zapui.png"
echo "✅ Found: gpui.png"
echo ""

# Create comparison images
if command -v convert &> /dev/null; then
    echo "Creating comparison images..."
    
    # Diff image
    DIFF_IMG="$SCREENSHOTS_DIR/diff.png"
    compare "$GPUI_IMG" "$ZAPUI_IMG" "$DIFF_IMG" 2>/dev/null && \
        echo "✅ Created: diff.png (differences highlighted)" || \
        echo "⚠️  Could not create diff (images may be different sizes)"
    
    # Animated GIF toggle
    GIF_IMG="$SCREENSHOTS_DIR/toggle.gif"
    convert -delay 100 "$GPUI_IMG" "$ZAPUI_IMG" -loop 0 "$GIF_IMG" 2>/dev/null && \
        echo "✅ Created: toggle.gif (animated toggle)" || \
        echo "⚠️  Could not create toggle GIF"
    
else
    echo "⚠️  ImageMagick not installed"
    echo "   Install with: sudo apt install imagemagick"
    echo "   Skipping comparison image generation"
fi

# Update REPORT.md with screenshot links
REPORT_FILE="$EXAMPLE_DIR/REPORT.md"
if [ -f "$REPORT_FILE" ]; then
    echo ""
    echo "Updating REPORT.md with screenshots..."
    
    # Check if screenshots section already has images
    if ! grep -q "!\[GPUI\]" "$REPORT_FILE" 2>/dev/null; then
        # Replace the screenshots section
        sed -i 's|## Screenshots.*|## Screenshots\n\n### GPUI (Rust)\n\n![GPUI](screenshots/gpui.png)\n\n### ZapUI (Zig)\n\n![ZapUI](screenshots/zapui.png)\n\n### Animated Toggle\n\n![Toggle](screenshots/toggle.gif)\n\n### Pixel Diff\n\n![Diff](screenshots/diff.png)|' "$REPORT_FILE" 2>/dev/null || true
    fi
fi

echo ""
echo "=== Results ==="
ls -la "$SCREENSHOTS_DIR/"

echo ""
echo "View the comparison in REPORT.md or:"
echo "  - diff.png: Pixel differences"
echo "  - toggle.gif: Animated toggle between both"
