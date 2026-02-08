#!/bin/bash
# Capture screenshot of a ZapUI example on Windows using PrintWindow API
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

# Copy exe to Windows temp
cp "$EXE" /mnt/c/temp/

echo "Launching and capturing..."
powershell.exe -Command '
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PrintWin {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
}
"@

Stop-Process -Name "'"$EXAMPLE"'" -Force -EA SilentlyContinue
Start-Sleep -Milliseconds 500

Start-Process "C:\temp\'"$EXAMPLE"'.exe"
Start-Sleep -Seconds 3

$p = Get-Process -Name "'"$EXAMPLE"'" -EA SilentlyContinue | Select -First 1
if ($p -and $p.MainWindowHandle -ne 0) {
    $handle = $p.MainWindowHandle
    [PrintWin]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 500
    
    $rect = New-Object PrintWin+RECT
    [PrintWin]::GetWindowRect($handle, [ref]$rect) | Out-Null
    $w = $rect.R - $rect.L
    $h = $rect.B - $rect.T
    Write-Host "Window: ${w} x ${h}"
    
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [PrintWin]::PrintWindow($handle, $hdc, 0) | Out-Null
    $g.ReleaseHdc($hdc)
    $bmp.Save("C:\temp\zapui_capture.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Captured"
}

Stop-Process -Name "'"$EXAMPLE"'" -Force -EA SilentlyContinue
'

if [ -f "/mnt/c/temp/zapui_capture.png" ]; then
    cp "/mnt/c/temp/zapui_capture.png" "$SCREENSHOTS_DIR/zapui.png"
    rm "/mnt/c/temp/zapui_capture.png"
    echo "✅ Saved: $SCREENSHOTS_DIR/zapui.png"
else
    echo "❌ Screenshot failed"
    exit 1
fi
