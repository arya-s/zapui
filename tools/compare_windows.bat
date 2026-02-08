@echo off
REM Screenshot comparison tool for GPUI vs ZapUI on Windows
REM Uses ShareX for capturing screenshots
REM
REM Usage:
REM   compare_windows.bat hello_world
REM   compare_windows.bat shadow
REM
REM Prerequisites:
REM   - ShareX installed and running
REM   - Rust/Cargo for GPUI
REM   - Zig cross-compiled ZapUI executable
REM   - Zed repository cloned

setlocal enabledelayedexpansion

set EXAMPLE=%1
if "%EXAMPLE%"=="" set EXAMPLE=hello_world

set SCRIPT_DIR=%~dp0
set ZAPUI_DIR=%SCRIPT_DIR%..
set EXAMPLE_DIR=%ZAPUI_DIR%\examples\gpui_ports\%EXAMPLE%
set SCREENSHOTS_DIR=%EXAMPLE_DIR%\screenshots

REM Default paths - adjust these to match your setup
set ZED_DIR=C:\Users\%USERNAME%\src\zed
set SHAREX_PATH=C:\Program Files\ShareX\ShareX.exe

echo ============================================
echo  GPUI vs ZapUI Screenshot Comparison
echo  Example: %EXAMPLE%
echo ============================================
echo.

REM Create screenshots directory
if not exist "%SCREENSHOTS_DIR%" mkdir "%SCREENSHOTS_DIR%"

echo Screenshots will be saved to:
echo   %SCREENSHOTS_DIR%
echo.

REM Check if ZapUI executable exists
set ZAPUI_EXE=%ZAPUI_DIR%\zig-out\bin\%EXAMPLE%.exe
if not exist "%ZAPUI_EXE%" (
    echo ZapUI executable not found: %ZAPUI_EXE%
    echo.
    echo Build it first with:
    echo   wsl -e zig build %EXAMPLE% -Dtarget=x86_64-windows
    echo.
    echo Or use hello_world:
    set ZAPUI_EXE=%ZAPUI_DIR%\zig-out\bin\hello_world.exe
)

if not exist "%ZAPUI_EXE%" (
    echo No ZapUI executable found. Build first!
    exit /b 1
)

echo.
echo ============================================
echo  Step 1: ZapUI (Zig)
echo ============================================
echo.
echo Starting: %ZAPUI_EXE%
echo.
echo Use ShareX to capture the window:
echo   - Press Ctrl+Shift+PrintScreen for window capture
echo   - Save as: %SCREENSHOTS_DIR%\zapui.png
echo.
echo Press any key when ready to launch ZapUI...
pause >nul

start "" "%ZAPUI_EXE%"

echo.
echo ZapUI window should be open.
echo Capture it with ShareX, then close the window.
echo.
echo Press any key to continue to GPUI...
pause >nul

echo.
echo ============================================
echo  Step 2: GPUI (Rust)
echo ============================================
echo.

if not exist "%ZED_DIR%\Cargo.toml" (
    echo Zed repository not found at: %ZED_DIR%
    echo.
    echo Please clone it:
    echo   git clone https://github.com/zed-industries/zed.git %ZED_DIR%
    echo.
    echo Or set ZED_DIR environment variable to your Zed path.
    echo.
    echo Skipping GPUI...
    goto :done
)

echo Building and running GPUI example...
echo.
echo Use ShareX to capture the window:
echo   - Press Ctrl+Shift+PrintScreen for window capture
echo   - Save as: %SCREENSHOTS_DIR%\gpui.png
echo.
echo Press any key when ready to launch GPUI...
pause >nul

pushd "%ZED_DIR%"
cargo run --example %EXAMPLE% -p gpui
popd

:done
echo.
echo ============================================
echo  Done!
echo ============================================
echo.
echo Screenshots should be in:
echo   %SCREENSHOTS_DIR%
echo.
echo Expected files:
echo   - zapui.png (ZapUI screenshot)
echo   - gpui.png (GPUI screenshot)
echo.

if exist "%SCREENSHOTS_DIR%\zapui.png" (
    echo   [OK] zapui.png found
) else (
    echo   [MISSING] zapui.png
)

if exist "%SCREENSHOTS_DIR%\gpui.png" (
    echo   [OK] gpui.png found
) else (
    echo   [MISSING] gpui.png
)

echo.
echo To create comparison image, run in WSL:
echo   ./tools/create_comparison.sh %EXAMPLE%
echo.

endlocal
