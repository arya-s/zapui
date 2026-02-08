#!/bin/bash
# Capture screenshot of a GPUI example on Windows
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

echo "=== Capturing GPUI: $EXAMPLE ==="

# Check for pre-built GPUI example
ZED_DIR="/mnt/c/src/zed"
EXAMPLE_EXE="$ZED_DIR/target/debug/examples/${EXAMPLE}.exe"

if [ ! -f "$EXAMPLE_EXE" ]; then
    echo "Building GPUI example (may take a while first time)..."
    powershell.exe -Command "cd 'C:\src\zed'; cargo build --example $EXAMPLE -p gpui"
fi

if [ ! -f "$EXAMPLE_EXE" ]; then
    echo "❌ Failed to build GPUI example"
    exit 1
fi

# Copy to temp
cp "$EXAMPLE_EXE" "/mnt/c/temp/${EXAMPLE}_gpui.exe"

echo "Launching and capturing..."
powershell.exe -Command '
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinCapture {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
}
"@

Start-Process "C:\temp\'"$EXAMPLE"'_gpui.exe"
Start-Sleep -Seconds 3

$p = Get-Process -Name "'"$EXAMPLE"'_gpui" -EA SilentlyContinue | Select -First 1
if ($p -and $p.MainWindowHandle -ne 0) {
    $h = $p.MainWindowHandle
    [WinCapture]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 500
    $r = New-Object WinCapture+RECT
    [WinCapture]::GetWindowRect($h, [ref]$r) | Out-Null
    $w = $r.R - $r.L
    $h = $r.B - $r.T
    Write-Host "Window: $w x $h"
    $bmp = New-Object Drawing.Bitmap($w, $h)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, [Drawing.Size]::new($w, $h))
    $bmp.Save("C:\temp\gpui_capture.png", [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Captured"
}

Stop-Process -Name "'"$EXAMPLE"'_gpui" -Force -EA SilentlyContinue
'

if [ -f "/mnt/c/temp/gpui_capture.png" ]; then
    cp "/mnt/c/temp/gpui_capture.png" "$SCREENSHOTS_DIR/gpui.png"
    rm "/mnt/c/temp/gpui_capture.png"
    echo "✅ Saved: $SCREENSHOTS_DIR/gpui.png"
else
    echo "❌ Screenshot failed"
    exit 1
fi
