"""Capture actual Ratatui frames from a pseudoterminal as PNG files.

Development dependencies: pyte and Pillow. Build the frontend first with
`cargo build --manifest-path frontend/Cargo.toml`.
"""

import codecs
import fcntl
import os
from pathlib import Path
import select
import struct
import subprocess
import termios
import tempfile
import time

import pyte
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "frontend/target/debug/terminal-launch-sim"
OUT = ROOT / "docs/screenshots"
COLS, ROWS = 106, 32


def drain(master, stream, seconds):
    decoder = codecs.getincrementaldecoder("utf-8")("replace")
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        if select.select([master], [], [], 0.05)[0]:
            try:
                data = os.read(master, 65536)
            except OSError:
                return
            if not data:
                return
            stream.feed(decoder.decode(data))


def capture(mode, commands, destination):
    master, slave = os.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    profile_dir = tempfile.TemporaryDirectory(prefix="tls-screenshot-")
    process = subprocess.Popen(
        [str(BIN)],
        cwd=ROOT / "frontend",
        env={**os.environ, "TERM": "xterm-256color",
             "TLS_PROFILE_PATH": str(Path(profile_dir.name) / "profile.json")},
        stdin=slave,
        stdout=slave,
        stderr=slave,
        start_new_session=True,
    )
    os.close(slave)
    screen = pyte.Screen(COLS, ROWS)
    stream = pyte.Stream(screen)
    try:
        drain(master, stream, 2.0)
        os.write(master, mode.encode())
        drain(master, stream, 0.6)
        for command in commands:
            os.write(master, command.encode() + b"\r")
            drain(master, stream, 0.5)
        draw(screen, destination)
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        os.close(master)
        profile_dir.cleanup()


def draw(screen, destination):
    font_path = subprocess.check_output(
        ["fc-match", "-f", "%{file}", "DejaVu Sans Mono"], text=True
    ).strip()
    font = ImageFont.truetype(font_path, 18)
    cell_width = round(font.getlength("M"))
    cell_height = 26
    pad = 24
    background = (15, 20, 18)
    image = Image.new(
        "RGB", (COLS * cell_width + 2 * pad, ROWS * cell_height + 2 * pad), background
    )
    draw = ImageDraw.Draw(image)
    palette = {
        "default": (215, 221, 208),
        "yellow": (255, 196, 94),
        "green": (124, 224, 156),
        "white": (240, 240, 235),
        "black": background,
        "red": (255, 116, 112),
        "blue": (117, 174, 255),
        "cyan": (112, 222, 224),
        "magenta": (216, 146, 238),
    }
    for row in range(ROWS):
        for col in range(COLS):
            cell = screen.buffer[row][col]
            if cell.data == " ":
                continue
            color = palette.get(cell.fg, palette["default"])
            draw.text(
                (pad + col * cell_width, pad + row * cell_height),
                cell.data,
                font=font,
                fill=color,
            )
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, optimize=True)


if __name__ == "__main__":
    if not BIN.exists():
        raise SystemExit("Build frontend first: cargo build --manifest-path frontend/Cargo.toml")
    capture("1", ["check", "launch", "wait 30"], OUT / "space.png")
    capture("2", ["assign orion", "assign vega", "wait 3"], OUT / "central.png")
    capture("2", ["assign orion", "assign vega", "wait 10", "research filter", "central 43", "tech"],
            OUT / "research.png")
    print("Captured space.png, central.png and research.png")
