; AMDRyzer - Advanced AMD Ryzen System Optimization Tool v2.0
; Optimized for AMD Ryzen processors using AVX2/AVX-512
; Author: Ryan K

section .data
    ; Enhanced menu strings with more options
    menu_header      db "=== AMDRyzer v2.0 ===", 0xA
                     db "Advanced AMD Ryzen System Optimization Tool", 0xA, 0xA, 0
    menu_options     db "1. System Diagnostics", 0xA
                     db "2. Memory Analysis", 0xA
                     db "3. Storage Tools", 0xA
                     db "4. Boot Repair", 0xA
                     db "5. Performance Optimizer", 0xA
                     db "6. Temperature Monitor", 0xA
                     db "7. Core Manager", 0xA
                     db "8. Exit", 0xA
                     db "Select option (1-8): ", 0
    
    ; Detailed status messages
    msg_cpu_check    db "Performing comprehensive CPU analysis:", 0xA
                     db "- Checking core configuration", 0xA
                     db "- Verifying cache hierarchy", 0xA
                     db "- Testing AVX support", 0xA
                     db "- Measuring frequencies", 0xA, 0
    
    msg_mem_check    db "Initiating advanced memory diagnostics:", 0xA
                     db "- Testing RAM integrity", 0xA
                     db "- Checking timing parameters", 0xA
                     db "- Verifying memory channels", 0xA
                     db "- Analyzing FCLK/UCLK sync", 0xA, 0
    
    msg_disk_check   db "Starting comprehensive storage analysis:", 0xA
                     db "- Scanning partition table", 0xA
                     db "- Checking sector health", 0xA
                     db "- Analyzing file system", 0xA
                     db "- Testing read speeds", 0xA, 0
    
    msg_boot_check   db "Performing boot sector analysis:", 0xA
                     db "- Verifying MBR/GPT structure", 0xA
                     db "- Checking boot parameters", 0xA
                     db "- Analyzing boot sequence", 0xA, 0
    
    msg_perf_check   db "Running performance diagnostics:", 0xA
                     db "- Analyzing power states", 0xA
                     db "- Checking boost behavior", 0xA
                     db "- Monitoring voltages", 0xA, 0
    
    msg_temp_check   db "Monitoring thermal conditions:", 0xA
                     db "- Per-core temperature", 0xA
                     db "- Socket temperature", 0xA
                     db "- VRM temperature", 0xA, 0
    
    msg_core_check   db "Analyzing core configuration:", 0xA
                     db "- Core/Thread mapping", 0xA
                     db "- CCX topology", 0xA
                     db "- Core power states", 0xA, 0

    ; Error messages
    err_avx         db "Error: AVX support not detected", 0xA, 0
    err_temp        db "Error: Unable to read temperature sensor", 0xA, 0
    err_mem         db "Error: Memory test failed at address: ", 0
    err_disk        db "Error: Disk access failed, sector: ", 0
    err_cpu         db "Error: Unsupported CPU detected", 0xA, 0
    err_features    db "Error: Required CPU features not available", 0xA, 0
    err_checksum    db "Error: Sector checksum verification failed at sector: ", 0

    ; Format strings
    fmt_temp        db "Core %d Temperature: %d°C", 0xA, 0
    fmt_freq        db "Core %d Frequency: %d MHz", 0xA, 0
    fmt_mem         db "Memory Channel %d: %d MB/s", 0xA, 0
    fmt_cache       db "L%d Cache: %d KB", 0xA, 0

    ; CPU feature detection masks
    avx2_mask       dq 0x20
    avx512_mask     dq 0x10000
    smt_mask        dq 0x1000000

    ; Performance monitoring constants
    perf_event_cpu  dq 0x0000
    perf_event_mem  dq 0x0001
    perf_event_io   dq 0x0002

section .bss
    ; Extended data buffers
    cpu_info        resb 64     ; Extended CPU information buffer
    temp_buffer     resb 4096   ; Enlarged general purpose buffer
    perf_data       resb 1024   ; Performance metrics buffer
    core_temps      resb 256    ; Per-core temperature buffer
    mem_test_buf    resb 65536  ; Memory testing buffer
    disk_buffer     resb 4096   ; Disk operation buffer
    
    ; State tracking variables
    current_core    resq 1      ; Current core being processed
    error_code      resq 1      ; Last error code
    test_status     resq 1      ; Current test status
    core_count      resq 1      ; Number of CPU cores
    
    ; Performance monitoring
    perf_counters   resq 8      ; Hardware performance counters
    freq_data       resq 32     ; Frequency measurement data
    voltage_data    resq 32     ; Voltage measurement data

section .text
global _start

_start:
    ; Initialize system and verify CPU compatibility
    call init_system
    test rax, rax
    jz init_error

    ; Enable advanced CPU features
    call enable_cpu_features
    
    ; Main program loop with enhanced error handling
main_loop:
    ; Clear screen and display menu
    call clear_screen
    mov rdi, menu_header
    call print_string
    mov rdi, menu_options
    call print_string
    
    ; Get and validate user input
    call read_input
    call validate_input
    test rax, rax
    jz invalid_input
    
    ; Enhanced menu processing
    cmp al, '1'
    je system_diagnostics
    cmp al, '2'
    je memory_analysis
    cmp al, '3'
    je storage_tools
    cmp al, '4'
    je boot_repair
    cmp al, '5'
    je performance_optimizer
    cmp al, '6'
    je temperature_monitor
    cmp al, '7'
    je core_manager
    cmp al, '8'
    je exit_program
    jmp main_loop

; ===== System Diagnostics =====
system_diagnostics:
    push rbp
    mov rbp, rsp
    sub rsp, 32             ; Reserve stack space

    ; Display diagnostic header
    mov rdi, msg_cpu_check
    call print_string

    ; Get detailed CPU information
    call get_cpu_details
    test rax, rax
    jz .cpu_error

    ; Check CPU features
    call check_cpu_features
    test rax, rax
    jz .feature_error

    ; Analyze CPU topology
    call analyze_cpu_topology
    
    ; Test cache hierarchy
    call test_cache_hierarchy
    
    ; Measure base frequencies
    call measure_frequencies
    
    ; Display comprehensive results
    call display_cpu_report

    mov rsp, rbp
    pop rbp
    jmp main_loop

.cpu_error:
    mov rdi, err_cpu
    call print_error
    jmp .cleanup

.feature_error:
    mov rdi, err_features
    call print_error

.cleanup:
    mov rsp, rbp
    pop rbp
    jmp main_loop

; ===== Memory Analysis =====
memory_analysis:
    push rbp
    mov rbp, rsp
    sub rsp, 64             ; Extended stack frame

    ; Initialize AVX for memory testing
    vzeroupper
    
    ; Test memory in chunks using AVX-512 if available
    mov rdi, msg_mem_check
    call print_string
    
    ; Perform memory channel analysis
    call analyze_memory_channels
    
    ; Test memory integrity
    mov rdi, mem_test_buf
    mov rsi, 65536
    call test_memory_integrity
    
    ; Check memory timing parameters
    call check_memory_timings
    
    ; Verify infinity fabric synchronization
    call check_fclk_sync
    
    ; Display detailed memory report
    call display_memory_report

    mov rsp, rbp
    pop rbp
    jmp main_loop

; ===== Storage Tools =====
storage_tools:
    push rbp
    mov rbp, rsp
    sub rsp, 128            ; Large stack frame for disk operations

    ; Initialize disk subsystem
    call init_disk_subsystem
    
    ; Scan partition table
    mov rdi, disk_buffer
    call scan_partition_table
    
    ; Check sector health
    mov rcx, 1000          ; Number of sectors to check
    call verify_disk_sectors
    
    ; Analyze file system
    call analyze_filesystem
    
    ; Perform disk benchmarks
    call benchmark_disk_performance
    
    ; Generate comprehensive report
    call generate_disk_report

    mov rsp, rbp
    pop rbp
    jmp main_loop

; ===== Boot Repair =====
boot_repair:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; Display boot check message
    mov rdi, msg_boot_check
    call print_string

    ; Analyze boot sector
    call analyze_boot_sector
    
    ; Check partition table
    call check_partition_table
    
    ; Verify boot parameters
    call verify_boot_params
    
    ; Generate boot report
    call generate_boot_report

    mov rsp, rbp
    pop rbp
    jmp main_loop

; ===== Performance Optimizer =====
performance_optimizer:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; Analyze current performance state
    call analyze_performance_state
    
    ; Check power delivery
    call check_power_delivery
    
    ; Monitor boost behavior
    call monitor_boost_behavior
    
    ; Optimize core configuration
    call optimize_core_config
    
    ; Apply optimized settings
    call apply_performance_settings
    
    ; Verify optimization results
    call verify_optimization

    mov rsp, rbp
    pop rbp
    jmp main_loop

; ===== Temperature Monitor =====
temperature_monitor:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; Initialize temperature monitoring
    call init_temp_monitor
    
    ; Read temperature sensors
    mov rcx, [core_count]
    xor rbx, rbx           ; Core counter

.temp_loop:
    push rcx
    mov rdi, rbx
    call read_core_temp
    mov [core_temps + rbx*8], rax
    
    ; Format and display temperature
    mov rdi, fmt_temp
    mov rsi, rbx
    mov rdx, rax
    call printf
    
    inc rbx
    pop rcx
    loop .temp_loop
    
    ; Check thermal throttling
    call check_thermal_throttling
    
    ; Display thermal summary
    call display_thermal_report

    mov rsp, rbp
    pop rbp
    jmp main_loop

; ===== Core Manager =====
core_manager:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; Get current core configuration
    call get_core_config
    
    ; Analyze CCX topology
    call analyze_ccx_topology
    
    ; Check core power states
    call check_core_states
    
    ; Monitor per-core utilization
    call monitor_core_usage
    
    ; Generate core management report
    call generate_core_report

    mov rsp, rbp
    pop rbp
    jmp main_loop

; ===== Utility Functions =====

; CPU Feature Detection
check_cpu_features:
    push rbx
    push rcx
    push rdx
    
    ; Get CPU vendor string
    xor eax, eax
    cpuid
    mov [cpu_info], ebx
    mov [cpu_info+4], edx
    mov [cpu_info+8], ecx
    
    ; Get feature flags
    mov eax, 1
    cpuid
    mov [cpu_info+12], edx   ; Standard features
    mov [cpu_info+16], ecx   ; Extended features
    
    ; Check for AVX2
    mov eax, 7
    xor ecx, ecx
    cpuid
    test ebx, [avx2_mask]
    jz .no_avx2
    
    ; Check for AVX-512
    test ebx, [avx512_mask]
    jz .no_avx512
    
    ; Success
    mov rax, 1
    jmp .done

.no_avx2:
    mov rdi, err_avx
    call print_string
    xor rax, rax
    jmp .done

.no_avx512:
    ; AVX2 available but no AVX-512
    mov rax, 2

.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; Memory Testing
test_memory_integrity:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Parameters:
    ; rdi = buffer address
    ; rsi = size to test
    
    ; Initialize test pattern
    vpcmpeqd ymm0, ymm0, ymm0   ; All 1's
    
    ; Write test pattern
    mov rcx, rsi
    shr rcx, 5                  ; Divide by 32 (AVX2 register size)
    
.write_loop:
    vmovdqu [rdi], ymm0
    add rdi, 32
    dec rcx
    jnz .write_loop
    
    ; Verify pattern
    sub rdi, rsi                ; Reset address
    mov rcx, rsi
    shr rcx, 5
    
.verify_loop:
    vmovdqu ymm1, [rdi]
    vpcmpeqd ymm2, ymm1, ymm0
    vptest ymm2, ymm2
    jnz .mismatch
    
    add rdi, 32
    dec rcx
    jnz .verify_loop
    
    ; Success
    mov rax, 1
    jmp .done
    
.mismatch:
    ; Calculate failing address
    mov rax, rdi
    sub rax, [rbp+16]          ; Original buffer address
    
    ; Report error
    push rax
    mov rdi, err_mem
    call print_string
    pop rdi
    call print_hex
    
    xor rax, rax               ; Return failure

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; Disk Operations
verify_disk_sectors:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Parameters:
    ; rcx = number of sectors to check
    
    ; Initialize disk buffer
    mov rdi, disk_buffer
    mov rsi, 4096
    call clear_buffer
    
    ; Read and verify sectors
.sector_loop:
    push rcx
    
    ; Read sector
    mov rax, rcx              ; Sector number
    mov rdi, disk_buffer
    call read_sector
    test rax, rax
    jz .read_error
    
    ; Verify sector integrity
    mov rdi, disk_buffer
    call verify_sector_checksum
    test rax, rax
    jz .checksum_error
    
    pop rcx
    dec rcx
    jnz .sector_loop
    
    ; Success
    mov rax, 1
    jmp .done
    
.read_error:
    pop rcx
    mov rdi, err_disk
    call print_string
    mov rdi, rcx
    call print_number
    xor rax, rax
    jmp .done
    
.checksum_error:
    pop rcx
    mov rdi, err_checksum
    call print_string
    mov rdi, rcx
    call print_number
    xor rax, rax

.done:
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; Performance Monitoring
monitor_boost_behavior:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Initialize performance counters
    mov rcx, [perf_event_cpu]
    call setup_perf_counter
    
    ; Monitor each core
    mov rcx, [core_count]
    xor rbx, rbx               ; Core counter
    
.core_loop:
    push rcx
    
    ; Read current frequency
    mov rdi, rbx
    call read_core_freq
    mov [freq_data + rbx*8], rax
    
    ; Read current voltage
    call read_core_voltage
    mov [voltage_data + rbx*8], rax
    
    ; Check if boosting
    call check_boost_state
    mov [perf_data + rbx*8], rax
    
    inc rbx
    pop rcx
    dec rcx
    jnz .core_loop
    
    ; Generate boost report
    call generate_boost_report
    
    mov rsp, rbp
    pop rbp
    ret

; System Initialization
init_system:
    ; Verify CPU compatibility
    call check_cpu_vendor
    test rax, rax
    jz .cpu_error
    
    ; Initialize subsystems
    call init_perf_monitoring
    call init_temp_sensors
    call init_memory_controller
    
    ; Success
    mov rax, 1
    ret
    
.cpu_error:
    xor rax, rax
    ret

; Error Handling
handle_error:
    ; Save error code
    mov [error_code], rdi
    
    ; Log error
    call log_error
    
    ; Display error message
    mov rdi, [error_code]
    call print_error_message
    
    ret

; Clean Exit
exit_program:
    ; Cleanup and shutdown
    call cleanup_system
    
    ; Exit program
    mov rax, 60     ; sys_exit
    xor rdi, rdi    ; status = 0
    syscall

; String Utilities
print_string:
    push rdi
    mov rcx, -1
    xor al, al
    repne scasb
    not rcx
    dec rcx
    
    pop rsi
    mov rdx, rcx    ; Length
    mov rax, 1      ; sys_write
    mov rdi, 1      ; stdout
    syscall
    ret

print_hex:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Convert to hex string
    mov rsi, rsp
    call convert_to_hex
    
    ; Print result
    mov rdi, rsi
    call print_string
    
    mov rsp, rbp
    pop rbp
    ret

; Screen Management
clear_screen:
    push rbp
    mov rbp, rsp
    
    ; ANSI escape sequence to clear screen
    mov rdi, 27     ; ESC
    call putchar
    mov rdi, '['
    call putchar
    mov rdi, '2'
    call putchar
    mov rdi, 'J'
    call putchar
    
    ; Move cursor to home position
    mov rdi, 27
    call putchar
    mov rdi, '['
    call putchar
    mov rdi, 'H'
    call putchar
    
    mov rsp, rbp
    pop rbp
    ret

; Input Handling
read_input:
    mov rax, 0      ; sys_read
    mov rdi, 0      ; stdin
    mov rsi, temp_buffer
    mov rdx, 1
    syscall
    mov al, [temp_buffer]
    ret

validate_input:
    ; Check if input is within valid range
    cmp al, '1'
    jl .invalid
    cmp al, '8'
    jg .invalid
    mov rax, 1
    ret
    
.invalid:
    xor rax, rax
    ret

invalid_input:
    ; Handle invalid input
    mov rdi, err_invalid_input
    call print_string
    jmp main_loop

init_error:
    ; Handle initialization error
    mov rdi, err_init
    call print_string
    jmp exit_program

; Additional utility functions
putchar:
    push rdi
    mov rsi, rsp
    mov rax, 1      ; sys_write
    mov rdi, 1      ; stdout
    mov rdx, 1      ; length
    syscall
    pop rdi
    ret

print_number:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Convert number to string
    mov rsi, rsp
    call convert_to_decimal
    
    ; Print result
    mov rdi, rsi
    call print_string
    
    mov rsp, rbp
    pop rbp
    ret

print_error:
    ; Print error message in red
    push rdi
    
    ; ANSI red color
    mov rdi, 27
    call putchar
    mov rdi, '['
    call putchar
    mov rdi, '3'
    call putchar
    mov rdi, '1'
    call putchar
    mov rdi, 'm'
    call putchar
    
    ; Print message
    pop rdi
    call print_string
    
    ; Reset color
    mov rdi, 27
    call putchar
    mov rdi, '['
    call putchar
    mov rdi, '0'
    call putchar
    mov rdi, 'm'
    call putchar
    
    ret