#!/bin/bash
# Screenshot comparison tool for GPUI vs ZapUI examples
#
# Usage:
#   ./compare_screenshots.sh <example_name>
#   ./compare_screenshots.sh hello_world
#
# Screenshots are saved to examples/gpui_ports/<name>/screenshots/

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"

# Create directories if needed
mkdir -p "$SCREENSHOTS_DIR"

echo "=== Screenshot Comparison: $EXAMPLE ==="
echo "Output directory: $SCREENSHOTS_DIR"
echo ""

# Function to take screenshot of active window
take_screenshot() {
    local name=$1
    local output="$SCREENSHOTS_DIR/${name}.png"
    
    # Wait for window to appear
    sleep 1.5
    
    # Try different screenshot tools
    if command -v scrot &> /dev/null; then
        scrot -u "$output" 2>/dev/null || scrot "$output"
    elif command -v gnome-screenshot &> /dev/null; then
        gnome-screenshot -w -f "$output"
    elif command -v import &> /dev/null; then
        import -window root "$output"
    else
        echo "No screenshot tool found. Install scrot, gnome-screenshot, or imagemagick."
        return 1
    fi
    
    echo "Screenshot saved: $output"
}

# Build and run ZapUI version
echo "=== Building ZapUI $EXAMPLE ==="
cd "$ZAPUI_DIR"

# Check for the example in different locations
if [ -f "examples/gpui_ports/$EXAMPLE/$EXAMPLE.zig" ]; then
    ZIG_FILE="examples/gpui_ports/$EXAMPLE/$EXAMPLE.zig"
elif [ -f "playground/$EXAMPLE.zig" ]; then
    ZIG_FILE="playground/$EXAMPLE.zig"
elif [ "$EXAMPLE" = "hello_world" ]; then
    ZIG_FILE="playground/hello_world.zig"
else
    echo "ZapUI example not found for: $EXAMPLE"
    echo "Run: make port-gpui EXAMPLE=$EXAMPLE"
    exit 1
fi

echo "Using: $ZIG_FILE"

# Try to build the specific example, fall back to hello-world
if zig build "$EXAMPLE" 2>/dev/null; then
    ZAPUI_BIN="zig-out/bin/$EXAMPLE"
elif zig build hello-world 2>/dev/null; then
    ZAPUI_BIN="zig-out/bin/hello_world"
    echo "Note: Using hello_world as fallback"
else
    echo "Build failed"
    exit 1
fi

echo ""
echo "=== Running ZapUI ==="
echo "Window will open. Press Enter here when ready to capture screenshot..."
$ZAPUI_BIN &
ZAPUI_PID=$!

read -r
take_screenshot "zapui"
kill $ZAPUI_PID 2>/dev/null || true
wait $ZAPUI_PID 2>/dev/null || true

echo ""
echo "=== GPUI (Rust) ==="
echo "To capture GPUI screenshot:"
echo "  1. Build and run GPUI example on Windows/macOS"
echo "  2. Take screenshot manually"
echo "  3. Save to: $SCREENSHOTS_DIR/gpui.png"
echo ""

# Check if GPUI screenshot exists for comparison
ZAPUI_IMG="$SCREENSHOTS_DIR/zapui.png"
GPUI_IMG="$SCREENSHOTS_DIR/gpui.png"

if [ -f "$ZAPUI_IMG" ] && [ -f "$GPUI_IMG" ]; then
    echo "=== Creating Comparison ==="
    
    if command -v convert &> /dev/null; then
        SIDE_BY_SIDE="$SCREENSHOTS_DIR/comparison.png"
        DIFF_IMG="$SCREENSHOTS_DIR/diff.png"
        
        # Create side-by-side (GPUI left, ZapUI right)
        convert "$GPUI_IMG" "$ZAPUI_IMG" +append -background white -splice 10x0+50%+0 "$SIDE_BY_SIDE" 2>/dev/null || \
        convert "$GPUI_IMG" "$ZAPUI_IMG" +append "$SIDE_BY_SIDE"
        
        echo "Side-by-side: $SIDE_BY_SIDE"
        
        # Create diff image
        compare "$GPUI_IMG" "$ZAPUI_IMG" "$DIFF_IMG" 2>/dev/null && echo "Diff image: $DIFF_IMG" || true
    else
        echo "Install ImageMagick for automatic comparison images"
    fi
fi

echo ""
echo "=== Done ==="
echo "Screenshots in: $SCREENSHOTS_DIR/"
ls -la "$SCREENSHOTS_DIR/" 2>/dev/null || true
