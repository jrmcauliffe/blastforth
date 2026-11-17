;==============================================================
; PARSING
;==============================================================
; word: split the TIB into blank-delimited words.
;==============================================================

        DEFCODE "word", WORD, 0         ; ( char -- c-addr )
        lea TIB_START, a0               ; a0 = TIB start
        move.w var_toin, d1             ; d1 = >in
        adda.w d1, a0                   ; a0 = read pointer, TIB + >in
        move.w var_ntib, d2             ; d2 = characters left to read,
        sub.w  d1, d2                   ; #tib - >in
        lea WORD_BUF+1, a1              ; a1 = write pointer, after the length byte
        ; Skip leading delimiters
-       subq.w #1, d2                   ; Any characters left?
        bmi.s +                         ; No: end of line, empty word
        move.b (a0)+, d0                ; Next character
        bsr.s WordIsDelim               ; Z = 1 if it is a delimiter
        beq.s -                         ; Delimiter: keep skipping
        ; Copy the word: d0 holds its first character
-       move.b d0, (a1)+                ; Store the character
        subq.w #1, d2                   ; Any characters left?
        bmi.s +                         ; No: the word ends at the end of the line
        move.b (a0)+, d0                ; Next character (a delimiter is consumed too)
        bsr.s WordIsDelim               ; Z = 1 if it is a delimiter
        bne.s -                         ; Not a delimiter: copy it
        ; Done: store the length, update >in, return WORD_BUF
+       move.w a1, d0                   ; Low word of the write pointer
        sub.w  #(WORD_BUF+1)&$FFFF, d0  ; Length = write pointer - first character
        move.b d0, WORD_BUF             ; Length byte
        move.w a0, d1                   ; Low word of the read pointer
        sub.w  #TIB_START&$FFFF, d1     ; >in = read pointer - TIB
        move.w d1, var_toin
        move.w #WORD_BUF&$FFFF, d7      ; TOS = c-addr of the counted string
        NEXT

; WordIsDelim: is d0 a delimiter for word?
; In: d0.b = character, d7.b = delimiter. Out: Z = 1 if delimiter.
; A space delimiter also matches every control character ($00-$1F),
; so tabs separate words.
WordIsDelim:
        cmp.b d7, d0                    ; Exactly the delimiter?
        beq.s +                         ; Yes: Z = 1
        cmp.b #$20, d7                  ; Delimiter is a space?
        bne.s +                         ; No: Z = 0 from this compare
        cmp.b #$20, d0                  ; Control character?
        bhi.s +                         ; No (above $20): Z = 0
        cmp.b d0, d0                    ; Yes: set Z = 1
+       rts
