# Forth design

Decisions for the blastforth core. Cycle counts are from the 68000 timing tables, not measured.

## Threading: 16-bit direct threading (DTC)

Chosen for learning: the inner interpreter is a few visible instructions, threads are plain data (readable in a memory dump, easy `SEE`), the compiler is just `,`, and it matches the standard texts (*Moving Forth*, jonesforth). Subroutine threading with inlining is about 2x faster but needs a native code generator. It stays an option for later; primitives are machine code in both models and carry over unchanged.

A thread cell is a 16-bit code address. `movea.w` sign-extends it to 32 bits, so a cell can reach two windows:

| Cell value | Address | Use |
|---|---|---|
| $0000-$7FFF | $000000-$007FFF | first 32 KiB of ROM: kernel |
| $8000-$FFFF | $FF8000-$FFFFFF | upper 32 KiB of work RAM: user dictionary |

Every code field, and so every word a thread refers to, must lie in one of these windows. Other ROM (tiles, sound, source) is plain data reached with 32-bit fetches.

Inner interpreter (illustrative):

```asm
NEXT:	movea.w	(a5)+,a0	; 8  fetch cell at IP, sign-extend to address
	jmp	(a0)		; 8  jump to the code field

; Colon definition code field: jsr DOCOL (abs.w, 4 bytes).
; jsr pushes the address after itself = start of the thread.
DOCOL:	move.l	(sp),d0		; thread address
	move.l	a5,(sp)		; save caller's IP on the return stack
	movea.l	d0,a5		; IP = thread
	NEXT

EXIT:	movea.l	(sp)+,a5	; restore caller's IP
	NEXT
```

IP is a full 32-bit register and is saved and restored with `.l`, because it can point anywhere in ROM. Only the cells are 16-bit.

Approximate costs: NEXT 16 cycles; a colon call plus return about 106.

## Cells

16-bit cells. The 68000 has a 16-bit ALU and bus, so `.w` operations are cheaper than `.l`. 64 KiB of RAM does not need wider cells. Addresses outside the 16-bit windows need double-cell words (`2@` and similar).

## Registers

| Register | Role |
|---|---|
| `a5` | IP (instruction pointer) |
| `a6` | data stack pointer, grows down |
| `d7` | top of data stack (cached) |
| `a7` | return stack, shared with `jsr` and interrupts |
| `a0` | word address after NEXT; scratch |
| `a1`, `d0`-`d2` | scratch, free for primitives |

Other registers are not yet assigned.

`a7` as return stack is safe with interrupts: VBlank and HBlank push their frames below the return stack and pop them before returning. `a7` must stay even; word pushes keep it even.

## Dictionary header

```
link        dc.w   previous header (16-bit address, same windows as cells)
flags+len   dc.b   flag bits + name length
name        dc.b   name characters
            align 2
code field  machine code (primitive) or jsr DOCOL (colon definition)
body        thread cells / data
```

Flags+len byte:

| Bit | Meaning |
|---|---|
| 7 | immediate |
| 6 | hidden (being defined, not findable yet) |
| 5 | reserved |
| 4-0 | name length, 1-31 characters |

## Input

Serial on controller port 2 at 4800 baud, driven from the e4thcom terminal (see the README). The setup follows [rhargreaves/mega-drive-serial-port](https://github.com/rhargreaves/mega-drive-serial-port) v0.3.0, known to work on hardware: S-Ctrl `$38`, then port 2 control `$7F`, then VDP register `$0B` = `$08` (external interrupt), then SR mask 1. Receive is interrupt-driven: S-Ctrl RINT raises IRQ 2, whose handler reads RxData and stores the byte in a ring buffer. `SerialGetc` sleeps in `stop #$2100` while the buffer is empty; it masks interrupts around the empty check so a byte arriving just before the `stop` still wakes it.

Transmit has no interrupt. `SerialPutc` waits on S-Ctrl TFUL (at most 2.08 ms per byte) and is the only code that writes TxData. A transmit queue drained from the H interrupt can replace it later (step 7, if real-time code needs non-blocking output) without changing its callers.

## Memory map

Work RAM `$FF0000-$FF7FFF` is outside the cell windows, so Forth cannot address it with `@`/`!`. It holds kernel-private data:

| Address | Size | Use |
|---|---|---|
| `$FF0000` | 256 bytes | serial receive ring buffer |
| `$FF0100` | 1 byte | receive head index (written by the IRQ 2 handler) |
| `$FF0101` | 1 byte | receive tail index (written by `SerialGetc`) |

The Forth side (`$FF8000-$FFFFFF`) is reachable by 16-bit cells and by absolute short addressing (2 bytes and 4 cycles cheaper than absolute long). The dictionary grows up from the bottom; both stacks grow down from the top, so the free space is one gap between `HERE` and the data stack. Sizes are a first cut and can change.

| Range | Size | Use |
|---|---|---|
| `$FFFF00-$FFFFFF` | 256 B | system variables (`HERE`, `LATEST`, `STATE`, `BASE`, `>IN`, `#TIB`, ...) |
| `$FFFC00-$FFFEFF` | 768 B | return stack: `a7` starts at `$FFFF00` (vector 0). Also holds `jsr` return addresses and interrupt frames (6 bytes each). |
| `$FFFA00-$FFFBFF` | 512 B | data stack, 256 cells: `a6` starts at `$FFFC00` (second item; TOS is in `d7`) |
| `$FFF900-$FFF97F` | 128 B | TIB (e4thcom sends at most 128 characters per line) |
| `$FFF980-$FFF9FF` | 128 B | `WORD` buffer / number hold area |
| `$FF8000-$FFF8FF` | 30,976 B | user dictionary, grows up from `$FF8000` |

There is no overflow protection: a stack that overflows writes into its neighbour. A depth check in the interpreter loop (step 4) or guard gaps can be added later.

## Still open

- Number of primitives in the kernel versus words defined in Forth.
