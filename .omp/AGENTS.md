# blastforth

A Forth system that runs on the Sega Mega Drive / Genesis, written in Motorola 68000 assembly.
`blastforth.asm` is the Forth kernel ROM, built up step by step per `docs/implementation-plan.md` (currently step 1: interrupt-driven serial echo on port 2). `hello.asm` is the original Hello World reference: vector table, ROM header, VDP init, palette, font tiles, main loop.

## Toolchain

- Assembler: `asl` (Macro Assembler AS), `/usr/local/bin/asl`. Source uses `cpu 68000`, `SUPMODE ON`, `PADDING OFF`.
- ROM packer: `p2bin`, `/usr/local/bin/p2bin`.
- Emulator: BlastEm, `/home/aigui/bin/blastem64/blastem`. The agent cannot see the screen, so report what to look for rather than claiming it works. To inspect registers, memory and execution without the GUI, use the `blastem-debug` skill (gdb-multiarch over BlastEm's `-D` stub). Never `pkill blastem`: the user may have their own instance open.
- Forth terminal: e4thcom runs in the user's tmux session `forth` (real serial port, or BlastEm via `blastem-serial`; the agent's side is the same). Attach by using that session: `./forth-cmd 'line'` types lines and prints the screen, `./forth-upload file.fs` does `#include`, `tmux capture-pane -p -t forth` just reads it. If the session is missing, ask the user to start it. See skill `blastem-serial`.

## Build

Two steps, by hand (no Makefile yet):

```sh
asl blastforth.asm                 # -> blastforth.p (assembler intermediate)
p2bin blastforth.p blastforth.bin  # -> blastforth.bin (ROM image)
./blastem-serial blastforth.bin    # BlastEm with port 2 as a serial port (see README)
```

Generated, never edit: `*.p`, `*.bin`, `*.lst`, `*.map`. Only `*.bin` is gitignored right now.

## Source conventions

- Match the style of `hello.asm`: tab-indented instructions, aligned trailing `;` comments, `;====` section banners with explanatory header comments, `equ` constants grouped by purpose, `macro`/`endm` helpers.
- Use relative (anonymous) labels (`+` / `-`) for local branches, not named local labels. See the `beq +` in the TMSS check. This was a deliberate change (commit "Swap named to relative labels").
- Strict 68000 only: no 68010/68020+ instructions, addressing modes, or opcodes. The Mega Drive CPU is a 68000 at ~7.6 MHz.
- Comment every hardware register value, VDP command and magic number with what it means (bit fields, addresses, units). Follow the VDP register table in `hello.asm` as the model.
- Prefer named `equ` constants over literals for hardware addresses (VDP ports, TMSS, VRAM layout).

## Hardware notes

- ROM starts with the 64-entry CPU vector table, then the 256-byte header (`SEGA MEGA DRIVE ` at $100).
- 68000 requires word-aligned code and word/long accesses on even addresses. Use `align 2` after odd-length `dc.b` data (asl has no `even`).
- Work RAM is $FF0000-$FFFFFF (64 KiB). Initial SP (return stack top) is $FFFF00 in `blastforth.asm`; see the memory map in `docs/forth-design.md`.
- VDP: control port $C00004, data port $C00000. TMSS signature must be written on hardware version != 0.
- VDP layout in `hello.asm`: tiles at VRAM $0000, Plane A $C000, Plane B $E000; 64x32 plane, H40 (320x224).

## Forth design

Decided and recorded in `docs/forth-design.md`: 16-bit direct threading (16-bit cells reaching ROM $0000-$7FFF and RAM $FF8000-$FFFFFF), registers (`a5` IP, `a6` data stack, `d7` TOS, `a7` return stack), dictionary header layout, serial input. Follow that document and keep it up to date.

Decided and recorded there: RAM memory map, header flag bits. Still open (listed at the end of that document): the primitive set. Ask the user before deciding it; do not pick it silently.
