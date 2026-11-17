;==============================================================
; SERIAL I/O
;==============================================================
; Follows rhargreaves/mega-drive-serial-port v0.3.0 (src/serial.c),
; known to work on hardware.
;==============================================================

; Serial receive ring buffer (kernel-private, lower 32 KiB of work RAM;
; see "Memory map" in docs/forth-design.md). 256 bytes with byte-sized
; indices, so the indices wrap for free. Empty when head = tail; full when
; head + 1 = tail (one slot stays unused, capacity 255 bytes).
rx_buf					equ $00FF0000	; 256-byte buffer
rx_head					equ $00FF0100	; byte: next slot to write (only INT_SerialRx writes it)
rx_tail					equ $00FF0101	; byte: next slot to read (only SerialGetc writes it)

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
