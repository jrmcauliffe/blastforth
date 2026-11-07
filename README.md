# blastforth

A Forth system for the Sega Mega Drive / Genesis, in 68000 assembly. `blastforth.asm` is the kernel ROM (`asl blastforth.asm && p2bin blastforth.p blastforth.bin`); `hello.asm` is the original Hello World reference. Design decisions are in `docs/forth-design.md`.

## Serial terminal

The Forth terminal is [e4thcom](https://wiki.forth-ev.de/doku.php/projects:e4thcom:start) running inside a tmux session named `forth`. It talks to the Mega Drive over a serial port on controller port 2, either:

- **in BlastEm**, which emulates the port as a unix socket (`blastem-serial` turns that into a pty), or
- **on real hardware**, through a USB serial adapter.

Everything else (the user typing, the agent reading and writing) goes through that one tmux session, so it is the same whichever side e4thcom is connected to.

### Requirements

- `tmux` and `socat` (`sudo apt install tmux socat`; socat is only needed for BlastEm)
- e4thcom at `~/bin/e4thcom-0.8.5.2/e4thcom` (set `E4THCOM=/path/to/e4thcom` to use another copy)
- BlastEm at `~/bin/blastem64/blastem` (set `BLASTEM=...` to use another)

### Start a session (BlastEm)

From the project root, in this order:

```sh
./blastem-serial roms/mega-drive-serial-port-v0.3.0.bin   # opens a BlastEm window, serial on controller port 2
./forth-connect                                           # starts e4thcom in tmux session 'forth' and attaches
```

`blastem-serial` takes any ROM (for example `blastforth.bin`). It must be running before `forth-connect`.

### Start a session (real hardware)

No `blastem-serial` needed. Connect the adapter, then:

```sh
./forth-connect ttyUSB0 B4800     # device name under /dev, baud as an e4thcom B-constant
```

The baud must match what the ROM sets in the S-Ctrl register (00 in bits 7-6 = 4800, 01 = 2400, 10 = 1200, 11 = 300).

### Everyday use

| Want to | Do |
|---|---|
| Leave the session running, go back to the shell | `Ctrl-b d` |
| Come back to it | `./forth-connect` (says "already running" and attaches) or `tmux attach -t forth` |
| Quit e4thcom (also ends the session) | type `\` then Enter |
| Restart e4thcom (BlastEm keeps running) | quit it as above, then `./forth-connect` again |
| Stop BlastEm | `./blastem-serial stop` (`./blastem-serial status` shows what is running) |

`forth-connect [device [baud [plugin]]]` defaults to the BlastEm pty (`../tmp/blastforth-tty`), `B4800` and the `anyforth` plugin. e4thcom prepends `/dev/` to the device, hence the relative path.

### Letting the agent in

The agent reads and writes the same `forth` session. You start it as above; the agent then uses:

```sh
./forth-cmd 'some text' 'another line'   # types each line, waits for the screen to settle, prints it
tmux capture-pane -p -t forth -S -60     # just read the screen
```

The agent does not start e4thcom itself. If the `forth` session is not running it asks you to start it.

`./forth-upload file.fs` types `#include file.fs`. There is no Forth on the target yet, so it is not usable for now.

### Things that behave unexpectedly

- **Typing freezes the output.** While e4thcom's input line has text in it, e4thcom stops updating the display. Backspacing the line empty resumes it (tested); Enter sends the line to the target. This is e4thcom, not the ROM.
- **Type in the tmux window, not the BlastEm window.** BlastEm's keys are emulator hotkeys (for example `u` enters its debugger, `l` loads a state) and do not go to the serial port.
- **What you type is not the target's echo.** e4thcom shows your text in its own command-line buffer and sends it, with a trailing CR, only on Enter, without local echo. Before sending, it backspaces the cursor to the start of the typed text (`ui?` in `src/mfp1.5w4.0.2/sio-term-readline.mf`), so an echo from the target prints exactly over it and looks like nothing happened. `blastforth.asm` starts each echoed line with CR LF so the echo shows on its own line.
- **If socat dies, BlastEm freezes** on its next transmit. Run `./blastem-serial stop` and start again. Quitting and restarting e4thcom is safe.
- **Output sent while e4thcom is not attached queues up** and appears when it attaches again.
- **Only controller port 2** carries the serial port in BlastEm, and only one port can at a time.
- Logs for the emulator side: `/tmp/blastforth-emu/blastem.log` and `socat.log`.
