#!/bin/bash
# Capture screenshot of a GPUI example on Windows
#
# Usage:
#   ./capture_gpui.sh hello_world
#
# Requires: Zed repo at C:\src\zed

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"

mkdir -p "$SCREENSHOTS_DIR"

echo "=== Capturing GPUI: $EXAMPLE ==="
echo ""

# Find Zed repo
ZED_DIR="/mnt/c/src/zed"
if [ ! -d "$ZED_DIR" ]; then
    echo "Zed repo not found at $ZED_DIR"
    echo "Clone it with: git clone --depth 1 https://github.com/zed-industries/zed.git /mnt/c/src/zed"
    exit 1
fi

# Check if the example exists
EXAMPLE_EXE="$ZED_DIR/target/debug/examples/${EXAMPLE}.exe"
if [ ! -f "$EXAMPLE_EXE" ]; then
    echo "Building GPUI example (first time may take several minutes)..."
    powershell.exe -Command "cd 'C:\src\zed'; cargo build --example $EXAMPLE -p gpui"
fi

if [ ! -f "$EXAMPLE_EXE" ]; then
    echo "Failed to build example"
    exit 1
fi

# Copy files to temp
WIN_TEMP="/mnt/c/temp"
mkdir -p "$WIN_TEMP"
cp "$EXAMPLE_EXE" "$WIN_TEMP/${EXAMPLE}_gpui.exe"
cp "$SCRIPT_DIR/capture_window.ps1" "$WIN_TEMP/"

echo "Running GPUI example..."
powershell.exe -Command "Start-Process 'C:\temp\\${EXAMPLE}_gpui.exe'"

# Wait for window to appear
sleep 3

echo "Capturing window..."
WIN_OUTPUT="C:\\temp\\gpui_screenshot.png"

# The GPUI process name might not have _gpui suffix in the window
powershell.exe -ExecutionPolicy Bypass -File "C:\\temp\\capture_window.ps1" -ProcessName "${EXAMPLE}_gpui" -OutputPath "$WIN_OUTPUT" 2>/dev/null || \
powershell.exe -ExecutionPolicy Bypass -File "C:\\temp\\capture_window.ps1" -ProcessName "$EXAMPLE" -OutputPath "$WIN_OUTPUT" 2>/dev/null || true

# Copy screenshot back
if [ -f "/mnt/c/temp/gpui_screenshot.png" ]; then
    cp "/mnt/c/temp/gpui_screenshot.png" "$SCREENSHOTS_DIR/gpui.png"
    echo ""
    echo "✅ Screenshot saved: $SCREENSHOTS_DIR/gpui.png"
    ls -la "$SCREENSHOTS_DIR/gpui.png"
else
    echo ""
    echo "❌ Screenshot not found"
fi

# Kill the app
echo "Closing GPUI window..."
taskkill.exe /IM "${EXAMPLE}_gpui.exe" /F 2>/dev/null || true

# Cleanup
rm -f "$WIN_TEMP/${EXAMPLE}_gpui.exe" 2>/dev/null || true
rm -f "$WIN_TEMP/capture_window.ps1" 2>/dev/null || true
rm -f "$WIN_TEMP/gpui_screenshot.png" 2>/dev/null || true
