; AMDRyzer v3.0 - Advanced Hardware Diagnostic & Profiling Tool
; Features: CPU Topology, RDTSC Benchmarking, Multi-pass AVX2 Memory Testing
; Build: nasm -f elf64 AMDRyzer.asm -o AMDRyzer.o && ld AMDRyzer.o -o AMDRyzer
; Most recent dense update to a functional tool finally - ro

section .data
    ; Menu Strings
    menu_header       db 0xA, "=== AMDRyzer v3.0 / Advanced Hardware Diagnostic ===", 0xA
                      db "1. System Diagnostics (Topology & Architecture)", 0xA
                      db "2. Memory Analysis (Multi-Pass AVX2 Stress & Benchmark)", 0xA
                      db "3. Storage Tools (Partition Table Analysis)", 0xA
                      db "4. Boot Sector Analysis (MBR Signature Check)", 0xA
                      db "5. Performance Monitor (Thermal & Freq)", 0xA
                      db "6. Exit", 0xA, 0xA
                      db "Select option (1-6): ", 0

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
    msg_mmap_fail     db "[-] Memory allocation failed.", 0xA, 0
    msg_pass_1        db "[*] Pass 1/4: Writing 0xFF (All 1s)... ", 0
    msg_pass_2        db "[*] Pass 2/4: Writing 0x00 (All 0s)... ", 0
    msg_pass_3        db "[*] Pass 3/4: Writing 0x55 (Alternating Bits)... ", 0
    msg_pass_4        db "[*] Pass 4/4: Writing 0xAA (Inverse Alternating)... ", 0
    msg_ok            db "OK", 0xA, 0
    msg_mem_cycles    db "[+] Benchmark: Total CPU Cycles for AVX2 memory writes: ", 0

    ; Storage/Boot Strings
    msg_boot_start    db "[*] Analyzing Sector 0 of /dev/sda...", 0xA, 0
    msg_boot_pass     db "[+] Valid MBR Boot Signature (0xAA55) detected.", 0xA, 0
    msg_boot_fail     db "[-] Invalid boot signature or missing MBR.", 0xA, 0
    err_root          db "[-] Error: Root privileges required for raw block access.", 0xA, 0

    ; Sensor Strings
    msg_temp_lbl      db "[+] System Thermal Zone 0: ", 0
    msg_freq_lbl      db "[+] CPU0 Current Frequency: ", 0
    msg_celsius       db " C", 0xA, 0
    msg_mhz           db " MHz", 0xA, 0
    
    newline           db 0xA, 0

    ; File Paths
    path_partitions   db "/proc/partitions", 0
    path_sda          db "/dev/sda", 0
    path_thermal      db "/sys/class/thermal/thermal_zone0/temp", 0
    path_freq         db "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", 0

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
    file_buf          resb 4096
    num_str_buf       resb 32
    cycle_start       resq 1
    cycle_end         resq 1

section .text
global _start

_start:
.main_loop:
    mov rdi, menu_header
    call print_string

    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rsi, input_buf
    mov rdx, 2
    syscall

    mov al, [input_buf]
    
    cmp al, '1'
    je .cmd_diag
    cmp al, '2'
    je .cmd_mem
    cmp al, '3'
    je .cmd_storage
    cmp al, '4'
    je .cmd_boot
    cmp al, '5'
    je .cmd_perf
    cmp al, '6'
    je .exit
    jmp .main_loop

.cmd_diag:
    call do_sys_diag
    jmp .main_loop
.cmd_mem:
    call do_mem_test
    jmp .main_loop
.cmd_storage:
    call do_storage_analysis
    jmp .main_loop
.cmd_boot:
    call do_boot_analysis
    jmp .main_loop
.cmd_perf:
    call do_perf_monitor
    jmp .main_loop
.exit:
    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall

; ==========================================
; 1. System Diagnostics & CPU Topology
; ==========================================
do_sys_diag:
    ; --- Vendor Detection ---
    xor eax, eax
    cpuid
    mov dword [vendor_id], ebx
    mov dword [vendor_id+4], edx
    mov dword [vendor_id+8], ecx
    mov byte [vendor_id+12], 0

    cmp ebx, 0x756e6547 ; "Genu"
    je .is_intel
    cmp ebx, 0x68747541 ; "Auth"
    je .is_amd
    mov rdi, msg_unknown
    jmp .print_vendor
.is_intel:
    mov rdi, msg_intel
    jmp .print_vendor
.is_amd:
    mov rdi, msg_amd
.print_vendor:
    call print_string

    ; --- Brand String ---
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .check_cores
    mov rdi, brand_string
    mov eax, 0x80000002
    cpuid
    mov [rdi], eax
    mov [rdi+4], ebx
    mov [rdi+8], ecx
    mov [rdi+12], edx
    mov eax, 0x80000003
    cpuid
    mov [rdi+16], eax
    mov [rdi+20], ebx
    mov [rdi+24], ecx
    mov [rdi+28], edx
    mov eax, 0x80000004
    cpuid
    mov [rdi+32], eax
    mov [rdi+36], ebx
    mov [rdi+40], ecx
    mov [rdi+44], edx
    mov byte [rdi+48], 0

    mov rdi, msg_brand
    call print_string
    mov rdi, brand_string
    call print_string
    mov rdi, newline
    call print_string

.check_cores:
    ; --- Logical Core Count ---
    mov eax, 1
    cpuid
    shr ebx, 16
    and ebx, 0xFF       ; Extract logical processor count
    mov rax, rbx
    push rax
    mov rdi, msg_cores
    call print_string
    pop rax
    call print_number
    mov rdi, newline
    call print_string

    ; --- L2/L3 Cache Info ---
    mov eax, 0x80000006
    cpuid
    
    ; L2 Cache size (KB) is in ecx [31:16]
    mov r8d, ecx
    shr r8d, 16
    mov rax, r8
    push rax
    mov rdi, msg_l2_cache
    call print_string
    pop rax
    call print_number
    mov rdi, newline
    call print_string
    
    ; L3 Cache size (x 512KB chunks) is in edx [31:18]
    mov r8d, edx
    shr r8d, 18
    shr r8d, 1          ; Convert 512KB chunks to MB (/2)
    mov rax, r8
    push rax
    mov rdi, msg_l3_cache
    call print_string
    pop rax
    call print_number
    mov rdi, newline
    call print_string

    ; --- AVX2 Check ---
    mov eax, 7
    xor ecx, ecx
    cpuid
    mov r8, [avx2_mask]
    and rbx, r8
    jz .no_avx
    mov rdi, msg_avx2_pass
    call print_string
    ret
.no_avx:
    mov rdi, msg_avx2_fail
    call print_string
    ret

; ==========================================
; 2. Memory Analysis (Multi-Pass & Benchmark)
; ==========================================
do_mem_test:
    mov rdi, msg_mmap_start
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
    jl .fail
    mov [mem_ptr], rax

    ; Start RDTSC Benchmark
    call get_cycles
    mov [cycle_start], rax

    ; --- Pass 1: All 1s (0xFF) ---
    mov rdi, msg_pass_1
    call print_string
    vpcmpeqd ymm0, ymm0, ymm0   ; Set to all 1s
    call write_pattern
    mov rdi, msg_ok
    call print_string

    ; --- Pass 2: All 0s (0x00) ---
    mov rdi, msg_pass_2
    call print_string
    vpxor ymm0, ymm0, ymm0      ; Set to all 0s
    call write_pattern
    mov rdi, msg_ok
    call print_string

    ; --- Pass 3: Alternating 0x55 ---
    mov rdi, msg_pass_3
    call print_string
    ; Load 0x55555555 into a GPR, broadcast to YMM
    mov eax, 0x55555555
    vmovd xmm1, eax
    vpbroadcastd ymm0, xmm1
    call write_pattern
    mov rdi, msg_ok
    call print_string

    ; --- Pass 4: Alternating 0xAA ---
    mov rdi, msg_pass_4
    call print_string
    mov eax, 0xAAAAAAAA
    vmovd xmm1, eax
    vpbroadcastd ymm0, xmm1
    call write_pattern
    mov rdi, msg_ok
    call print_string

    ; End RDTSC Benchmark
    call get_cycles
    mov [cycle_end], rax

    ; Calculate and print cycles
    mov rax, [cycle_end]
    sub rax, [cycle_start]
    push rax
    mov rdi, msg_mem_cycles
    call print_string
    pop rax
    call print_number
    mov rdi, newline
    call print_string

    ; Cleanup
    mov rax, 11                 ; sys_munmap
    mov rdi, [mem_ptr]
    mov rsi, TEST_SIZE
    syscall
    ret

.fail:
    mov rdi, msg_mmap_fail
    call print_string
    ret

; Helper for memory passes
write_pattern:
    mov rdi, [mem_ptr]
    mov rcx, TEST_SIZE
    shr rcx, 5                  ; Convert bytes to 32-byte (YMM) chunks
.loop:
    vmovdqu [rdi], ymm0
    add rdi, 32
    dec rcx
    jnz .loop
    ret

; RDTSC Helper
get_cycles:
    lfence              ; Serialize execution
    rdtsc
    shl rdx, 32
    or rax, rdx
    ret

; ==========================================
; 3. Storage Tools
; ==========================================
do_storage_analysis:
    mov rax, 2          ; sys_open
    mov rdi, path_partitions
    xor rsi, rsi        ; O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .done

    mov r8, rax         ; save fd
.read_loop:
    mov rax, 0          ; sys_read
    mov rdi, r8
    mov rsi, file_buf
    mov rdx, 4095
    syscall
    test rax, rax
    jle .close
    
    mov byte [file_buf+rax], 0
    mov rdi, file_buf
    call print_string
    jmp .read_loop
.close:
    mov rax, 3          ; sys_close
    mov rdi, r8
    syscall
.done:
    ret

; ==========================================
; 4. Boot Sector Analysis
; ==========================================
do_boot_analysis:
    mov rdi, msg_boot_start
    call print_string

    mov rax, 2          ; sys_open
    mov rdi, path_sda
    xor rsi, rsi        ; O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .no_perms

    mov r8, rax         
    mov rax, 0          ; sys_read
    mov rdi, r8
    mov rsi, file_buf
    mov rdx, 512        ; Sector 0 size
    syscall
    
    push rax
    mov rax, 3          ; sys_close
    mov rdi, r8
    syscall
    pop rax
    
    cmp rax, 512
    jne .invalid

    movzx r10, byte [file_buf+510]
    movzx r11, byte [file_buf+511]
    cmp r10, 0x55
    jne .invalid
    cmp r11, 0xAA
    jne .invalid

    mov rdi, msg_boot_pass
    call print_string
    ret
.invalid:
    mov rdi, msg_boot_fail
    call print_string
    ret
.no_perms:
    mov rdi, err_root
    call print_string
    ret

; ==========================================
; 5. Performance Monitor
; ==========================================
do_perf_monitor:
    ; Read Thermal Zone
    mov rdi, path_thermal
    call read_int_from_file
    test rax, rax
    js .skip_temp
    
    mov rcx, 1000
    xor rdx, rdx
    div rcx
    push rax
    mov rdi, msg_temp_lbl
    call print_string
    pop rax
    call print_number
    mov rdi, msg_celsius
    call print_string

.skip_temp:
    ; Read Freq
    mov rdi, path_freq
    call read_int_from_file
    test rax, rax
    js .done
    
    mov rcx, 1000
    xor rdx, rdx
    div rcx
    push rax
    mov rdi, msg_freq_lbl
    call print_string
    pop rax
    call print_number
    mov rdi, msg_mhz
    call print_string
.done:
    ret

; ==========================================
; Utility Functions
; ==========================================
print_string:
    push rdi
    mov rcx, -1
    xor al, al
    repne scasb
    not rcx
    dec rcx
    pop rsi
    mov rdx, rcx
    mov rax, 1
    mov rdi, 1
    syscall
    ret

print_number:
    mov r8, rax
    mov rcx, 10
    mov rsi, num_str_buf + 30
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

read_int_from_file:
    mov rax, 2
    xor rsi, rsi
    xor rdx, rdx
    syscall
    test rax, rax
    js .err
    mov r8, rax
    mov rax, 0
    mov rdi, r8
    mov rsi, file_buf
    mov rdx, 63
    syscall
    test rax, rax
    jle .close_err
    mov byte [file_buf+rax], 0
    xor rax, rax
    xor rcx, rcx
.parse:
    movzx rdx, byte [file_buf+rcx]
    cmp dl, '0'
    jl .done_parse
    cmp dl, '9'
    jg .done_parse
    sub dl, '0'
    imul rax, 10
    add rax, rdx
    inc rcx
    jmp .parse
.done_parse:
    push rax
    mov rax, 3
    mov rdi, r8
    syscall
    pop rax
    ret
.close_err:
    mov rax, 3
    mov rdi, r8
    syscall
.err:
    mov rax, -1
    ret
