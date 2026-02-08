#!/bin/bash
# Capture screenshot of a ZapUI example on Windows using ShareX (run from WSL)
#
# Usage:
#   ./capture_zapui.sh hello_world
#   ./capture_zapui.sh playground
#
# Requires: ShareX installed on Windows

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

# Find ShareX
SHAREX="/mnt/c/Program Files/ShareX/ShareX.exe"
if [ ! -f "$SHAREX" ]; then
    SHAREX="/mnt/c/Program Files (x86)/ShareX/ShareX.exe"
fi

if [ ! -f "$SHAREX" ]; then
    echo "ShareX not found. Please install ShareX."
    exit 1
fi

# ShareX screenshots folder
SHAREX_FOLDER="/mnt/c/Users/$USER/Documents/ShareX/Screenshots"
if [ ! -d "$SHAREX_FOLDER" ]; then
    # Try common Windows username
    SHAREX_FOLDER="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')/Documents/ShareX/Screenshots"
fi

# Copy exe to Windows temp (WSL UNC paths don't work well)
WIN_TEMP="/mnt/c/temp"
mkdir -p "$WIN_TEMP"
cp "$EXE" "$WIN_TEMP/"

echo "Launching $EXAMPLE.exe..."
powershell.exe -Command "Start-Process 'C:\temp\\${EXAMPLE}.exe'"

# Wait for window to appear and render
sleep 2

# Bring window to foreground
echo "Focusing window..."
powershell.exe -Command '
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

$proc = Get-Process -Name "'"$EXAMPLE"'" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc) {
    $proc.Refresh()
    [Win32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    Write-Host "Focused: $($proc.MainWindowTitle)"
}
'

sleep 0.5

# Record time before capture
BEFORE_TIME=$(date +%s)

# Use ShareX to capture the active window
echo "Capturing with ShareX..."
"$SHAREX" -ActiveWindow -silent &

# Wait for ShareX to complete capture
sleep 3

# Kill the app
echo "Closing window..."
taskkill.exe /IM "${EXAMPLE}.exe" /F 2>/dev/null || true

# Find the most recent screenshot in ShareX folder (created after we started)
echo "Finding screenshot..."
LATEST_SCREENSHOT=""
for dir in "$SHAREX_FOLDER"/*; do
    if [ -d "$dir" ]; then
        for file in "$dir"/*.png; do
            if [ -f "$file" ]; then
                FILE_TIME=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                if [ "$FILE_TIME" -ge "$BEFORE_TIME" ]; then
                    LATEST_SCREENSHOT="$file"
                fi
            fi
        done
    fi
done

if [ -n "$LATEST_SCREENSHOT" ] && [ -f "$LATEST_SCREENSHOT" ]; then
    cp "$LATEST_SCREENSHOT" "$SCREENSHOTS_DIR/zapui.png"
    echo ""
    echo "✅ Screenshot saved: $SCREENSHOTS_DIR/zapui.png"
    ls -la "$SCREENSHOTS_DIR/zapui.png"
else
    echo ""
    echo "❌ Could not find ShareX screenshot"
    echo "Check ShareX folder: $SHAREX_FOLDER"
fi

# Cleanup temp exe
rm -f "$WIN_TEMP/${EXAMPLE}.exe" 2>/dev/null || true
