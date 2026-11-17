;==============================================================
; THREADING AND HEADER MACROS
;==============================================================
; 16-bit direct threading (see "Threading" in
; docs/forth-design.md). A thread is a list of 16-bit cells,
; each the address of a word's code field, which is machine
; code: a primitive's body or a jsr DOCOL.
;==============================================================

; NEXT: run the word whose cell IP points at. Inlined at the end
; of every primitive.
; In: a5 = IP (next cell). Out: a0 = code field, a5 += 2. Uses a0.
NEXT macro
	movea.w (a5)+, a0	; Fetch cell at IP, sign-extend to code field address, IP += 2
	jmp (a0)		; Set PC to code field
	endm

; Dictionary header flag bits, in the flags+len byte (see
; "Dictionary header" in docs/forth-design.md). Bits 4-0 = name length.
f_immediate				equ $80		; Bit 7: runs even while compiling
f_hidden				equ $40		; Bit 6: being defined, FIND skips it

; Assembly-time only: address of the newest header so far. Each HEADER
; links to it, then becomes it. 0 ends the chain (no header can be at $0000,
; the vector table).
link_prev				set 0

; HEADER: dictionary header, ending at the word's code field.
; name = Forth name string (lowercase), stored in ROM.
; label = asl label for the code field (uppercase), used in threads.
; flags = f_immediate / f_hidden, or 0.
; Layout: link (dc.w), flags+len (dc.b), name, align 2, code field.
HEADER macro name, label, flags, {GLOBALSYMBOLS}
hdr_start	set *				; This header's address
	dc.w   link_prev			; Link to the previous header
link_prev	set hdr_start			; This header is now the newest
	dc.b   (flags)|strlen(name), name	; Flags+len, then the name characters
	align  2				; Code field must be even
label:						; Code field
	endm

; DEFCODE: header for a machine code primitive. The code follows,
; ending in NEXT. Same bytes as HEADER; the name marks the word's kind.
DEFCODE macro name, label, flags, {GLOBALSYMBOLS}
	HEADER name, label, flags
	endm

; DEFWORD: header plus code field (jsr DOCOL) for a colon definition.
; The thread follows as dc.w cells, ending in EXIT.
DEFWORD macro name, label, flags, {GLOBALSYMBOLS}
	HEADER name, label, flags
	jsr    DOCOL				; Code field: enter the thread that follows
	endm

DEFCONST macro name, label, value, {GLOBALSYMBOLS}
	HEADER name, label, 0
	jsr DOCON		; Code field, push value of cell that follows
	dc.w (value)&$FFFF	; Const value, low 16 bits
	endm

; DOTSTR: compile (.") plus an inline counted string into a ROM thread.
DOTSTR macro text
	dc.w PDOTQUOTE		; Print the string that follows
	dc.b strlen(text), text	; Length byte, then the characters
	align 2			; Next cell must be even
	endm
