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
    
    # Side-by-side (GPUI left, ZapUI right)
    SIDE_BY_SIDE="$SCREENSHOTS_DIR/comparison.png"
    convert "$GPUI_IMG" "$ZAPUI_IMG" +append \
        -background white -splice 10x0+50%+0 \
        "$SIDE_BY_SIDE" 2>/dev/null || \
    convert "$GPUI_IMG" "$ZAPUI_IMG" +append "$SIDE_BY_SIDE"
    echo "✅ Created: comparison.png (side-by-side)"
    
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

echo ""
echo "=== Results ==="
ls -la "$SCREENSHOTS_DIR/"

echo ""
echo "View the comparison:"
echo "  - comparison.png: Side-by-side (GPUI | ZapUI)"
echo "  - diff.png: Pixel differences"
echo "  - toggle.gif: Animated toggle between both"
