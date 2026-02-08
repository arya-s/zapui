#!/bin/bash
# Capture screenshot of a GPUI example on Windows using PrintWindow API
#
# Usage:
#   ./capture_gpui.sh hello_world

set -e

EXAMPLE=${1:-hello_world}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAPUI_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ZAPUI_DIR/examples/gpui_ports/$EXAMPLE"
SCREENSHOTS_DIR="$EXAMPLE_DIR/screenshots"

mkdir -p "$SCREENSHOTS_DIR"

# GPUI examples location
GPUI_DIR="/mnt/c/Users/iafan/source/zed/crates/gpui/examples"
GPUI_EXE_DIR="/mnt/c/Users/iafan/source/zed/target/debug/examples"

EXE="$GPUI_EXE_DIR/${EXAMPLE}.exe"

if [ ! -f "$EXE" ]; then
    echo "GPUI executable not found: $EXE"
    echo "Build GPUI example first:"
    echo "  cd /mnt/c/Users/iafan/source/zed"
    echo "  cargo build --example $EXAMPLE"
    exit 1
fi

echo "=== Capturing GPUI: $EXAMPLE ==="

# Copy exe to Windows temp
cp "$EXE" /mnt/c/temp/gpui_${EXAMPLE}.exe

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

Stop-Process -Name "gpui_'"$EXAMPLE"'" -Force -EA SilentlyContinue
Start-Sleep -Milliseconds 500

Start-Process "C:\temp\gpui_'"$EXAMPLE"'.exe"
Start-Sleep -Seconds 3

$p = Get-Process -Name "gpui_'"$EXAMPLE"'" -EA SilentlyContinue | Select -First 1
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
    $bmp.Save("C:\temp\gpui_capture.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Captured"
}

Stop-Process -Name "gpui_'"$EXAMPLE"'" -Force -EA SilentlyContinue
'

if [ -f "/mnt/c/temp/gpui_capture.png" ]; then
    cp "/mnt/c/temp/gpui_capture.png" "$SCREENSHOTS_DIR/gpui.png"
    rm "/mnt/c/temp/gpui_capture.png"
    echo "✅ Saved: $SCREENSHOTS_DIR/gpui.png"
else
    echo "❌ Screenshot failed"
    exit 1
fi
