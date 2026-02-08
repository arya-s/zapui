#!/bin/bash
# Capture screenshot of a GPUI example on Windows using ShareX (run from WSL)
#
# Usage:
#   ./capture_gpui.sh hello_world
#   ./capture_gpui.sh shadow
#
# Requires: 
#   - ShareX installed on Windows
#   - Rust/Cargo on Windows
#   - Zed repo cloned to C:\src\zed

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"

mkdir -p "$SCREENSHOTS_DIR"

echo "=== Capturing GPUI: $EXAMPLE ==="
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

# Find Zed repo
ZED_DIR="/mnt/c/src/zed"
if [ ! -d "$ZED_DIR" ]; then
    echo "Zed repo not found at $ZED_DIR"
    echo "Clone it with: git clone --depth 1 https://github.com/zed-industries/zed.git /mnt/c/src/zed"
    exit 1
fi

# Check if the example exists
if [ ! -f "$ZED_DIR/crates/gpui/examples/${EXAMPLE}.rs" ]; then
    echo "GPUI example not found: ${EXAMPLE}.rs"
    echo ""
    echo "Available examples:"
    ls "$ZED_DIR/crates/gpui/examples/"*.rs 2>/dev/null | xargs -n1 basename | sed 's/.rs$//'
    exit 1
fi

# ShareX screenshots folder  
SHAREX_FOLDER="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')/Documents/ShareX/Screenshots"

# Build the example if not already built
EXAMPLE_EXE="$ZED_DIR/target/debug/examples/${EXAMPLE}.exe"
if [ ! -f "$EXAMPLE_EXE" ]; then
    echo "Building GPUI example (first time may take several minutes)..."
    cd "$ZED_DIR"
    powershell.exe -Command "cd 'C:\src\zed'; cargo build --example $EXAMPLE -p gpui"
fi

if [ ! -f "$EXAMPLE_EXE" ]; then
    echo "Failed to build example"
    exit 1
fi

echo "Running GPUI example..."

# Copy to temp to avoid path issues
cp "$EXAMPLE_EXE" "/mnt/c/temp/${EXAMPLE}_gpui.exe"

# Start the example
powershell.exe -Command "Start-Process 'C:\temp\\${EXAMPLE}_gpui.exe'"

# Wait for window to appear
sleep 3

# Record time before capture
BEFORE_TIME=$(date +%s)

# Focus window and capture with ShareX
echo "Capturing with ShareX..."
powershell.exe -Command "
Add-Type @'
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport(\"user32.dll\")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@

# Find the GPUI window - it might have various titles
\$procs = Get-Process | Where-Object { 
    \$_.MainWindowTitle -ne '' -and 
    (\$_.ProcessName -like '*${EXAMPLE}*' -or \$_.MainWindowTitle -like '*Hello*' -or \$_.MainWindowTitle -like '*World*')
}

if (\$procs) {
    \$proc = \$procs | Select-Object -First 1
    [Win32]::SetForegroundWindow(\$proc.MainWindowHandle) | Out-Null
    Write-Host \"Focused: \$(\$proc.MainWindowTitle)\"
} else {
    Write-Host 'Window not found'
}
"

sleep 0.5

# Use ShareX to capture the active window
"$SHAREX" -ActiveWindow -silent &
sleep 3

# Kill the example
echo "Closing GPUI window..."
taskkill.exe /IM "${EXAMPLE}_gpui.exe" /F 2>/dev/null || true

# Find the most recent screenshot in ShareX folder
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
    cp "$LATEST_SCREENSHOT" "$SCREENSHOTS_DIR/gpui.png"
    echo ""
    echo "✅ Screenshot saved: $SCREENSHOTS_DIR/gpui.png"
    ls -la "$SCREENSHOTS_DIR/gpui.png"
else
    echo ""
    echo "❌ Could not find ShareX screenshot"
    echo "Check ShareX folder: $SHAREX_FOLDER"
fi

# Cleanup
rm -f "/mnt/c/temp/${EXAMPLE}_gpui.exe" 2>/dev/null || true
