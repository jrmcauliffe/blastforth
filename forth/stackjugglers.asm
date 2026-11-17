;==============================================================
; STACK WORDS
;==============================================================
; Data and return stack manipulation.
;==============================================================

        DEFCODE "dup", DUP, 0   ; ( x -- x x )
        move.w d7, -(a6)
        NEXT

        DEFCODE "drop", DROP, 0 ; ( x -- )
        move.w (a6)+, d7
        NEXT

        DEFCODE "nip", NIP, 0   ; ( a b -- b )
        addq.l #2, a6
        NEXT

        DEFCODE "swap", SWAP, 0 ; ( a b -- b a )
        move.w d7, d1
        move.w (a6), d7
        move.w d1, (a6)
        NEXT

        DEFCODE "over", OVER, 0 ; ( a b -- a b a )
        move.w d7, -(a6)
        move.w 2(a6), d7
        NEXT

        DEFCODE "?dup", QDUP, 0 ; ( a -- a a | 0 )
        tst.w d7
        beq.s +
        move.w d7, -(a6)
+       NEXT

        DEFCODE "2drop", TWODROP, 0     ; ( a b -- )
        addq.l #2, a6                   ; nip
        move.w (a6)+, d7                ; drop
        NEXT

        DEFCODE "2dup", TWODUP, 0       ; ( a b -- a b a b )
        move.w (a6), d1                 ; save a
        move.w d7, -(a6)                ; push b
        move.w d1, -(a6)                ; push a
        NEXT

        DEFCODE "rot", ROT, 0           ; ( a b c -- b c a )
        move.w 2(a6), d1                ; save a
        move.w (a6), 2(a6)
        move.w d7, (a6)
        move.w d1, d7
        NEXT

        DEFCODE ">r", TOR, 0            ; ( a -- ) ( R: -- a )
        move.w d7, -(sp)
        move.w (a6)+, d7
        NEXT

        DEFCODE "r>", RFROM, 0          ; (  -- a ) ( R: a -- )
        move.w d7, -(a6)
        move.w (sp)+, d7
        NEXT

        DEFCODE "r@", RFETCH, 0         ; (  -- a ) ( R: a -- a )
        move.w d7, -(a6)
        move.w (sp), d7
        NEXT

; depth: Number of cells currently on stack
        DEFCODE "depth", DEPTH, 0       ; ( -- n )
        move.w #DS_START&$FFFF, d0      ; Only need low word for diff, not real address
        sub.w a6, d0                    ; Bytes in stack
        asr.w #1, d0                    ; /2, each cell is 2 bytes
        move.w d7, -(a6)                ; Push old TOS down
        move.w d0, d7                   ; New TOS, depth
        NEXT

; rp0!: Empty return stack
        DEFCODE "rp0!", RPZEROSTORE, 0  ; ( -- ) ( R: i*x -- )
        movea.l #RS_START, sp           ; Empty return stack
        NEXT
