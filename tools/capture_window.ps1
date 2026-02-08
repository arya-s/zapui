# Capture a specific window by process name
# Usage: .\capture_window.ps1 -ProcessName "hello_world" -OutputPath "C:\temp\screenshot.png"

param(
    [Parameter(Mandatory=$true)]
    [string]$ProcessName,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

public class WindowCapture {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowDC(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    
    [DllImport("gdi32.dll")]
    public static extern bool BitBlt(IntPtr hdcDest, int xDest, int yDest, int wDest, int hDest, 
        IntPtr hdcSource, int xSrc, int ySrc, int RasterOp);
    
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    
    public const int SW_RESTORE = 9;
    public const int SRCCOPY = 0x00CC0020;
    public const uint PW_CLIENTONLY = 0x1;
    public const uint PW_RENDERFULLCONTENT = 0x2;
}
"@

# Find the process
$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $proc) {
    Write-Error "Process '$ProcessName' not found"
    exit 1
}

if ($proc.MainWindowHandle -eq 0) {
    Write-Error "Process has no main window"
    exit 1
}

$hwnd = $proc.MainWindowHandle

# Restore and focus the window
[WindowCapture]::ShowWindow($hwnd, [WindowCapture]::SW_RESTORE) | Out-Null
[WindowCapture]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

# Get window rect
$rect = New-Object WindowCapture+RECT
[WindowCapture]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

Write-Host "Window size: ${width}x${height}"

# Create bitmap and capture using PrintWindow (works better for hidden/overlapped windows)
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$hdc = $graphics.GetHdc()

# Use PrintWindow with PW_RENDERFULLCONTENT for best results
$result = [WindowCapture]::PrintWindow($hwnd, $hdc, 2)

$graphics.ReleaseHdc($hdc)

if (-not $result) {
    Write-Warning "PrintWindow failed, falling back to screen capture"
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($width, $height))
}

# Save
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "Saved: $OutputPath"
