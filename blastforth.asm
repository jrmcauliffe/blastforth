;==============================================================
; BLASTFORTH - SEGA MEGA DRIVE/GENESIS FORTH
;==============================================================
; Step 1 of docs/implementation-plan.md: serial echo in plain
; assembly. Controller port 2 runs as a UART at 4800 baud.
; Received bytes arrive through the external interrupt (IRQ 2)
; into a ring buffer; the main loop sleeps until a byte is
; there and sends it back.
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
	dc.l   $00FFFF00			; Initial stack pointer: top of the return stack ($FFFC00-$FFFEFF, docs/forth-design.md)
	dc.l   CPU_EntryPoint		; Start of program
	dc.l   CPU_Exception		; Bus error
	dc.l   CPU_Exception		; Address error
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

DS_START				equ $FFFC00
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

; EXIT: leave a colon word. Compiled as the last cell of every
; colon word; undoes DOCOL.
; In: (sp) = caller's IP. Out: a5 = caller's IP, sp += 4.
EXIT:
	move.l (sp)+, a5	; Pop the caller's IP
	NEXT

LIT:				; ( -- n )
	move.w d7, -(a6)	; Push old TOS down
	move.w (a5)+, d7	; New TOS and IP += 2
	NEXT

EMIT:				; ( c -- )
	move.w d7, d0		; TOS to d0
	move.w (a6)+, d7	; Refill TOS
	jsr SerialPutc		; Call serial routine
	NEXT

HALT:				; Temp for testing
-	bra.s -			; Loop

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
	; Banner, then echo forever
	;==============================================================

	lea    Banner, a1
-	move.b (a1)+, d0
	beq.s  +
	jsr    SerialPutc
	bra.s  -
+
	; Temp boot code
	movea.l #DS_START, a6		; Set SP address
	lea BT, a5
	NEXT

	; e4thcom shows the typed line itself, so an echo written at the same place
	; is indistinguishable from it. Start each echoed line with CR LF to put it
	; on its own line. e4thcom ends each line with CR only (manual, "Buffered
	; Command Line"); add LF after it too.
	; d3.b = 1 while at the start of an echoed line, 0 inside one.
	moveq  #1, d3
-	jsr    SerialGetc			; Waits until a byte arrives
	tst.b  d3
	beq.s  +				; Inside a line: echo directly
	move.b d0, d2				; Keep the byte across the CR LF
	moveq  #char_cr, d0
	jsr    SerialPutc
	moveq  #char_lf, d0
	jsr    SerialPutc
	move.b d2, d0
	clr.b  d3				; Now inside the echoed line
+	jsr    SerialPutc			; Echo it (SerialPutc leaves d0 unchanged)
	cmpi.b #char_cr, d0
	bne.s  -
	moveq  #char_lf, d0
	jsr    SerialPutc
	moveq  #1, d3				; Next byte starts a new echoed line
	bra.s  -

Banner:
	dc.b "blastforth", char_cr, char_lf, 0
	align  2				; Word-align the code after the odd-length string (asl has no EVEN)

HI:
	jsr DOCOL
	dc.w LIT, 'H', EMIT
	dc.w LIT, 'i', EMIT
	dc.w EXIT
BT:
	dc.w HI, HI, HALT
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

; Exception interrupt - called if an error has occured
CPU_Exception:
	stop   #$2700				; Halt with all interrupts masked
	rte

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
	move.w #$18-1, d0			; 24 registers (-1 for DBRA)
	move.w #$8000, d1			; Command for register 0
-	move.b (a0)+, d1			; Value into the low byte
	move.w d1, vdp_control			; Write register
	addi.w #$0100, d1			; Next register number
	dbra   d0, -
	rts

; A label defining the end of ROM so we can compute the total size.
ROM_End:
