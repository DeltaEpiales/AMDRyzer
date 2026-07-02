# 💻 AMDRyzer v4.2 - Universal Hardware Diagnostic Suite

AMDRyzer is a low-level hardware profiling and diagnostic utility written entirely in pure x64 assembly. Originally targeted exclusively at AMD platforms on Linux, v4.2 is a major architectural overhaul that introduces universal auto-detection for Intel/AMD microarchitectures and native support for both Windows and Linux environments. 🌍

This tool bypasses standard high-level libraries (like glibc or the MSVC runtime) to interact directly with the operating system kernels via raw system calls (Linux) and core Win32 APIs (Windows). ⚙️

## ⚡ Core Features

* 🔍 Microarchitecture Identification: Directly queries CPU registers via CPUID (with strict ABI-compliant stack and register preservation) to map vendor (GenuineIntel / AuthenticAMD), brand strings, logical core counts, and L2/L3 cache topologies.
*  Cross-Platform AVX2 Benchmarking: Allocates 256MB of physical RAM via sys_mmap (Linux) or VirtualAlloc (Windows). Bombards the memory with 4-pass, 256-bit wide alternating bit patterns (0xFF, 0x00, 0x55, 0xAA) using vpbroadcastd.
*  Hardware Latency Profiling: Utilizes serialized lfence and rdtsc instructions to measure the exact CPU clock cycle latency of the memory stress test.
*  Bare-Metal Block Access: Bypasses the filesystem to attempt raw Sector 0 reads of /dev/sda (Linux) or \\.\PhysicalDrive0 (Windows) to validate the Master Boot Record (MBR) 0xAA55 hex signature.
*  Automated Fine-Tuning Guide: Dynamically generates and writes a local text file (AMDRyzer_Tuning_Guide.txt) containing advanced BIOS and hardware optimization tips for modern Ryzen processors.

## 🚨 Prerequisites

* 🖥️ Host OS: Windows 10/11 (x64) or Linux (x86_64)
* 🔨 Assembler: NASM (Netwide Assembler)
* 🔗 Linkers: Microsoft Visual Studio Linker (link.exe) for Windows, ld for Linux
* 🐍 Launcher: Python 3.x
* 🔑 Permissions: Root / Administrator privileges are required only for Option 3 (Boot Sector Analysis).

## 🛠️ Building from Source

Because AMDRyzer interfaces directly with each operating system's specific Application Binary Interface (ABI), you must compile the respective binary for your target OS. 🏗️

Windows Build Instructions:
Open the x64 Native Tools Command Prompt for VS and run:
nasm -f win64 AMDRyzer_win.asm -o AMDRyzer_win.obj
link.exe /subsystem:console /entry:main AMDRyzer_win.obj kernel32.lib

Linux Build Instructions:
Open your terminal and run:
nasm -f elf64 AMDRyzer_linux.asm -o AMDRyzer_linux.o
ld AMDRyzer_linux.o -o AMDRyzer_linux

## 🚀 Usage

Ensure your compiled binaries and launcher.py are in the same directory. Run the launcher script, which will automatically detect your host OS and boot the correct native assembly executable. 

python launcher.py

Note: To successfully analyze Sector 0 of your primary storage drive, you must run the launcher with elevated privileges (sudo on Linux, or from an Administrator command prompt on Windows), otherwise the kernel will block raw disk access. 

## ⚠️ Safety & Scope

AMDRyzer v4.2 is a strictly diagnostic tool. It allocates its own isolated memory for testing and only performs read operations on system block devices. The only disk write operation it performs is creating the tuning guide text file in its local directory. It will not write to your boot sector, alter your CPU power states, or permanently modify system parameters. 

## Author

Ryan Osacra 
