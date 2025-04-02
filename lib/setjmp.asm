global _setjmp, _longjmp
extern csv
section .text
_setjmp:
        mov     bx, sp
        mov     ax, [bx]
        mov     bx, [bx+2]
        mov     [bx], bp
        mov     [bx+2], sp
        mov     [bx+4], ax
        xor     ax, ax
        ret

_longjmp:
        xor     ax, ax
        call    csv
        mov     bx, [bp+4]
        mov     ax, [bp+6]
        or      ax, ax
        jne     L1
        inc     ax
L1:     mov     cx, [bx]
L2:     cmp     cx, [bp]
        je      L3
        mov     bp, [bp]
        or      bp, bp
        jne     L2
        hlt
L3:     mov     di, [bp-2]
        mov     si, [bp-4]
        mov     bp, [bp]
        mov     sp, [bx+2]
        mov     cx, [bx+4]
        mov     bx, sp
        mov     [bx], cx
        ret
