#!/bin/bash
# Capture screenshot of a ZapUI example on Windows using ShareX CLI
#
# Usage:
#   ./capture_zapui.sh hello_world

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"
OUTPUT_FILE="$SCREENSHOTS_DIR/zapui.png"

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

# Launch the app and wait for it to render
echo "Launching ${EXAMPLE}.exe..."
powershell.exe -Command "Start-Process 'C:\temp\\${EXAMPLE}.exe'"
sleep 1

# Activate the window before capturing
echo "Activating window..."
powershell.exe -Command "
\$wshell = New-Object -ComObject wscript.shell
\$proc = Get-Process -Name '${EXAMPLE}' -ErrorAction SilentlyContinue | Select-Object -First 1
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
powershell.exe -Command "Stop-Process -Name '${EXAMPLE}' -Force -EA SilentlyContinue" 2>/dev/null || true
