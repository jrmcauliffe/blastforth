---
name: blastem-debug
description: Debug the blastforth Mega Drive ROM in BlastEm from the command line. Use gdb-multiarch over BlastEm's -D GDB stub for 68000 registers, disassembly, memory and breakpoints, and BlastEm's native -d debugger (scripts/bdbg.py) for VDP registers and sprites, watchpoints, Z80 commands, and YM2612 info.
---

# Debugging a ROM in BlastEm

BlastEm acts as a GDB remote stub with `-D`. Drive it with `gdb-multiarch` in batch mode.
Every run launches a fresh BlastEm window that starts halted at the ROM entry point, then closes when gdb exits.
Verified working on this machine (gdb-multiarch 17.1, BlastEm in `/home/aigui/bin/blastem64`).

## Template

Build the ROM first (`asl hello.asm && p2bin hello.p hello.bin`), then:

```sh
cd /home/aigui/projects/blastforth
timeout 60 gdb-multiarch --batch -nx \
  -ex 'set architecture m68k' -ex 'set endian big' -ex 'set confirm off' \
  -ex 'target remote | /home/aigui/bin/blastem64/blastem hello.bin -D' \
  -ex 'info registers pc sp ps' \
  -ex 'x/8i $pc' \
  -ex 'break *0x3A0' -ex 'continue' -ex 'info registers' \
  -ex 'quit' 2>&1
```

Replace the middle `-ex` lines with what you need. Output is plain text on stdout.

## Required settings (each one is a real failure if missed)

- `set endian big`: without it gdb treats the target as little-endian and registers come back byte-swapped (`pc 0x38030000` instead of `0x338`, `sp 0xe0ff00` instead of `0xffe000`). Memory dumps in bytes (`x/xb`) hide the problem, so check a register early.
- `set architecture m68k`: system `/usr/bin/gdb` is x86-only; use `gdb-multiarch`.
- Wrap in `timeout N`: `continue` with no breakpoint hit (for example the main loop) blocks forever.
- `~/.config/blastem/blastem.cfg` must contain `video { vsync on }`. BlastEm's default is `vsync off`, which Wayland/SDL rejects with "Failed to set vsync to off: That operation is not supported", and the stub then gave no replies in a raw-protocol test. The file was created for this and fixed it. If the error returns, check that file first.
- Use the `target remote |` form shown above: it makes gdb spawn BlastEm itself and own its lifetime.

## What was verified

| Capability | Command | Result |
|---|---|---|
| Entry state | `info registers pc sp ps` | `pc 0x338`, `sp 0xffe000`, `ps 0x2700` for `hello.bin` |
| Disassembly | `x/8i $pc` | works (gdb prints AT&T-style m68k syntax) |
| Memory read | `x/4xw 0` | vector table: SP `0xffe000`, entry `0x338` |
| Memory write | `set {char}0xFF0000 = 0x42` then `x/2xb 0xFF0000` | write persists in work RAM |
| Single step | `stepi` | pc advances (`0x338 jsr 0x406` → `0x406` → `0x40c`) |
| Breakpoint + continue | `break *0x3A0`, `continue` | stops at `0x3a0` |
| VDP status read | `x/2xw 0xC00004` | reads the VDP control port |

## Limits and gotchas

- The status register is named `ps` in gdb (`info registers ps`, `$ps`), not `sr`.
- `detach` is not implemented by the stub ("Command D is not implemented", then a connection-reset error). End with `quit` instead; BlastEm exits with it.
- Watchpoints and tracepoints are unsupported through the GDB stub. Use the native debugger below for watchpoints.
- No symbols: `asl` produces no ELF, so gdb shows `?? ()` and warns "No executable has been specified". That warning is harmless. Use raw addresses.
- Find a label's address from the listing: `asl -q -L hello.asm` writes `hello.lst` next to the source (delete it afterwards, it is a generated file); its "symbol table" section lists `NAME : ADDRESS`.
- Reading some VDP/IO registers has side effects on real hardware and may in the emulator too (the VDP data port at `0xC00000` advances the VRAM address). Prefer reading the control port, RAM, and ROM. Writing to hardware registers changes the running emulation.
- State does not persist between runs. Each gdb run restarts the ROM from reset.
- Only the 68000 is reachable through the GDB stub. For VDP, Z80 and YM2612 views use the native debugger below.

## Native debugger (VDP, Z80, watchpoints, YM2612)

`blastem hello.bin -d` starts BlastEm in its own command-line debugger on stdin/stdout. It needs a terminal, so drive it through a pty with the bundled script (BlastEm window opens; the script kills only the process it started):

```sh
cd /home/aigui/projects/blastforth
python3 .omp/skills/blastem-debug/scripts/bdbg.py -r hello.bin \
  'b 0x3A0' 'c' 'p/x pc' 'vr' 'vs' 'p/x [0xFF0000]' 'z80 p/x pc'
```

Use `-w SECONDS` to wait longer for commands that run the emulation (`c`, `frames N`). Run `help` to list every command; `z80 help` lists Z80 commands.

Verified on `hello.bin`:

| Goal | Command | Notes |
|---|---|---|
| Registers / PC | `p/x pc`, `p/x d0`, `p/x a0`, `p/x sr` | `p/x` prints hex without `0x` |
| Breakpoint, run | `b 0x3A0`, `c` | prints `68K Breakpoint 0 hit` and the instruction |
| Step | `n` (next), `s` (into calls), `o` (over, ignores backward branches) | prints the next instruction |
| Run N frames | `frames 2` | stops after N video frames |
| VDP registers | `vr` | decoded: plane table addresses, H40/V28, DMA, status. After init, matches `VDPRegisters` in `hello.asm` (`02: 30 Scroll A $C000`, `0C: 81 Width: 40`) |
| VDP sprites | `vs` | one line per sprite from the table |
| VDP reg write break | `vrb` / `vrb REG` | enters the debugger on a VDP register write (accepted; not exercised further) |
| Read memory | `p/x [0xFF0000]` | reads one 16-bit word. `[0x100]` returned `5345` ("SE" of `SEGA`) |
| Write memory | `set [0xFF0010] 0x1234` | read back `1234` |
| Watchpoint | `watchpoint 0xFF0000 [SIZE]` | accepted: `68K Watchpoint 0 set for $FF0000` (trigger not exercised) |
| Z80 command | `z80 p/x pc`, `z80 p/x sp`, `z80 b 0`, `z80 watchpoint 0x10` | `z80 <command>` runs one Z80 command from the 68K prompt. Z80 `pc` was `0`, `sp` `ffff` at start |
| Named addresses | `variable Entry 0x338`, then `b Entry`, `p/x Entry` | workaround for symbols |
| Other | `ymchannel`, `ymtimer`, `softreset`, `printf`, `display`, `save`/`load` | listed in `help`, not exercised |

Native debugger gotchas:

- Addresses need a `0x` or `$`-style prefix that the parser accepts as one token. `b 3A0` fails ("takes a max of 1 arguments, but at least 2 provided") because `3` and `A0` split into a number and the register `A0`. Write `b 0x3A0`.
- Do not send a bare `z80`. It switches to the Z80 context, which blocks until the Z80 executes, and `hello.bin` never starts the Z80, so every later command went unanswered. Use `z80 COMMAND` instead.
- `c` with no breakpoint hit never returns to the prompt. Set a breakpoint first.
- `symbols FILENAME` needs a quoted string. Quoted files in the formats `name 338`, `name: 338`, `338 name`, `name = 0x338`, `name equ $338`, `338 T name` and tab-separated produced no error and no symbols, so the file format is unknown. Use `variable` or raw addresses.
- Z80 breakpoint and watchpoint hits were not exercised: `hello.asm` never starts the Z80. Test those with a ROM that loads and releases the Z80.

## Cleanup

Do not `pkill blastem`. The user may have their own BlastEm instance open. A batch gdb run kills the BlastEm it started when it exits; confirm with `pgrep -a blastem` and kill only a PID you started.
