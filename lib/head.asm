global begtext, begdata, begbss, _data_org, _exit, auto_start
extern _main, _stackpt

section .text
auto_start:
begtext:
    jmp L0
    times 7 dw 0       ; kernel uses this area as stack for initial IRET
L0: mov sp, _stackpt
    call _main
L1: jmp L1             ; this will never be executed
_exit: jmp _exit       ; this will never be executed either

section .data
begdata:
_data_org:             ; fs needs to know where build stuffed table
    dw 0xDADA, 0, 0, 0, 0, 0, 0, 0 ; first 8 words of MM, FS, INIT are for stack
                                    ; 0xDADA is magic number for build

section .bss
begbss: