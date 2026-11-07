@echo off
rem AMDRyzer Windows Build Script
rem Supports MinGW gcc or MSVC link.exe

where nasm >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [!] Error: NASM not found in PATH.
    exit /b 1
)

echo [*] Assembling AMDRyzer_win.asm with NASM...
nasm -f win64 AMDRyzer_win.asm -o AMDRyzer_win.obj
if %ERRORLEVEL% neq 0 (
    echo [-] Assembly failed.
    exit /b %ERRORLEVEL%
)

rem Check for GCC first
where gcc >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [*] Linking with GCC...
    gcc AMDRyzer_win.obj -o AMDRyzer_win.exe -nostdlib -lkernel32 -e main
    if %ERRORLEVEL% equ 0 goto success
)

rem Check for Microsoft Linker
where cl.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [*] Linking with MSVC link.exe...
    link.exe /nologo /subsystem:console /entry:main AMDRyzer_win.obj kernel32.lib /out:AMDRyzer_win.exe
    if %ERRORLEVEL% equ 0 goto success
)

echo [!] Error: Neither GCC nor MSVC linker found in PATH.
exit /b 1

:success
echo [+] Build successful: AMDRyzer_win.exe
del AMDRyzer_win.obj 2>nul
exit /b 0
