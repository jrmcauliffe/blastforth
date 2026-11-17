;==============================================================
; MEGA DRIVE HARDWARE CONSTANTS
;==============================================================

; VDP port addresses
vdp_control				equ $00C00004
vdp_data				equ $00C00000

; Hardware version address
hardware_ver_address	equ $00A10001

; TMSS
tmss_address			equ $00A14000
tmss_signature			equ 'SEGA'

; Status register values (bit 13 = supervisor, bits 8-10 = interrupt mask)
sr_irq_off				equ $2700	; Supervisor, mask 7: all maskable interrupts blocked
sr_irq_on				equ $2100	; Supervisor, mask 1: IRQ 2 (serial), 4 (H), 6 (V) allowed

; Controller port 2, parallel mode
io_ctrl2				equ $00A1000B	; Pin directions (bits 0-6, 1 = output), bit 7 = TH interrupt enable
io_ctrl2_setup			equ $7F			; Pins 0-6 output, TH interrupt off (reference: CTRL_PCS_OUT)

; Controller port 2, serial mode (UART)
io_txdata2				equ $00A10015	; TxData: byte to send
io_rxdata2				equ $00A10017	; RxData: last byte received
io_sctrl2				equ $00A10019	; S-Ctrl: serial control and status, bits below

; S-Ctrl bit numbers (for btst)
sctrl_tful				equ 0		; 1 = TxData holds a byte not yet sent

; VDP register $0B (mode 3) write command: 100 01011 00001000
;   bit 3 = 1: IE2, external interrupt (IRQ 2) on; V/H scroll fullscreen
vdp_reg0b_extint		equ $8B08

; S-Ctrl value written at boot:
;   bits 7-6 = 00: 4800 bps (480 bytes/s, 2.08 ms per byte)
;   bit 5    = 1:  SIN, TR (pin 9) is serial input (RxData)
;   bit 4    = 1:  SOUT, TL (pin 6) is serial output (TxData)
;   bit 3    = 1:  RINT, raise the external interrupt when a byte is received
sctrl_setup				equ $38
