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
; CPU VECTOR TABLE
;==============================================================
; Read by the CPU from $0000 on reset. IRQ level 2 is the
; external interrupt, raised by the serial port on receive.
;==============================================================
	dc.l   RS_START			; Initial stack pointer: top of the return stack ($FFFC00-$FFFEFF, docs/forth-design.md)
	dc.l   CPU_EntryPoint		; Start of program
	dc.l   CPU_AddressError		; Bus error
	dc.l   CPU_AddressError		; Address error
	dc.l   CPU_Exception		; Illegal instruction
	dc.l   CPU_Exception		; Division by zero
	dc.l   CPU_Exception		; CHK CPU_Exception
	dc.l   CPU_Exception		; TRAPV CPU_Exception
	dc.l   CPU_Exception		; Privilege violation
	dc.l   INT_Null				; TRACE exception
	dc.l   INT_Null				; Line-A emulator
	dc.l   INT_Null				; Line-F emulator
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Spurious exception
	dc.l   INT_Null				; IRQ level 1
	dc.l   INT_SerialRx			; IRQ level 2 (external interrupt: serial byte received)
	dc.l   INT_Null				; IRQ level 3
	dc.l   INT_HInterrupt		; IRQ level 4 (horizontal retrace interrupt)
	dc.l   INT_Null				; IRQ level 5
	dc.l   INT_VInterrupt		; IRQ level 6 (vertical retrace interrupt)
	dc.l   INT_Null				; IRQ level 7
	dc.l   INT_Null				; TRAP #00 exception
	dc.l   INT_Null				; TRAP #01 exception
	dc.l   INT_Null				; TRAP #02 exception
	dc.l   INT_Null				; TRAP #03 exception
	dc.l   INT_Null				; TRAP #04 exception
	dc.l   INT_Null				; TRAP #05 exception
	dc.l   INT_Null				; TRAP #06 exception
	dc.l   INT_Null				; TRAP #07 exception
	dc.l   INT_Null				; TRAP #08 exception
	dc.l   INT_Null				; TRAP #09 exception
	dc.l   INT_Null				; TRAP #10 exception
	dc.l   INT_Null				; TRAP #11 exception
	dc.l   INT_Null				; TRAP #12 exception
	dc.l   INT_Null				; TRAP #13 exception
	dc.l   INT_Null				; TRAP #14 exception
	dc.l   INT_Null				; TRAP #15 exception
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)
	dc.l   INT_Null				; Unused (reserved)

;==============================================================
; SEGA MEGA DRIVE ROM HEADER
;==============================================================
; Metadata at $100. The console only checks "SEGA" at $100
; (TMSS); emulators read the title and region.
;==============================================================
	dc.b "SEGA MEGA DRIVE "                                 ; Console name
	dc.b "BLASTFORTH      "                                 ; Copyright holder and release date
	dc.b "BLASTFORTH                                      " ; Domestic name
	dc.b "BLASTFORTH                                      " ; International name
	dc.b "GM XXXXXXXX-XX"                                   ; Version number
	dc.w $0000                                              ; Checksum
	dc.b "J               "                                 ; I/O support
	dc.l ROM_Start                                          ; Start address of ROM
	dc.l ROM_End-1                                          ; End address of ROM
	dc.l $00FF0000                                          ; Start address of RAM
	dc.l $00FF0000+$0000FFFF                                ; End address of RAM
	dc.l $00000000                                          ; SRAM enabled
	dc.l $00000000                                          ; Unused
	dc.l $00000000                                          ; Start address of SRAM
	dc.l $00000000                                          ; End address of SRAM
	dc.l $00000000                                          ; Unused
	dc.l $00000000                                          ; Unused
	dc.b "                                        "         ; Notes (unused)
	dc.b "  E             "                                 ; Country codes

;==============================================================
; INITIAL VDP REGISTER VALUES
;==============================================================
; 24 register values copied to the VDP during initialisation.
; Same as hello.asm except H interrupt off ($00). The external
; interrupt ($0B bit 3) is turned on later, in the serial setup.
;==============================================================
VDPRegisters:
	dc.b $04 ; $00: H interrupt off (bit 4 = 0), bit 2 must be 1
	dc.b $74 ; $01: V interrupt on, display on, DMA on, Genesis mode on
	dc.b $30 ; $02: Pattern table for Scroll Plane A at VRAM $C000 (bits 3-5 = bits 13-15)
	dc.b $00 ; $03: Pattern table for Window Plane at VRAM $0000 (disabled) (bits 1-5 = bits 11-15)
	dc.b $07 ; $04: Pattern table for Scroll Plane B at VRAM $E000 (bits 0-2 = bits 11-15)
	dc.b $78 ; $05: Sprite table at VRAM $F000 (bits 0-6 = bits 9-15)
	dc.b $00 ; $06: Unused
	dc.b $00 ; $07: Background colour: bits 0-3 = colour, bits 4-5 = palette
	dc.b $00 ; $08: Unused
	dc.b $00 ; $09: Unused
	dc.b $08 ; $0A: Frequency of Horiz. interrupt in Rasters (unused while H interrupt is off)
	dc.b $00 ; $0B: External interrupt off until serial setup, V scroll fullscreen, H scroll fullscreen
	dc.b $81 ; $0C: Shadows and highlights off, interlace off, H40 mode (320 x 224 screen res)
	dc.b $3F ; $0D: Horiz. scroll table at VRAM $FC00 (bits 0-5)
	dc.b $00 ; $0E: Unused
	dc.b $02 ; $0F: Autoincrement 2 bytes
	dc.b $01 ; $10: Scroll plane size: 64x32 tiles
	dc.b $00 ; $11: Window Plane X pos 0 left (pos in bits 0-4, left/right in bit 7)
	dc.b $00 ; $12: Window Plane Y pos 0 up (pos in bits 0-4, up/down in bit 7)
	dc.b $FF ; $13: DMA length lo byte
	dc.b $FF ; $14: DMA length hi byte
	dc.b $00 ; $15: DMA source address lo byte
	dc.b $00 ; $16: DMA source address mid byte
	dc.b $80 ; $17: DMA source address hi byte, memory-to-VRAM mode (bits 6-7)

;==============================================================
; CONSTANTS
;==============================================================

; VDP port addresses
vdp_control				equ $00C00004
vdp_data				equ $00C00000

; Hardware version address
hardware_ver_address	equ $00A10001

; TMSS
tmss_address			equ $00A14000
tmss_signature			equ 'SEGA'

; Status register values (bit 13 = supervisor, bits 8-10 = interrupt mask)
sr_irq_off				equ $2700	; Supervisor, mask 7: all maskable interrupts blocked
sr_irq_on				equ $2100	; Supervisor, mask 1: IRQ 2 (serial), 4 (H), 6 (V) allowed

; Controller port 2, parallel mode
io_ctrl2				equ $00A1000B	; Pin directions (bits 0-6, 1 = output), bit 7 = TH interrupt enable
io_ctrl2_setup			equ $7F			; Pins 0-6 output, TH interrupt off (reference: CTRL_PCS_OUT)

; Controller port 2, serial mode (UART)
io_txdata2				equ $00A10015	; TxData: byte to send
io_rxdata2				equ $00A10017	; RxData: last byte received
io_sctrl2				equ $00A10019	; S-Ctrl: serial control and status, bits below

; S-Ctrl bit numbers (for btst)
sctrl_tful				equ 0		; 1 = TxData holds a byte not yet sent

; VDP register $0B (mode 3) write command: 100 01011 00001000
;   bit 3 = 1: IE2, external interrupt (IRQ 2) on; V/H scroll fullscreen
vdp_reg0b_extint		equ $8B08

; S-Ctrl value written at boot:
;   bits 7-6 = 00: 4800 bps (480 bytes/s, 2.08 ms per byte)
;   bit 5    = 1:  SIN, TR (pin 9) is serial input (RxData)
;   bit 4    = 1:  SOUT, TL (pin 6) is serial output (TxData)
;   bit 3    = 1:  RINT, raise the external interrupt when a byte is received
sctrl_setup				equ $38

; Serial receive ring buffer (kernel-private, lower 32 KiB of work RAM;
; see "Memory map" in docs/forth-design.md). 256 bytes with byte-sized
; indices, so the indices wrap for free. Empty when head = tail; full when
; head + 1 = tail (one slot stays unused, capacity 255 bytes).
rx_buf					equ $00FF0000	; 256-byte buffer
rx_head					equ $00FF0100	; byte: next slot to write (only INT_SerialRx writes it)
rx_tail					equ $00FF0101	; byte: next slot to read (only SerialGetc writes it)

; ASCII
char_cr					equ $0D
char_lf					equ $0A

; Forth stacks (see "Memory map" in docs/forth-design.md). Both grow down.
DS_START		equ $00FFFC00   ; Data stack top: a6 starts here
RS_START		equ $00FFFF00   ; Return stack top: sp starts here (vector 0)

; Forth system variables (see "Outer interpreter" in docs/forth-design.md).
; One cell each. Written sign-extended ($FFFFxxxx) so asl uses absolute
; short addressing: 2 bytes and 4 cycles less than absolute long.
var_here		equ $FFFFFF00    ; Next free dictionary byte
var_latest		equ $FFFFFF02    ; Header of the newest word
var_state		equ $FFFFFF04    ; 0 = interpreting, else compiling
var_base		equ $FFFFFF06    ; Number base for number and .
var_toin		equ $FFFFFF08    ; >in: parse offset into the TIB
var_ntib		equ $FFFFFF0A    ; #tib: characters in the TIB

TIB_START		equ $FFFFF900    ; Terminal input buffer, 128 bytes
WORD_BUF		equ $FFFFF980    ; Word Buffer
DICT_START		equ $FFFF8000    ; User dictionary, grows up

;==============================================================
; INNER INTERPRETER
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

; DOCOL: enter a colon word. A colon word's code field is
; jsr DOCOL; jsr pushes the address after itself, which is the
; start of the word's thread.
; In: (sp) = thread address, a5 = caller's IP.
; Out: (sp) = caller's IP, a5 = thread. Uses a0.
DOCOL:
	movea.l (sp), a0	; Thread address pushed by jsr
	move.l a5, (sp)		; Replace it with the caller's IP (saved for EXIT)
	movea.l a0, a5		; IP = start of the thread
	NEXT

DOCON:
	movea.l (sp)+, a0	; Address of value cell
	move.w d7, -(a6)	; Push down stack
	move.w (a0), d7		; New TOS
	NEXT

	DEFCONST "here", HERE, var_here		; ( -- addr ) next free dictionary byte
	DEFCONST "latest", LATEST, var_latest	; ( -- addr ) newest header
	DEFCONST "state", STATE, var_state	; ( -- addr ) 0 = interpreting
	DEFCONST "base", BASE, var_base		; ( -- addr ) number base
	DEFCONST ">in", TOIN, var_toin		; ( -- addr ) parse offset into the TIB
	DEFCONST "#tib", NTIB, var_ntib		; ( -- addr ) characters in the TIB
	DEFCONST "tib", TIB, TIB_START		; ( -- addr ) the TIB itself

; EXIT: leave a colon word. Compiled as the last cell of every
; colon word; undoes DOCOL.
; In: (sp) = caller's IP. Out: a5 = caller's IP, sp += 4.
	DEFCODE "exit", EXIT, 0
	move.l (sp)+, a5	; Pop the caller's IP
	NEXT

	DEFCODE "lit", LIT, 0		; ( -- n )
	move.w d7, -(a6)	; Push old TOS down
	move.w (a5)+, d7	; New TOS and IP += 2
	NEXT

	DEFCODE "emit", EMIT, 0		; ( c -- )
	move.w d7, d0		; TOS to d0
	move.w (a6)+, d7	; Refill TOS
	jsr SerialPutc		; Call serial routine
	NEXT

	DEFCODE "key", KEY, 0		; ( -- c )
	jsr SerialGetc			; Wait for byte in d0.w
	move.w d7, -(a6)		; Push old TOS down
	move.w d0, d7			; New TOS, c
	NEXT

	DEFCODE "execute", EXECUTE, 0	; ( xt -- )
	movea.w d7, a0		; sign-extend cell to address ($8000+ -> $FF8000+)
	move.w (a6)+, d7	; Refill TOS
	jmp (a0)		; jmp to code field
				; No Next required as target word will have one

	DEFCODE "branch", BRANCH, 0	; ( -- )
	movea.w (a5), a5		; Set the next cell as the new instruction pointer
	NEXT

	DEFCODE "0branch", ZBRANCH, 0	; ( flag -- )
	tst.w d7		; flag == 0?
	beq.s +			; If yes, take branch
	move.w (a6)+, d7	; Refill TOS
	addq.l #2, a5		; If no, skip target cell
	NEXT
+	move.w (a6)+, d7	; Refill TOS
	movea.w (a5), a5	; Update IP with target address
	NEXT

;==============================================================
; CODE ENTRY POINT
;==============================================================
CPU_EntryPoint:

	; Write the TMSS signature (if a model 1+ Mega Drive)
	jsr    VDP_WriteTMSS

	; Load the initial VDP registers
	jsr    VDP_LoadRegisters

	;==============================================================
	; Serial port on controller port 2
	;==============================================================
	; Same order and values as rhargreaves/mega-drive-serial-port v0.3.0
	; (serial_init), which is known to work on hardware: S-Ctrl, then the
	; port control register, then VDP external interrupt, then the CPU mask.
	;
	; Empty the receive buffer before the interrupt can fire: work RAM
	; holds garbage after power-on.
	clr.b  rx_head
	clr.b  rx_tail

	move.b #sctrl_setup, io_sctrl2		; 4800 bps, serial in and out, interrupt on receive
	move.b #io_ctrl2_setup, io_ctrl2	; Pins 0-6 output, TH interrupt off
	move.w #vdp_reg0b_extint, vdp_control	; VDP: external interrupt (IRQ 2) on

	; Allow IRQ 2 and above. Must be mask 1 or lower, or the serial interrupt never arrives.
	move.w #sr_irq_on, sr

	;==============================================================
	; Banner, then start the interpreter
	;==============================================================

	lea    Banner, a1
	jsr  SerialPutString

	; Forth system variables (see "Outer interpreter" in docs/forth-design.md)
	move.w #DICT_START&$FFFF, var_here	; Empty RAM dictionary: next free byte is $FF8000
	move.w #rom_latest, var_latest		; Search starts at the newest ROM header
	move.w #10, var_base			; Decimal
	clr.w  var_toin				; Parse from the start of the TIB
	clr.w  var_ntib				; TIB empty
	jmp ABORT

Banner:
	dc.b "blastforth", 0
AddrErrMsg:
	dc.b "addr error ", 0
PcMsg:
	dc.b " pc ", 0
	align  2				; Word-align the code after the odd-length string (asl has no EVEN)

	DEFCODE ".hex", PRINTHEX, 0	; ( x -- ) 4 hex digits, unsigned, ignores base
	move.w d7, d1		; TOS to scratch register
	move.w (a6)+, d7	; POP TOS
	jsr SerialPutHex	; Expects val in d1
	moveq #' ', d0		; Output final space
	jsr SerialPutc		; For clarity
	NEXT

	DEFCODE "dup", DUP, 0	; ( x -- x x )
	move.w d7, -(a6)
	NEXT

	DEFCODE "drop", DROP, 0 ; ( x -- )
	move.w (a6)+, d7
	NEXT

	DEFCODE "nip", NIP, 0	; ( a b -- b )
	addq.l #2, a6
	NEXT

	DEFCODE "swap", SWAP, 0	; ( a b -- b a )
	move.w d7, d1
	move.w (a6), d7
	move.w d1, (a6)
	NEXT

	DEFCODE "over", OVER, 0	; ( a b -- a b a )
	move.w d7, -(a6)
	move.w 2(a6), d7
	NEXT

	DEFCODE "?dup", QDUP, 0	; ( a -- a a | 0 )
	tst.w d7
	beq.s +
	move.w d7, -(a6)
+	NEXT

	DEFCODE "2drop", TWODROP, 0	; ( a b -- )
	addq.l #2, a6			; nip
	move.w (a6)+, d7		; drop
	NEXT

	DEFCODE "2dup", TWODUP, 0	; ( a b -- a b a b )
	move.w (a6), d1			; save a
	move.w d7, -(a6)		; push b
	move.w d1, -(a6)		; push a
	NEXT

	DEFCODE "rot", ROT, 0		; ( a b c -- b c a )
	move.w 2(a6), d1		; save a
	move.w (a6), 2(a6)
	move.w d7, (a6)
	move.w d1, d7
	NEXT

	DEFCODE ">r", TOR, 0		; ( a -- ) ( R: -- a )
	move.w d7, -(sp)
	move.w (a6)+, d7
	NEXT

	DEFCODE "r>", RFROM, 0		; (  -- a ) ( R: a -- )
	move.w d7, -(a6)
	move.w (sp)+, d7
	NEXT

	DEFCODE "r@", RFETCH, 0		; (  -- a ) ( R: a -- a )
	move.w d7, -(a6)
	move.w (sp), d7
	NEXT

	DEFCODE "1+", ONEPLUS, 0	; ( n -- n+1 )
	addq.w #1, d7
	NEXT

	DEFCODE "1-", ONEMINUS, 0   ; ( n -- n-1 )
	subq.w #1, d7
	NEXT

	DEFCODE "negate", NEGATE, 0	; ( n -- -n )
	neg.w d7
	NEXT

	DEFCODE "2*", TWOSTAR, 0	; ( n -- n*2 )
	add.w d7, d7
	NEXT

	DEFCODE "2/", TWOSLASH, 0	; ( n -- n/2 )
	asr.w #1, d7
	NEXT

	DEFCODE "+", PLUS, 0		; ( a b -- a+b )
	add.w (a6)+, d7
	NEXT

	DEFCODE "-", MINUS, 0		; ( a b -- a-b )
	sub.w (a6)+, d7
	neg.w d7
	NEXT

	DEFCODE "*", STAR, 0		; ( a b -- a*b )
	muls.w (a6)+, d7
	NEXT

	DEFCODE "/mod", SLASHMOD, 0	; ( a b -- rem quot )
	move.w (a6), d1
	ext.l d1
	divs d7, d1
	move.w d1, d7
	swap d1
	move.w d1, (a6)
	NEXT

	DEFCODE "and", AND, 0		; ( a b -- a&b )
	and.w (a6)+, d7
	NEXT

	DEFCODE "or", OR, 0		; ( a b -- a|b )
	or.w (a6)+, d7
	NEXT

	DEFCODE "xor", XOR, 0		; ( a b -- a^b )
	move.w (a6)+, d0		; Source for eor must be data reg.
	eor.w d0, d7
	NEXT

	DEFCODE "invert", INVERT, 0	; ( a -- ~a )
	not.w d7
	NEXT

	DEFCODE "lshift", LSHIFT, 0	; ( x u -- x' )
	move.w (a6)+, d0
	lsl.w d7, d0
	move.w d0, d7
	NEXT

	DEFCODE "rshift", RSHIFT, 0	; ( x u -- x' )
	move.w (a6)+, d0
	lsr.w d7, d0
	move.w d0, d7
	NEXT

	DEFCODE "0=", ZEROEQUALS, 0	; ( n -- flag )
	tst d7
	seq d7
	ext.w d7
	NEXT

	DEFCODE "0<", ZEROLESS, 0	; ( n -- flag )
	tst d7
	smi d7
	ext.w d7
	NEXT

	DEFCODE "=", EQUALS, 0		; ( a b -- flag )
	move.w (a6)+, d0
	cmp.w d7, d0
	seq d7
	ext.w d7
	NEXT

	DEFCODE "<", LESS, 0		; ( a b -- flag )
	move.w (a6)+, d0
	cmp.w d7, d0
	slt d7
	ext.w d7
	NEXT

	DEFCODE ">", GREATER, 0		; ( a b -- flag )
	move.w (a6)+, d0
	cmp.w d7, d0
	sgt d7
	ext.w d7
	NEXT

	DEFCODE "u<", ULESS, 0		; ( a b -- flag )
	move.w (a6)+, d0
	cmp.w d7, d0
	scs d7
	ext.w d7
	NEXT

	DEFCODE "@", FETCH, 0		; ( addr -- x )
	movea.w d7, a0			; Sign-extend cell to address ($8000+ -> $FF8000+)
	move.w (a0), d7			; Fetch
	NEXT

	DEFCODE "!", STORE, 0		; ( x addr -- )
	movea.w d7, a0			; Sign-extend cell to address ($8000+ -> $FF8000+)
	move.w (a6)+, (a0)		; Store
	move.w (a6)+, d7		; Refill TOS
	NEXT

	DEFCODE "c@", CFETCH, 0		; ( addr -- c )
	movea.w d7, a0			; Sign-extend cell to address ($8000+ -> $FF8000+)
	clr.w d7			; Clear destination
	move.b (a0), d7			; Fetch
	NEXT

	DEFCODE "c!", CSTORE, 0		; ( c addr -- )
	movea.w d7, a0			; Sign-extend cell to address ($8000+ -> $FF8000+)
	move.w (a6)+, d0		; Pop whole word
	move.b d0, (a0)			; Store only lower byte
	move.w (a6)+, d7		; Refill TOS
	NEXT

	DEFCODE "+!", PLUSSTORE, 0	; ( n addr -- )
	movea.w d7, a0			; Sign-extend cell to address ($8000+ -> $FF8000+)
	move.w (a6)+, d0		; Pop n
	add.w d0, (a0)			; Add an to cell at addr
	move.w (a6)+, d7		; Refill TOS
	NEXT

	DEFCODE "cmove", CMOVE, 0	; ( src dst u -- )
	movea.w (a6)+, a0		; Pop dst address
	movea.w (a6)+, a1		; Pop src address
	tst.w d7			; Check if zero bytes specified
	beq.s +				; If so leave
	subq #1, d7			; Decrement remaining bytes
-	move.b (a1)+, (a0)+		; Move current byte and inc
	dbra d7, -			; loop
+	move.w (a6)+, d7		; Refill TOS
	NEXT

	DEFCODE "fill", FILL, 0		; ( addr u c -- )
	move.w (a6)+, d0		; Pop fill count
	movea.w (a6)+, a0		; Pop dst address
	tst.w d0			; Check if zero bytes specified
	beq.s +				; If so leave
	subq #1, d0			; Decrement remaining bytes
-	move.b d7, (a0)+		; Move byte and inc
	dbra d0, -			; loop
+	move.w (a6)+, d7		; Refill TOS
	NEXT

	DEFCODE "count", COUNT, 0	; ( c-addr -- c-addr+1 u )
	movea.w d7, a0			; Save c-addr
	addq.w #1, d7			; Next address
	move.w d7, -(a6)		; Push under TOS
	moveq #0, d7			; Clear upper bits
	move.b (a0), d7			; u to TOS
	NEXT

	DEFCODE "type", TYPE, 0		; ( c-addr u -- )
	movea.w (a6)+, a0		; Pop c-addr
	tst.w d7			; Check if zero bytes specified
	beq.s +				; If so leave
	subq #1, d7			; Decrement remaining bytes
-	move.b (a0)+, d0		; Move current byte and inc
	jsr SerialPutc			; Print char
	dbra d7, -			; loop
+	move.w (a6)+, d7		; Refill TOS
	NEXT

	DEFCODE "accept", ACCEPT, 0	; ( c-addr +n -- +n2 )
	movea.w (a6)+, a1		; Pop c-addr
	moveq #0, d2			; Count starts at zero
-	jsr SerialGetc			; Next byte in d0.w
	cmp.b #char_cr, d0		; CR?
	beq.s +				; Then done
	cmp.b #char_lf, d0		; LF?
	beq.s -				; Then skip to next
	cmp.w d7, d2			; Count >= limit?
	bhs.s -				; Full, but keep reading until CR
	move.b d0, (a1)+		; Store received char and inc
	jsr SerialPutc			; Echo it (d0 still holds the char)
	addq.w #1, d2			; Inc count
	bra.s -				; Next char
+	moveq #' ', d0			; Echo Enter as a space: output follows on the same line
	jsr SerialPutc
	move.w d2, d7			; Number stored to TOS
	NEXT

	DEFCODE "word", WORD, 0		; ( char -- c-addr )
	lea TIB_START, a0		; a0 = TIB start
	move.w var_toin, d1		; d1 = >in
	adda.w d1, a0			; a0 = read pointer, TIB + >in
	move.w var_ntib, d2		; d2 = characters left to read,
	sub.w  d1, d2			; #tib - >in
	lea WORD_BUF+1, a1		; a1 = write pointer, after the length byte
	; Skip leading delimiters
-	subq.w #1, d2			; Any characters left?
	bmi.s +				; No: end of line, empty word
	move.b (a0)+, d0		; Next character
	bsr.s WordIsDelim		; Z = 1 if it is a delimiter
	beq.s -				; Delimiter: keep skipping
	; Copy the word: d0 holds its first character
-	move.b d0, (a1)+		; Store the character
	subq.w #1, d2			; Any characters left?
	bmi.s +				; No: the word ends at the end of the line
	move.b (a0)+, d0		; Next character (a delimiter is consumed too)
	bsr.s WordIsDelim		; Z = 1 if it is a delimiter
	bne.s -				; Not a delimiter: copy it
	; Done: store the length, update >in, return WORD_BUF
+	move.w a1, d0			; Low word of the write pointer
	sub.w  #(WORD_BUF+1)&$FFFF, d0	; Length = write pointer - first character
	move.b d0, WORD_BUF		; Length byte
	move.w a0, d1			; Low word of the read pointer
	sub.w  #TIB_START&$FFFF, d1	; >in = read pointer - TIB
	move.w d1, var_toin
	move.w #WORD_BUF&$FFFF, d7	; TOS = c-addr of the counted string
	NEXT

; WordIsDelim: is d0 a delimiter for word?
; In: d0.b = character, d7.b = delimiter. Out: Z = 1 if delimiter.
; A space delimiter also matches every control character ($00-$1F),
; so tabs separate words.
WordIsDelim:
	cmp.b d7, d0			; Exactly the delimiter?
	beq.s +				; Yes: Z = 1
	cmp.b #$20, d7			; Delimiter is a space?
	bne.s +				; No: Z = 0 from this compare
	cmp.b #$20, d0			; Control character?
	bhi.s +				; No (above $20): Z = 0
	cmp.b d0, d0			; Yes: set Z = 1
+	rts

; Find: Find a word in the dictionary from its counted string
; a0 = c-addr
; a1 = Current word pointer
; d0 = Count of string to find
; d1 = Index tmp var
; d2 = scratch
	DEFCODE "find", FIND, 0		; ( c-addr -- c-addr 0 | xt 1 | xt -1 )
	movea.w d7, a0			; move c-addr into address register
	moveq #0, d0			; clear count register
	move.b (a0), d0			; store string count byte in d0
	movea.w var_latest, a1		; Move latest to current word register
-	move.b 2(a1), d2		; Get flag/length byte from current word
	andi.b #f_hidden|$1F, d2	; Take only hidden bit and length
	cmp.b d0, d2			; If hidden or not same len, this will not be equal
	bne.s ++			; Go to get next word
	move.w d0, d1			; Setup index counter
	subq.w #1, d1			; dbra stops at -1
-	move.b 3(a1, d1.w), d2		; nth char of name (working backwards with index)
	cmp.b 1(a0, d1.w), d2		; compare with same char of counted string
	bne.s ++			; Not equal, skip to next word
	dbra d1, -			; keep comparing bytes
	move.w a1, d1			; Found, Header address (low word)
	add.w d0, d1			; + name length
	addq.w #4, d1			; + 3 for link and flags/len, + 1 to round up
	andi.w #$FFFE, d1		; Clear bit 0: even code field address = xt
	move.w d1, -(a6)		; Push xt under TOS
	moveq #-1, d7			; Assume normal: -1
	tst.b 2(a1)			; Immediate? (bit 7 = sign of the flags+len byte)
	bpl.s +				; No: keep -1
	moveq #1, d7			; Yes: 1
+	NEXT
+	move.w (a1), d2			; Load pointer to next word
	bne.s +				; Skip ahead if not zero
	move.w d7, -(a6)		; push counted string under TOS
	moveq #0, d7			; Set TOS (d7) to 0
	NEXT				; Leave
+	movea.w d2, a1			; Refill current word pointer
	bra.s --			; Jump to next

; Number: convert a counted string into a number of correct base
; a0 = String read pointer
; a1 = end pointer (instead of count)
; d0 = temp len then current char (then numeric equivalent)
; d1 = total so far
; d2 = base (starting with var_base, update if prefix present)
; d7 = sign flag
	DEFCODE "number", NUMBER, 0	; ( c-addr -- n -1 | c-addr 0 )
	move.w d7, -(a6)		; Push under TOS for failure path
	movea.w d7, a0			; Grab c-addr
	moveq #0, d0			; Clear d0 for length byte
	move.b (a0)+, d0		; Load len into d0 and inc a0 to first char
	beq.s NumberFail		; Fail if len = 0
	moveq #0, d1			; total to zero
	moveq #0, d7			; sign flag to false
	lea 0(a0, d0.w), a1		; Load last char location+1 into a1
	move.b (a0), d0			; Base test, grab first char
	moveq #16, d2			; Check Hexadecimal
	cmpi.b #'$', d0			; '$' prefix?
	beq.s +				; Branch if hex
	moveq #10, d2			; Check Decimal
	cmpi.b #'#', d0			; '#' prefix?
	beq.s +				; Branch if decimal
	moveq #2, d2			; Check Binary
	cmpi.b #'%', d0			; '%' prefix?
	beq.s +				; Branch if binary
	move.w var_base, d2		; Set base from current
	bra.s ++			; Don't skip a char
+	addq.l #1, a0			; Move past base prefix now
+	move.b (a0), d0			; sign test, grab first char
	cmpi.b #'-', d0			; '-' char?
	bne.s +				; skip ahead if not minus
	addq.l #1, a0			; otherwise move past sign and
	moveq #-1, d7			; set sign flag
+	cmpa.l a1, a0			; On to digits, first check any chars left?
	bhs.s NumberFail		; If none, drop to failure output
-	move.b (a0)+, d0		; Get next char
	or.b #$20, d0			; Trick to fold A-Z to a-z, nums not affected
	sub.b #'0', d0			; Convert char value to digit value
	cmpi.b #10, d0			; Is it between 0-9?
	blo.s +				; Yes, it's a digit
	sub.b #'a'-'0', d0		; Convert char value to alpha position value
	cmpi.b #26, d0			; Is it between a-z? (for bases > 16)
	bhs.s NumberFail		; No, can't be a digit
	add.b #10, d0			; a = 10 etc
+	cmp.b d2, d0			; is it within the current base?
	bhs.s NumberFail		; No, can't be a valid digit
	mulu.w d2, d1			; total *= base (32-bit product, low word kept)
	add.w d0, d1			; total += digit
	cmpa.l a1, a0			; More digits to go?
	blo.s -				; Go back and read another
	tst.w d7			; Otherwise check if we need to handle minus
	beq.s +				; No, skip over
	neg.w d1			; otherwise yes, negate
+	move.w d1, (a6)			; Replace under TOS with numeric value
	moveq #-1, d7			; Set TOS return flag as true
	NEXT				; Leave
NumberFail:
	moveq #0, d7			; Make TOS failure result
	NEXT

; .: print n as signed number in base, followed by a space.
; d0 = char to send via SerialPutc
; d1 = zero extended value
; d2 = base
; a1 = sp before any digits are pushed
	DEFCODE ".", DOT, 0		; ( n -- )
	moveq #0, d1			; Clear upper word d1
	move.w d7, d1			; Number to print from TOS
	bpl.s +				; if >= 0, skip printing '-'
	moveq #'-', d0			; Print '-'
	jsr SerialPutc			; Send to console
	neg.w d1			; Now make positive
+	move.w (a6)+, d7		; Refill TOS (n consumed)
	move.w var_base, d2		; Set base from current
	movea.l sp, a1			; Save sp to mark where digits start
-	divu.w d2, d1			; d1 = rem:quot (Z = quot 0, then overwritten below)
	swap   d1			; d1 = quotient:remainder
	move.w d1, -(sp)		; Push the digit
	clr.w  d1			; d1 = quotient:0
	swap   d1			; d1 = 0:quotient; Z = 1 if quotient is 0
	bne.s  -			; More digits
-	move.w (sp)+, d0		; begin text output, pop digit off sp
	cmpi.b #10, d0			; 0-9?
	blo.s +				; Yes:, add '0' to get char
	addq.b #'A'-'0'-10, d0		; No:, do some gymnastics to make next adjustment work
+	addi.b #'0', d0			; Get correct char value for digit
	jsr SerialPutc			; Send to terminal
	cmpa.l a1, sp			; Back to where we started?
	bne.s -				; No: back to pop another digit
	moveq #' ', d0			; We need a trailing space
	jsr SerialPutc			; Send to terminal
	NEXT

; depth: Number of cells currently on stack
	DEFCODE "depth", DEPTH, 0	; ( -- n )
	move.w #DS_START&$FFFF, d0	; Only need low word for diff, not real address
	sub.w a6, d0			; Bytes in stack
	asr.w #1, d0			; /2, each cell is 2 bytes
	move.w d7, -(a6)		; Push old TOS down
	move.w d0, d7			; New TOS, depth
	NEXT

; rp0!: Empty return stack
	DEFCODE "rp0!", RPZEROSTORE, 0	; ( -- ) ( R: i*x -- )
	movea.l #RS_START, sp		; Empty return stack
	NEXT

; abort: Empty data stack and return to interpreting, then call quit
	DEFCODE "abort", ABORT, 0	; ( i*x -- )
	movea.l #DS_START, a6		; Empty data stack
	clr.w var_state			; Back to interpret mode
	jmp QUIT			; Enter quit. no NEXT required

	DEFWORD "interpret", INTERPRET, 0	; ( i*x -- j*x ) run each word in the TIB
-	dc.w LIT, $20, WORD			; ( c-addr ) next word
	dc.w DUP, CFETCH, ZBRANCH, ++		; Length 0: end of line
	dc.w FIND, QDUP, ZBRANCH, +		; ( xt f | c-addr ) not found: try a number
	dc.w DROP, EXECUTE, BRANCH, -		; Found: run it (flag unused until step 5)
+	dc.w NUMBER, ZBRANCH, ++		; ( n | c-addr ) not a number: unknown
	dc.w BRANCH, -				; Number: leave it on the stack
+	dc.w DROP, EXIT				; Drop the empty c-addr; line done
+	dc.w COUNT, TYPE			; Print the unknown word
	dc.w LIT, ' ', EMIT, LIT, '?', EMIT	; then " ?"
	dc.w ABORT				; Empty the stacks, back to quit

	DEFCODE "(.\x22)", PDOTQUOTE, 0		; ( -- ) print the counted string inline in the thread
	moveq #0, d1				; Clear upper bits for length
	move.b (a5)+, d1			; Save length of c-str
	bra.s +					; branch to length test
-	move.b (a5)+, d0			; next char
	jsr SerialPutc				; Send to console
+	dbra d1, -				; dec and loop
	move.l a5, d0				; Next address after string
	addq.l #1, d0				; Round up for...
	andi.w #$FFFE, d0			; ...address boundary
	movea.l d0, a5				; IP = next cell addr.
	NEXT

	DEFWORD "quit", QUIT, 0			; ( -- ) ( R: i*x -- ) outer loop, never returns
	dc.w RPZEROSTORE			; Empty the return stack
	dc.w LIT, 13, EMIT, LIT, 10, EMIT	; CR LF: end the previous line (after an abort)
-	dc.w TIB, LIT, 128, ACCEPT, NTIB, STORE	; Read a line; #tib = its length
	dc.w LIT, 0, TOIN, STORE		; Parse from the start
	dc.w INTERPRET				; Run it
	dc.w DEPTH, ZEROLESS, ZBRANCH, +	; Stack underflow?
	DOTSTR " stack?"			; Yes: complain...
	dc.w ABORT				; ...and start again
+	DOTSTR " ok"				; No: prompt
	dc.w LIT, 13, EMIT, LIT, 10, EMIT	; CR LF
	dc.w BRANCH, -				; Next line

;==============================================================
; SERIAL I/O
;==============================================================
; Follows rhargreaves/mega-drive-serial-port v0.3.0 (src/serial.c),
; known to work on hardware.
;==============================================================

; SerialGetc: wait for a received byte.
; Out: d0.w = byte ($00xx). Uses d1, a0.
; Only reads RAM: the receive interrupt fills the buffer. Sleeps with STOP
; while the buffer is empty. Interrupts are masked around the empty check,
; and STOP unmasks and halts in one instruction, so a byte arriving between
; the check and the sleep still wakes it.
SerialGetc:
-	move.w #sr_irq_off, sr			; No IRQ between the check and STOP
	move.b rx_tail, d0
	cmp.b  rx_head, d0
	bne.s  +				; Buffer not empty
	stop   #sr_irq_on			; Unmask and sleep until any interrupt
	bra.s  -				; Woken: check again (could be V interrupt)
+	move.w #sr_irq_on, sr
	moveq  #0, d1
	move.b d0, d1				; d1.w = tail index, 0-255
	addq.b #1, d0				; Advance tail, wraps at 256
	lea    rx_buf, a0
	move.b (a0,d1.w), d1			; Received byte
	move.b d0, rx_tail			; Free the slot after reading it
	moveq  #0, d0
	move.b d1, d0				; d0.w = received byte
	rts

; SerialPutc: send one byte, waiting while the transmitter is full.
; In: d0.b = byte. Uses nothing else.
; There is no transmit interrupt; at 4800 bps the wait is at most
; 2.08 ms per byte. Received bytes keep arriving by interrupt meanwhile.
SerialPutc:
-	btst   #sctrl_tful, io_sctrl2		; TFUL set: previous byte not taken yet
	bne.s  -
	move.b d0, io_txdata2
	rts

; SerialPutHex: send d1.w as 4 hex digits, most significant first.
; In: d1.w = value (unchanged on return). Uses d0, d2.
SerialPutHex:
	moveq #3, d2		; Loop countdown
-	rol.w #4, d1
	move.w d1, d0		; Copy to extract bottom nibble
	andi.w #$F, d0		; Mask bottom nibble
	addi.b #'0', d0		; 0-9 -> '0'-'9', 10-15 -> ':'-'?'
	cmpi.b #'9', d0
	bls.s  +      		; '9' or below: a digit, done
	addq.b #7, d0      	; skip ':'..'@' to land on 'A'-'F'
+	jsr SerialPutc		; Output char
	dbra d2, -              ; Loop if more nibbles left
	rts

; SerialPutString: send zero terminated string in (a1) to serial port
; In: a1 = string. Out: a1 = past the terminating 0. Uses d0.
SerialPutString:
-	move.b (a1)+, d0
	beq.s  +
	jsr    SerialPutc
	bra.s  -
+	rts

;==============================================================
; INTERRUPT ROUTINES
;==============================================================

; IRQ 2: external interrupt, raised by the serial port when a byte is received.
; Like the reference (ui_callback): read RxData, store it. Drops the byte
; when the buffer is full.
INT_SerialRx:
	movem.l d0-d1/a0, -(sp)
	move.b io_rxdata2, d0			; Received byte
	moveq  #0, d1
	move.b rx_head, d1			; d1.w = head index, 0-255
	lea    rx_buf, a0
	move.b d0, (a0,d1.w)			; Store; the head slot is free even when full
	addq.b #1, d1				; Next head, wraps at 256
	cmp.b  rx_tail, d1
	beq.s  +				; Full: do not advance, byte dropped
	move.b d1, rx_head			; Publish the byte to SerialGetc
+	movem.l (sp)+, d0-d1/a0
	rte

; Vertical interrupt - run once per frame
INT_VInterrupt:
	rte

; Horizontal interrupt - disabled in VDP register $00
INT_HInterrupt:
	rte

; NULL interrupt - for interrupts we don't care about
INT_Null:
	rte

; Exception interrupt - called if an error has occurred
CPU_Exception:
	stop   #$2700				; Halt with all interrupts masked
	rte

; CPU Address error handler
CPU_AddressError:
	lea AddrErrMsg, a1
	jsr SerialPutString
	move.w 4(sp), d1
	jsr SerialPutHex
	lea PcMsg, a1
	jsr SerialPutString
	move.w 12(sp), d1
	jsr SerialPutHex
	movea.l #RS_START, sp   ; Empty return stack (drops the exception frame and any junk)
	movea.l #DS_START, a6   ; Empty data stack
	jmp ABORT

;==============================================================
; UTILITY FUNCTIONS
;==============================================================

VDP_WriteTMSS:
	; Write 'SEGA' to $A14000 on hardware version != 0, or the VDP locks up.
	move.b hardware_ver_address, d0		; Mega Drive hardware version register
	andi.b #$0F, d0				; Version in bits 0-3
	beq    +				; Version 0: no TMSS
	move.l #tmss_signature, tmss_address	; Write "SEGA" to $A14000
+	move.w vdp_control, d0			; Read VDP status register (hangs if no access)
	rts

VDP_LoadRegisters:
	; Write each table byte as a register command: 100R RRRR VVVV VVVV
	; (R = register number, V = value) to the control port.
	lea    VDPRegisters, a0			; Register table
	moveq #$18-1, d0			; 24 registers (-1 for DBRA)
	move.w #$8000, d1			; Command for register 0
-	move.b (a0)+, d1			; Value into the low byte
	move.w d1, vdp_control			; Write register
	addi.w #$0100, d1			; Next register number
	dbra   d0, -
	rts

; Last rom dictionary pointer
rom_latest equ link_prev

; A label defining the end of ROM so we can compute the total size.
ROM_End:
