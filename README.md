# AMDRyzer v3.0 - Universal Hardware Diagnostic Tool

AMDRyzer is a lightweight, low-level hardware profiling and diagnostic utility written entirely in x64 Linux assembly. Originally targeted exclusively at AMD platforms, v3.0 introduces universal auto-detection for both AMD and Intel microarchitectures. 

This tool bypasses standard high-level libraries (like glibc) to interact directly with the Linux kernel via raw system calls, CPUID instruction branches, and hardware time-stamp counters.

## Core Features

- Microarchitecture Identification: Directly queries CPU registers to map vendor (GenuineIntel / AuthenticAMD), brand strings, logical core counts, and L2/L3 cache topologies.
- AVX2 Memory Benchmarking: Allocates 256MB of physical RAM via sys_mmap and bombards it with 4-pass, 256-bit wide alternating bit patterns (0xFF, 0x00, 0x55, 0xAA) using vpbroadcastd.
- Hardware Latency Profiling: Utilizes serialized lfence and rdtsc instructions to measure the exact CPU clock cycle latency of the memory stress test.
- Bare-Metal Block Access: Directly parses /proc/partitions and attempts raw sector reads of /dev/sda to validate the Master Boot Record (MBR) 0xAA55 hex signature.
- Kernel Sensor Polling: Reads and parses live motherboard thermal zones and CPU frequency governors directly from sysfs.

## Prerequisites

- x86_64 Linux-based operating system
- NASM (Netwide Assembler)
- Root privileges (Required only for Option 4: Boot Sector Analysis)

## Building from Source

No standard C library is required. Assemble and link directly as a standalone ELF64 binary:

nasm -f elf64 AMDRyzer.asm -o AMDRyzer.o
ld AMDRyzer.o -o AMDRyzer

## Usage

Run the executable directly from the terminal. 

./AMDRyzer

Note: To successfully analyze Sector 0 of your primary storage drive (Menu Option 4), you must run the tool with sudo, otherwise the kernel will block the sys_open call and return an access error.

## Safety & Scope

Unlike previous stubbed versions, v3.0 is completely read-only. It allocates its own memory for testing and only performs read operations on system block devices and files. It will not write to your boot sector, alter your CPU power states, or permanently modify system parameters. - There will be a separate branch coming in the near future with improved system writing capabilities; it's currently being developed and tested. This will lead to two versions of the application a safe to run read only and a more advanced read/write application.

## Author

Ryan Osacra
