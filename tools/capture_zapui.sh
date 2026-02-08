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

# Copy exe to Windows temp
cp "$EXE" /mnt/c/temp/

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

Start-Process "C:\temp\'"$EXAMPLE"'.exe"
Start-Sleep -Seconds 2

$p = Get-Process -Name "'"$EXAMPLE"'" -EA SilentlyContinue | Select -First 1
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
    $bmp.Save("C:\temp\zapui_capture.png", [Drawing.Imaging.ImageFormat]::Png)
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
