%define STACKSIZE 8192

global _main, _exit, _edata, _end, _putc, _getc, _reset_diskette, _diskio
global csv, cret, begtext, begdata, begbss
global _cylsiz, _tracksiz, _drive

section .text
begtext:

start:
    mov dx, bx           ; bootblok puts # sectors/track in bx
    xor ax, ax
    mov bx, _edata       ; prepare to clear bss
    mov cx, _end
    sub cx, bx
    shr cx, 1
st_1:
    mov [bx], ax         ; clear bss
    add bx, 2
    loop st_1

    mov [_tracksiz], dx  ; dx (was bx) is # sectors/track
    add dx, dx
    mov [_cylsiz], dx    ; # sectors/cylinder
    mov sp, kerstack + STACKSIZE
    call _main
    mov bx, ax           ; put scan code for '=' in bx
    cli
    mov dx, 0x60
    mov ds, dx
    mov es, dx
    mov ss, dx
    jmp 0x60:0           ; jump to kernel

_exit:
    mov bx, [_tracksiz]
    jmp start

_putc:
    xor ax, ax
    call csv
    mov al, [bp+4]       ; al contains char to be printed
    mov ah, 14           ; 14 = print char
    mov bl, 1            ; foreground color
    push bp              ; not preserved
    int 0x10             ; call BIOS VIDEO_IO
    pop bp
    jmp cret

_getc:
    xor ah, ah
    int 0x16
    ret

_reset_diskette:
    xor ax, ax
    call csv
    push es              ; not preserved
    int 0x13             ; call BIOS DISKETTE_IO
    pop es
    jmp cret

; handle diskio(RW, sector_number, buffer, sector_count) call
; Do not issue a BIOS call that crosses a track boundary
_diskio:
    xor ax, ax
    call csv
    mov [tmp1], 0        ; tmp1 = # sectors actually transferred
    mov di, [bp+10]      ; di = # sectors to transfer
    mov [tmp2], di       ; tmp2 = # sectors to transfer
d0:
    mov ax, [bp+6]       ; ax = sector number to start at
    xor dx, dx           ; dx:ax is dividend
    div word [_cylsiz]   ; ax = cylinder, dx = sector within cylinder
    mov cl, ah           ; cl = hi-order bits of cylinder
    ror cl, 1            ; BIOS expects hi bits in a funny place
    ror cl, 1            ; ditto
    mov ch, al           ; cx = sector # in BIOS format
    mov ax, dx           ; ax = sector offset within cylinder
    xor dx, dx           ; dx:ax is dividend
    div word [_tracksiz] ; ax = head, dx = sector
    mov dh, al           ; dh = head
    or cl, dl            ; cl = 2 high-order cyl bits || sector
    inc cl               ; BIOS counts sectors starting at 1
    mov dl, [_drive]     ; dl = drive code (0-3 or 0x80 - 0x81)
    mov bx, [bp+8]       ; bx = address of buffer
    mov al, cl           ; al = sector #
    add al, [bp+10]      ; compute last sector
    dec al               ; al = last sector to transfer
    cmp al, [_tracksiz]  ; see if last sector is on next track
    jle d1               ; jump if last sector is on this track
    mov [bp+10], 1       ; transfer 1 sector at a time
d1:
    mov ah, [bp+4]       ; ah = READING or WRITING
    add ah, 2            ; BIOS codes are 2 and 3, not 0 and 1
    mov al, [bp+10]      ; al = # sectors to transfer
    mov [tmp], ax        ; al is # sectors to read/write
    push es              ; BIOS ruins es
    int 0x13             ; issue BIOS call
    pop es               ; restore es
    cmp ah, 0            ; ah != 0 means BIOS detected error
    jne d2               ; exit with error
    mov ax, [tmp]        ; fetch count of sectors transferred
    xor ah, ah           ; count is in ax
    add [tmp1], ax       ; tmp1 accumulates sectors transferred
    mov si, [tmp1]       ; are we done yet?
    cmp si, [tmp2]       ; ditto
    je d2                ; jump if done
    inc word [bp+6]      ; next time around, start 1 sector higher
    add word [bp+8], 0x200 ; move up in buffer by 512 bytes
    jmp d0
d2:
    jmp cret

csv:
    pop bx
    push bp
    mov bp, sp
    push di
    push si
    sub sp, ax
    jmp bx

cret:
    lea sp, [bp-4]
    pop si
    pop di
    pop bp
    ret

section .data
begdata:
tmp:    dw 0
tmp1:   dw 0
tmp2:   dw 0

section .bss
begbss:
kerstack: resw STACKSIZE / 2 ; kernel stack