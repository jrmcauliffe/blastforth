#!/usr/bin/env python3
"""Run BlastEm's native debugger (-d) on a ROM, send debugger commands, print replies.

usage: bdbg.py [-r ROM] [-w SECONDS] COMMAND [COMMAND ...]

Each COMMAND is one debugger line (quote it). Replies are read until the
output has been quiet for a moment (at most SECONDS, default 2.0 per command).
Commands that resume execution (c, frames N) only reply when the debugger is
re-entered, so give them a breakpoint or raise -w. BlastEm is started on a pty,
and only the process group started here is killed on exit.
"""
import argparse, os, pty, select, signal, subprocess, sys, time

BLASTEM = os.environ.get("BLASTEM", "/home/aigui/bin/blastem64/blastem")
NOISE = ("Window created", "SDL2 Render", "Initialized", "Added ", "IO port",
         "Product ID", "SHA1", "Not found in ROM DB", "width:")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-r", "--rom", default="hello.bin")
    ap.add_argument("-w", "--wait", type=float, default=2.0)
    ap.add_argument("commands", nargs="+")
    a = ap.parse_args()

    master, slave = pty.openpty()
    proc = subprocess.Popen([BLASTEM, a.rom, "-d"], stdin=slave, stdout=slave,
                            stderr=slave, start_new_session=True)
    os.close(slave)

    def read(limit):
        out, end = b"", time.time() + limit
        while time.time() < end:
            if select.select([master], [], [], 0.2)[0]:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                out += chunk
                end = min(end, time.time() + 0.6)
        return out.decode(errors="replace")

    try:
        read(5)  # startup banner and first prompt
        for cmd in a.commands:
            os.write(master, (cmd + "\n").encode())
            reply = read(a.wait)
            lines = [l for l in reply.splitlines()
                     if l.strip() and l.strip() not in (">", cmd.strip())
                     and not l.startswith(NOISE)]
            print(f"> {cmd}")
            print("\n".join(lines))
    finally:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()


if __name__ == "__main__":
    main()
