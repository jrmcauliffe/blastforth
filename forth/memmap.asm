;==============================================================
; FORTH MEMORY MAP
;==============================================================
; Stacks, system variables, buffers and the RAM dictionary.
; See "Memory map" in docs/forth-design.md.
;==============================================================

; ASCII
char_cr                                 equ $0D
char_lf                                 equ $0A

; Forth stacks (see "Memory map" in docs/forth-design.md). Both grow down.
DS_START                equ $00FFFC00   ; Data stack top: a6 starts here
RS_START                equ $00FFFF00   ; Return stack top: sp starts here (vector 0)

; Forth system variables (see "Outer interpreter" in docs/forth-design.md).
; One cell each. Written sign-extended ($FFFFxxxx) so asl uses absolute
; short addressing: 2 bytes and 4 cycles less than absolute long.
var_here                equ $FFFFFF00    ; Next free dictionary byte
var_latest              equ $FFFFFF02    ; Header of the newest word
var_state               equ $FFFFFF04    ; 0 = interpreting, else compiling
var_base                equ $FFFFFF06    ; Number base for number and .
var_toin                equ $FFFFFF08    ; >in: parse offset into the TIB
var_ntib                equ $FFFFFF0A    ; #tib: characters in the TIB

TIB_START               equ $FFFFF900    ; Terminal input buffer, 128 bytes
WORD_BUF                equ $FFFFF980    ; Word Buffer
DICT_START              equ $FFFF8000    ; User dictionary, grows up
