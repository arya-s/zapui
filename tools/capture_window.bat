@echo off
REM Capture a window by process name
REM Usage: capture_window.bat <process_name> <output_path>

set PROCESS=%1
set OUTPUT=%2

REM Start the app if not already running
if not exist "C:\temp\%PROCESS%.exe" (
    echo Error: C:\temp\%PROCESS%.exe not found
    exit /b 1
)

echo Starting %PROCESS%...
start "" "C:\temp\%PROCESS%.exe"
timeout /t 2 /nobreak > nul

REM Focus the window using PowerShell
echo Focusing window...
powershell -Command ^
    "$p = Get-Process -Name '%PROCESS%' -EA SilentlyContinue | Select -First 1; ^
    if ($p -and $p.MainWindowHandle -ne 0) { ^
        Add-Type @' ^
        using System; ^
        using System.Runtime.InteropServices; ^
        public class Focus { ^
            [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr h); ^
            [DllImport(\"user32.dll\")] public static extern bool ShowWindow(IntPtr h, int c); ^
        } ^
'@; ^
        [Focus]::ShowWindow($p.MainWindowHandle, 9); ^
        Start-Sleep -Milliseconds 300; ^
        [Focus]::SetForegroundWindow($p.MainWindowHandle); ^
        Write-Host 'Window focused'; ^
    }"

timeout /t 1 /nobreak > nul

REM Capture using ShareX
echo Capturing...
"C:\Program Files\ShareX\ShareX.exe" -ActiveWindow -silent
timeout /t 2 /nobreak > nul

REM Kill the app
taskkill /IM "%PROCESS%.exe" /F > nul 2>&1

echo Done
