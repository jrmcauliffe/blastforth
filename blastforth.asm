;==============================================================
; BLASTFORTH - SEGA MEGA DRIVE/GENESIS FORTH
;==============================================================
; Forth Kernel
;
; Build:
;    asl blastforth.asm
;    p2bin blastforth.p blastforth.bin
;==============================================================
	cpu 68000
	SUPMODE ON
	PADDING OFF
; A label defining the start of ROM so we can compute the total size.
ROM_Start:

;==============================================================
; MEGA DRIVE HARDWARE
;==============================================================
	include "md/hardware.asm"		; Hardware equates: VDP, TMSS, SR, controller port 2
	include "md/vectors.asm"		; CPU vector table, must be at $0000
	include "md/header.asm"			; ROM header, must be at $100
	include "md/vdp.asm"			; VDP register table, TMSS write, register load
	include "md/boot.asm"			; CPU_EntryPoint: hardware and Forth init, then abort
	include "md/serial.asm"			; Receive ring buffer, SerialGetc/Putc/PutString/PutHex
	include "md/interrupts.asm"		; Serial receive IRQ, V/H interrupts, exception handlers

;==============================================================
; FORTH KERNEL
;==============================================================
; Every header, code field and thread branch target must stay
; below $8000 (16-bit cells, see docs/forth-design.md). The
; include order is the dictionary link order.
;==============================================================
	include "forth/memmap.asm"		; Stacks, system variables, TIB, dictionary start
	include "forth/macros.asm"		; NEXT, HEADER, DEFCODE, DEFWORD, DEFCONST, DOTSTR
	include "forth/inner.asm"		; DOCOL, DOCON, exit, lit, execute, branch, 0branch
	include "forth/variables.asm"		; here latest state base >in #tib tib
	include "forth/stackjugglers.asm"	; dup drop nip swap over ?dup 2drop 2dup rot >r r> r@ depth rp0!
	include "forth/calculations.asm"	; 1+ 1- negate 2* 2/ + - * /mod
	include "forth/logic.asm"		; and or xor invert lshift rshift
	include "forth/comparisons.asm"		; 0= 0< = < > u<
	include "forth/memory.asm"		; @ ! c@ c! +! cmove fill
	include "forth/strings.asm"		; count type (.")
	include "forth/terminal.asm"		; emit key accept
	include "forth/token.asm"		; word
	include "forth/numberstrings.asm"	; number . .hex
	include "forth/dictionary.asm"		; find
	include "forth/interpreter.asm"		; abort interpret quit

; Last rom dictionary pointer
rom_latest equ link_prev

; A label defining the end of ROM so we can compute the total size.
ROM_End:
