#!/bin/bash
# Capture screenshot of a GPUI example on Windows using ShareX CLI
#
# Usage:
#   ./capture_gpui.sh hello_world

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"
OUTPUT_FILE="$SCREENSHOTS_DIR/gpui.png"

mkdir -p "$SCREENSHOTS_DIR"

# GPUI examples location
GPUI_EXE_DIR="/mnt/c/src/zed/target/debug/examples"

EXE="$GPUI_EXE_DIR/${EXAMPLE}.exe"

if [ ! -f "$EXE" ]; then
    echo "GPUI executable not found: $EXE"
    echo "Build GPUI example first:"
    echo "  cd /mnt/c/src/zed"
    echo "  cargo build -p gpui --example $EXAMPLE"
    exit 1
fi

echo "=== Capturing GPUI: $EXAMPLE ==="

# Copy exe to Windows temp
cp "$EXE" /mnt/c/temp/gpui_${EXAMPLE}.exe

# Launch the app and wait for it to render
echo "Launching gpui_${EXAMPLE}.exe..."
powershell.exe -Command "Start-Process 'C:\temp\gpui_${EXAMPLE}.exe'"
sleep 1

# Activate the window before capturing
echo "Activating window..."
powershell.exe -Command "
\$wshell = New-Object -ComObject wscript.shell
\$proc = Get-Process -Name 'gpui_${EXAMPLE}' -ErrorAction SilentlyContinue | Select-Object -First 1
if (\$proc) {
    Add-Type @'
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport(\"user32.dll\")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
'@
    [Win32]::SetForegroundWindow(\$proc.MainWindowHandle)
}
"
sleep 1

# Capture with ShareX (saves to its default Screenshots folder)
echo "Capturing with ShareX..."
powershell.exe -Command "& 'C:\Program Files\ShareX\ShareX.exe' -ActiveWindow -silent"

# Wait for ShareX to finish
sleep 2

# Find the most recent screenshot from ShareX's default folder
SHAREX_SCREENSHOT=$(powershell.exe -Command "(Get-ChildItem \"\$env:USERPROFILE\Documents\ShareX\Screenshots\" -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName" 2>/dev/null | tr -d '\r')

if [ -n "$SHAREX_SCREENSHOT" ]; then
    # Convert Windows path to WSL path and copy
    WSL_PATH=$(wslpath "$SHAREX_SCREENSHOT")
    cp "$WSL_PATH" "$OUTPUT_FILE"
    echo "✅ Saved: $OUTPUT_FILE"
else
    echo "❌ Screenshot failed"
    exit 1
fi

# Kill the app
powershell.exe -Command "Stop-Process -Name 'gpui_${EXAMPLE}' -Force -EA SilentlyContinue" 2>/dev/null || true
