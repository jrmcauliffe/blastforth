;==============================================================
; COMPARISONS
;==============================================================
; Flags are -1 (true) or 0 (false).
;==============================================================

        DEFCODE "0=", ZEROEQUALS, 0     ; ( n -- flag )
        tst d7
        seq d7
        ext.w d7
        NEXT

        DEFCODE "0<", ZEROLESS, 0       ; ( n -- flag )
        tst d7
        smi d7
        ext.w d7
        NEXT

        DEFCODE "=", EQUALS, 0          ; ( a b -- flag )
        move.w (a6)+, d0
        cmp.w d7, d0
        seq d7
        ext.w d7
        NEXT

        DEFCODE "<", LESS, 0            ; ( a b -- flag )
        move.w (a6)+, d0
        cmp.w d7, d0
        slt d7
        ext.w d7
        NEXT

        DEFCODE ">", GREATER, 0         ; ( a b -- flag )
        move.w (a6)+, d0
        cmp.w d7, d0
        sgt d7
        ext.w d7
        NEXT

        DEFCODE "u<", ULESS, 0          ; ( a b -- flag )
        move.w (a6)+, d0
        cmp.w d7, d0
        scs d7
        ext.w d7
        NEXT
