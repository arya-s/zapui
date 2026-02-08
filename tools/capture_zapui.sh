#!/bin/bash
# Capture screenshot of a ZapUI example on Windows (run from WSL)
#
# Usage:
#   ./capture_zapui.sh hello_world
#   ./capture_zapui.sh playground

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

# Convert WSL path to Windows path for the screenshot
WIN_SCREENSHOTS_DIR=$(wslpath -w "$SCREENSHOTS_DIR")

# Copy exe to Windows temp (WSL UNC paths don't work well with Windows APIs)
WIN_TEMP="/mnt/c/temp"
mkdir -p "$WIN_TEMP"
cp "$EXE" "$WIN_TEMP/"

# Create the PowerShell capture script
cat > /tmp/capture_window.ps1 << 'PSEOF'
param($ProcessName, $OutputPath)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Enable DPI awareness for correct coordinates
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class DpiAware {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
[DpiAware]::SetProcessDPIAware() | Out-Null

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }
}
"@

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $proc) {
    Write-Host "Process $ProcessName.exe not found"
    exit 1
}

$proc.Refresh()
$hwnd = $proc.MainWindowHandle
Write-Host "Found: $($proc.MainWindowTitle) (PID: $($proc.Id))"

if ($hwnd -eq [IntPtr]::Zero) {
    Write-Host "No main window handle"
    exit 1
}

# Bring to foreground
[Win32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

# Get window rect
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

Write-Host "Window: ${width}x${height} at ($($rect.Left), $($rect.Top))"

if ($width -lt 10 -or $height -lt 10) {
    Write-Host "Invalid window size"
    exit 1
}

# Capture using CopyFromScreen
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($width, $height))
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "Screenshot saved"
PSEOF

echo "Launching $EXAMPLE.exe..."
powershell.exe -Command "Start-Process 'C:\temp\\${EXAMPLE}.exe'"

# Wait for window to appear and render
sleep 2

# Run the PowerShell capture script
echo "Capturing window screenshot..."
WIN_PS_SCRIPT=$(wslpath -w /tmp/capture_window.ps1)
powershell.exe -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" -ProcessName "$EXAMPLE" -OutputPath "${WIN_SCREENSHOTS_DIR}\\zapui.png"

# Kill the app
echo "Closing window..."
taskkill.exe /IM "${EXAMPLE}.exe" /F 2>/dev/null || true

# Cleanup
rm -f /tmp/capture_window.ps1
rm -f "$WIN_TEMP/${EXAMPLE}.exe" 2>/dev/null || true

echo ""
if [ -f "$SCREENSHOTS_DIR/zapui.png" ]; then
    echo "✅ Screenshot saved: $SCREENSHOTS_DIR/zapui.png"
    ls -la "$SCREENSHOTS_DIR/zapui.png"
else
    echo "❌ Screenshot failed"
fi
