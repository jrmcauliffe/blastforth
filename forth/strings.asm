;==============================================================
; STRINGS
;==============================================================
; Counted strings and text output.
;==============================================================

        DEFCODE "count", COUNT, 0       ; ( c-addr -- c-addr+1 u )
        movea.w d7, a0                  ; Save c-addr
        addq.w #1, d7                   ; Next address
        move.w d7, -(a6)                ; Push under TOS
        moveq #0, d7                    ; Clear upper bits
        move.b (a0), d7                 ; u to TOS
        NEXT

        DEFCODE "type", TYPE, 0         ; ( c-addr u -- )
        movea.w (a6)+, a0               ; Pop c-addr
        tst.w d7                        ; Check if zero bytes specified
        beq.s +                         ; If so leave
        subq #1, d7                     ; Decrement remaining bytes
-       move.b (a0)+, d0                ; Move current byte and inc
        jsr SerialPutc                  ; Print char
        dbra d7, -                      ; loop
+       move.w (a6)+, d7                ; Refill TOS
        NEXT

        DEFCODE "(.\x22)", PDOTQUOTE, 0         ; ( -- ) print the counted string inline in the thread
        moveq #0, d1                            ; Clear upper bits for length
        move.b (a5)+, d1                        ; Save length of c-str
        bra.s +                                 ; branch to length test
-       move.b (a5)+, d0                        ; next char
        jsr SerialPutc                          ; Send to console
+       dbra d1, -                              ; dec and loop
        move.l a5, d0                           ; Next address after string
        addq.l #1, d0                           ; Round up for...
        andi.w #$FFFE, d0                       ; ...address boundary
        movea.l d0, a5                          ; IP = next cell addr.
        NEXT
