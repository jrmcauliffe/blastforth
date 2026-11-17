;==============================================================
; CODE ENTRY POINT
;==============================================================
CPU_EntryPoint:

        ; Write the TMSS signature (if a model 1+ Mega Drive)
        jsr    VDP_WriteTMSS

        ; Load the initial VDP registers
        jsr    VDP_LoadRegisters

        ;==============================================================
        ; Serial port on controller port 2
        ;==============================================================
        ; Same order and values as rhargreaves/mega-drive-serial-port v0.3.0
        ; (serial_init), which is known to work on hardware: S-Ctrl, then the
        ; port control register, then VDP external interrupt, then the CPU mask.
        ;
        ; Empty the receive buffer before the interrupt can fire: work RAM
        ; holds garbage after power-on.
        clr.b  rx_head
        clr.b  rx_tail

        move.b #sctrl_setup, io_sctrl2          ; 4800 bps, serial in and out, interrupt on receive
        move.b #io_ctrl2_setup, io_ctrl2        ; Pins 0-6 output, TH interrupt off
        move.w #vdp_reg0b_extint, vdp_control   ; VDP: external interrupt (IRQ 2) on

        ; Allow IRQ 2 and above. Must be mask 1 or lower, or the serial interrupt never arrives.
        move.w #sr_irq_on, sr

        ;==============================================================
        ; Banner, then start the interpreter
        ;==============================================================

        lea    Banner, a1
        jsr  SerialPutString

        ; Forth system variables (see "Outer interpreter" in docs/forth-design.md)
        move.w #DICT_START&$FFFF, var_here      ; Empty RAM dictionary: next free byte is $FF8000
        move.w #rom_latest, var_latest          ; Search starts at the newest ROM header
        move.w #10, var_base                    ; Decimal
        clr.w  var_toin                         ; Parse from the start of the TIB
        clr.w  var_ntib                         ; TIB empty
        jmp ABORT

Banner:
        dc.b "blastforth", 0
AddrErrMsg:
        dc.b "addr error ", 0
PcMsg:
        dc.b " pc ", 0
DivZeroMsg:
        dc.b "divide by 0", 0
ExceptionMsg:
        dc.b "exception", 0
        align  2                                ; Word-align the code after the odd-length string (asl has no EVEN)
