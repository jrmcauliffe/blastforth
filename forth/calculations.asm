;==============================================================
; ARITHMETIC
;==============================================================
; 16-bit signed arithmetic. /mod is symmetric (divs).
;==============================================================

        DEFCODE "1+", ONEPLUS, 0        ; ( n -- n+1 )
        addq.w #1, d7
        NEXT

        DEFCODE "1-", ONEMINUS, 0   ; ( n -- n-1 )
        subq.w #1, d7
        NEXT

        DEFCODE "negate", NEGATE, 0     ; ( n -- -n )
        neg.w d7
        NEXT

        DEFCODE "2*", TWOSTAR, 0        ; ( n -- n*2 )
        add.w d7, d7
        NEXT

        DEFCODE "2/", TWOSLASH, 0       ; ( n -- n/2 )
        asr.w #1, d7
        NEXT

        DEFCODE "+", PLUS, 0            ; ( a b -- a+b )
        add.w (a6)+, d7
        NEXT

        DEFCODE "-", MINUS, 0           ; ( a b -- a-b )
        sub.w (a6)+, d7
        neg.w d7
        NEXT

        DEFCODE "*", STAR, 0            ; ( a b -- a*b )
        muls.w (a6)+, d7
        NEXT

        DEFCODE "/mod", SLASHMOD, 0     ; ( a b -- rem quot )
        move.w (a6), d1
        ext.l d1
        divs d7, d1
        move.w d1, d7
        swap d1
        move.w d1, (a6)
        NEXT
