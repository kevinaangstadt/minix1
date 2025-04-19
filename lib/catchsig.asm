global _begsig
extern _vectab, _M
mtype equ 2          ; M+mtype = &M.m_type

section .text
_begsig:
    push ax         ; after interrupt, save all regs
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    mov bx, sp
    mov bx, [bx + 18] ; bx = signal number
    mov ax, bx       ; ax = signal number
    dec bx           ; vectab[0] is for sig 1
    add bx, bx       ; pointers are two bytes on 8088
    mov bx, [_vectab + bx] ; bx = address of routine to call
    push dword [_M + mtype] ; push status of last system call
    push ax          ; func called with signal number as arg
    call bx
back:
    pop ax           ; get signal number off stack
    pop dword [_M + mtype] ; restore status of previous system call
    pop es           ; signal handling finished
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop word [dummy]      ; remove signal number from stack
    iret

section .data
dummy: dw 0