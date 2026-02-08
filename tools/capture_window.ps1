# Capture a specific window by process name using DWM
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
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    
    public const int SW_RESTORE = 9;
    public const int SW_SHOW = 5;
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_SHOWWINDOW = 0x0040;
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

# Force window to top using TOPMOST trick
[WindowCapture]::ShowWindow($hwnd, [WindowCapture]::SW_RESTORE) | Out-Null
[WindowCapture]::SetWindowPos($hwnd, [WindowCapture]::HWND_TOPMOST, 0, 0, 0, 0, 
    [WindowCapture]::SWP_NOMOVE -bor [WindowCapture]::SWP_NOSIZE -bor [WindowCapture]::SWP_SHOWWINDOW) | Out-Null
Start-Sleep -Milliseconds 200
[WindowCapture]::SetWindowPos($hwnd, [WindowCapture]::HWND_NOTOPMOST, 0, 0, 0, 0,
    [WindowCapture]::SWP_NOMOVE -bor [WindowCapture]::SWP_NOSIZE -bor [WindowCapture]::SWP_SHOWWINDOW) | Out-Null
[WindowCapture]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

# Get window rect
$rect = New-Object WindowCapture+RECT
[WindowCapture]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

Write-Host "Window size: ${width}x${height}"

# Capture using CopyFromScreen (screen capture)
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($width, $height))

# Save
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "Saved: $OutputPath"
