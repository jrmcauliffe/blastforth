;==============================================================
; SEGA MEGA DRIVE ROM HEADER
;==============================================================
; Metadata at $100. The console only checks "SEGA" at $100
; (TMSS); emulators read the title and region.
;==============================================================
	dc.b "SEGA MEGA DRIVE "                                 ; Console name
	dc.b "BLASTFORTH      "                                 ; Copyright holder and release date
	dc.b "BLASTFORTH                                      " ; Domestic name
	dc.b "BLASTFORTH                                      " ; International name
	dc.b "GM XXXXXXXX-XX"                                   ; Version number
	dc.w $0000                                              ; Checksum
	dc.b "J               "                                 ; I/O support
	dc.l ROM_Start                                          ; Start address of ROM
	dc.l ROM_End-1                                          ; End address of ROM
	dc.l $00FF0000                                          ; Start address of RAM
	dc.l $00FF0000+$0000FFFF                                ; End address of RAM
	dc.l $00000000                                          ; SRAM enabled
	dc.l $00000000                                          ; Unused
	dc.l $00000000                                          ; Start address of SRAM
	dc.l $00000000                                          ; End address of SRAM
	dc.l $00000000                                          ; Unused
	dc.l $00000000                                          ; Unused
	dc.b "                                        "         ; Notes (unused)
	dc.b "  E             "                                 ; Country codes
