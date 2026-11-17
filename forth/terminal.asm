;==============================================================
; TERMINAL
;==============================================================
; Forth words on top of the serial routines in md/serial.asm.
;==============================================================

        DEFCODE "emit", EMIT, 0         ; ( c -- )
        move.w d7, d0           ; TOS to d0
        move.w (a6)+, d7        ; Refill TOS
        jsr SerialPutc          ; Call serial routine
        NEXT

        DEFCODE "key", KEY, 0           ; ( -- c )
        jsr SerialGetc                  ; Wait for byte in d0.w
        move.w d7, -(a6)                ; Push old TOS down
        move.w d0, d7                   ; New TOS, c
        NEXT

        DEFCODE "accept", ACCEPT, 0     ; ( c-addr +n -- +n2 )
        movea.w (a6)+, a1               ; Pop c-addr
        moveq #0, d2                    ; Count starts at zero
-       jsr SerialGetc                  ; Next byte in d0.w
        cmp.b #char_cr, d0              ; CR?
        beq.s +                         ; Then done
        cmp.b #char_lf, d0              ; LF?
        beq.s -                         ; Then skip to next
        cmp.w d7, d2                    ; Count >= limit?
        bhs.s -                         ; Full, but keep reading until CR
        move.b d0, (a1)+                ; Store received char and inc
        jsr SerialPutc                  ; Echo it (d0 still holds the char)
        addq.w #1, d2                   ; Inc count
        bra.s -                         ; Next char
+       moveq #' ', d0                  ; Echo Enter as a space: output follows on the same line
        jsr SerialPutc
        move.w d2, d7                   ; Number stored to TOS
        NEXT
