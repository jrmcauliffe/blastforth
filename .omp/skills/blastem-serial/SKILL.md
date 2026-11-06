---
name: blastem-serial
description: Read from and write to the blastforth Forth terminal, which is e4thcom running in the tmux session `forth`. e4thcom may be talking to a real serial port or to BlastEm's emulated controller-port UART; the agent's side is identical.
---

# Forth terminal: attach to the tmux session `forth`

The user runs e4thcom in a tmux session named `forth`. The agent just talks to that session; what e4thcom is connected to (real serial port, or BlastEm) makes no difference to it.

- `./forth-cmd 'line' ['line' ...]`: types each line into the session, waits for the pane to stop changing, prints the last 60 lines.
- `./forth-upload file.fs`: types `#include file.fs` and prints the result. There is no Forth on the target yet, so there is nothing to compile the upload until it exists. The `anyforth` plugin does no error checking; only e4thcom's own failures (`Msg from HOST`, e.g. file not found) are detected.
- Just look: `tmux capture-pane -p -t forth -S -60`.
- Type something raw: `tmux send-keys -t forth -l -- 'text'; tmux send-keys -t forth Enter`. A trailing `;` must be written `\;`, or tmux treats it as a command separator and nothing is typed.
- e4thcom holds its display while its input line has text in it (tested: typing `abc` without Enter froze the pane, backspacing it empty resumed the stream; nothing is sent to the target until Enter). So if the user has half-typed something, the pane looks stuck and the agent's line is appended to theirs. Clear it with BSpace keys (`tmux send-keys -t forth BSpace`); tmux's `BTab` is not understood by e4thcom and prints a stray `Z`.

If `tmux has-session -t forth` fails, there is nothing to attach to: ask the user to start it (`./forth-connect`). Do not start another e4thcom on the same device.

## Starting it (the user does this, in their own terminal)

```sh
./blastem-serial roms/xxx.bin # BlastEm with controller port 2 as a UART, bridged to a pty (needs socat)
./forth-connect              # e4thcom on that pty, in tmux session 'forth'
./forth-connect ttyUSB0      # or: e4thcom on a real serial port
```

`forth-connect [device [baud [plugin]]]` runs `e4thcom -t plugin -d device -b baud` (defaults: `../tmp/blastforth-tty`, `B4800`, `anyforth`) in session `forth` and attaches. e4thcom prepends `/dev/` to the device, hence the relative path. The scripts use `~/bin/e4thcom-0.8.5.2/e4thcom`, not the `~/bin/e4thcom` wrapper, which hardcodes a plugin from another project. `anyforth` is e4thcom's generic plugin (terminal plus `#include` upload, no error checking).

`blastem-serial ROM` writes a private BlastEm config (port 2 `serial`, a unix socket) under `/tmp/blastforth-emu/`, starts BlastEm, and runs `socat` to turn the socket into the pty `/tmp/blastforth-tty`. `blastem-serial stop` stops both (`status` shows them). It does not touch `~/.config/blastem`. Never `pkill blastem`.

## Emulator notes

- Port 2 UART registers: TxData `$A10015`, RxData `$A10017`, S-Ctrl `$A10019` (b7-6 baud 00=4800/01=2400/10=1200/11=300, b5 SIN, b4 SOUT, b3 RINT, b2 RERR, b1 RRDY, b0 TFUL). Port 1 is 6 lower, EXT 6 higher; only one port can be serial (one socket). Use port 2; port 1 has an emulator quirk on S-Ctrl writes.
- BlastEm accepts a single client (socat). If socat dies, BlastEm freezes on its next transmit, blocked in `accept()` waiting for a new client, and it then ignores SIGTERM (SDL turns it into a quit event the blocked thread never handles). `blastem-serial stop` therefore sends SIGTERM, waits ~2 s, then SIGKILLs BlastEm; never rely on a plain `kill`. `blastem-serial` keeps a pty slave open so quitting and restarting e4thcom is safe; output sent while no console is attached queues and appears on attach.
- Nothing echoes except the ROM (raw pty). The emulator only transmits when SOUT is set; receive is effectively always on once S-Ctrl is non-zero, so a working emulator session does not prove SIN or the pin wiring for hardware.
- No window-less mode (SDL's dummy driver leaves BlastEm without a renderer). Logs: `/tmp/blastforth-emu/blastem.log`, `socat.log`.
- Debug the ROM itself with the `blastem-debug` skill.
