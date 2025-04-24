bits 16
cpu 8086
; When the PC is powered on, it reads the first block from the floppy
; disk into address 0x7C00 and jumps to it. This boot block must contain
; the boot program in this file. The boot program first copies itself to
; address 192K - 512 (to get itself out of the way). Then it loads the 
; operating system from the boot diskette into memory, and then jumps to fsck.
; Loading is not trivial because the PC is unable to read a track into
; memory across a 64K boundary, so the positioning of everything is critical.
; The number of sectors to load is contained at address 504 of this block.
; The value is put there by the build program after it has discovered how
; big the operating system is. When the bootblok program is finished loading,
; it jumps indirectly to the program (fsck) whose address is given by the
; last two words in the boot block. 
;
; Summary of the words patched into the boot block by build:
; Word at 502: # sectors to load
; Word at 504: # DS value for fsck
; Word at 506: # PC value for fsck
; Word at 508: # CS value for fsck
; Word at 510: # Magic number (0xAA55) to indicate a boot block
;
; This version of the boot block must be assembled without separate I & D
; space.

%define LOADSEG 0x0060         ; here the boot block will start loading
%define BIOSSEG 0x07C0         ; here the boot block itself is loaded
%define BOOTSEG 0x2FE0         ; here it will copy itself (192K-512b)
%define DSKBASE 120            ; 120 = 4 * 0x1E = ptr to disk parameters

%define final   502
%define fsck_ds 504
%define fsck_pc 506
%define fsck_cs 508

global begtext, begdata, begbss, endtext, enddata, endbss  ; asld needs these

section .text
begtext:

; copy bootblock to bootseg
    mov ax, BIOSSEG
    mov ds, ax
    xor si, si           ; ds:si - original block
    mov ax, BOOTSEG
    mov es, ax
    xor di, di           ; es:di - new block
    mov cx, 256          ; # words to move
    rep movsw            ; copy loop

; start boot procedure
    jmp BOOTSEG:start    ; set cs to bootseg

start:
    mov dx, cs
    mov ds, dx           ; set ds to cs
    xor ax, ax
    mov es, ax           ; set es to 0
    mov ss, ax           ; set ss to 0
    mov sp, 1024         ; initialize sp (top of vector table)

; initialize disk parameters
    ; mov ax, atpar        ; tentatively assume 17 sector harddisk
    ; mov [es:DSKBASE], ax
    ; mov [es:DSKBASE+2], dx

; print greeting
    mov ax, 2            ; reset video
    int 0x10
    mov ax, 0x0200       ; BIOS call to put cursor in ul corner
    xor bx, bx
    xor dx, dx
    int 0x10
    mov bx, greet
    call print

; ; Determine if this is a 1.2M diskette by trying to read sector 15.
;     xor ax, ax
;     int 0x13
;     xor ax, ax
;     mov es, ax
;     mov ax, 0x0201
;     mov bx, 0x0600
;     mov cx, 0x000F
;     mov dx, 0x0000
;     int 0x13
;     jnb L1

; ; Error. It wasn't 1.2M. Now set up for 360K.
;     mov word [tracksiz], 9    ; 360K uses 9 sectors/track
;     xor ax, ax
;     mov es, ax
;     mov ax, pcpar
;     mov [es:DSKBASE], ax
;     int 0x13             ; diskette reset

; reset the hard disk
    xor ax, ax
    mov dl, 0x80
    int 0x13             ; reset hard disk

    ; DEBUG test loading one sector
    ; mov ax, 0x0060
    ; mov es, ax
    ; mov ax, 0x0201
    ; xor bx, bx
    ; mov cx, 0x0002
    ; mov dx, 0x0080
    ; int 0x13

L1:

; Load the operating system from diskette.
load:
    ;DEBUG
    mov ax, LOADSEG
    mov es, ax
    mov ax, 0x80
    mov ah, 0x1B       ; opcode for read LBA
    xor bx, bx
    mov cx, 0x0001      ; start from LBA address 1
    mov dx, 0x0000
    int 0x13

    mov ax, LOADSEG + 0x1000
    mov es, ax
    mov ax, [final]
    sub ax, 0x80
    mov ah, 0x1B       ; opcode for read LBA
    xor bx, bx
    mov cx, 0x0081      ; start from LBA address 1
    mov dx, 0x0000
    int 0x13
    
    ; push ax
    ; mov ah, 0x0e
    ; mov al, 'R'
    ; int 0x10             ; print 'R'
    ; pop ax
    ; call setreg          ; set up ah, cx, dx
    ; mov bx, [disksec]    ; bx = number of next sector to read
    ; add bx, 2            ; diskette sector 1 goes at 1536 ("sector" 3)
    ; shl bx, 1            ; multiply sector number by 32
    ; shl bx, 1            ; ditto
    ; shl bx, 1            ; ditto
    ; shl bx, 1            ; ditto
    ; shl bx, 1            ; ditto
    ; mov es, bx           ; core address is es:bx (with bx = 0)
    ; xor bx, bx           ; see above
    ; add [disksec], ax    ; ax tells how many sectors to read
    ; mov ah, 0x1B         ; opcode for read LBA
    ; int 0x13             ; call the BIOS for a read
    ; push ax
    ; mov ah, 0x0e
    ; mov al, 'T'
    ; int 0x10             ; print 'R'
    ; pop ax
    ; jb error             ; jump on diskette error
    ; mov ax, [disksec]    ; see if we are done loading
    ; cmp ax, [final]      ; ditto
    ; jb load              ; jump if there is more to load

; Loading done. Finish up.
    ; mov dx, 0x03F2       ; kill the motor
    ; mov ax, 0x000C
    ; out dx, ax
    
    cli
    mov bx, [tracksiz]   ; fsck expects # sectors/track in bx
    mov ax, [fsck_ds]    ; set segment registers
    mov ds, ax           ; when sep I&D DS != CS
    mov es, ax           ; otherwise they are the same.
    mov ss, ax           ; words 504 - 510 are patched by build

    jmp far [cs:fsck_pc]    ; jump to fsck

; Setting up the registes for an LBA should be straightforward.
setreg:
    mov ax, [final]   
    inc ax 
    sub ax, [disksec]    ; ax = # sectors left to read
    cmp ax, 0xFF
    jbe set1             ; jump if less than 255 
    mov ax, 0xFF         ; else set to 255
set1:
    ; LBA is the logical block address of the next sector to read
    mov cx, [disksec]    ; cx = # sectors to read
    xor dx, dx           ; uppor LBA is going to always be 0...small
    ret
    
; data is little endian
print_data:
    mov ax, [fsck_cs]
    mov ds, ax           ; Set data segment to LOADSEG
    xor si, si      ; Start address of memory to print
    mov bx, 1      ; Number of sectors to print
    mov cx, 9            ; Convert sectors to bytes (512 bytes per sector)
    shl bx, cl
    mov cx, bx
    add cx, si           ; Calculate end address

print_loop:
    mov ax, [si]         ; Load 16-bit word from memory
    push cx              ; Save cx
    push si              ; Save si

    ; Print low byte
    call print_hex       ; Print as 
    
    push ax 
    mov al, ' '
    mov ah, 0x0E
    int 0x10             ; Print space
    pop ax

    ; Print high byte
    mov al, ah           ; Move high byte to al
    call print_hex       ; Print as hex

    ; Print a space
    mov al, ' '
    mov ah, 0x0E
    int 0x10

    pop si               ; Restore si
    pop cx               ; Restore cx
    add si, 2            ; Move to the next word
    cmp si, cx           ; Check if we reached the end
    jb print_loop        ; Loop if not done
    ret

print_hex:
    push ax              ; Save ax
    push bx              ; Save bx
    push cx              ; Save cx

    mov ah, 0            ; Clear high byte
    mov bl, al           ; Copy byte to bl
    shr al, 1            ; Get high nibble
    shr al, 1
    shr al, 1
    shr al, 1
    call print_nibble    ; Print high nibble
    mov al, bl           ; Restore original byte
    and al, 0x0F         ; Get low nibble
    call print_nibble    ; Print low nibble

    pop cx               ; Restore cx
    pop bx               ; Restore bx
    pop ax               ; Restore ax
    ret

print_nibble:
    add al, '0'          ; Convert to ASCII
    cmp al, '9'          ; Check if it's greater than '9'
    jbe print_char       ; If not, it's a digit
    add al, 7            ; Convert to ASCII letter (A-F)
print_char:
    mov ah, 0x0E         ; BIOS teletype function
    int 0x10             ; Print character
    ret

; ; Given the number of the next disk block to read, disksec, compute the
; ; cylinder, sector, head, and number of sectors to read as follows:
; ; al = # sectors to read; cl = sector #; ch = cyl; dh = head; dl = 80
; setreg: 
;     mov si, [tracksiz]   ; 17 sectors/track for hard disk image
;     mov ax, [disksec]    ; ax = next sector to read
;     xor dx, dx           ; dx:ax = 32-bit dividend
;     div si               ; divide sector # by track size
;     mov cx, ax           ; cx = track #; dx = sector (0-origin)
;     mov bx, dx           ; bx = sector number (0-origin)
;     mov ax, [disksec]    ; ax = next sector to read
;     add ax, si           ; ax = last sector to read + 1
;     dec ax               ; ax = last sector to read
;     xor dx, dx           ; dx:ax = 32-bit dividend
;     div si               ; divide last sector by track size
;     cmp al, cl           ; is starting track = ending track
;     je set1              ; jump if whole read on 1 cylinder
;     sub si, dx           ; compute lower sector count
;     dec si               ; si = # sectors to read

; ; Check to see if this read crosses a 64K boundary (128 sectors).
; ; Such calls must be avoided. The BIOS gets them wrong.
; set1:
;     mov ax, [disksec]    ; ax = next sector to read
;     add ax, 2            ; disk sector 1 goes in core sector 3
;     mov dx, ax           ; dx = next sector to read
;     add dx, si           ; dx = one sector beyond end of read
;     dec dx               ; dx = last sector to read
;     shl ax, 1            ; ah = which 64K bank does read start at
;     shl dx, 1            ; dh = which 64K bank does read end in
;     cmp ah, dh           ; ah != dh means read crosses 64K boundary
;     je set2              ; jump if no boundary crossed
;     shr dl, 1            ; dl = excess beyond 64K boundary
;     xor dh, dh           ; dx = excess beyond 64K boundary
;     sub si, dx           ; adjust si
;     dec si               ; si = number of sectors to read

; set2:
;     mov ax, si           ; ax = number of sectors to read
;     xor dx, dx           ; dh = head, dl = drive
;     mov dh, cl           ; dh = track
;     and dh, 0xF          ; dh = head
;     mov ch, cl           ; ch = track to read
;     shr ch, 1            ; ch = cylinder (divide by 16)
;     shr ch, 1            ; ditto
;     shr ch, 1            ; ditto
;     shr ch, 1            ; ditto
;     mov cl, bl           ; cl = sector number (0-origin)
;     inc cl               ; cl = sector number (1-origin)
;     mov dl, 0x80         ; dl = drive number (0)
;     ret                  ; return values in ax, cx, dx

;-------------------------------+
;    error & print routines     |
;-------------------------------+

error:
    push ax
    mov [dbg], ah
    add byte [dbg], 0x30
    mov bx, dbg
    call print
    mov bx, fderr
    call print           ; print msg
    xor cx, cx
err1:
    mul cx               ; delay
    loop err1
    int 0x19

print:                   ; print string (bx)
    mov al, [bx]         ; al contains char to be printed
    test al, al          ; null char?
    jne prt1             ; no
    ret                  ; else return
prt1:
    mov ah, 14           ; 14 = print char
    inc bx               ; increment string pointer
    push bx              ; save bx
    mov bl, 1            ; foreground color
    xor bh, bh           ; page 0
    int 0x10             ; call BIOS VIDEO_IO
    pop bx               ; restore bx
    jmp print            ; next character

section .data
disksec: dw 1
tracksiz: dw 17          ; 17 sectors/track for Hard Disk Image
pcpar: db 0xDF, 0x02, 25, 2, 9, 0x2A, 0xFF, 0x50, 0xF6, 1, 3   ; for PC
atpar: db 0xDF, 0x02, 25, 2, 15, 0x1B, 0xFF, 0x54, 0xF6, 1, 8  ; for AT

rdbg: db "Read", 13, 10, 0
fderr: db "Read error.  Automatic reboot.", 13, 10, 0
greet: db 13, "Booting MINIX 1.1", 13, 10, 0
dbg: db 0,0

section .bss
begbss:

section .text
endtext:
section .data
enddata:
section .bss
endbss: