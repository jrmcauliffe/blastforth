;==============================================================
; OUTER INTERPRETER
;==============================================================
; abort, interpret and quit. See "Outer interpreter" in
; docs/forth-design.md.
;==============================================================

; abort: Empty data stack and return to interpreting, then call quit
        DEFCODE "abort", ABORT, 0       ; ( i*x -- )
        movea.l #DS_START, a6           ; Empty data stack
        clr.w var_state                 ; Back to interpret mode
        jmp QUIT                        ; Enter quit. no NEXT required

        DEFWORD "interpret", INTERPRET, 0       ; ( i*x -- j*x ) run each word in the TIB
-       dc.w LIT, $20, WORD                     ; ( c-addr ) next word
        dc.w DUP, CFETCH, ZBRANCH, ++           ; Length 0: end of line
        dc.w FIND, QDUP, ZBRANCH, +             ; ( xt f | c-addr ) not found: try a number
        dc.w DROP, EXECUTE, BRANCH, -           ; Found: run it (flag unused until step 5)
+       dc.w NUMBER, ZBRANCH, ++                ; ( n | c-addr ) not a number: unknown
        dc.w BRANCH, -                          ; Number: leave it on the stack
+       dc.w DROP, EXIT                         ; Drop the empty c-addr; line done
+       dc.w COUNT, TYPE                        ; Print the unknown word
        dc.w LIT, ' ', EMIT, LIT, '?', EMIT     ; then " ?"
        dc.w ABORT                              ; Empty the stacks, back to quit

        DEFWORD "quit", QUIT, 0                 ; ( -- ) ( R: i*x -- ) outer loop, never returns
        dc.w RPZEROSTORE                        ; Empty the return stack
        dc.w LIT, 13, EMIT, LIT, 10, EMIT       ; CR LF: end the previous line (after an abort)
-       dc.w TIB, LIT, 128, ACCEPT, NTIB, STORE ; Read a line; #tib = its length
        dc.w LIT, 0, TOIN, STORE                ; Parse from the start
        dc.w INTERPRET                          ; Run it
        dc.w DEPTH, ZEROLESS, ZBRANCH, +        ; Stack underflow?
        DOTSTR " stack?"                        ; Yes: complain...
        dc.w ABORT                              ; ...and start again
+       DOTSTR " ok"                            ; No: prompt
        dc.w LIT, 13, EMIT, LIT, 10, EMIT       ; CR LF
        dc.w BRANCH, -                          ; Next line
