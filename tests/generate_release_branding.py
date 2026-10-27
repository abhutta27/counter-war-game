from pathlib import Path
import struct

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "branding"


def make_splash() -> None:
    width, height = 1600, 900
    splash = Image.new("RGB", (width, height))
    pixels = splash.load()
    top = (7, 13, 18)
    bottom = (21, 25, 29)
    for y in range(height):
        ratio = y / (height - 1)
        color = tuple(round(a + (b - a) * ratio) for a, b in zip(top, bottom))
        for x in range(width):
            pixels[x, y] = color

    logo = Image.open(BRAND / "counter_war_logo.png").convert("RGBA")
    logo.thumbnail((1240, 470), Image.Resampling.LANCZOS)
    x = (width - logo.width) // 2
    y = (height - logo.height) // 2
    splash.paste(logo, (x, y), logo)
    splash.save(BRAND / "counter_war_splash.png", optimize=True)


def make_icon() -> None:
    sizes = (16, 32, 48, 64, 128, 256)
    payloads = [(BRAND / f"cw_mark_{size}.png").read_bytes() for size in sizes]
    header = struct.pack("<HHH", 0, 1, len(sizes))
    offset = 6 + 16 * len(sizes)
    entries = []
    for size, payload in zip(sizes, payloads):
        dimension = 0 if size == 256 else size
        entries.append(
            struct.pack("<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(payload), offset)
        )
        offset += len(payload)
    (BRAND / "counter_war.ico").write_bytes(header + b"".join(entries) + b"".join(payloads))


if __name__ == "__main__":
    make_splash()
    make_icon()
    print("[ReleaseBranding] PASS: 1600x900 splash and 16/32/48/64/128/256 ICO generated")
