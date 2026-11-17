;==============================================================
; NUMBERS
;==============================================================
; Number conversion and printing.
;==============================================================

        DEFCODE ".hex", PRINTHEX, 0     ; ( x -- ) 4 hex digits, unsigned, ignores base
        move.w d7, d1           ; TOS to scratch register
        move.w (a6)+, d7        ; POP TOS
        jsr SerialPutHex        ; Expects val in d1
        moveq #' ', d0          ; Output final space
        jsr SerialPutc          ; For clarity
        NEXT

; Number: convert a counted string into a number of correct base
; a0 = String read pointer
; a1 = end pointer (instead of count)
; d0 = temp len then current char (then numeric equivalent)
; d1 = total so far
; d2 = base (starting with var_base, update if prefix present)
; d7 = sign flag
        DEFCODE "number", NUMBER, 0     ; ( c-addr -- n -1 | c-addr 0 )
        move.w d7, -(a6)                ; Push under TOS for failure path
        movea.w d7, a0                  ; Grab c-addr
        moveq #0, d0                    ; Clear d0 for length byte
        move.b (a0)+, d0                ; Load len into d0 and inc a0 to first char
        beq.s NumberFail                ; Fail if len = 0
        moveq #0, d1                    ; total to zero
        moveq #0, d7                    ; sign flag to false
        lea 0(a0, d0.w), a1             ; Load last char location+1 into a1
        move.b (a0), d0                 ; Base test, grab first char
        moveq #16, d2                   ; Check Hexadecimal
        cmpi.b #'$', d0                 ; '$' prefix?
        beq.s +                         ; Branch if hex
        moveq #10, d2                   ; Check Decimal
        cmpi.b #'#', d0                 ; '#' prefix?
        beq.s +                         ; Branch if decimal
        moveq #2, d2                    ; Check Binary
        cmpi.b #'%', d0                 ; '%' prefix?
        beq.s +                         ; Branch if binary
        move.w var_base, d2             ; Set base from current
        bra.s ++                        ; Don't skip a char
+       addq.l #1, a0                   ; Move past base prefix now
+       move.b (a0), d0                 ; sign test, grab first char
        cmpi.b #'-', d0                 ; '-' char?
        bne.s +                         ; skip ahead if not minus
        addq.l #1, a0                   ; otherwise move past sign and
        moveq #-1, d7                   ; set sign flag
+       cmpa.l a1, a0                   ; On to digits, first check any chars left?
        bhs.s NumberFail                ; If none, drop to failure output
-       move.b (a0)+, d0                ; Get next char
        or.b #$20, d0                   ; Trick to fold A-Z to a-z, nums not affected
        sub.b #'0', d0                  ; Convert char value to digit value
        cmpi.b #10, d0                  ; Is it between 0-9?
        blo.s +                         ; Yes, it's a digit
        sub.b #'a'-'0', d0              ; Convert char value to alpha position value
        cmpi.b #26, d0                  ; Is it between a-z? (for bases > 16)
        bhs.s NumberFail                ; No, can't be a digit
        add.b #10, d0                   ; a = 10 etc
+       cmp.w d2, d0                    ; is it within the current base? (word compare: d0 upper byte is 0)
        bhs.s NumberFail                ; No, can't be a valid digit
        mulu.w d2, d1                   ; total *= base (32-bit product, low word kept)
        add.w d0, d1                    ; total += digit
        cmpa.l a1, a0                   ; More digits to go?
        blo.s -                         ; Go back and read another
        tst.w d7                        ; Otherwise check if we need to handle minus
        beq.s +                         ; No, skip over
        neg.w d1                        ; otherwise yes, negate
+       move.w d1, (a6)                 ; Replace under TOS with numeric value
        moveq #-1, d7                   ; Set TOS return flag as true
        NEXT                            ; Leave
NumberFail:
        moveq #0, d7                    ; Make TOS failure result
        NEXT

; .: print n as signed number in base, followed by a space.
; A base outside 2-36 prints " base?", sets base back to 10 and aborts:
; base 0 would divide by zero, base 1 would push digits forever.
; d0 = char to send via SerialPutc
; d1 = zero extended value
; d2 = base
; a1 = sp before any digits are pushed
        DEFCODE ".", DOT, 0             ; ( n -- )
        move.w var_base, d2             ; Set base from current
        cmpi.w #2, d2                   ; Unsigned compares: negative bases count as large
        blo.s DotBadBase                ; 0 or 1: no valid conversion
        cmpi.w #36, d2                  ; Highest base with a digit character (0-9, A-Z)
        bhi.s DotBadBase
        moveq #0, d1                    ; Clear upper word d1
        move.w d7, d1                   ; Number to print from TOS
        bpl.s +                         ; if >= 0, skip printing '-'
        moveq #'-', d0                  ; Print '-'
        jsr SerialPutc                  ; Send to console
        neg.w d1                        ; Now make positive
+       move.w (a6)+, d7                ; Refill TOS (n consumed)
        movea.l sp, a1                  ; Save sp to mark where digits start
-       divu.w d2, d1                   ; d1 = rem:quot (Z = quot 0, then overwritten below)
        swap   d1                       ; d1 = quotient:remainder
        move.w d1, -(sp)                ; Push the digit
        clr.w  d1                       ; d1 = quotient:0
        swap   d1                       ; d1 = 0:quotient; Z = 1 if quotient is 0
        bne.s  -                        ; More digits
-       move.w (sp)+, d0                ; begin text output, pop digit off sp
        cmpi.b #10, d0                  ; 0-9?
        blo.s +                         ; Yes:, add '0' to get char
        addq.b #'A'-'0'-10, d0          ; No:, do some gymnastics to make next adjustment work
+       addi.b #'0', d0                 ; Get correct char value for digit
        jsr SerialPutc                  ; Send to terminal
        cmpa.l a1, sp                   ; Back to where we started?
        bne.s -                         ; No: back to pop another digit
        moveq #' ', d0                  ; We need a trailing space
        jsr SerialPutc                  ; Send to terminal
        NEXT
DotBadBase:
        move.w #10, var_base            ; Back to decimal so the next . works
        lea DotBaseMsg, a1
        jsr SerialPutString             ; " base?"
        jmp ABORT                       ; Empty the stacks, back to quit; no NEXT
DotBaseMsg:
        dc.b " base?", 0
        align 2                         ; Word-align the next header after the odd-length string
