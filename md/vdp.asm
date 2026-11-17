;==============================================================
; INITIAL VDP REGISTER VALUES
;==============================================================
; 24 register values copied to the VDP during initialisation.
; Same as hello.asm except H interrupt off ($00). The external
; interrupt ($0B bit 3) is turned on later, in the serial setup.
;==============================================================
VDPRegisters:
        dc.b $04 ; $00: H interrupt off (bit 4 = 0), bit 2 must be 1
        dc.b $74 ; $01: V interrupt on, display on, DMA on, Genesis mode on
        dc.b $30 ; $02: Pattern table for Scroll Plane A at VRAM $C000 (bits 3-5 = bits 13-15)
        dc.b $00 ; $03: Pattern table for Window Plane at VRAM $0000 (disabled) (bits 1-5 = bits 11-15)
        dc.b $07 ; $04: Pattern table for Scroll Plane B at VRAM $E000 (bits 0-2 = bits 11-15)
        dc.b $78 ; $05: Sprite table at VRAM $F000 (bits 0-6 = bits 9-15)
        dc.b $00 ; $06: Unused
        dc.b $00 ; $07: Background colour: bits 0-3 = colour, bits 4-5 = palette
        dc.b $00 ; $08: Unused
        dc.b $00 ; $09: Unused
        dc.b $08 ; $0A: Frequency of Horiz. interrupt in Rasters (unused while H interrupt is off)
        dc.b $00 ; $0B: External interrupt off until serial setup, V scroll fullscreen, H scroll fullscreen
        dc.b $81 ; $0C: Shadows and highlights off, interlace off, H40 mode (320 x 224 screen res)
        dc.b $3F ; $0D: Horiz. scroll table at VRAM $FC00 (bits 0-5)
        dc.b $00 ; $0E: Unused
        dc.b $02 ; $0F: Autoincrement 2 bytes
        dc.b $01 ; $10: Scroll plane size: 64x32 tiles
        dc.b $00 ; $11: Window Plane X pos 0 left (pos in bits 0-4, left/right in bit 7)
        dc.b $00 ; $12: Window Plane Y pos 0 up (pos in bits 0-4, up/down in bit 7)
        dc.b $FF ; $13: DMA length lo byte
        dc.b $FF ; $14: DMA length hi byte
        dc.b $00 ; $15: DMA source address lo byte
        dc.b $00 ; $16: DMA source address mid byte
        dc.b $80 ; $17: DMA source address hi byte, memory-to-VRAM mode (bits 6-7)

;==============================================================
; VDP ROUTINES
;==============================================================

VDP_WriteTMSS:
        ; Write 'SEGA' to $A14000 on hardware version != 0, or the VDP locks up.
        move.b hardware_ver_address, d0         ; Mega Drive hardware version register
        andi.b #$0F, d0                         ; Version in bits 0-3
        beq    +                                ; Version 0: no TMSS
        move.l #tmss_signature, tmss_address    ; Write "SEGA" to $A14000
+       move.w vdp_control, d0                  ; Read VDP status register (hangs if no access)
        rts

VDP_LoadRegisters:
        ; Write each table byte as a register command: 100R RRRR VVVV VVVV
        ; (R = register number, V = value) to the control port.
        lea    VDPRegisters, a0                 ; Register table
        moveq #$18-1, d0                        ; 24 registers (-1 for DBRA)
        move.w #$8000, d1                       ; Command for register 0
-       move.b (a0)+, d1                        ; Value into the low byte
        move.w d1, vdp_control                  ; Write register
        addi.w #$0100, d1                       ; Next register number
        dbra   d0, -
        rts
