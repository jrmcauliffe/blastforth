;==============================================================
; MEMORY
;==============================================================
; Cell and byte access, block move and fill.
;==============================================================

        DEFCODE "@", FETCH, 0           ; ( addr -- x )
        movea.w d7, a0                  ; Sign-extend cell to address ($8000+ -> $FF8000+)
        move.w (a0), d7                 ; Fetch
        NEXT

        DEFCODE "!", STORE, 0           ; ( x addr -- )
        movea.w d7, a0                  ; Sign-extend cell to address ($8000+ -> $FF8000+)
        move.w (a6)+, (a0)              ; Store
        move.w (a6)+, d7                ; Refill TOS
        NEXT

        DEFCODE "c@", CFETCH, 0         ; ( addr -- c )
        movea.w d7, a0                  ; Sign-extend cell to address ($8000+ -> $FF8000+)
        clr.w d7                        ; Clear destination
        move.b (a0), d7                 ; Fetch
        NEXT

        DEFCODE "c!", CSTORE, 0         ; ( c addr -- )
        movea.w d7, a0                  ; Sign-extend cell to address ($8000+ -> $FF8000+)
        move.w (a6)+, d0                ; Pop whole word
        move.b d0, (a0)                 ; Store only lower byte
        move.w (a6)+, d7                ; Refill TOS
        NEXT

        DEFCODE "+!", PLUSSTORE, 0      ; ( n addr -- )
        movea.w d7, a0                  ; Sign-extend cell to address ($8000+ -> $FF8000+)
        move.w (a6)+, d0                ; Pop n
        add.w d0, (a0)                  ; Add an to cell at addr
        move.w (a6)+, d7                ; Refill TOS
        NEXT

        DEFCODE "cmove", CMOVE, 0       ; ( src dst u -- )
        movea.w (a6)+, a0               ; Pop dst address
        movea.w (a6)+, a1               ; Pop src address
        tst.w d7                        ; Check if zero bytes specified
        beq.s +                         ; If so leave
        subq #1, d7                     ; Decrement remaining bytes
-       move.b (a1)+, (a0)+             ; Move current byte and inc
        dbra d7, -                      ; loop
+       move.w (a6)+, d7                ; Refill TOS
        NEXT

        DEFCODE "fill", FILL, 0         ; ( addr u c -- )
        move.w (a6)+, d0                ; Pop fill count
        movea.w (a6)+, a0               ; Pop dst address
        tst.w d0                        ; Check if zero bytes specified
        beq.s +                         ; If so leave
        subq #1, d0                     ; Decrement remaining bytes
-       move.b d7, (a0)+                ; Move byte and inc
        dbra d0, -                      ; loop
+       move.w (a6)+, d7                ; Refill TOS
        NEXT
