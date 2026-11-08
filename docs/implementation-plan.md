# Implementation plan

The order to build blastforth in. jonesforth is the guide for what comes first, not a template to copy: the word lists and details are ours to decide. Design decisions live in `docs/forth-design.md`.

## Open decisions

Decided and recorded in `docs/forth-design.md`: the RAM memory map (Forth side), the header flag bits, lowercase names with exact-match `FIND`, the primitive set (common words in machine code, see "Primitives"), shipped words as ROM colon definitions, symmetric division, and absolute `branch` / `0branch` targets.

Nothing is open right now; new questions go in `docs/forth-design.md`, "Still open".

Record each decision in `docs/forth-design.md` when made.

## Steps

1. **Serial echo in plain assembly.** Before any Forth, get a character in and back out over controller port 2. Every later step depends on seeing output. *Done:* `blastforth.asm` echoes over port 2 at 4800 baud with interrupt-driven receive, tested in BlastEm and on hardware.
2. **Inner interpreter.** `NEXT`, `DOCOL`, `EXIT`, plus a header macro. Hand-write a thread in ROM that prints text with just `LIT` and `EMIT`, and have one colon word call another. This is the core of the system. *Done:* `NEXT` macro, `DOCOL`, `EXIT`, `LIT`, `EMIT` and the `HEADER` macro in `blastforth.asm`; a boot thread runs colon word `hihi`, which calls `hi` twice, printing `HiHi` (tested in BlastEm). The `hi`/`hihi`/`halt` test words and boot thread are temporary.
3. **Enough primitives to compute.** Stack, arithmetic, comparison, memory. Add an address-error handler early: odd-address `@` will happen, and without a handler the CPU just halts. *Done:* every primitive in the table in `docs/forth-design.md` ("Primitives") is in `blastforth.asm`. `CPU_AddressError` prints the fault address and PC over serial, then halts. The memory words, `key`, `execute`, `branch` and `0branch` were tested in BlastEm through the boot thread. The `two` and `halt` words and the boot thread are temporary.
4. **Outer interpreter, built up in order.** `KEY` / line input → `WORD` → `NUMBER` → `FIND` → `INTERPRET` / `QUIT`. Result: a calculator REPL over e4thcom. Design in `docs/forth-design.md`, "Outer interpreter". Sub-steps, each tested through the boot thread:
   1. `DOCON`, the system variables and `tib`, set at boot. Test: `base @ .hex` prints `000A`.
   2. `count`, `type`, `accept`. Test: read a line and `type` it back.
   3. `word`. Test: split a typed line, printing each word between brackets.
   4. `find`. Test: `dup` gives the `DUP` address and `-1`; an unknown name gives `0`.
   5. `number` and `.`. Test: `123`, `-5`, `$ff`, `%101`, a bad digit.
   6. `depth`, `abort`, `interpret`, `quit`. Boot into `quit`; remove the boot thread and temporary words; the address-error handler jumps to `abort` instead of `halt`. Test: `2 3 + .` prints `5  ok`.
5. **Compiler.** `CREATE`, `,`, `[`, `]`, `:`, `;`, `IMMEDIATE`, `0BRANCH`. Once `: STAR 42 EMIT ;` works, most remaining work is in Forth.
6. **Grow the system.** Control structures, number printing, strings, `WORDS`. Words the system ships with go into ROM as `DEFWORD` threads, so the RAM dictionary stays free for user code (see "Primitives" in `docs/forth-design.md`). Move a word to machine code only when speed or hardware access needs it.
7. **Mega Drive words.** Long-address access for VDP and I/O, a screen console, joypad, VBlank.

Each step ends with something testable. Until the REPL exists (step 4), check state with the `blastem-debug` gdb workflow: `a5` (IP), `a6`/`d7` (data stack), PC.

## What to borrow from jonesforth

- The order of steps 2–5: each stage gives a testable result before the next.
- The split: a small machine-code core, everything else as colon definitions. Unlike jonesforth, those live in ROM, not compiled from source at startup.
- The idea of `IMMEDIATE` words, such as `IF` built from `HERE` and back-patching. Read it for the technique.

## Where jonesforth does not apply

- **Cells and address windows.** 16-bit cells, and `@`/`!` only reach ROM `$0000-$7FFF` and RAM `$FF8000-$FFFFFF`. Anything Forth touches by address must live in `$FF8000+`, so the memory map has to fit that. Hardware ports and the lower 32 KiB of RAM need long-address words.
- **Cached TOS.** TOS lives in `d7`; every primitive must keep that invariant.
- **Serial input and flow control.** No stdin. The serial receive buffer holds one byte. During `#include`, the `anyforth` plugin sends the next line once the target has been silent for ~100 ms, so a line that compiles silently for longer than that can lose input. A blastforth plugin can instead wait for a prompt such as ` ok`, as the noForth plugin does.
- **ROM vs RAM dictionary.** Kernel headers in ROM cannot change. `LATEST` and `HERE` are RAM variables set at boot.
