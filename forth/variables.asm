;==============================================================
; SYSTEM VARIABLES
;==============================================================
; Constants that push the address of a system variable.
;==============================================================

        DEFCONST "here", HERE, var_here         ; ( -- addr ) next free dictionary byte
        DEFCONST "latest", LATEST, var_latest   ; ( -- addr ) newest header
        DEFCONST "state", STATE, var_state      ; ( -- addr ) 0 = interpreting
        DEFCONST "base", BASE, var_base         ; ( -- addr ) number base
        DEFCONST ">in", TOIN, var_toin          ; ( -- addr ) parse offset into the TIB
        DEFCONST "#tib", NTIB, var_ntib         ; ( -- addr ) characters in the TIB
        DEFCONST "tib", TIB, TIB_START          ; ( -- addr ) the TIB itself
