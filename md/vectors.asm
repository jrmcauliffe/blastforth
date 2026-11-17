;==============================================================
; CPU VECTOR TABLE
;==============================================================
; Read by the CPU from $0000 on reset. IRQ level 2 is the
; external interrupt, raised by the serial port on receive.
;==============================================================
        dc.l   RS_START                 ; Initial stack pointer: top of the return stack ($FFFC00-$FFFEFF)
        dc.l   CPU_EntryPoint           ; Start of program
        dc.l   CPU_AddressError         ; Bus error
        dc.l   CPU_AddressError         ; Address error
        dc.l   CPU_Exception            ; Illegal instruction
        dc.l   CPU_DivZero              ; Division by zero
        dc.l   CPU_Exception            ; CHK CPU_Exception
        dc.l   CPU_Exception            ; TRAPV CPU_Exception
        dc.l   CPU_Exception            ; Privilege violation
        dc.l   INT_Null                 ; TRACE exception
        dc.l   CPU_Exception            ; Line-A emulator (opcode $Axxx)
        dc.l   CPU_Exception            ; Line-F emulator (opcode $Fxxx)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Spurious exception
        dc.l   INT_Null                 ; IRQ level 1
        dc.l   INT_SerialR              ; IRQ level 2 (external interrupt: serial byte received)
        dc.l   INT_Null                 ; IRQ level 3
        dc.l   INT_HInterrupt           ; IRQ level 4 (horizontal retrace interrupt)
        dc.l   INT_Null                 ; IRQ level 5
        dc.l   INT_VInterrupt           ; IRQ level 6 (vertical retrace interrupt)
        dc.l   INT_Null                 ; IRQ level 7
        dc.l   INT_Null                 ; TRAP #00 exception
        dc.l   INT_Null                 ; TRAP #01 exception
        dc.l   INT_Null                 ; TRAP #02 exception
        dc.l   INT_Null                 ; TRAP #03 exception
        dc.l   INT_Null                 ; TRAP #04 exception
        dc.l   INT_Null                 ; TRAP #05 exception
        dc.l   INT_Null                 ; TRAP #06 exception
        dc.l   INT_Null                 ; TRAP #07 exception
        dc.l   INT_Null                 ; TRAP #08 exception
        dc.l   INT_Null                 ; TRAP #09 exception
        dc.l   INT_Null                 ; TRAP #10 exception
        dc.l   INT_Null                 ; TRAP #11 exception
        dc.l   INT_Null                 ; TRAP #12 exception
        dc.l   INT_Null                 ; TRAP #13 exception
        dc.l   INT_Null                 ; TRAP #14 exception
        dc.l   INT_Null                 ; TRAP #15 exception
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
        dc.l   INT_Null                 ; Unused (reserved)
