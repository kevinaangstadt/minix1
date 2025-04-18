bits 16
cpu 8086
; This file is part of the lowest layer of the MINIX kernel. All processing
; switching and message handling is done here and in file "proc.c". This file
; is entered on every transition to the kernel, both for sending/receiving
; messages and for all interrupts. In all cases, the trap or interrupt
; routine first calls save() to store the machine state in the proc table.
; Then the stack is switched to k_stack. Finally, the real trap or interrupt
; handler (in C) is called. When it returns, the interrupt routine jumps to
; restart, to run the process or task whose number is in 'cur_proc'.

; The external entry points into this file are:
;   s_call:	process or task wants to send or receive a message
;   tty_int:	interrupt routine for each key depression and release
;   lpr_int:	interrupt routine for each line printer interrupt
;   disk_int:	disk interrupt routine
;   wini_int:	winchester interrupt routine
;   clock_int:	clock interrupt routine (HZ times per second)
;   surprise:	all other interrupts < 16 are vectored here
;   trp:	all traps with vector >= 16 are vectored here
;   divide:	divide overflow traps are vectored here
;   restart:	start running a task or process

; These symbols MUST agree with the values in ../h/com.h to avoid disaster.
%define K_STACK_BYTES 256
%define WINI -6
%define FLOPPY -5
%define CLOCK -3
%define IDLE -999
%define DISKINT 1
%define CLOCK_TICK 2

; The following procedures are defined in this file and called from outside it.
global _tty_int, _lpr_int, _clock_int, _disk_int, _wini_int
global _s_call, _surprise, _trp, _divide, _restart

; The following external procedures are called in this file.
extern _main, _sys_call, _interrupt, _keyboard, _panic, _unexpected_int, _trap
extern _pr_char, _div_trap

; Variables, data structures and miscellaneous.
extern _cur_proc, _proc_ptr, _scan_code, _int_mess, _k_stack, splimit
global _sizes, begtext, begdata, begbss

; The following constants are offsets into the proc table.
%define esreg 14
%define dsreg 16
%define csreg 18
%define ssreg 20
%define SP 22
%define PC 24
%define PSW 28
%define SPLIM 50
%define OFF 18
%define ROFF 12

section .text
begtext:
;*===========================================================================*
;*				MINIX					     *
;*===========================================================================*
MINIX:				; this is the entry point for the MINIX kernel.
    jmp near M_0 		; skip over the next few bytes
    dw 0, 0			; build puts DS at kernel text address 4
M_0:
    cli                     ; disable interrupts
    mov ax, cs		; set up segment registers
    mov ds, ax		; set up ds
    mov ax, [4]		; build has loaded this word with ds value
    mov ds, ax		; ds now contains proper value
    mov ss, ax		; ss now contains proper value
    mov [_scan_code], bx	; save scan code for '=' key from bootstrap
    mov sp, _k_stack	; set sp to point to the top of the
    add sp, K_STACK_BYTES	; 	kernel stack

    call _main		; start the main program of MINIX
M_1:
    jmp near M_1	; this should never be executed

;*===========================================================================*
;*				s_call					     *
;*===========================================================================*
_s_call:			; System calls are vectored here.
    call save		; save the machine state
    mov bp, [_proc_ptr]	; use bp to access sys call parameters
    push word [bp + 2]	; push(pointer to user message) (was bx)
    push word [bp]		; push(src/dest) (was ax)
    push word [_cur_proc]	; push caller
    push word [bp + 4]	; push(SEND/RECEIVE/BOTH) (was cx)
    call _sys_call		; sys_call(function, caller, src_dest, m_ptr)
    jmp _restart		; jump to code to restart proc/task running

;*===========================================================================*
;*				tty_int					     *
;*===========================================================================*
_tty_int:			; Interrupt routine for terminal input.
    call save		; save the machine state
    call _keyboard		; process a keyboard interrupt
    jmp _restart		; continue execution

;*===========================================================================*
;*				lpr_int					     *
;*===========================================================================*
_lpr_int:			; Interrupt routine for terminal input.
    call save		; save the machine state
    call _pr_char		; process a line printer interrupt
    jmp _restart		; continue execution

;*===========================================================================*
;*				disk_int				     *
;*===========================================================================*
_disk_int:			; Interrupt routine for the floppy disk.
    call save		; save the machine state
    mov word [_int_mess + 2], DISKINT ; build message for disk task
    mov ax, _int_mess	; prepare to call interrupt(FLOPPY, &intmess)
    push ax			; push second parameter
    mov ax, FLOPPY		; prepare to push first parameter
    push ax			; push first parameter
    call _interrupt		; this is the call
    jmp _restart		; continue execution

;*===========================================================================*
;*				wini_int				     *
;*===========================================================================*
_wini_int:			; Interrupt routine for the winchester disk.
    call save		; save the machine state
    mov word [_int_mess + 2], DISKINT ; build message for winchester task
    mov ax, _int_mess	; prepare to call interrupt(WINI, &intmess)
    push ax			; push second parameter
    mov ax, WINI		; prepare to push first parameter
    push ax			; push first parameter
    call _interrupt		; this is the call
    jmp _restart		; continue execution

;*===========================================================================*
;*				clock_int				     *
;*===========================================================================*
_clock_int:			; Interrupt routine for the clock.
    call save		; save the machine state
    mov word [_int_mess + 2], CLOCK_TICK ; build message for clock task
    mov ax, _int_mess	; prepare to call interrupt(CLOCK, &intmess)
    push ax			; push second parameter
    mov ax, CLOCK		; prepare to push first parameter
    push ax			; push first parameter
    call _interrupt		; this is the call
    jmp _restart		; continue execution

;*===========================================================================*
;*				surprise				     *
;*===========================================================================*
_surprise:			; This is where unexpected interrupts come.
    call save		; save the machine state
    call _unexpected_int	; go panic
    jmp _restart		; never executed

;*===========================================================================*
;*				trp					     *
;*===========================================================================*
_trp:				; This is where unexpected traps come.
    call save		; save the machine state
    call _trap		; print a message
    jmp _restart		; this error is not fatal

;*===========================================================================*
;*				divide					     *
;*===========================================================================*
_divide:			; This is where divide overflow traps come.
    call save		; save the machine state
    call _div_trap		; print a message
    jmp _restart		; this error is not fatal

;*===========================================================================*
;*				save					     *
;*===========================================================================*
save:				; save the machine state in the proc table.  
    push ds			; stack: psw/cs/pc/ret addr/ds
    push cs			; prepare to restore ds
    pop ds			; ds has now been set to cs
    mov ds, [4]		; word 4 in kernel text space contains ds value
    pop word [ds_save]		; stack: psw/cs/pc/ret addr
    pop word [ret_save]		; stack: psw/cs/pc
    mov [bx_save], bx	; save bx for later ; we need a free register
    mov bx, [_proc_ptr]	; start save set up; make bx point to save area
    add bx, OFF		; bx points to place to store cs
    pop word [bx + PC - OFF]	; store pc in proc table 
    pop word [bx + csreg - OFF]	; store cs in proc table
    pop word [bx + PSW - OFF]	; store psw 
    mov [bx + ssreg - OFF], ss ; store ss
    mov [bx + SP - OFF], sp	; sp as it was prior to interrupt
    mov sp, bx		; now use sp to point into proc table/task save
    mov bx, ds		; about to set ss
    mov ss, bx		; set ss
    push word [ds_save]		; start saving all the registers, sp first
    push es			; save es between sp and bp
    mov es, bx		; es now references kernel memory too
    push bp			; save bp
    push di			; save di
    push si			; save si
    push dx			; save dx
    push cx			; save cx
    push word [bx_save]		; save original bx
    push ax			; all registers now saved
    mov sp, _k_stack	; temporary stack for interrupts
    add sp, K_STACK_BYTES	; set sp to top of temporary stack
    mov word [splimit], _k_stack	; limit for temporary stack
    add word [splimit], 8		; splimit checks for stack overflow
    mov ax, [ret_save]	; ax = address to return to
    jmp ax			; return to caller; Note: sp points to saved ax

;*===========================================================================*
;*				restart					     *
;*===========================================================================*
_restart:			; This routine sets up and runs a proc or task.
    cmp word [_cur_proc], IDLE	; restart user; if cur_proc = IDLE, go idle
    je idle			; no user is runnable, jump to idle routine
    cli			; disable interrupts
    mov sp, [_proc_ptr]	; return to user, fetch regs from proc table
    pop ax			; start restoring registers
    pop bx			; restore bx
    pop cx			; restore cx
    pop dx			; restore dx
    pop si			; restore si
    pop di			; restore di
    mov [lds_low], bx	; lds_low contains bx
    mov bx, sp		; bx points to saved bp register
    mov bp, [bx + SPLIM - ROFF] ; splimit = p_splimit
    mov [splimit], bp		; ditto
    mov bp, [bx + dsreg - ROFF] ; bp = ds
    mov [lds_low + 2], bp	; lds_low+2 contains ds
    pop bp			; restore bp
    pop es			; restore es
    mov sp, [bx + SP - ROFF] ; restore sp
    mov ss, [bx + ssreg - ROFF] ; restore ss using the value of ds
    push word [bx + PSW - ROFF]	; push psw
    push word [bx + csreg - ROFF]; push cs
    push word [bx + PC - ROFF]	; push pc
    lds bx, [lds_low]	; restore ds and bx in one fell swoop
    iret			; return to user or task

;*===========================================================================*
;*				idle					     *
;*===========================================================================*
idle:				; executed when there is no work 
    sti			; enable interrupts
L3:  	hlt			; just idle while waiting for interrupt
    jmp L3			; loop until interrupt

;*===========================================================================*
;*				data					     *
;*===========================================================================*
section .data
begdata:
_sizes:  dw 0x526F		; this must be the first data entry (magic #)
     resw 7		; build table uses prev word and this space
bx_save: dw 0		; storage for bx
ds_save: dw 0		; storage for ds
ret_save: dw 0		; storage for return address
lds_low: dw 0, 0		; storage used for restoring bx
ttyomess: db "RS232 interrupt", 0

section .bss
begbss: