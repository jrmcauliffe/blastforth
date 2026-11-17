;==============================================================
; INTERRUPT ROUTINES
;==============================================================

; IRQ 2: external interrupt, raised by the serial port when a byte is received.
; Like the reference (ui_callback): read RxData, store it. Drops the byte
; when the buffer is full.
INT_SerialRx:
        movem.l d0-d1/a0, -(sp)
        move.b io_rxdata2, d0                   ; Received byte
        moveq  #0, d1
        move.b rx_head, d1                      ; d1.w = head index, 0-255
        lea    rx_buf, a0
        move.b d0, (a0,d1.w)                    ; Store; the head slot is free even when full
        addq.b #1, d1                           ; Next head, wraps at 256
        cmp.b  rx_tail, d1
        beq.s  +                                ; Full: do not advance, byte dropped
        move.b d1, rx_head                      ; Publish the byte to SerialGetc
+       movem.l (sp)+, d0-d1/a0
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
        stop   #$2700                           ; Halt with all interrupts masked
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
