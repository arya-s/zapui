#!/bin/bash
# Capture screenshot of a ZapUI example on Windows
#
# Usage:
#   ./capture_zapui.sh hello_world

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"

mkdir -p "$SCREENSHOTS_DIR"

EXE="$ZAPUI_DIR/zig-out/bin/${EXAMPLE}.exe"

if [ ! -f "$EXE" ]; then
    echo "Executable not found: $EXE"
    echo "Build first with: make windows"
    exit 1
fi

echo "=== Capturing ZapUI: $EXAMPLE ==="
echo ""

# Copy exe to Windows temp
WIN_TEMP="/mnt/c/temp"
mkdir -p "$WIN_TEMP"
cp "$EXE" "$WIN_TEMP/"

# Copy capture script
cp "$SCRIPT_DIR/capture_window.ps1" "$WIN_TEMP/"

echo "Launching $EXAMPLE.exe..."
powershell.exe -Command "Start-Process 'C:\temp\\${EXAMPLE}.exe'"

# Wait for window to appear
sleep 2

echo "Capturing window..."
WIN_OUTPUT="C:\\temp\\zapui_screenshot.png"

powershell.exe -ExecutionPolicy Bypass -File "C:\\temp\\capture_window.ps1" -ProcessName "$EXAMPLE" -OutputPath "$WIN_OUTPUT"

# Copy screenshot back
if [ -f "/mnt/c/temp/zapui_screenshot.png" ]; then
    cp "/mnt/c/temp/zapui_screenshot.png" "$SCREENSHOTS_DIR/zapui.png"
    echo ""
    echo "✅ Screenshot saved: $SCREENSHOTS_DIR/zapui.png"
    ls -la "$SCREENSHOTS_DIR/zapui.png"
else
    echo ""
    echo "❌ Screenshot not found"
fi

# Kill the app
echo "Closing window..."
taskkill.exe /IM "${EXAMPLE}.exe" /F 2>/dev/null || true

# Cleanup
rm -f "$WIN_TEMP/${EXAMPLE}.exe" 2>/dev/null || true
rm -f "$WIN_TEMP/capture_window.ps1" 2>/dev/null || true
rm -f "$WIN_TEMP/zapui_screenshot.png" 2>/dev/null || true
