@echo off
REM ============================================================================
REM ZapUI Hello World - Windows build and run script
REM ============================================================================
REM
REM Prerequisites:
REM   1. Zig compiler installed and in PATH
REM      Download from: https://ziglang.org/download/
REM
REM   2. GLFW3 library
REM      Option A: Install via vcpkg:
REM                vcpkg install glfw3:x64-windows
REM                vcpkg integrate install
REM
REM      Option B: Download pre-built binaries from https://www.glfw.org/download
REM                Extract and set GLFW_PATH environment variable, or copy
REM                glfw3.lib to a location in your library path
REM
REM   3. OpenGL (included with graphics drivers)
REM
REM ============================================================================

echo.
echo ==========================================
echo   ZapUI Hello World - Windows Build
echo ==========================================
echo.

REM Check if zig is available
where zig >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Zig compiler not found in PATH!
    echo.
    echo Please install Zig from https://ziglang.org/download/
    echo and add it to your PATH environment variable.
    echo.
    pause
    exit /b 1
)

echo Zig compiler found:
zig version
echo.

echo Building ZapUI Hello World...
echo.

zig build hello-world

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ==========================================
    echo   BUILD FAILED
    echo ==========================================
    echo.
    echo Common issues on Windows:
    echo.
    echo 1. GLFW not found:
    echo    - Install via vcpkg: vcpkg install glfw3:x64-windows
    echo    - Or download from https://www.glfw.org/download
    echo.
    echo 2. Missing Visual C++ libs:
    echo    - Install Visual Studio Build Tools
    echo    - Or install Windows SDK
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   BUILD SUCCESSFUL
echo ==========================================
echo.
echo Running Hello World...
echo Press ESC in the window to exit.
echo.

zig-out\bin\hello_world.exe

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Program exited with error code: %ERRORLEVEL%
)

echo.
pause
