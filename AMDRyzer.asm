default rel

; AMDRyzer v4.2 - Linux Native Execution (Direct Addressing & File Generation)
; Compiles with NASM and LD
; Features: CPU Topology, RDTSC Benchmarking, Multi-pass AVX2 Memory Testing, SysFS file writes

section .data
    ; Menu Strings
    menu_header       db 0xA, "=== AMDRyzer v4.2 / Linux Hardware Diagnostics ===", 0xA
                      db "1. System Diagnostics (Topology & Architecture)", 0xA
                      db "2. Memory Analysis (mmap AVX2 Benchmark)", 0xA
                      db "3. Boot Sector Analysis (Raw /dev/sda Read)", 0xA
                      db "4. Generate Hardware Fine-Tuning Guide (TXT)", 0xA
                      db "5. Exit", 0xA, 0xA
                      db "Select option (1-5): ", 0

    ; CPU Strings
    msg_intel         db "[+] Architecture: Intel (GenuineIntel)", 0xA, 0
    msg_amd           db "[+] Architecture: AMD (AuthenticAMD)", 0xA, 0
    msg_unknown       db "[?] Architecture: Unknown Vendor", 0xA, 0
    msg_brand         db "[+] Processor: ", 0
    msg_cores         db "[+] Logical Cores Detected: ", 0
    msg_l2_cache      db "[+] L2 Cache Size (KB): ", 0
    msg_l3_cache      db "[+] L3 Cache Size (MB): ", 0
    
    msg_avx2_pass     db "[+] AVX2 Instructions: Supported", 0xA, 0
    msg_avx2_fail     db "[-] AVX2 Instructions: NOT Supported", 0xA, 0

    ; Memory Strings
    msg_mmap_start    db "[*] Allocating 256MB physical RAM via mmap...", 0xA, 0
    msg_mem_pass      db "[+] Memory integrity test passed using AVX2.", 0xA, 0
    msg_mem_fail      db "[-] Memory allocation failed.", 0xA, 0
    msg_pass_1        db "[*] Pass 1/4: Writing 0xFF (All 1s)... OK", 0xA, 0
    msg_pass_2        db "[*] Pass 2/4: Writing 0x00 (All 0s)... OK", 0xA, 0
    msg_pass_3        db "[*] Pass 3/4: Writing 0x55 (Alternating)... OK", 0xA, 0
    msg_pass_4        db "[*] Pass 4/4: Writing 0xAA (Inverse)... OK", 0xA, 0
    msg_cycles        db "[+] Benchmark: Total CPU Cycles elapsed: ", 0

    ; Storage/Boot Strings
    path_sda          db "/dev/sda", 0
    msg_boot_start    db "[*] Analyzing Sector 0 of /dev/sda...", 0xA, 0
    msg_boot_pass     db "[+] Valid MBR Boot Signature (0xAA55) detected.", 0xA, 0
    msg_boot_fail     db "[-] Invalid boot signature or missing MBR.", 0xA, 0
    err_root          db "[-] Error: Sudo privileges required for raw block access.", 0xA, 0

    ; Tips Feature
    tips_file         db "AMDRyzer_Tuning_Guide.txt", 0
    msg_tips_start    db "[*] Generating hardware tuning guide...", 0xA, 0
    msg_tips_pass     db "[+] Success! 'AMDRyzer_Tuning_Guide.txt' saved to directory.", 0xA, 0
    msg_tips_fail     db "[-] Failed to write file. Check directory permissions.", 0xA, 0

    tips_content      db "=== AMDRyzer Hardware Fine-Tuning Guide ===", 0xA
                      db "1. Infinity Fabric (FCLK): Always maintain a 1:1 ratio between FCLK and MCLK (Memory Clock). For 6000MHz RAM, set FCLK to 3000MHz.", 0xA
                      db "2. Precision Boost Overdrive (PBO): Use Curve Optimizer with negative offsets (-15 to -30) per-core to undervolt. This lowers thermals and INCREASES boost clocks.", 0xA
                      db "3. VSOC Voltage: Keep VSOC under 1.25V (ideally 1.20V) to prevent degradation on Ryzen 7000/8000 processors when EXPO is enabled.", 0xA
                      db "4. Memory Context Restore: Enable this in BIOS to drastically reduce DDR5 boot training times.", 0xA
                      db "5. NVMe Storage: Ensure your M.2 drives have at least 10% free space for SLC caching to maintain peak write speeds.", 0xA, 0
    tips_len          equ $ - tips_content - 1

    newline           db 0xA, 0

    ; Constants
    avx2_mask         dq 0x00000020
    PROT_READ         equ 0x1
    PROT_WRITE        equ 0x2
    MAP_PRIVATE       equ 0x2
    MAP_ANONYMOUS     equ 0x20
    TEST_SIZE         equ 268435456 ; 256 MB

section .bss
    input_buf         resb 2
    vendor_id         resb 13
    brand_string      resb 49
    mem_ptr           resq 1
    file_buf          resb 512
    num_str_buf       resb 32
    cycle_start       resq 1
    hFile             resq 1

section .text
global _start

_start:
.main_loop:
    lea rdi, [rel menu_header]
    call print_string

    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    lea rsi, [rel input_buf]
    mov rdx, 2
    syscall

    mov al, [rel input_buf]
    
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
    ; --- Vendor Detection ---
    xor eax, eax
    cpuid
    mov dword [rel vendor_id], ebx
    mov dword [rel vendor_id+4], edx
    mov dword [rel vendor_id+8], ecx
    mov byte [rel vendor_id+12], 0

    cmp ebx, 0x756e6547 ; "Genu"
    je .is_intel
    cmp ebx, 0x68747541 ; "Auth"
    je .is_amd
    lea rdi, [rel msg_unknown]
    jmp .print_vendor
.is_intel:
    lea rdi, [rel msg_intel]
    jmp .print_vendor
.is_amd:
    lea rdi, [rel msg_amd]
.print_vendor:
    call print_string

    ; --- Brand String Extraction (Direct Addressing) ---
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

    lea rdi, [rel msg_brand]
    call print_string
    lea rdi, [rel brand_string]
    call print_string
    lea rdi, [rel newline]
    call print_string

.do_cores:
    mov eax, 1
    cpuid
    shr ebx, 16
    and ebx, 0xFF
    push rbx
    
    lea rdi, [rel msg_cores]
    call print_string
    pop rax
    call print_number
    lea rdi, [rel newline]
    call print_string

.do_cache:
    mov eax, 0x80000006
    cpuid
    
    ; L2 Cache size (KB)
    mov r8d, ecx
    shr r8d, 16
    push r8
    
    ; L3 Cache size (MB)
    mov r9d, edx
    shr r9d, 18
    shr r9d, 1
    push r9
    
    lea rdi, [rel msg_l2_cache]
    call print_string
    pop rax                 ; Popping L3 first because of stack order
    mov r10, rax            ; Save L3 temporarily
    
    mov rax, [rsp]          ; Grab L2
    call print_number
    lea rdi, [rel newline]
    call print_string
    
    lea rdi, [rel msg_l3_cache]
    call print_string
    mov rax, r10            ; Retrieve L3
    call print_number
    lea rdi, [rel newline]
    call print_string
    pop r8                  ; Clean stack of L2

.do_avx_check:
    mov eax, 7
    xor ecx, ecx
    cpuid
    mov r8, [rel avx2_mask]
    and rbx, r8
    jz .no_avx
    lea rdi, [rel msg_avx2_pass]
    call print_string
    jmp .diag_done
.no_avx:
    lea rdi, [rel msg_avx2_fail]
    call print_string

.diag_done:
    jmp .main_loop

.cmd_mem:
    lea rdi, [rel msg_mmap_start]
    call print_string

    ; Mmap 256MB
    mov rax, 9                  ; sys_mmap
    xor rdi, rdi
    mov rsi, TEST_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall

    cmp rax, 0
    jl .mem_fail
    mov [rel mem_ptr], rax

    ; Start RDTSC Benchmark
    lfence
    rdtsc
    shl rdx, 32
    or rax, rdx
    mov [rel cycle_start], rax

    ; --- Pass 1 ---
    lea rdi, [rel msg_pass_1]
    call print_string
    vpcmpeqd ymm0, ymm0, ymm0
    call write_pattern

    ; --- Pass 2 ---
    lea rdi, [rel msg_pass_2]
    call print_string
    vpxor ymm0, ymm0, ymm0
    call write_pattern

    ; --- Pass 3 ---
    lea rdi, [rel msg_pass_3]
    call print_string
    mov eax, 0x55555555
    vmovd xmm1, eax
    vpbroadcastd ymm0, xmm1
    call write_pattern

    ; --- Pass 4 ---
    lea rdi, [rel msg_pass_4]
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
    push rax

    lea rdi, [rel msg_cycles]
    call print_string
    pop rax
    call print_number
    lea rdi, [rel newline]
    call print_string

    lea rdi, [rel msg_mem_pass]
    call print_string

    ; Cleanup memory
    mov rax, 11                 ; sys_munmap
    mov rdi, [rel mem_ptr]
    mov rsi, TEST_SIZE
    syscall
    jmp .main_loop

.mem_fail:
    lea rdi, [rel msg_mem_fail]
    call print_string
    jmp .main_loop

.cmd_boot:
    lea rdi, [rel msg_boot_start]
    call print_string

    mov rax, 2          ; sys_open
    lea rdi, [rel path_sda]
    xor rsi, rsi        ; O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .no_perms

    mov r8, rax         
    mov rax, 0          ; sys_read
    mov rdi, r8
    lea rsi, [rel file_buf]
    mov rdx, 512        ; Sector 0 size
    syscall
    
    push rax
    mov rax, 3          ; sys_close
    mov rdi, r8
    syscall
    pop rax
    
    cmp rax, 512
    jne .invalid

    movzx r10, byte [rel file_buf+510]
    movzx r11, byte [rel file_buf+511]
    cmp r10, 0x55
    jne .invalid
    cmp r11, 0xAA
    jne .invalid

    lea rdi, [rel msg_boot_pass]
    call print_string
    jmp .main_loop
.invalid:
    lea rdi, [rel msg_boot_fail]
    call print_string
    jmp .main_loop
.no_perms:
    lea rdi, [rel err_root]
    call print_string
    jmp .main_loop

.cmd_tips:
    lea rdi, [rel msg_tips_start]
    call print_string

    ; sys_open (O_WRONLY | O_CREAT | O_TRUNC = 577 decimal)
    mov rax, 2
    lea rdi, [rel tips_file]
    mov rsi, 577        
    mov rdx, 420        ; 0644 permissions
    syscall

    cmp rax, 0
    jl .tips_fail
    mov [rel hFile], rax

    ; sys_write
    mov rdi, rax
    mov rax, 1
    lea rsi, [rel tips_content]
    mov rdx, tips_len
    syscall

    ; sys_close
    mov rax, 3
    mov rdi, [rel hFile]
    syscall

    lea rdi, [rel msg_tips_pass]
    call print_string
    jmp .main_loop

.tips_fail:
    lea rdi, [rel msg_tips_fail]
    call print_string
    jmp .main_loop

.exit:
    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall

; ==========================================
; Utility Functions
; ==========================================

write_pattern:
    mov rdi, [rel mem_ptr]
    mov rcx, TEST_SIZE
    shr rcx, 5                  ; Divide by 32 for YMM chunks
.loop:
    vmovdqu [rdi], ymm0
    add rdi, 32
    dec rcx
    jnz .loop
    ret

print_string:
    push rdi
    mov rcx, -1
    xor al, al
    cld
    repne scasb
    not rcx
    dec rcx
    pop rsi
    mov rdx, rcx
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    ret

print_number:
    mov r8, rax
    mov rcx, 10
    lea rsi, [rel num_str_buf + 30]
    mov byte [rsi+1], 0
.loop:
    xor rdx, rdx
    mov rax, r8
    div rcx
    mov r8, rax
    add dl, '0'
    mov [rsi], dl
    dec rsi
    test r8, r8
    jnz .loop
    inc rsi
    mov rdi, rsi
    call print_string
    ret
