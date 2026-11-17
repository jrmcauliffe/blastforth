;==============================================================
; DICTIONARY
;==============================================================
; Dictionary search.
;==============================================================

; Find: Find a word in the dictionary from its counted string
; a0 = c-addr
; a1 = Current word pointer
; d0 = Count of string to find
; d1 = Index tmp var
; d2 = scratch
        DEFCODE "find", FIND, 0         ; ( c-addr -- c-addr 0 | xt 1 | xt -1 )
        movea.w d7, a0                  ; move c-addr into address register
        moveq #0, d0                    ; clear count register
        move.b (a0), d0                 ; store string count byte in d0
        movea.w var_latest, a1          ; Move latest to current word register
-       move.b 2(a1), d2                ; Get flag/length byte from current word
        andi.b #f_hidden|$1F, d2        ; Take only hidden bit and length
        cmp.b d0, d2                    ; If hidden or not same len, this will not be equal
        bne.s ++                        ; Go to get next word
        move.w d0, d1                   ; Setup index counter
        subq.w #1, d1                   ; dbra stops at -1
-       move.b 3(a1, d1.w), d2          ; nth char of name (working backwards with index)
        cmp.b 1(a0, d1.w), d2           ; compare with same char of counted string
        bne.s ++                        ; Not equal, skip to next word
        dbra d1, -                      ; keep comparing bytes
        move.w a1, d1                   ; Found, Header address (low word)
        add.w d0, d1                    ; + name length
        addq.w #4, d1                   ; + 3 for link and flags/len, + 1 to round up
        andi.w #$FFFE, d1               ; Clear bit 0: even code field address = xt
        move.w d1, -(a6)                ; Push xt under TOS
        moveq #-1, d7                   ; Assume normal: -1
        tst.b 2(a1)                     ; Immediate? (bit 7 = sign of the flags+len byte)
        bpl.s +                         ; No: keep -1
        moveq #1, d7                    ; Yes: 1
+       NEXT
+       move.w (a1), d2                 ; Load pointer to next word
        bne.s +                         ; Skip ahead if not zero
        move.w d7, -(a6)                ; push counted string under TOS
        moveq #0, d7                    ; Set TOS (d7) to 0
        NEXT                            ; Leave
+       movea.w d2, a1                  ; Refill current word pointer
        bra.s --                        ; Jump to next
