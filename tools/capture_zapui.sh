#!/bin/bash
# Capture screenshot of a ZapUI example on Windows using ShareX
#
# Usage:
#   ./capture_zapui.sh hello_world
#
# Note: Don't interact with other windows while capturing

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

# Copy exe to Windows temp
cp "$EXE" /mnt/c/temp/

# Get ShareX screenshot folder
USERNAME=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
SHAREX_FOLDER="/mnt/c/Users/$USERNAME/Documents/ShareX/Screenshots"

echo "Launching ${EXAMPLE}.exe..."
powershell.exe -Command "Start-Process 'C:\temp\\${EXAMPLE}.exe'"
sleep 2

echo "Capturing..."
"/mnt/c/Program Files/ShareX/ShareX.exe" -ActiveWindow -silent &
sleep 2

echo "Closing..."
taskkill.exe /IM "${EXAMPLE}.exe" /F 2>/dev/null || true
sleep 1

# Find most recent screenshot
NEWEST=$(find "$SHAREX_FOLDER" -name "*.png" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

if [ -n "$NEWEST" ]; then
    cp "$NEWEST" "$SCREENSHOTS_DIR/zapui.png"
    echo "✅ Saved: $SCREENSHOTS_DIR/zapui.png"
else
    echo "❌ Screenshot not found"
fi
