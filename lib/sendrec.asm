; See ../h/com.h for C definitions
%define SEND 1
%define RECEIVE 2
%define BOTH 3
%define SYSVEC 32

;========================================================================;
;                           send and receive                              ;
;========================================================================;
; send(), receive(), sendrec() all save bp, but destroy ax, bx, and cx.
global _send, _receive, _sendrec

_send:
    mov cx, SEND        ; send(dest, ptr)
    jmp L0

_receive:
    mov cx, RECEIVE     ; receive(src, ptr)
    jmp L0

_sendrec:
    mov cx, BOTH        ; sendrec(srcdest, ptr)
    jmp L0

L0:
    push bp             ; save bp
    mov bp, sp          ; can't index off sp
    mov ax, [bp+4]      ; ax = dest-src
    mov bx, [bp+6]      ; bx = message pointer
    int SYSVEC          ; trap to the kernel
    pop bp              ; restore bp
    ret                 ; return