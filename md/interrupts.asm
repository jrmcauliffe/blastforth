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

; CPU exceptions: print what happened and the PC, then recover to the prompt.
; Divide by zero, CHK and TRAPV push a 6-byte frame: SR at (sp), PC long at
; 2(sp) (low word at 4(sp)), pointing after the faulting instruction.
; Illegal instruction, privilege violation and Line-A/F use the same frame,
; but their PC points at the faulting instruction itself.
; Only the PC's low word is printed: exact for ROM below $10000, and the
; 16-bit cell form ($8xxx) for code in RAM.
CPU_DivZero:
        lea DivZeroMsg, a1              ; "divide by 0"
        bra.s +
CPU_Exception:
        lea ExceptionMsg, a1            ; "exception": illegal, CHK, TRAPV, privilege, Line-A/F
+       jsr SerialPutString
        lea PcMsg, a1
        jsr SerialPutString
        move.w 4(sp), d1                ; PC low word from the 6-byte frame
        jsr SerialPutHex
        bra.s CPU_Recover

; CPU Address error handler (also bus error). 14-byte frame: access address
; low word at 4(sp), PC low word at 12(sp).
CPU_AddressError:
        lea AddrErrMsg, a1
        jsr SerialPutString
        move.w 4(sp), d1
        jsr SerialPutHex
        lea PcMsg, a1
        jsr SerialPutString
        move.w 12(sp), d1
        jsr SerialPutHex
; Shared tail: empty both stacks and restart the interpreter. An exception
; keeps the interrupt mask it interrupted (it could be mask 7, inside
; SerialGetc's check or an interrupt handler), so unmask IRQ 2 again or quit
; would wait for a key that never arrives.
CPU_Recover:
        movea.l #RS_START, sp           ; Empty return stack (drops the exception frame and any junk)
        movea.l #DS_START, a6           ; Empty data stack
        move.w #sr_irq_on, sr           ; Supervisor, mask 1: serial IRQ 2 allowed again
        jmp ABORT
