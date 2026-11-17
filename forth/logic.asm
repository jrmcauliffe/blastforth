;==============================================================
; LOGIC
;==============================================================
; Bitwise operations and shifts.
;==============================================================

        DEFCODE "and", AND, 0           ; ( a b -- a&b )
        and.w (a6)+, d7
        NEXT

        DEFCODE "or", OR, 0             ; ( a b -- a|b )
        or.w (a6)+, d7
        NEXT

        DEFCODE "xor", XOR, 0           ; ( a b -- a^b )
        move.w (a6)+, d0                ; Source for eor must be data reg.
        eor.w d0, d7
        NEXT

        DEFCODE "invert", INVERT, 0     ; ( a -- ~a )
        not.w d7
        NEXT

        DEFCODE "lshift", LSHIFT, 0     ; ( x u -- x' )
        move.w (a6)+, d0
        lsl.w d7, d0
        move.w d0, d7
        NEXT

        DEFCODE "rshift", RSHIFT, 0     ; ( x u -- x' )
        move.w (a6)+, d0
        lsr.w d7, d0
        move.w d0, d7
        NEXT
