# AMDRyzer

Low-level x86-64 hardware profiling and diagnostic suite written entirely in standalone assembly (NASM). 

AMDRyzer operates without high-level runtime libraries (no glibc, no MSVCRT), interfacing directly with operating system kernels via raw Linux system calls and core Win32 system APIs. It is designed for low-level systems engineers, hardware researchers, and reverse engineers who require bare-metal execution and cycle-accurate telemetry.

---

## Technical Architecture

* **Direct Microarchitecture Probing**: Queries hardware CPU registers directly using `CPUID` with strict register preservation to retrieve vendor identification (`GenuineIntel` / `AuthenticAMD`), brand strings, logical core counts, and cache hierarchy topologies.
* **AVX2 Vector Memory Stressing**: Allocates 256MB of physical RAM via `sys_mmap` (Linux) or `VirtualAlloc` (Windows), executing a 4-pass, 256-bit wide alternating pattern sweep (`0xFF`, `0x00`, `0x55`, `0xAA`) using `vpbroadcastd`.
* **Hardware Latency Profiling**: Utilizes serialized `lfence` and `rdtsc` instruction pairs to measure exact CPU clock cycle duration across memory load operations.
* **Raw Block Device Access**: Bypasses the filesystem layer to perform raw Sector 0 reads on primary block devices (`/dev/sda` on Linux, `\\.\PhysicalDrive0` on Windows) to validate the Master Boot Record (MBR) `0xAA55` signature.
* **Kernel & Sysfs Telemetry**: Under Linux, queries thermal and processor frequency sysfs interfaces (`/sys/class/thermal/`, `/sys/devices/system/cpu/`) directly.

---

## Repository Structure

```
AMDRyzer/
├── AMDRyzer.asm        # Linux implementation (Raw x86-64 syscalls, no libc)
├── AMDRyzer_win.asm    # Windows implementation (Win64 ABI, kernel32 linkage)
├── Makefile            # Linux build automation
├── build.bat           # Windows MSVC / NASM build script
├── LICENSE             # MIT License
└── README.md
```

---

## Building from Source

### Prerequisites

* **Assembler**: [NASM](https://www.nasm.us/) (Netwide Assembler)
* **Linux Linker**: GNU `ld` (binutils)
* **Windows Linker**: Microsoft Visual Studio Linker (`link.exe`) from the x64 Native Tools Command Prompt

### Linux Build

Using `make`:
```bash
make
```

Or manually:
```bash
nasm -f elf64 AMDRyzer.asm -o AMDRyzer.o
ld AMDRyzer.o -o AMDRyzer
```

Run the binary:
```bash
./AMDRyzer
```

*Note: Option 3 (Sector 0 Boot Signature Analysis) requires root privileges (`sudo ./AMDRyzer`) to read raw block devices.*

### Windows Build

Using `build.bat` (from the **x64 Native Tools Command Prompt for VS**):
```cmd
build.bat
```

Or manually:
```cmd
nasm -f win64 AMDRyzer_win.asm -o AMDRyzer_win.obj
link.exe /nologo /subsystem:console /entry:main AMDRyzer_win.obj kernel32.lib /out:AMDRyzer_win.exe
```

Run the executable:
```cmd
.\AMDRyzer_win.exe
```

*Note: Raw disk reads on Windows (`\\.\PhysicalDrive0`) require running the terminal as Administrator.*

---

## Safety and Operational Scope

AMDRyzer is strictly a read-only diagnostic and telemetry utility. It allocates memory exclusively within its own process space and issues read-only requests to block storage. It does not write to the boot sector, modify CPU voltage/frequency states, or alter persistent system configuration.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
