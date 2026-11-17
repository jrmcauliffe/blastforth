;==============================================================
; INNER INTERPRETER
;==============================================================
; Code field routines and the words that run threads.
;==============================================================

; DOCOL: enter a colon word. A colon word's code field is
; jsr DOCOL; jsr pushes the address after itself, which is the
; start of the word's thread.
; In: (sp) = thread address, a5 = caller's IP.
; Out: (sp) = caller's IP, a5 = thread. Uses a0.
DOCOL:
	movea.l (sp), a0	; Thread address pushed by jsr
	move.l a5, (sp)		; Replace it with the caller's IP (saved for EXIT)
	movea.l a0, a5		; IP = start of the thread
	NEXT

DOCON:
	movea.l (sp)+, a0	; Address of value cell
	move.w d7, -(a6)	; Push down stack
	move.w (a0), d7		; New TOS
	NEXT

; EXIT: leave a colon word. Compiled as the last cell of every
; colon word; undoes DOCOL.
; In: (sp) = caller's IP. Out: a5 = caller's IP, sp += 4.
	DEFCODE "exit", EXIT, 0
	move.l (sp)+, a5	; Pop the caller's IP
	NEXT

	DEFCODE "lit", LIT, 0		; ( -- n )
	move.w d7, -(a6)	; Push old TOS down
	move.w (a5)+, d7	; New TOS and IP += 2
	NEXT

	DEFCODE "execute", EXECUTE, 0	; ( xt -- )
	movea.w d7, a0		; sign-extend cell to address ($8000+ -> $FF8000+)
	move.w (a6)+, d7	; Refill TOS
	jmp (a0)		; jmp to code field
				; No Next required as target word will have one

	DEFCODE "branch", BRANCH, 0	; ( -- )
	movea.w (a5), a5		; Set the next cell as the new instruction pointer
	NEXT

	DEFCODE "0branch", ZBRANCH, 0	; ( flag -- )
	tst.w d7		; flag == 0?
	beq.s +			; If yes, take branch
	move.w (a6)+, d7	; Refill TOS
	addq.l #2, a5		; If no, skip target cell
	NEXT
+	move.w (a6)+, d7	; Refill TOS
	movea.w (a5), a5	; Update IP with target address
	NEXT
