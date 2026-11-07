default rel

; AMDRyzer v4.2 - Windows Native Execution (Register Collision Fixed)
; Compiles with NASM and MSVC Linker

extern GetStdHandle
extern ReadFile
extern WriteFile
extern VirtualAlloc
extern VirtualFree
extern CreateFileA
extern CloseHandle
extern ExitProcess

section .data
    menu_header       db 0Dh, 0Ah, "=== AMDRyzer v4.2 / Windows Hardware Diagnostics ===", 0Dh, 0Ah
                      db "1. System Diagnostics (Topology & Architecture)", 0Dh, 0Ah
                      db "2. Memory Analysis (VirtualAlloc AVX2 Benchmark)", 0Dh, 0Ah
                      db "3. Boot Sector Analysis (Raw PhysicalDrive0 Read)", 0Dh, 0Ah
                      db "4. Generate Hardware Fine-Tuning Guide (TXT)", 0Dh, 0Ah
                      db "5. Exit", 0Dh, 0Ah, 0Dh, 0Ah
                      db "Select option (1-5): ", 0

    ; CPU Strings
    msg_intel         db "[+] Architecture: Intel (GenuineIntel)", 0Dh, 0Ah, 0
    msg_amd           db "[+] Architecture: AMD (AuthenticAMD)", 0Dh, 0Ah, 0
    msg_unknown       db "[?] Architecture: Unknown Vendor", 0Dh, 0Ah, 0
    msg_brand         db "[+] Processor: ", 0
    msg_cores         db "[+] Logical Cores Detected: ", 0
    msg_l2_cache      db "[+] L2 Cache Size (KB): ", 0
    msg_l3_cache      db "[+] L3 Cache Size (MB): ", 0
    msg_intel_cache   db "[*] Cache Topology: AMD Extended Leaf 0x80000006 (Intel uses Leaf 0x04)", 0Dh, 0Ah, 0
    
    msg_avx2_pass     db "[+] AVX2 Instructions: Supported", 0Dh, 0Ah, 0
    msg_avx2_fail     db "[-] AVX2 Instructions: NOT Supported", 0Dh, 0Ah, 0

    ; Memory Strings
    msg_mem_start     db "[*] Allocating 256MB physical RAM via VirtualAlloc...", 0Dh, 0Ah, 0
    msg_mem_pass      db "[+] Memory integrity test passed using AVX2.", 0Dh, 0Ah, 0
    msg_mem_fail      db "[-] Memory allocation failed.", 0Dh, 0Ah, 0
    msg_pass_1        db "[*] Pass 1/4: Writing 0xFF (All 1s)... OK", 0Dh, 0Ah, 0
    msg_pass_2        db "[*] Pass 2/4: Writing 0x00 (All 0s)... OK", 0Dh, 0Ah, 0
    msg_pass_3        db "[*] Pass 3/4: Writing 0x55 (Alternating)... OK", 0Dh, 0Ah, 0
    msg_pass_4        db "[*] Pass 4/4: Writing 0xAA (Inverse)... OK", 0Dh, 0Ah, 0
    msg_cycles        db "[+] Benchmark: CPU Cycles elapsed: ", 0

    ; Storage Strings
    drive_path        db "\\.\PhysicalDrive0", 0
    msg_boot_start    db "[*] Analyzing Sector 0 of PhysicalDrive0...", 0Dh, 0Ah, 0
    msg_boot_pass     db "[+] Valid MBR Boot Signature (0xAA55) detected.", 0Dh, 0Ah, 0
    msg_boot_fail     db "[-] Invalid boot signature.", 0Dh, 0Ah, 0
    err_admin         db "[-] Error: Run As Administrator required for raw disk access.", 0Dh, 0Ah, 0

    ; Tips Feature
    tips_file         db "AMDRyzer_Tuning_Guide.txt", 0
    msg_tips_start    db "[*] Generating hardware tuning guide...", 0Dh, 0Ah, 0
    msg_tips_pass     db "[+] Success! 'AMDRyzer_Tuning_Guide.txt' saved to directory.", 0Dh, 0Ah, 0
    msg_tips_fail     db "[-] Failed to write file.", 0Dh, 0Ah, 0

    tips_content      db "=== AMDRyzer Hardware Fine-Tuning Guide ===", 0Dh, 0Ah
                      db "1. Infinity Fabric (FCLK): Always maintain a 1:1 ratio between FCLK and MCLK (Memory Clock). For 6000MHz RAM, set FCLK to 3000MHz.", 0Dh, 0Ah
                      db "2. Precision Boost Overdrive (PBO): Use Curve Optimizer with negative offsets (-15 to -30) per-core to undervolt. This lowers thermals and INCREASES boost clocks.", 0Dh, 0Ah
                      db "3. VSOC Voltage: Keep VSOC under 1.25V (ideally 1.20V) to prevent degradation on Ryzen 7000/8000 processors when EXPO is enabled.", 0Dh, 0Ah
                      db "4. Memory Context Restore: Enable this in BIOS to drastically reduce DDR5 boot training times.", 0Dh, 0Ah
                      db "5. NVMe Storage: Ensure your M.2 drives have at least 10% free space for SLC caching to maintain peak write speeds.", 0Dh, 0Ah, 0
    tips_len          equ $ - tips_content - 1

    newline           db 0Dh, 0Ah, 0

    ; Win32 Constants
    STD_OUTPUT_HANDLE equ -11
    STD_INPUT_HANDLE  equ -10
    MEM_COMMIT        equ 0x00001000
    MEM_RESERVE       equ 0x00002000
    PAGE_READWRITE    equ 0x04
    MEM_RELEASE       equ 0x8000
    TEST_SIZE         equ 268435456 ; 256 MB

section .bss
    hStdOut           resq 1
    hStdIn            resq 1
    hFile             resq 1
    chars_rw          resq 1
    input_buf         resb 16
    vendor_id         resb 13
    brand_string      resb 49
    mem_ptr           resq 1
    file_buf          resb 512
    num_str_buf       resb 32
    cycle_start       resq 1

section .text
global main

main:
    ; Establish a massive, permanent 128-byte stack frame.
    push rbp
    mov rbp, rsp
    sub rsp, 128
    and rsp, -16

    ; Get console handles
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov [rel hStdOut], rax

    mov rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov [rel hStdIn], rax

.main_loop:
    lea rcx, [rel menu_header]
    call print_string

    ; ReadFile from STDIN
    mov rcx, [rel hStdIn]
    lea rdx, [rel input_buf]
    mov r8, 16
    lea r9, [rel chars_rw]
    mov qword [rsp+32], 0
    call ReadFile

    ; If ReadFile fails or returns 0 bytes (EOF or closed pipe), exit cleanly
    test eax, eax
    jz .exit
    cmp qword [rel chars_rw], 0
    jz .exit

    ; Scan input_buf for first valid choice ('1' through '5')
    lea rsi, [rel input_buf]
    mov rcx, [rel chars_rw]
.find_char:
    mov al, [rsi]
    cmp al, '1'
    jb .next_c
    cmp al, '5'
    jbe .handle_choice
.next_c:
    inc rsi
    dec rcx
    jnz .find_char
    jmp .main_loop

.handle_choice:
    cmp al, '1'
    je .cmd_diag
    cmp al, '2'
    je .cmd_mem
    cmp al, '3'
    je .cmd_boot
    cmp al, '4'
    je .cmd_tips
    cmp al, '5'
    je .exit
    jmp .main_loop

.cmd_diag:
    ; Save RBX manually to our stack frame (Offset 80)
    mov [rsp+80], rbx
    
    xor eax, eax
    cpuid
    mov dword [rel vendor_id], ebx
    mov dword [rel vendor_id+4], edx
    mov dword [rel vendor_id+8], ecx
    mov byte [rel vendor_id+12], 0
    
    mov rbx, [rsp+80]
    
    cmp dword [rel vendor_id], 0x756e6547 ; "Genu"
    je .is_intel
    cmp dword [rel vendor_id], 0x68747541 ; "Auth"
    je .is_amd
    lea rcx, [rel msg_unknown]
    jmp .print_vendor
.is_intel:
    lea rcx, [rel msg_intel]
    jmp .print_vendor
.is_amd:
    lea rcx, [rel msg_amd]
.print_vendor:
    call print_string

    ; Brand String - Direct Addressing Fix
    mov [rsp+80], rbx
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .do_cores
    
    mov eax, 0x80000002
    cpuid
    mov dword [rel brand_string], eax
    mov dword [rel brand_string+4], ebx
    mov dword [rel brand_string+8], ecx
    mov dword [rel brand_string+12], edx
    
    mov eax, 0x80000003
    cpuid
    mov dword [rel brand_string+16], eax
    mov dword [rel brand_string+20], ebx
    mov dword [rel brand_string+24], ecx
    mov dword [rel brand_string+28], edx
    
    mov eax, 0x80000004
    cpuid
    mov dword [rel brand_string+32], eax
    mov dword [rel brand_string+36], ebx
    mov dword [rel brand_string+40], ecx
    mov dword [rel brand_string+44], edx
    mov byte [rel brand_string+48], 0

    mov rbx, [rsp+80]
    
    lea rcx, [rel msg_brand]
    call print_string
    lea rcx, [rel brand_string]
    call print_string
    lea rcx, [rel newline]
    call print_string

.do_cores:
    mov [rsp+80], rbx
    mov eax, 1
    cpuid
    shr ebx, 16
    and ebx, 0xFF
    mov [rsp+88], rbx       ; Save core count to stack
    mov rbx, [rsp+80]
    
    lea rcx, [rel msg_cores]
    call print_string
    mov rcx, [rsp+88]
    call print_number
    lea rcx, [rel newline]
    call print_string

.do_cache:
    mov [rsp+80], rbx
    
    ; Check if AMD ("AuthenticAMD")
    cmp dword [rel vendor_id], 0x68747541 ; "Auth"
    jne .intel_cache_note

    mov eax, 0x80000006
    cpuid
    
    ; L2 Cache size
    mov r8d, ecx
    shr r8d, 16
    mov [rsp+88], r8
    
    ; L3 Cache size
    mov r8d, edx
    shr r8d, 18
    shr r8d, 1
    mov [rsp+96], r8
    
    mov rbx, [rsp+80]
    
    lea rcx, [rel msg_l2_cache]
    call print_string
    mov rcx, [rsp+88]
    call print_number
    lea rcx, [rel newline]
    call print_string
    
    lea rcx, [rel msg_l3_cache]
    call print_string
    mov rcx, [rsp+96]
    call print_number
    lea rcx, [rel newline]
    call print_string
    jmp .do_avx_check

.intel_cache_note:
    mov rbx, [rsp+80]
    lea rcx, [rel msg_intel_cache]
    call print_string

.do_avx_check:
    mov [rsp+80], rbx
    mov eax, 7
    xor ecx, ecx
    cpuid
    mov r8d, 0x00000020
    and ebx, r8d
    mov [rsp+88], rbx
    mov rbx, [rsp+80]

    cmp qword [rsp+88], 0
    jz .no_avx
    lea rcx, [rel msg_avx2_pass]
    call print_string
    jmp .diag_done
.no_avx:
    lea rcx, [rel msg_avx2_fail]
    call print_string

.diag_done:
    jmp .main_loop


.cmd_mem:
    lea rcx, [rel msg_mem_start]
    call print_string

    xor rcx, rcx
    mov rdx, TEST_SIZE
    mov r8, MEM_COMMIT | MEM_RESERVE
    mov r9, PAGE_READWRITE
    call VirtualAlloc
    
    test rax, rax
    jz .mem_fail
    mov [rel mem_ptr], rax

    ; Start RDTSC Benchmark
    lfence
    rdtsc
    shl rdx, 32
    or rax, rdx
    mov [rel cycle_start], rax

    ; Run AVX2 Passes
    lea rcx, [rel msg_pass_1]
    call print_string
    vpcmpeqd ymm0, ymm0, ymm0
    call write_pattern

    lea rcx, [rel msg_pass_2]
    call print_string
    vpxor ymm0, ymm0, ymm0
    call write_pattern

    lea rcx, [rel msg_pass_3]
    call print_string
    mov eax, 0x55555555
    vmovd xmm1, eax
    vpbroadcastd ymm0, xmm1
    call write_pattern

    lea rcx, [rel msg_pass_4]
    call print_string
    mov eax, 0xAAAAAAAA
    vmovd xmm1, eax
    vpbroadcastd ymm0, xmm1
    call write_pattern

    ; End RDTSC Benchmark
    lfence
    rdtsc
    shl rdx, 32
    or rax, rdx
    sub rax, [rel cycle_start]
    
    mov [rsp+88], rax
    
    lea rcx, [rel msg_cycles]
    call print_string
    mov rcx, [rsp+88]
    call print_number
    lea rcx, [rel newline]
    call print_string

    lea rcx, [rel msg_mem_pass]
    call print_string

    ; Free Memory
    mov rcx, [rel mem_ptr]
    xor rdx, rdx
    mov r8, MEM_RELEASE
    call VirtualFree
    jmp .main_loop
.mem_fail:
    lea rcx, [rel msg_mem_fail]
    call print_string
    jmp .main_loop

.cmd_boot:
    lea rcx, [rel msg_boot_start]
    call print_string

    ; CreateFileA PhysicalDrive0
    lea rcx, [rel drive_path]
    mov rdx, 0x80000000         ; GENERIC_READ
    mov r8, 3                   ; FILE_SHARE_READ | FILE_SHARE_WRITE
    xor r9, r9
    mov qword [rsp+32], 3       ; OPEN_EXISTING
    mov qword [rsp+40], 0x80    ; FILE_ATTRIBUTE_NORMAL
    mov qword [rsp+48], 0
    call CreateFileA

    cmp rax, -1                 ; INVALID_HANDLE_VALUE
    je .boot_admin

    mov [rel hFile], rax
    
    ; ReadFile
    mov rcx, rax
    lea rdx, [rel file_buf]
    mov r8, 512
    lea r9, [rel chars_rw]
    mov qword [rsp+32], 0
    call ReadFile

    ; Close Handle
    mov rcx, [rel hFile]
    call CloseHandle

    movzx r10, byte [rel file_buf+510]
    movzx r11, byte [rel file_buf+511]
    cmp r10, 0x55
    jne .boot_fail
    cmp r11, 0xAA
    jne .boot_fail

    lea rcx, [rel msg_boot_pass]
    call print_string
    jmp .main_loop
.boot_fail:
    lea rcx, [rel msg_boot_fail]
    call print_string
    jmp .main_loop
.boot_admin:
    lea rcx, [rel err_admin]
    call print_string
    jmp .main_loop

.cmd_tips:
    lea rcx, [rel msg_tips_start]
    call print_string

    ; CreateFileA
    lea rcx, [rel tips_file]
    mov rdx, 0x40000000         ; GENERIC_WRITE
    xor r8, r8
    xor r9, r9
    mov qword [rsp+32], 2       ; CREATE_ALWAYS
    mov qword [rsp+40], 0x80    ; FILE_ATTRIBUTE_NORMAL
    mov qword [rsp+48], 0
    call CreateFileA

    cmp rax, -1
    je .tips_fail
    mov [rel hFile], rax

    ; WriteFile
    mov rcx, rax
    lea rdx, [rel tips_content]
    mov r8, tips_len
    lea r9, [rel chars_rw]
    mov qword [rsp+32], 0
    call WriteFile

    ; CloseHandle
    mov rcx, [rel hFile]
    call CloseHandle

    lea rcx, [rel msg_tips_pass]
    call print_string
    jmp .main_loop
.tips_fail:
    lea rcx, [rel msg_tips_fail]
    call print_string
    jmp .main_loop

.exit:
    xor rcx, rcx
    call ExitProcess

; Helper: AVX2 Write Loop
write_pattern:
    mov rdx, [rel mem_ptr]
    mov rcx, TEST_SIZE
    shr rcx, 5
.loop:
    vmovdqu [rdx], ymm0
    add rdx, 32
    dec rcx
    jnz .loop
    ret

; Helper: Print String (arg1: rcx = string ptr)
print_string:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    mov [rsp+48], rbx
    mov [rsp+56], rdi
    
    mov rdi, rcx
    mov rbx, rcx
    xor al, al
    mov rcx, -1
    cld                         ; Clear direction flag for safety
    repne scasb
    not rcx
    dec rcx
    
    mov r8, rcx
    mov rdx, rbx
    mov rcx, [rel hStdOut]
    lea r9, [rel chars_rw]
    mov qword [rsp+32], 0
    call WriteFile
    
    mov rbx, [rsp+48]
    mov rdi, [rsp+56]
    
    mov rsp, rbp
    pop rbp
    ret

; Helper: Print Number (arg1: rcx = value)
print_number:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    mov [rsp+48], rbx
    
    mov rax, rcx
    mov rbx, 10
    lea r8, [rel num_str_buf + 30]
    mov byte [r8+1], 0
.loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [r8], dl
    dec r8
    test rax, rax
    jnz .loop
    
    inc r8
    mov rcx, r8
    call print_string
    
    mov rbx, [rsp+48]
    
    mov rsp, rbp
    pop rbp
    ret
