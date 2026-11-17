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

Names: Forth word names are lowercase (`emit`, `dup`). `FIND` compares names exactly, byte for byte: `EMIT` does not find `emit`. In the assembly source each word also has an uppercase asl label for its code field (`EMIT`, `DUP`), used when writing threads by hand. The label is never stored in ROM; it differs from the name where the name is not a valid asl symbol (`!` → `STORE`, `1+` → `ONEPLUS`). asl symbols are case-insensitive, so the uppercase is a readability convention only.

## Input

Serial on controller port 2 at 4800 baud, driven from the e4thcom terminal (see the README). The setup follows [rhargreaves/mega-drive-serial-port](https://github.com/rhargreaves/mega-drive-serial-port) v0.3.0, known to work on hardware: S-Ctrl `$38`, then port 2 control `$7F`, then VDP register `$0B` = `$08` (external interrupt), then SR mask 1. Receive is interrupt-driven: S-Ctrl RINT raises IRQ 2, whose handler reads RxData and stores the byte in a ring buffer. `SerialGetc` sleeps in `stop #$2100` while the buffer is empty; it masks interrupts around the empty check so a byte arriving just before the `stop` still wakes it.

Transmit has no interrupt. `SerialPutc` waits on S-Ctrl TFUL (at most 2.08 ms per byte) and is the only code that writes TxData. A transmit queue drained from the H interrupt can replace it later (step 7, if real-time code needs non-blocking output) without changing its callers.

e4thcom line handling: e4thcom ends each line it sends with CR only, no LF (manual, "Buffered Command Line"). It displays the typed line itself, and after Enter its cursor goes back to the start of that line without a line feed, so output that is not preceded by an echo overwrites the typed line (seen in step 4.6: `7  okepth .` for `1 2 depth .`). `accept` therefore echoes each character it stores, which redraws the line in place, and echoes Enter as a space, so output follows on the same line as the input: `2 3 + . 5  ok`. Echo costs no throughput: sending a byte takes as long as receiving one (2.08 ms at 4800 baud), and receive continues by interrupt meanwhile. Mecrisp-Stellaris shows the same layout; e4thcom's `mecrisp-st.efc` plugin uses its replies (` ok.` then LF) for upload flow control and error detection.

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

## Primitives

Common words are machine code, not only a minimal eForth-style core: most of them are a few 68000 instructions, and as colon definitions they would cost several `NEXT`s plus a `DOCOL`/`EXIT` each. Everything else the system ships with is a colon definition hand-threaded in ROM (`DEFWORD`), so the RAM dictionary (`$FF8000-$FFF8FF`) is left entirely for user definitions. Names are as typed (lowercase).

| Group | Primitives |
|---|---|
| Inner interpreter | `exit` `lit` `branch` `0branch` `execute` |
| Stack | `dup` `drop` `swap` `over` `rot` `nip` `?dup` `2dup` `2drop` `>r` `r>` `r@` |
| Arithmetic | `+` `-` `1+` `1-` `2*` `2/` `negate` `*` `/mod` |
| Logic | `and` `or` `xor` `invert` `lshift` `rshift` |
| Comparison | `=` `<` `>` `u<` `0=` `0<` |
| Memory | `@` `!` `c@` `c!` `+!` `cmove` `fill` |
| I/O | `emit` `key` `type` `.` `.hex` `(.")` |
| Outer interpreter | `accept` `word` `find` `number` `count` `depth` `abort` `rp0!` |

Division is symmetric (truncates toward zero), as the 68000's `divs` does: `-7 2 /mod` gives remainder `-1`, quotient `-3`. Forth 2012 allows symmetric or floored; standard `fm/mod` (floored) and `sm/rem` (symmetric) can be added later for code that needs a specific one.

`branch` and `0branch` take their target from the next cell as an absolute address, sign-extended like any other cell: `movea.w (a5),a5` (12 cycles) when the branch is taken. A not-taken `0branch` steps over the cell with `addq.l #2,a5`. In ROM, asl fills the cell from a label (`dc.w BRANCH, loop`); the compiler stores `HERE` values. A thread that branches must lie in `$0000-$7FFF` or `$FF8000-$FFFFFF`, as code fields already must. A relative offset (`adda.w (a5),a5`) would cost the same and make threads movable, but blastforth never moves compiled code.

## Outer interpreter

The scanners (`accept`, `word`, `find`, `number`) are machine code: they are byte loops, and `find` runs for every word of every line during `#include`, inside e4thcom's ~100 ms silence window. `interpret` and `quit` are control logic and are ROM colon definitions (`DEFWORD`), hand-threaded with `BRANCH`/`ZBRANCH` labels.

Interfaces (classic, as in jonesforth and most texts):

| Word | Stack | Behaviour |
|---|---|---|
| `accept` | `( c-addr +n -- +n )` | Read bytes with `SerialGetc` into the buffer until CR; store at most `+n`, drop the rest of the line. LF is ignored. Echoes each stored byte, and a space for the CR (see "Input"). No backspace handling: e4thcom edits the line before sending it. |
| `word` | `( char -- c-addr )` | Skip leading `char`, copy up to the next `char` or the end of the TIB into the `WORD` buffer as a counted string (length byte, then characters), advance `>in`. With `char` = space (`bl`), every byte `<= $20` counts as a delimiter, so tabs separate words. Returns length 0 at the end of the line. |
| `find` | `( c-addr -- c-addr 0 \| xt 1 \| xt -1 )` | Walk the chain from `latest`, skip hidden headers, compare length and name bytes exactly. `xt` is the code field address. `1` = immediate, `-1` = normal. |
| `number` | `( c-addr -- n -1 \| c-addr 0 )` | Convert a counted string. Optional prefix `$` (hex), `#` (decimal) or `%` (binary) overrides `base` for this number only; then optional `-`; then at least one digit. Digits `0-9`, `a-z`/`A-Z` = 10-35, each must be below the base (a 16-bit compare, so a base of 256 or more accepts every digit). 16-bit result, overflow wraps. No range check on `base`: a bad base only makes numbers fail or misread, and a prefix (`#10 base !`) always gets back. |
| `.` | `( n -- )` | Print signed in `base`, then a space. `base` outside 2-36 (unsigned compare, so negative counts as large) prints ` base?`, sets `base` to 10 and `abort`s: base 0 would divide by zero, base 1 would push digits forever, above 36 has no digit characters. The check is in `.`, not where `base` is set, because a plain `!` can set it. |
| `.hex` | `( x -- )` | Print unsigned as 4 hex digits (`SerialPutHex`), then a space; ignores `base`. For addresses and bit patterns. Not standard; the only unsigned/hex output until step 6 adds `u.`, `hex`, `decimal`. |
| `count` | `( c-addr -- c-addr+1 u )` | Counted string to address and length. |
| `type` | `( c-addr u -- )` | Send `u` bytes with `SerialPutc`. |
| `depth` | `( -- n )` | Number of cells on the data stack before `depth` ran. |
| `abort` | `( i*x -- )` | Empty the data stack, set `state` to 0, then enter `quit` (`jmp QUIT`, its code field; `quit` never exits, so the IP `DOCOL` saves is unused). |
| `rp0!` | `( -- ) ( R: i*x -- )` | Empty the return stack: `sp` = `RS_START`. Lets `quit`, a colon definition, reset the return stack itself. |
| `(.")` | `( -- )` | Print the counted string stored inline in the thread after it, then continue at the next even address after the string. `quit` uses it for ` ok` and ` stack?`; step 6's `."` compiles it. In ROM threads, written with a macro: `dc.w PDOTQUOTE`, `dc.b` length and text, `align 2`. |

`quit` empties the return stack with `rp0!`, sends CR LF (ending the line after an `abort`'s message), then loops: `accept` a line into the TIB, set `#tib` and `>in`, `interpret`, check the stack, print ` ok` and CR LF. Keeping the reset in `quit` (not only in `abort`) matches the standard split: `quit` clears the return stack and keeps the data stack, `abort` clears the data stack and calls `quit`. An unknown word prints the word and ` ?`, then `abort`s. After each line, a negative `depth` prints ` stack?` and `abort`s. Every reply ends in CR LF, so the next typed line starts at column 0. ` ok` is also what a future e4thcom plugin can wait for as flow control (see "Input").

### Constants and variables

A constant's code field is `jsr DOCON`, followed by one `dc.w` cell holding its value, the same shape as a colon word. `DOCON` pops the address `jsr` pushed and pushes the cell stored there. A variable is a constant whose value is its RAM address, so system variables in ROM need no RAM header. Step 5's `constant` and `variable` reuse `DOCON`.

System variables (cells, top of RAM, see "Memory map"):

| Address | Variable | Boot value |
|---|---|---|
| `$FFFF00` | `here` | `$8000` (dictionary start, `$FF8000`) |
| `$FFFF02` | `latest` | header of the last ROM word |
| `$FFFF04` | `state` | 0 (interpreting) |
| `$FFFF06` | `base` | 10 |
| `$FFFF08` | `>in` | 0 |
| `$FFFF0A` | `#tib` | 0 |

`tib` is a constant: `$F900` (`$FFF900`).

## CPU exceptions

Every CPU fault Forth code can cause prints a message and the low word of the PC, then returns to the prompt like `abort`. The handlers are in `md/interrupts.asm`.

- Bus error, address error → `CPU_AddressError`: `addr error XXXX pc XXXX` (access address, PC). This is a 14-byte frame, with the address low word at `4(sp)` and the PC low word at `12(sp)`.
- Division by zero → `CPU_DivZero`: `divide by 0 pc XXXX`.
- Illegal instruction, CHK, TRAPV, privilege violation, Line-A, Line-F → `CPU_Exception`: `exception pc XXXX`.
- These are 6-byte frames: SR at `(sp)`, PC long at `2(sp)`, low word at `4(sp)`. For divide by zero, CHK and TRAPV the PC is the next instruction; for illegal, privilege and Line-A/F it is the faulting one.
- Only the PC's low word is printed. That is exact for ROM below `$10000`; code in RAM shows as `8xxx`, its 16-bit cell form.
- All three share the tail `CPU_Recover`. It empties the return stack (`sp` = `RS_START`, dropping the frame) and the data stack, sets `sr` to `sr_irq_on`, then `jmp ABORT`. A non-interrupt exception keeps the mask it interrupted, which can be 7 (inside `SerialGetc`'s check, or an interrupt handler). Without the reset, `quit` would wait for a key that never arrives.
- TRACE, TRAP, spurious and the reserved vectors stay on `INT_Null` (`rte`). Nothing sets the trace bit, and a TRAP returns past itself.

Example: `1 0 /mod` prints `divide by 0 pc 0600`, and `$4afc $8000 ! $8000 execute` (the ILLEGAL opcode) prints `exception pc 8000`. Both were tested in BlastEm, as were Line-A, Line-F and an address error. CHK, TRAPV and privilege violation share the path but were not triggered.

## Still open

Nothing right now.
