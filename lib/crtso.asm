; This is the C run-time start-off routine.  It's job is to take the
; arguments as put on the stack by EXEC, and to parse them and set them up the
; way _main expects them.

; global _main, _exit, crtso, _environ
; global begtext, begdata, begbss, endtext, enddata, endbss

global begtext, crtso, begdata, _environ, begbss, ___mkargv
extern _main, _exit, endtext, enddata, endbss

section .text
begtext:
crtso:
    mov bx, sp
    mov cx, [bx]
    add bx, 2
    mov ax, cx
    inc ax
    shl ax, 1
    add ax, bx
___mkargv:
    mov [_environ], ax ; save envp in environ
    push ax            ; push environ
    push bx            ; push argv
    push cx            ; push argc
    call _main
    add sp, 6
    push ax            ; push exit status
    call _exit

section .data
begdata:
_environ: dw 0

section .bss
begbss: