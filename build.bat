@echo off
rem AMDRyzer Windows Build Script
rem Requires NASM and MSVC Linker (link.exe) in PATH or VS Developer Command Prompt

where nasm >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [!] Error: NASM not found in PATH.
    exit /b 1
)

where link.exe >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [!] Error: MSVC link.exe not found. Please run from 'x64 Native Tools Command Prompt for VS'.
    exit /b 1
)

echo [*] Assembling AMDRyzer_win.asm with NASM...
nasm -f win64 AMDRyzer_win.asm -o AMDRyzer_win.obj
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo [*] Linking AMDRyzer_win.exe with kernel32.lib...
link.exe /nologo /subsystem:console /entry:main AMDRyzer_win.obj kernel32.lib /out:AMDRyzer_win.exe
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo [+] Build successful: AMDRyzer_win.exe
del AMDRyzer_win.obj
