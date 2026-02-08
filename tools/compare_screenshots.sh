#!/bin/bash
# Screenshot comparison tool for GPUI vs ZapUI examples
#
# Usage:
#   ./compare_screenshots.sh <example_name>
#   ./compare_screenshots.sh hello_world
#
# Prerequisites:
#   - Rust/Cargo for GPUI
#   - Zig for ZapUI  
#   - scrot or gnome-screenshot for capturing
#   - ImageMagick for comparison

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$ZAPUI_DIR/screenshots"
GPUI_CLONE_DIR="/tmp/zed-gpui"

mkdir -p "$SCREENSHOTS_DIR"

echo "=== Screenshot Comparison: $EXAMPLE ==="
echo ""

# Function to take screenshot of active window
take_screenshot() {
    local name=$1
    local output="$SCREENSHOTS_DIR/${EXAMPLE}_${name}.png"
    
    # Wait for window to appear
    sleep 1
    
    # Try different screenshot tools
    if command -v scrot &> /dev/null; then
        # scrot can capture the focused window
        scrot -u "$output" || scrot "$output"
    elif command -v gnome-screenshot &> /dev/null; then
        gnome-screenshot -w -f "$output"
    elif command -v import &> /dev/null; then
        # ImageMagick import
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

if [ -f "playground/${EXAMPLE}.zig" ]; then
    # Check if there's a build target for it
    if grep -q "\"$EXAMPLE\"" build.zig; then
        zig build "$EXAMPLE" 2>/dev/null || zig build hello-world
        ZAPUI_BIN="zig-out/bin/$EXAMPLE"
    else
        # Use hello-world as fallback
        zig build hello-world
        ZAPUI_BIN="zig-out/bin/hello_world"
    fi
else
    echo "ZapUI example not found: playground/${EXAMPLE}.zig"
    echo "Using hello_world instead"
    zig build hello-world
    ZAPUI_BIN="zig-out/bin/hello_world"
fi

echo ""
echo "=== Running ZapUI ==="
echo "Press any key when the window is visible to take screenshot..."
$ZAPUI_BIN &
ZAPUI_PID=$!

read -n 1 -s
take_screenshot "zapui"
kill $ZAPUI_PID 2>/dev/null || true

echo ""
echo "=== GPUI Setup ==="

# Clone GPUI if needed
if [ ! -d "$GPUI_CLONE_DIR" ]; then
    echo "Cloning Zed repository (GPUI)..."
    git clone --depth 1 --filter=blob:none --sparse https://github.com/zed-industries/zed.git "$GPUI_CLONE_DIR"
    cd "$GPUI_CLONE_DIR"
    git sparse-checkout set crates/gpui
else
    echo "Using cached GPUI clone at $GPUI_CLONE_DIR"
    cd "$GPUI_CLONE_DIR"
    git pull --depth 1 2>/dev/null || true
fi

echo ""
echo "=== Building GPUI $EXAMPLE ==="
cd "$GPUI_CLONE_DIR"

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo "Cargo not found. Please install Rust to run GPUI examples."
    echo ""
    echo "ZapUI screenshot saved to: $SCREENSHOTS_DIR/${EXAMPLE}_zapui.png"
    exit 0
fi

cargo build --example "$EXAMPLE" -p gpui 2>&1 | tail -5 || {
    echo "Failed to build GPUI example: $EXAMPLE"
    echo ""
    echo "ZapUI screenshot saved to: $SCREENSHOTS_DIR/${EXAMPLE}_zapui.png"
    exit 0
}

echo ""
echo "=== Running GPUI ==="
echo "Press any key when the window is visible to take screenshot..."
cargo run --example "$EXAMPLE" -p gpui &
GPUI_PID=$!

read -n 1 -s
take_screenshot "gpui"
kill $GPUI_PID 2>/dev/null || true

echo ""
echo "=== Creating Comparison ==="

ZAPUI_IMG="$SCREENSHOTS_DIR/${EXAMPLE}_zapui.png"
GPUI_IMG="$SCREENSHOTS_DIR/${EXAMPLE}_gpui.png"
DIFF_IMG="$SCREENSHOTS_DIR/${EXAMPLE}_diff.png"
SIDE_BY_SIDE="$SCREENSHOTS_DIR/${EXAMPLE}_comparison.png"

if [ -f "$ZAPUI_IMG" ] && [ -f "$GPUI_IMG" ]; then
    if command -v compare &> /dev/null; then
        # Create diff image
        compare "$ZAPUI_IMG" "$GPUI_IMG" "$DIFF_IMG" 2>/dev/null || true
        
        # Create side-by-side comparison
        convert "$GPUI_IMG" "$ZAPUI_IMG" +append "$SIDE_BY_SIDE"
        
        echo "Comparison image: $SIDE_BY_SIDE"
        echo "Diff image: $DIFF_IMG"
    else
        echo "ImageMagick not found. Install it for image comparison."
    fi
fi

echo ""
echo "=== Done ==="
echo "Screenshots saved in: $SCREENSHOTS_DIR/"
ls -la "$SCREENSHOTS_DIR/${EXAMPLE}"* 2>/dev/null || true
