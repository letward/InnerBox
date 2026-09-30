"""InnerBox - procedural asset generator.

Produces every PNG and WAV the game ships with. Re-run with:
    python tools/gen_assets.py

All art is drawn pixel by pixel from a shared palette so the game reads as one
hand-made set. Everything lands in assets/ (textures) and assets/audio/.
"""

import json
import math
import os
import random
import struct
import wave

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets")
AUD = os.path.join(TEX, "audio")
os.makedirs(TEX, exist_ok=True)
os.makedirs(AUD, exist_ok=True)

random.seed(0x1A5E)

# --------------------------------------------------------------------------
# palette
# --------------------------------------------------------------------------
P = {
    "black":   "#0d0a14",
    "deep":    "#1b1430",
    "night":   "#2e2145",
    "violet":  "#6b4f9e",
    "violet2": "#8f74c4",
    "blue":    "#3a6ea5",
    "blue2":   "#2a4f7c",
    "sky":     "#6fb3d2",
    "light":   "#a8d8e8",
    "white":   "#ffffff",
    "g1":      "#2f6b3a",
    "g2":      "#46a04f",
    "g3":      "#7fd07a",
    "b1":      "#5a3d24",
    "b2":      "#8a5c33",
    "b3":      "#b98a54",
    "b4":      "#d8b184",
    "s1":      "#3b3b4a",
    "s2":      "#5c5c6e",
    "s3":      "#8b8b9e",
    "s4":      "#b7b7c8",
    "r1":      "#6b3220",
    "r2":      "#a34a26",
    "r3":      "#d97b3f",
    "gold":    "#f2c14e",
    "cream":   "#f6e7c8",
    "red":     "#c0392b",
    "pink":    "#e88ba0",
    "m1":      "#d6d6e4",
    "m2":      "#b0b0c6",
    "skin":    "#e8be96",
    "skin2":   "#c99a72",
    "ash":     "#cfc4b4",
}


def col(name):
    v = P[name]
    return tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))


def rr_of(dx, dy):
    return math.hypot(dx, dy)


PAL = {k: col(k) for k in P}

# --------------------------------------------------------------------------
# tiny pixel helpers
# --------------------------------------------------------------------------


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(d, x, y, c):
    """Plots one pixel. `d` is either an ImageDraw or a plot(x, y, color)."""
    if hasattr(d, "point"):
        d.point((x, y), fill=c)
    else:
        d(x, y, c)


def rect(d, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(d, xx, yy, c)


def line(d, x0, y0, x1, y1, c):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        px(d, x0, y0, c)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def disc(d, cx, cy, r, c):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px(d, x, y, c)


def ellipse(d, cx, cy, rx, ry, c):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                px(d, x, y, c)


def noise_speckle(d, x, y, w, h, c, n, rng):
    for _ in range(n):
        px(d, rng.randint(x, x + w - 1), rng.randint(y, y + h - 1), c)


# --------------------------------------------------------------------------
# tiles - 16x16, atlas 16 columns x 8 rows
# --------------------------------------------------------------------------
TS = 16
COLS = 16

TILE_ORDER = []


def tile_sheet():
    rng = random.Random(99)
    sheet = new(TS * COLS, TS * 8)
    d = ImageDraw.Draw(sheet)
    TILE_ORDER.clear()

    def add(name, fn):
        idx = len(TILE_ORDER)
        TILE_ORDER.append(name)
        ox, oy = (idx % COLS) * TS, (idx // COLS) * TS

        def sub(x, y, c):
            px(d, ox + x, oy + y, c)

        def srect(x, y, w, h, c):
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    sub(xx, yy, c)

        fn(sub, srect, rng)

    # ---- ground -------------------------------------------------------
    def grass(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["g1"])
        noise_speckle(d, 0, 0, 1, 1, PAL["g1"], 0, rng)
        for _ in range(26):
            sub(rng.randrange(16), rng.randrange(16), PAL["g2"])
        for _ in range(10):
            sub(rng.randrange(16), rng.randrange(16), PAL["g3"])

    add("grass", grass)

    def grass_flowers(sub, srect, rng):
        grass(sub, srect, rng)
        for _ in range(7):
            x, y = rng.randrange(2, 14), rng.randrange(2, 14)
            sub(x, y, PAL["cream"])
            sub(x, y + 1, PAL["gold"])

    add("grass_flowers", grass_flowers)

    def grass_dark(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["g1"])
        for _ in range(22):
            sub(rng.randrange(16), rng.randrange(16), PAL["night"])
        for _ in range(8):
            sub(rng.randrange(16), rng.randrange(16), PAL["g2"])

    add("grass_dark", grass_dark)

    def dirt(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["b1"])
        for _ in range(30):
            sub(rng.randrange(16), rng.randrange(16), PAL["b2"])
        for _ in range(10):
            sub(rng.randrange(16), rng.randrange(16), PAL["black"])

    add("dirt", dirt)

    def path(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["b3"])
        for _ in range(34):
            sub(rng.randrange(16), rng.randrange(16), PAL["b2"])
        for _ in range(8):
            sub(rng.randrange(16), rng.randrange(16), PAL["b4"])

    add("path", path)

    def stone_floor(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s2"])
        for y in (0, 8):
            srect(0, y, 16, 1, PAL["s1"])
        for x in (0, 8):
            srect(x, 0, 1, 16, PAL["s1"])
        for _ in range(12):
            sub(rng.randrange(16), rng.randrange(16), PAL["s1"])
        for _ in range(6):
            sub(rng.randrange(16), rng.randrange(16), PAL["s3"])

    add("stone_floor", stone_floor)

    def brick_floor(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["r1"])
        for y in range(0, 16, 4):
            srect(0, y, 16, 1, PAL["black"])
        for y in range(0, 16, 4):
            off = 0 if (y // 4) % 2 == 0 else 4
            for x in range(off, 16, 8):
                srect(x, y, 1, 4, PAL["black"])
        for _ in range(10):
            sub(rng.randrange(16), rng.randrange(16), PAL["r2"])

    add("brick_floor", brick_floor)

    def wood_floor(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["b2"])
        for y in range(0, 16, 4):
            srect(0, y, 16, 1, PAL["b1"])
        for _ in range(14):
            sub(rng.randrange(16), rng.randrange(16), PAL["b3"])

    add("wood_floor", wood_floor)

    def rug(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["red"])
        srect(1, 1, 14, 14, PAL["r1"])
        for i in range(3):
            srect(2 + i * 4, 2, 2, 12, PAL["gold"])
        srect(2, 7, 12, 2, PAL["gold"])

    add("rug", rug)

    def marble_floor(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["m1"])
        for x in range(0, 16, 8):
            srect(x, 0, 1, 16, PAL["m2"])
        for _ in range(10):
            sub(rng.randrange(16), rng.randrange(16), PAL["m2"])

    add("marble_floor", marble_floor)

    def sand(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["b4"])
        for _ in range(24):
            sub(rng.randrange(16), rng.randrange(16), PAL["b3"])

    add("sand", sand)

    def void(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["black"])
        for _ in range(8):
            sub(rng.randrange(16), rng.randrange(16), PAL["deep"])

    add("void", void)

    # ---- water (static tile, animation lives in water.png) -------------
    def water(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["blue"])
        for _ in range(10):
            sub(rng.randrange(16), rng.randrange(16), PAL["blue2"])
        srect(0, 0, 16, 1, PAL["sky"])

    add("water", water)

    def water_deep(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["blue2"])
        for _ in range(12):
            sub(rng.randrange(16), rng.randrange(16), PAL["deep"])

    add("water_deep", water_deep)

    def lava(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["r2"])
        for _ in range(18):
            sub(rng.randrange(16), rng.randrange(16), PAL["r3"])
        for _ in range(5):
            sub(rng.randrange(16), rng.randrange(16), PAL["gold"])

    add("lava", lava)

    def bridge(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["b2"])
        for x in range(0, 16, 4):
            srect(x, 0, 1, 16, PAL["b1"])
        for _ in range(10):
            sub(rng.randrange(16), rng.randrange(16), PAL["b3"])

    add("bridge", bridge)

    # ---- walls --------------------------------------------------------
    def stone_wall(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s1"])
        for row in range(4):
            y = row * 4
            off = 0 if row % 2 == 0 else 4
            for x in range(-4, 16, 8):
                xx = x + off
                for yy in range(y, y + 3):
                    for xxx in range(xx, xx + 7):
                        if 0 <= xxx < 16:
                            sub(xxx, yy, PAL["s2"])
                for xxx in range(xx, xx + 7):
                    if 0 <= xxx < 16:
                        sub(xxx, y, PAL["s3"])

    add("stone_wall", stone_wall)

    def stone_wall_top(sub, srect, rng):
        stone_wall(sub, srect, rng)
        srect(0, 0, 16, 2, PAL["s3"])

    add("stone_wall_top", stone_wall_top)

    def wood_wall(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["b3"])
        for x in range(0, 16, 4):
            srect(x, 0, 1, 16, PAL["b2"])
        for _ in range(10):
            sub(rng.randrange(16), rng.randrange(16), PAL["b4"])

    add("wood_wall", wood_wall)

    def roof(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["r1"])
        for row in range(4):
            y = row * 4
            off = 0 if row % 2 == 0 else 3
            for x in range(-3, 16, 6):
                for yy in range(y, y + 3):
                    for xxx in range(x + off, x + off + 5):
                        if 0 <= xxx < 16:
                            sub(xxx, yy, PAL["r2"])
                srect(max(0, x + off), y, min(5, 16 - max(0, x + off)), 1, PAL["r3"])

    add("roof", roof)

    def marble_wall(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["m2"])
        for y in range(0, 16, 8):
            srect(0, y, 16, 1, PAL["s1"])
            off = 0 if (y // 8) % 2 == 0 else 4
            for x in range(off, 16, 8):
                if x < 16:
                    srect(x, y, 1, 8, PAL["s1"])
        srect(0, 0, 16, 2, PAL["m1"])

    add("marble_wall", marble_wall)

    def moss_stone(sub, srect, rng):
        stone_wall(sub, srect, rng)
        for _ in range(14):
            sub(rng.randrange(16), rng.randrange(16), PAL["g1"])

    add("moss_stone", moss_stone)

    def gold_trim(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["night"])
        srect(0, 6, 16, 4, PAL["gold"])
        srect(0, 7, 16, 2, PAL["b4"])
        for x in range(0, 16, 4):
            srect(x, 4, 2, 2, PAL["gold"])
            srect(x, 10, 2, 2, PAL["gold"])

    add("gold_trim", gold_trim)

    def window_wall(sub, srect, rng):
        wood_wall(sub, srect, rng)
        srect(3, 4, 10, 9, PAL["b1"])
        srect(4, 5, 8, 7, PAL["sky"])
        srect(4, 5, 8, 2, PAL["light"])
        srect(7, 5, 1, 7, PAL["b1"])

    add("window_wall", window_wall)

    def house_door(sub, srect, rng):
        wood_wall(sub, srect, rng)
        srect(3, 3, 10, 13, PAL["b1"])
        srect(4, 4, 8, 12, PAL["b2"])
        srect(4, 9, 8, 1, PAL["b1"])
        srect(9, 8, 1, 1, PAL["gold"])

    add("house_door", house_door)

    def fence(sub, srect, rng):
        for x in (2, 9):
            srect(x, 2, 3, 13, PAL["b2"])
            srect(x, 2, 3, 1, PAL["b4"])
        srect(0, 6, 16, 2, PAL["b2"])
        srect(0, 6, 16, 1, PAL["b4"])

    add("fence", fence)

    def pillar(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s1"])
        srect(4, 1, 8, 14, PAL["m1"])
        srect(4, 1, 2, 14, PAL["white"])
        srect(10, 1, 2, 14, PAL["m2"])
        srect(3, 0, 10, 2, PAL["s3"])
        srect(3, 14, 10, 2, PAL["s3"])

    add("pillar", pillar)

    def grate(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s1"])
        for x in range(0, 16, 4):
            srect(x, 0, 2, 16, PAL["s2"])
        for y in range(0, 16, 4):
            srect(0, y, 16, 1, PAL["black"])

    add("grate", grate)

    def cobweb(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s1"])
        for i in range(0, 16, 3):
            sub(i, i, PAL["s3"])
            sub(15 - i, i, PAL["s3"])
        for i in range(1, 8):
            sub(i, i, PAL["s3"])
            sub(15 - i, i, PAL["s3"])

    add("cobweb", cobweb)

    # ---- props --------------------------------------------------------
    def tree(sub, srect, rng):
        srect(6, 10, 4, 6, PAL["b1"])
        srect(7, 10, 1, 6, PAL["b2"])
        disc(sub, 8, 7, 6.4, PAL["g1"])
        disc(sub, 6, 9, 4.2, PAL["g1"])
        disc(sub, 10, 9, 4.2, PAL["g1"])
        disc(sub, 8, 5, 4.6, PAL["g2"])
        disc(sub, 6, 7, 3.0, PAL["g2"])
        disc(sub, 10, 7, 3.0, PAL["g2"])
        disc(sub, 7, 4, 2.6, PAL["g3"])
        disc(sub, 10, 5, 2.0, PAL["g3"])

    add("tree", tree)

    def bush(sub, srect, rng):
        disc(sub, 8, 10, 5.6, PAL["g1"])
        disc(sub, 5, 12, 3.4, PAL["g1"])
        disc(sub, 11, 12, 3.4, PAL["g1"])
        disc(sub, 7, 8, 3.2, PAL["g2"])
        disc(sub, 10, 10, 2.6, PAL["g2"])

    add("bush", bush)

    def rock(sub, srect, rng):
        disc(sub, 8, 10, 6.0, PAL["s2"])
        disc(sub, 6, 8, 3.6, PAL["s3"])
        srect(6, 12, 5, 3, PAL["s1"])

    add("rock", rock)

    def rubble(sub, srect, rng):
        for _ in range(7):
            x, y = rng.randrange(1, 13), rng.randrange(3, 14)
            srect(x, y, rng.randrange(2, 4), 2, PAL["s2"])
            srect(x, y, 2, 1, PAL["s3"])

    add("rubble", rubble)

    def crate(sub, srect, rng):
        srect(1, 2, 14, 13, PAL["b1"])
        srect(2, 3, 12, 11, PAL["b2"])
        line(sub, 2, 3, 13, 13, PAL["b1"])
        line(sub, 13, 3, 2, 13, PAL["b1"])
        srect(2, 3, 12, 1, PAL["b4"])

    add("crate", crate)

    def barrel(sub, srect, rng):
        srect(3, 1, 10, 14, PAL["b1"])
        srect(4, 2, 8, 12, PAL["b2"])
        srect(4, 4, 8, 1, PAL["s3"])
        srect(4, 10, 8, 1, PAL["s3"])
        srect(4, 2, 1, 12, PAL["b3"])

    add("barrel", barrel)

    def chest(sub, srect, rng):
        srect(1, 5, 14, 10, PAL["b1"])
        srect(2, 6, 12, 8, PAL["b2"])
        srect(1, 5, 14, 4, PAL["b3"])
        srect(7, 7, 2, 5, PAL["gold"])

    add("chest_closed", chest)

    def chest_open(sub, srect, rng):
        srect(1, 7, 14, 8, PAL["b1"])
        srect(2, 8, 12, 6, PAL["b2"])
        srect(1, 2, 14, 4, PAL["b3"])
        srect(2, 8, 12, 2, PAL["gold"])

    add("chest_open", chest_open)

    def stairs_down(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s1"])
        for i in range(4):
            srect(1, 1 + i * 4, 14, 3, PAL["s2"])
            srect(1, 1 + i * 4, 14, 1, PAL["s3"])

    add("stairs_down", stairs_down)

    def stairs_up(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s1"])
        for i in range(4):
            shade = (PAL["s2"][0] - i * 10, PAL["s2"][1] - i * 10, PAL["s2"][2] - i * 8)
            srect(1, 1 + i * 4, 14, 3, shade)

    add("stairs_up", stairs_up)

    def brazier(sub, srect, rng):
        srect(5, 9, 6, 6, PAL["s2"])
        srect(4, 8, 8, 2, PAL["s3"])
        srect(6, 14, 4, 2, PAL["s1"])

    add("brazier_off", brazier)

    def brazier_on(sub, srect, rng):
        brazier(sub, srect, rng)
        disc(sub, 8, 6, 3.6, PAL["r3"])
        disc(sub, 8, 6, 2.2, PAL["gold"])
        sub(8, 3, PAL["r3"])
        sub(7, 4, PAL["gold"])
        sub(9, 4, PAL["gold"])

    add("brazier_on", brazier_on)

    def lantern(sub, srect, rng):
        srect(6, 2, 4, 2, PAL["s1"])
        srect(5, 4, 6, 7, PAL["s2"])
        srect(6, 5, 4, 5, PAL["deep"])
        srect(6, 13, 4, 2, PAL["s1"])

    add("lantern_off", lantern)

    def lantern_on(sub, srect, rng):
        lantern(sub, srect, rng)
        srect(6, 5, 4, 5, PAL["gold"])
        srect(7, 6, 2, 3, PAL["white"])

    add("lantern_on", lantern_on)

    def crystal(sub, srect, rng):
        line(sub, 8, 2, 4, 12, PAL["violet"])
        line(sub, 8, 2, 11, 12, PAL["violet"])
        srect(5, 9, 6, 5, PAL["violet"])
        line(sub, 8, 2, 8, 13, PAL["violet2"])
        srect(6, 4, 1, 6, PAL["light"])

    add("crystal", crystal)

    def core_glow(sub, srect, rng):
        disc(sub, 8, 8, 6.6, PAL["violet"])
        disc(sub, 8, 8, 4.6, PAL["violet2"])
        disc(sub, 8, 8, 2.8, PAL["light"])
        disc(sub, 8, 8, 1.4, PAL["white"])

    add("core_glow", core_glow)

    def flower_red(sub, srect, rng):
        grass(sub, srect, rng)
        for x, y in ((4, 5), (11, 9), (7, 12)):
            sub(x, y, PAL["red"])
            sub(x, y - 1, PAL["pink"])

    add("flower_red", flower_red)

    def grass_tuft(sub, srect, rng):
        grass(sub, srect, rng)
        for x, y in ((5, 11), (8, 9), (11, 12)):
            line(sub, x, y + 2, x, y, PAL["g3"])

    add("grass_tuft", grass_tuft)

    def mushroom(sub, srect, rng):
        srect(7, 9, 2, 5, PAL["cream"])
        disc(sub, 8, 8, 3.6, PAL["red"])
        sub(7, 7, PAL["white"])
        sub(10, 8, PAL["white"])

    add("mushroom", mushroom)

    def sign(sub, srect, rng):
        srect(7, 10, 2, 5, PAL["b1"])
        srect(3, 3, 10, 8, PAL["b2"])
        srect(3, 3, 10, 1, PAL["b4"])
        for y in (6, 8):
            srect(5, y, 6, 1, PAL["b1"])

    add("sign", sign)

    def hole(sub, srect, rng):
        disc(sub, 8, 8, 6.4, PAL["black"])
        disc(sub, 8, 8, 5.0, PAL["deep"])

    add("hole", hole)

    def arch(sub, srect, rng):
        srect(0, 0, 16, 16, PAL["s1"])
        for y in range(0, 16):
            if 4 <= y:
                srect(4, y, 8, 1, PAL["black"])
        srect(0, 0, 4, 16, PAL["s2"])
        srect(12, 0, 4, 16, PAL["s2"])
        srect(0, 0, 16, 2, PAL["s3"])
        srect(4, 2, 8, 2, PAL["s3"])

    add("arch", arch)

    sheet.save(os.path.join(TEX, "tiles.png"))
    with open(os.path.join(TEX, "tiles_index.json"), "w") as f:
        json.dump({n: i for i, n in enumerate(TILE_ORDER)}, f, indent=1)

    # keep the Godot-side lookup table in sync with the atlas order
    gd = ['class_name TileIndex', 'extends RefCounted', '',
          '## GENERATED by tools/gen_assets.py - do not edit by hand.',
          '',
          'const TILE_SIZE := 16',
          'const COLUMNS := 16',
          'const SHEET_PATH := "res://assets/tiles.png"',
          'const WATER_SHEET := "res://assets/water.png"',
          '',
          'const INDEX := {']
    for i, n in enumerate(TILE_ORDER):
        gd.append('\t"%s": %d,' % (n, i))
    gd += ['}', '',
           '',
           'static func id(name: String) -> int:',
           '\treturn int(INDEX.get(name, 0))',
           '',
           '',
           'static func has(name: String) -> bool:',
           '\treturn INDEX.has(name)', '']
    gd_path = os.path.join(ROOT, "src", "data", "tile_index.gd")
    os.makedirs(os.path.dirname(gd_path), exist_ok=True)
    with open(gd_path, "w") as f:
        f.write("\n".join(gd))
    print("tiles.png", len(TILE_ORDER), "tiles ->", gd_path)


def water_sheet():
    rng = random.Random(7)
    sheet = new(TS * 4, TS)
    d = ImageDraw.Draw(sheet)
    for f in range(4):
        ox = f * TS
        for y in range(TS):
            for x in range(TS):
                d.point((ox + x, y), fill=PAL["blue"])
        for _ in range(26):
            x, y = rng.randrange(TS), rng.randrange(TS)
            d.point((ox + x, y), fill=PAL["blue2"])
        for x in range(0, TS, 6):
            yy = (x // 6 + f * 2) % TS
            d.point((ox + x, yy), fill=PAL["sky"])
            d.point((ox + x + 1, yy), fill=PAL["sky"])
    sheet.save(os.path.join(TEX, "water.png"))


# --------------------------------------------------------------------------
# characters - 16x24 frames
# --------------------------------------------------------------------------
CW, CH = 16, 24


def humanoid(frame, pal, facing="down", pose="idle", scale=1.0):
    d = ImageDraw.Draw(frame)
    skin = pal.get("skin", PAL["skin"])
    skin2 = pal.get("skin2", PAL["skin2"])
    hair = pal.get("hair", PAL["b1"])
    shirt = pal.get("shirt", PAL["blue"])
    shirt2 = pal.get("shirt2", PAL["blue2"])
    pants = pal.get("pants", PAL["s1"])
    boot = pal.get("boot", PAL["black"])
    off = 1 if scale < 0.95 else 0
    dy = -1 if pose in ("walk1", "walk2") else 0
    dy += off

    def R(x, y, w, h, c):
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)

    def S(x, y, c):
        d.point((x, y), fill=c)

    # legs
    lt = 18 + dy
    if pose == "walk1":
        R(5, lt, 3, 5, pants)
        R(8, lt - 1, 3, 5, pants)
        R(5, lt + 4, 3, 1, boot)
        R(8, lt + 3, 3, 1, boot)
    elif pose == "walk2":
        R(5, lt - 1, 3, 5, pants)
        R(8, lt, 3, 5, pants)
        R(5, lt + 3, 3, 1, boot)
        R(8, lt + 4, 3, 1, boot)
    else:
        R(5, lt, 3, 5, pants)
        R(8, lt, 3, 5, pants)
        R(5, lt + 4, 3, 1, boot)
        R(8, lt + 4, 3, 1, boot)
    R(5, lt, 1, 4, pants if pants[0] < 200 else PAL["s1"])

    # torso
    tt = 12 + dy
    R(5, tt, 6, 6, shirt)
    R(5, tt, 1, 6, shirt2)
    R(5, tt + 5, 6, 1, shirt2)

    # arms
    at = 12 + dy
    swing = 0
    if pose == "walk1":
        swing = 1
    elif pose == "walk2":
        swing = -1
    la = at + swing
    ra = at - swing
    if pose in ("atk1", "atk2"):
        R(4, at, 2, 5, shirt)
        if facing == "right":
            R(11, at - 1, 2, 4, shirt)
            R(12, at - 1, 3, 3, skin)
        elif facing == "left":
            R(11, at, 2, 5, shirt)
            R(6, at - 1, 3, 3, skin)
        else:
            R(4, at, 2, 5, shirt)
            R(11, at, 2, 5, shirt)
    else:
        R(4, la, 2, 5, shirt)
        R(11, ra, 2, 5, shirt)
        R(4, la + 4, 2, 1, skin)
        R(11, ra + 4, 2, 1, skin)

    # head
    ht = 3 + dy
    R(5, ht, 6, 9, skin)
    R(5, ht + 7, 6, 2, skin2)
    # hair
    if facing == "up":
        R(4, ht - 1, 8, 8, hair)
    elif facing == "down":
        R(4, ht - 1, 8, 3, hair)
        R(4, ht + 2, 1, 3, hair)
        R(11, ht + 2, 1, 3, hair)
    else:
        back = 4 if facing == "right" else 11
        front = 11 if facing == "right" else 4
        R(4, ht - 1, 8, 3, hair)
        R(back, ht, 2, 9, hair)
        S(front, ht + 2, hair)
        S(front, ht + 3, hair)
    # face
    eye = PAL["black"]
    if facing == "down":
        S(6, ht + 5, eye)
        S(9, ht + 5, eye)
        S(7, ht + 7, skin2)
        S(8, ht + 7, skin2)
    elif facing == "left":
        S(6, ht + 5, eye)
        S(7, ht + 7, skin2)
    elif facing == "right":
        S(9, ht + 5, eye)
        S(8, ht + 7, skin2)
    return frame


def sword(d, facing, dy):
    steel = PAL["s4"]
    steel2 = PAL["white"]
    hilt = PAL["b1"]
    if facing == "right":
        d.rectangle([14, 13 + dy, 15, 17 + dy], fill=steel)
        d.rectangle([14, 13 + dy, 14, 16 + dy], fill=steel2)
        d.rectangle([12, 14 + dy, 13, 15 + dy], fill=hilt)
    elif facing == "left":
        d.rectangle([0, 13 + dy, 1, 17 + dy], fill=steel)
        d.rectangle([1, 13 + dy, 1, 16 + dy], fill=steel2)
        d.rectangle([2, 14 + dy, 3, 15 + dy], fill=hilt)
    elif facing == "down":
        d.rectangle([8, 17 + dy, 9, 21 + dy], fill=steel)
        d.rectangle([8, 17 + dy, 8, 20 + dy], fill=steel2)
        d.rectangle([7, 16 + dy, 10, 17 + dy], fill=hilt)
    else:
        d.rectangle([7, 0 + dy, 8, 4 + dy], fill=steel)
        d.rectangle([7, 0 + dy, 7, 3 + dy], fill=steel2)
        d.rectangle([6, 4 + dy, 9, 5 + dy], fill=hilt)


def player_sheet():
    faces = ["down", "up", "left", "right"]
    poses = ["idle", "walk1", "walk2", "atk1", "atk2"]
    sheet = new(CW * len(poses), CH * len(faces))
    pal = dict(hair=PAL["b3"], shirt=PAL["blue"], shirt2=PAL["blue2"],
               pants=PAL["s1"], boot=PAL["black"], skin=PAL["skin"], skin2=PAL["skin2"])
    for r, facing in enumerate(faces):
        for c, pose in enumerate(poses):
            fr = new(CW, CH)
            humanoid(fr, pal, facing, pose)
            if pose in ("atk1", "atk2"):
                d = ImageDraw.Draw(fr)
                if pose == "atk1":
                    d.line([0, 0, 0, 0], fill=(0, 0, 0, 0))
                sword(d, facing, 1 if pose == "atk1" else -1)
                if pose == "atk2":
                    for y in range(CH):
                        for x in range(CW):
                            r0, g0, b0, a0 = fr.getpixel((x, y))
                            if a0 and (r0 + g0 + b0) > 380:
                                fr.putpixel((x, y), (r0 + 30, g0 + 30, b0 + 40, a0))
            sheet.paste(fr, (c * CW, r * CH))
    sheet.save(os.path.join(TEX, "player.png"))


def npc_sheet(name, pal, extras=None):
    faces = ["down", "up", "left", "right"]
    poses = ["idle", "walk1", "walk2"]
    sheet = new(CW * 3, CH * 3)
    for r, facing in enumerate(faces[:3]):
        for c, pose in enumerate(poses):
            fr = new(CW, CH)
            humanoid(fr, pal, facing if facing != "right" else "left", pose)
            if extras:
                extras(ImageDraw.Draw(fr), facing, pose)
            sheet.paste(fr, (c * CW, r * CH))
    sheet.save(os.path.join(TEX, name + ".png"))


# --------------------------------------------------------------------------
# enemies
# --------------------------------------------------------------------------
def tick_sheet():
    w, h = 16, 16
    sheet = new(w * 4, h * 2)
    for row in range(2):
        for f in range(4):
            fr = new(w, h)
            d = ImageDraw.Draw(fr)
            bounce = 0 if (f + row) % 2 == 0 else 1
            cx, cy = 8, 8 - bounce
            disc(d, cx, cy, 5.4, PAL["r1"])
            disc(d, cx - 1, cy - 1, 4.0, PAL["r2"])
            disc(d, cx - 2, cy - 2, 2.2, PAL["r3"])
            for lx in (2, 5, 9, 12):
                ly = 13 + (1 if (f + lx) % 2 == 0 else 0)
                d.line([lx, 11, lx - 1, ly], fill=PAL["r1"])
                d.point((lx - 1, ly), fill=PAL["black"])
            d.point((6, 7), fill=PAL["gold"])
            d.point((10, 7), fill=PAL["gold"])
            d.point((6, 7), fill=PAL["black"])
            d.point((10, 7), fill=PAL["black"])
            d.point((6, 8), fill=PAL["gold"])
            d.point((10, 8), fill=PAL["gold"])
            sheet.paste(fr, (f * w, row * h))
    sheet.save(os.path.join(TEX, "rust_tick.png"))


def moth_sheet():
    w, h = 24, 20
    sheet = new(w * 4, h * 2)
    for row in range(2):
        for f in range(4):
            fr = new(w, h)
            d = ImageDraw.Draw(fr)
            flap = [0, 1, 0, 1][(f + row) % 4]
            cx, cy = 12, 10

            def wing(side, y0, y1, reach, thick):
                x_out = cx + side * (4 + reach + flap)
                lo, hi = sorted((cx + side * 3, x_out))
                yy = sorted((y0, y1))
                d.rectangle([lo, yy[0], hi, yy[1]],
                            fill=PAL["night"] if thick else PAL["violet"])
                for k in range(thick):
                    d.rectangle([min(lo, hi) + (0 if side > 0 else k), yy[0] + k,
                                 max(lo, hi) - (0 if side > 0 else k), yy[0] + k],
                                fill=PAL["violet2"])

            for s in (-1, 1):
                wing(s, cy - 4, cy - 1, 5, 3)
                wing(s, cy + 1, cy + 4, 4, 3)
                wing(s, cy - 8, cy - 6, 2, 1)
                wing(s, cy + 6, cy + 8, 2, 1)
            ellipse(d, cx, cy, 3.4, 5.0, PAL["deep"])
            ellipse(d, cx - 1, cy - 1, 2.0, 3.0, PAL["violet2"])
            d.point((cx - 2, cy - 3), fill=PAL["r3"])
            d.point((cx + 1, cy - 3), fill=PAL["r3"])
            for s in (-1, 1):
                d.line([cx + s * 2, cy - 5, cx + s * 4, cy - 8], fill=PAL["night"])
            sheet.paste(fr, (f * w, row * h))
    sheet.save(os.path.join(TEX, "gloom_moth.png"))


def boss_sheet():
    w, h = 48, 48
    sheet = new(w * 3, h * 3)
    for row in range(3):
        for f in range(3):
            fr = new(w, h)
            d = ImageDraw.Draw(fr)
            bob = [0, -2, 0][f]
            cx, cy = 24, 26 + bob
            for s in (-1, 1):
                for i in range(4):
                    d.line([cx + s * (12 + i * 4), cy - 8 + i * 2,
                            cx + s * (14 + i * 5), cy + 10 + i * 3], fill=PAL["r1"], width=4)
                    d.point((cx + s * (14 + i * 5), cy + 11 + i * 3), fill=PAL["r2"])
            disc(d, cx, cy, 17, PAL["r1"])
            disc(d, cx - 2, cy - 2, 13, PAL["r2"])
            disc(d, cx - 4, cy - 4, 7, PAL["r3"])
            disc(d, cx - 4, cy - 4, 3, PAL["gold"])
            disc(d, cx + 6, cy + 6, 4, PAL["r1"])
            d.point((cx - 5, cy - 7), fill=PAL["gold"])
            d.point((cx + 2, cy - 8), fill=PAL["gold"])
            for i in range(5):
                x = cx - 10 + i * 5
                d.line([x, cy + 13, x - 2, cy + 20], fill=PAL["r2"], width=2)
            sheet.paste(fr, (f * w, row * h))
    sheet.save(os.path.join(TEX, "boss.png"))


def bullet_sheet():
    w = h = 12
    sheet = new(w * 4, h)
    for f in range(4):
        fr = new(w, h)
        d = ImageDraw.Draw(fr)
        r = 3 + (f % 2)
        disc(d, 6, 6, r + 1, PAL["r3"])
        disc(d, 6, 6, r - 1, PAL["gold"])
        disc(d, 6, 6, 1, PAL["white"])
        sheet.paste(fr, (f * w, 0))
    sheet.save(os.path.join(TEX, "bullet.png"))


# --------------------------------------------------------------------------
# items / ui / portraits
# --------------------------------------------------------------------------
def items_sheet():
    order = ["salve", "ember", "shard", "key", "gear", "moon", "coin",
             "cog", "charm", "echo", "tick", "moth", "latch",
             "spare", "spare", "heart_f", "heart_h", "heart_e"]
    sheet = new(16 * SHEET_COLS, 16 * SHEET_ROWS)
    d = ImageDraw.Draw(sheet)

    def at(i):
        return ((i % SHEET_COLS) * 16, (i // SHEET_COLS) * 16)

    def sub(i, x, y, c):
        ox, oy = at(i)
        d.point((ox + x, oy + y), fill=c)

    def srect(i, x, y, w, h, c):
        ox, oy = at(i)
        d.rectangle([ox + x, oy + y, ox + x + w - 1, oy + y + h - 1], fill=c)

    # salve bottle: cork, neck, glass, liquid, label highlight
    srect(0, 6, 1, 4, 3, PAL["s3"])
    srect(0, 4, 4, 8, 2, PAL["s2"])
    srect(0, 4, 6, 8, 9, PAL["s4"])
    srect(0, 5, 7, 6, 7, PAL["red"])
    srect(0, 5, 7, 2, 7, PAL["pink"])
    srect(0, 4, 6, 8, 1, PAL["cream"])

    # ember
    ox, oy = at(1)
    for y in range(16):
        for x in range(16):
            dx, dy = x - 8, y - 9
            t = (dx * dx) / 16.0 + (dy * dy) / 28.0
            if t <= 1.0:
                c = PAL["r3"] if t > 0.45 else (PAL["gold"] if t > 0.18 else PAL["white"])
                d.point((ox + x, oy + y), fill=c)
    d.rectangle([ox + 7, oy + 12, ox + 8, oy + 15], fill=PAL["b1"])

    # shard
    ox, oy = at(2)
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 8
            t = (dx * dx) / 25.0 + (dy * dy) / 49.0
            if t <= 1.0:
                c = PAL["violet2"] if t > 0.35 else PAL["light"]
                d.point((ox + x, oy + y), fill=c)
    d.point((ox + 6, oy + 5), fill=PAL["white"])

    # key: bow on top, shaft, teeth
    srect(3, 6, 2, 4, 4, PAL["r3"])
    srect(3, 5, 3, 2, 2, PAL["black"])
    srect(3, 6, 8, 4, 2, PAL["r3"])
    srect(3, 10, 4, 2, 3, PAL["r3"])
    srect(3, 12, 2, 2, 2, PAL["r3"])

    # gear
    ox, oy = at(4)
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 7.5
            ang = math.atan2(dy, dx)
            teeth = 4.6 + (1.0 if math.cos(ang * 8) > 0.25 else -0.2)
            if rr_of(dx, dy) <= teeth:
                d.point((ox + x, oy + y), fill=PAL["r3"] if rr_of(dx, dy) < 4.6 else PAL["r2"])
    d.point((ox + 7, oy + 7), fill=PAL["black"])
    d.point((ox + 8, oy + 7), fill=PAL["black"])

    # paper moon
    ox, oy = at(5)
    disc(d, ox + 8, oy + 8, 6.0, PAL["cream"])
    for y in range(16):
        for x in range(16):
            if ((x - 11) ** 2 + (y - 6) ** 2) < 30:
                d.point((ox + x, oy + y), fill=(0, 0, 0, 0))
    d.point((ox + 6, oy + 10), fill=PAL["gold"])

    # coin
    ox, oy = at(6)
    disc(d, ox + 8, oy + 8, 6.0, PAL["gold"])
    disc(d, ox + 8, oy + 8, 4.2, PAL["r3"])
    d.point((ox + 8, oy + 8), fill=PAL["gold"])
    d.point((ox + 6, oy + 6), fill=PAL["cream"])

    # brass cog
    ox, oy = at(7)
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 7.5
            ang = math.atan2(dy, dx)
            teeth = 5.0 + (1.2 if math.cos(ang * 6) > 0.3 else -0.4)
            if rr_of(dx, dy) <= teeth:
                d.point((ox + x, oy + y), fill=PAL["gold"] if rr_of(dx, dy) < 4.2 else PAL["b3"])
    d.point((ox + 7, oy + 7), fill=PAL["s1"])
    d.point((ox + 8, oy + 7), fill=PAL["s1"])

    # paper charm (a folded star)
    ox, oy = at(8)
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 7.5
            ang = math.atan2(dy, dx)
            star = 6.2 * (0.62 + 0.38 * abs(math.cos(ang * 5.0)))
            if rr_of(dx, dy) <= star:
                d.point((ox + x, oy + y), fill=PAL["cream"] if rr_of(dx, dy) < star * 0.6 else PAL["b4"])
    d.point((ox + 7, oy + 7), fill=PAL["gold"])
    d.point((ox + 8, oy + 8), fill=PAL["gold"])

    # memory echo (a sound ripple)
    ox, oy = at(9)
    for r, c in ((6.0, PAL["violet"]), (4.0, PAL["violet2"]), (2.0, PAL["light"])):
        for y in range(16):
            for x in range(16):
                d0 = abs(rr_of(x - 7.5, y - 7.5) - r)
                if d0 < 0.8:
                    d.point((ox + x, oy + y), fill=c)

    # bestiary: rust tick
    ox, oy = at(10)
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 8.5
            if rr_of(dx, dy * 0.85) <= 5.4:
                d.point((ox + x, oy + y), fill=PAL["r2"] if rr_of(dx, dy * 0.85) > 3.4 else PAL["r3"])
    for lx in (3, 6, 9, 12):
        d.point((ox + lx, oy + 14), fill=PAL["r1"])
        d.point((ox + lx, oy + 15), fill=PAL["black"])
    d.point((ox + 6, oy + 7), fill=PAL["gold"])
    d.point((ox + 9, oy + 7), fill=PAL["gold"])

    # bestiary: gloom moth
    ox, oy = at(11)
    for s in (-1, 1):
        for i in range(6):
            if 4 + i < 12:
                d.point((ox + 7 + s * (4 + i), oy + 6 - i // 2), fill=PAL["violet"] if i < 3 else PAL["night"])
                d.point((ox + 7 + s * (4 + i), oy + 10 + i // 2), fill=PAL["violet"] if i < 3 else PAL["night"])
    for y in range(16):
        for x in range(16):
            if rr_of(x - 7.5, (y - 8.0) * 1.7) <= 2.6:
                d.point((ox + x, oy + y), fill=PAL["deep"])
    d.point((ox + 6, oy + 7), fill=PAL["r3"])
    d.point((ox + 9, oy + 7), fill=PAL["r3"])

    # the latch (story symbol)
    ox, oy = at(12)
    d.rectangle([ox + 3, oy + 5, ox + 12, oy + 10], fill=PAL["b2"])
    d.rectangle([ox + 4, oy + 6, ox + 11, oy + 9], fill=PAL["b3"])
    d.rectangle([ox + 6, oy + 7, ox + 9, oy + 8], fill=PAL["gold"])
    d.rectangle([ox + 3, oy + 3, ox + 12, oy + 4], fill=PAL["r3"])
    d.rectangle([ox + 7, oy + 1, ox + 8, oy + 3], fill=PAL["r3"])

    # hearts (9x9 inside a 16px cell, drawn top-left)
    outline = [(2, 1), (3, 1), (4, 1), (6, 1), (7, 1), (8, 1),
               (1, 2), (2, 2), (3, 2), (6, 2), (7, 2), (8, 2),
               (0, 3), (1, 3), (2, 3), (6, 3), (7, 3), (8, 3),
               (0, 4), (1, 4), (7, 4), (8, 4),
               (0, 5), (1, 5), (7, 5), (8, 5),
               (0, 6), (1, 6), (6, 6), (7, 6), (8, 6),
               (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (7, 7),
               (2, 8), (3, 8), (4, 8), (5, 8)]
    for i, mode in enumerate(("full", "half", "empty")):
        ox, oy = at(HEART_FULL + i)
        for (x, y) in outline:
            if mode == "empty":
                d.point((ox + x, oy + y), fill=PAL["s3"])
                continue
            filled = outline if mode == "full" else [(x, y) for (x, y) in outline if x <= 4]
            for (x, y) in filled:
                d.point((ox + x, oy + y), fill=PAL["red"])
        if mode != "empty":
            d.point((ox + 2, oy + 2), fill=PAL["pink"])
            d.point((ox + 3, oy + 2), fill=PAL["pink"])

    sheet.save(os.path.join(TEX, "items.png"))
    return order


def portraits_sheet(names):
    sheet = new(32 * len(names), 32)
    d = ImageDraw.Draw(sheet)

    def bust(i, skin, skin2, hair, cloth, cloth2, style):
        ox = i * 32
        d.rectangle([ox + 8, 2, ox + 23, 2], fill=hair)
        d.rectangle([ox + 7, 3, ox + 24, 17], fill=skin)
        d.rectangle([ox + 7, 14, ox + 24, 17], fill=skin2)
        if style == "up":
            d.rectangle([ox + 6, 2, ox + 25, 17], fill=hair)
        else:
            d.rectangle([ox + 6, 2, ox + 25, 5], fill=hair)
            d.rectangle([ox + 6, 5, ox + 8, 12], fill=hair)
            d.rectangle([ox + 23, 5, ox + 25, 12], fill=hair)
        d.rectangle([ox + 11, 9, ox + 13, 11], fill=PAL["black"])
        d.rectangle([ox + 18, 9, ox + 20, 11], fill=PAL["black"])
        d.rectangle([ox + 13, 14, ox + 18, 15], fill=skin2)
        d.rectangle([ox + 4, 22, ox + 27, 31], fill=cloth)
        d.rectangle([ox + 4, 22, ox + 27, 24], fill=cloth2)
        d.rectangle([ox + 14, 18, ox + 17, 22], fill=skin2)

    bust(0, PAL["skin"], PAL["skin2"], PAL["ash"], PAL["violet"], PAL["night"], "down")
    # beard
    d.rectangle([9, 13, 22, 20], fill=PAL["ash"])
    bust(1, PAL["skin"], PAL["skin2"], PAL["r3"], PAL["b2"], PAL["b1"], "down")
    d.rectangle([35, 2, 60, 6], fill=PAL["s3"])
    d.rectangle([41, 4, 43, 7], fill=PAL["gold"])
    d.rectangle([51, 4, 53, 7], fill=PAL["gold"])
    bust(2, PAL["skin"], PAL["skin2"], PAL["gold"], PAL["g2"], PAL["g1"], "down")
    bust(3, PAL["skin"], PAL["skin2"], PAL["b1"], PAL["red"], PAL["r1"], "down")
    # the box itself
    ox = 96
    d.rectangle([ox + 6, 8, ox + 25, 27], fill=PAL["b1"])
    d.rectangle([ox + 8, 10, ox + 23, 25], fill=PAL["b2"])
    d.rectangle([ox + 8, 10, ox + 23, 13], fill=PAL["gold"])
    d.rectangle([ox + 14, 14, ox + 17, 22], fill=PAL["violet"])
    d.rectangle([ox + 15, 16, ox + 16, 20], fill=PAL["light"])
    sheet.save(os.path.join(TEX, "portraits.png"))


# --------------------------------------------------------------------------
# audio
# --------------------------------------------------------------------------
RATE = 22050
SHEET_COLS = 5
SHEET_ROWS = 4
HEART_FULL = 15
HEART_HALF = 16
HEART_EMPTY = 17


def write_wav(name, buf):
    path = os.path.join(AUD, name)
    peak = max(1e-6, max(abs(v) for v in buf))
    norm = 0.92 / peak if peak > 0.92 else 1.0
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * norm)) * 32000)) for v in buf)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    return path


def adsr(i, n, atk=0.01, rel=0.3, sus=0.8):
    a = max(1, int(n * atk))
    r = max(1, int(n * rel))
    if i < a:
        return i / a
    if i > n - r:
        return sus * max(0.0, (n - i) / r)
    return sus


def sq(t, f, duty=0.5):
    return 1.0 if (t * f) % 1.0 < duty else -1.0


def tri(t, f):
    p = (t * f) % 1.0
    return 4.0 * abs(p - 0.5) - 1.0


def saw(t, f):
    return 2.0 * ((t * f) % 1.0) - 1.0


def sine(t, f):
    return math.sin(2 * math.pi * f * t)


NOTE_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name):
    m = name[:-1]
    if name in ("-", ".", "R", "r") or m not in NOTE_BASE:
        return 0.0
    octv = int(name[-1])
    semi = NOTE_BASE[m] + (octv - 4) * 12
    return 440.0 * (2.0 ** ((semi - 9) / 12.0))


def mix(buf, gen, start, dur, gain, rel=0.3, sus=0.8, atk=0.01):
    s0 = int(start * RATE)
    n = max(1, int(dur * RATE))
    for i in range(n):
        j = s0 + i
        if 0 <= j < len(buf):
            buf[j] += gen(i / RATE) * adsr(i, n, atk, rel, sus) * gain


def seq_add(buf, tokens, bpm, gen, gain, rel=0.25, sus=0.8, octave=0):
    beat = 60.0 / bpm
    t = 0.0
    for tok in tokens.split():
        name, _, dur = tok.partition(":")
        dd = float(dur) if dur else 1.0
        if name not in ("-", ".", "R", "r"):
            f = freq(name) * (2.0 ** octave)
            mix(buf, lambda tt, f=f: gen(tt, f), t, dd * beat, gain, rel, sus)
        t += dd * beat
    return t


def drums(buf, bpm, bars, gain=0.22, style="soft"):
    beat = 60.0 / bpm
    steps = bars * 4
    for i in range(steps):
        t = i * beat
        beat_hit = (i % 4) in (0, 2)
        if beat_hit:
            mix(buf, lambda tt: (1.0 if (int(tt * 90) % 2 == 0) else -1.0) * (1.0 - tt * 22),
                t, 0.16, gain * 1.0, rel=0.85, sus=0.25)
        if i % 4 == 2:
            mix(buf, lambda tt: math.sin(2 * math.pi * 160 * tt) * math.exp(-tt * 28),
                t, 0.2, gain * 0.9, rel=0.9, sus=0.2)
        if style == "drive" and i % 2 == 1:
            mix(buf, lambda tt: (random.random() * 2 - 1) * math.exp(-tt * 90),
                t, 0.08, gain * 0.55, rel=0.9, sus=0.2)


def build_music():
    # ---- title theme: slow, wistful -----------------------------------
    bpm = 76
    bars = 8
    beat = 60.0 / bpm
    total = bars * 4 * beat
    buf = [0.0] * int(total * RATE) + [0.0] * RATE
    mel = ("A4:2 C5:2 E5:2 D5:2 C5:4 -:4 B4:2 D5:2 F5:2 E5:2 D5:4 C5:4 "
           "E5:2 G5:2 A5:2 G5:2 E5:4 D5:4 C5:2 E5:2 D5:2 B4:2 A4:4 -:4")
    bass = ("A2:4 F2:4 C3:4 E2:4 F2:4 G2:4 E2:4 A2:4")
    seq_add(buf, mel, bpm, lambda t, f: 0.6 * sine(t, f) + 0.25 * sine(t, 2 * f),
            0.30, rel=0.5, sus=0.55)
    seq_add(buf, mel, bpm, lambda t, f: 0.3 * sq(t, f, 0.25), 0.07, rel=0.4, sus=0.4)
    seq_add(buf, bass, bpm, lambda t, f: 0.7 * tri(t, f), 0.22, rel=0.35, sus=0.6)
    write_wav("music_title.wav", buf)

    # ---- village theme: bright, hopeful -------------------------------
    bpm = 112
    bars = 8
    beat = 60.0 / bpm
    total = bars * 4 * beat
    buf = [0.0] * int(total * RATE)
    mel = ("G4:0.5 A4:0.5 B4:0.5 D5:0.5 G5:1 -:0.5 F5:0.5 E5:1 "
           "D5:0.5 E5:0.5 F5:0.5 G5:0.5 B5:1 A5:0.5 G5:1 "
           "E5:0.5 F5:0.5 G5:0.5 A5:0.5 C6:1 B5:0.5 A5:1 "
           "G5:0.5 A5:0.5 B5:0.5 D6:0.5 B5:1 G5:1.5 F5:0.5 "
           "D5:1 E5:1 F5:0.5 G5:0.5 E5:1 D5:1.5 C5:0.5 "
           "G4:0.5 A4:0.5 B4:0.5 D5:0.5 G5:1.5 E5:0.5 D5:1.5 "
           "C5:1 E5:1 G5:1 E5:1 F5:2 D5:2 B4:2 D5:2 G4:4")
    harm = ("B3:1 D4:1 G3:1 B3:1 D4:1 B3:1 G3:1 B3:1 D4:1 B3:1 G3:1")
    bass = ("G2:1 D3:1 G2:1 D3:1 C3:1 G3:1 C3:1 G3:1 "
            "E2:1 B2:1 E2:1 B2:1 F2:1 C3:1 F2:1 C3:1 "
            "G2:1 D3:1 G2:1 B2:1 C3:1 G3:1 A2:1 E3:1 "
            "F2:1 C3:1 F2:1 A2:1 G2:1 D3:1 G2:1 B2:1 "
            "D3:1 G3:1 D3:1 F3:1 G2:2 B2:2 D3:2 G2:2")
    seq_add(buf, mel, bpm, lambda t, f: 0.55 * sq(t, f, 0.5) + 0.2 * sq(t, f * 2, 0.25),
            0.24, rel=0.2, sus=0.72)
    seq_add(buf, harm, bpm, lambda t, f: 0.5 * sq(t, f, 0.125), 0.10, rel=0.3, sus=0.6)
    seq_add(buf, bass, bpm, lambda t, f: 0.6 * tri(t, f), 0.24, rel=0.25, sus=0.7)
    drums(buf, bpm, bars, 0.13, "soft")
    write_wav("music_village.wav", buf)

    # ---- wilds theme: sparse, uneasy ----------------------------------
    bpm = 88
    bars = 8
    beat = 60.0 / bpm
    total = bars * 4 * beat
    buf = [0.0] * int(total * RATE)
    mel = ("A4:2 -:2 E5:1 -:3 C5:2 -:2 B4:1 -:3 E4:2 -:2 "
           "G4:2 -:2 D5:1 -:3 B4:2 -:2 A4:1 -:3 E5:2 -:2 "
           "C5:2 -:2 G5:1 -:3 E5:2 -:2 D5:1 -:3 A4:4")
    low = ("A2:4 E3:4 A2:4 E3:4 F2:4 C3:4 E2:4 B2:4")
    seq_add(buf, mel, bpm, lambda t, f: 0.5 * sine(t, f) + 0.3 * sine(t, f * 3.01),
            0.26, rel=0.55, sus=0.5)
    seq_add(buf, low, bpm, lambda t, f: 0.7 * tri(t, f), 0.20, rel=0.4, sus=0.6)
    drums(buf, bpm, bars, 0.07, "soft")
    write_wav("music_wilds.wav", buf)

    # ---- boss theme: driving, mean ------------------------------------
    bpm = 152
    bars = 8
    beat = 60.0 / bpm
    total = bars * 4 * beat
    buf = [0.0] * int(total * RATE)
    mel = ("D5:0.5 D5:0.5 F5:0.5 D5:0.5 A5:1 G5:0.5 F5:0.5 D5:1 "
           "C5:0.5 C5:0.5 E5:0.5 C5:0.5 G5:1 E5:0.5 D5:1 "
           "D5:0.5 F5:0.5 A5:0.5 D6:1 A5:0.5 F5:1 D5:1 "
           "C5:0.5 E5:0.5 G5:0.5 C6:1 G5:0.5 E5:1 C5:1 "
           "Bb4:0.5 D5:0.5 F5:0.5 Bb5:1 F5:0.5 D5:1 A4:1 "
           "C5:0.5 E5:0.5 G5:0.5 C6:1 B5:0.5 A5:1 G5:1 "
           "A5:0.5 G5:0.5 F5:0.5 E5:0.5 D5:1.5 A4:0.5 D5:1.5 "
           "D5:2 D5:2 F5:2 A5:2 G5:2 F5:2 E5:2 D5:2")
    bass = ("D2:0.5 D2:0.5 D2:0.5 D2:0.5 A2:1 A2:1 "
            "C2:0.5 C2:0.5 C2:0.5 C2:0.5 G2:1 G2:1 "
            "D2:0.5 D2:0.5 A2:0.5 A2:0.5 D2:1 D2:1 "
            "C2:0.5 C2:0.5 G2:0.5 G2:0.5 C2:1 C2:1 "
            "Bb1:0.5 Bb1:0.5 F2:0.5 F2:0.5 Bb1:1 Bb1:1 "
            "C2:0.5 C2:0.5 G2:0.5 G2:0.5 C2:1 C2:1 "
            "D2:1 D2:1 D2:1 D2:1 A2:1 A2:1 A2:1 A2:1 "
            "D2:2 D2:2 D2:2 D2:2")
    seq_add(buf, mel, bpm, lambda t, f: 0.45 * saw(t, f) + 0.3 * sq(t, f, 0.25),
            0.22, rel=0.15, sus=0.75)
    seq_add(buf, bass, bpm, lambda t, f: 0.5 * sq(t, f, 0.5) + 0.4 * sq(t, f * 0.5, 0.5),
            0.26, rel=0.12, sus=0.8)
    drums(buf, bpm, bars, 0.20, "drive")
    write_wav("music_boss.wav", buf)


def build_sfx():
    rng = random.Random(5)

    def blank(dur):
        return [0.0] * int(dur * RATE)

    # sword swing
    b = blank(0.22)
    mix(b, lambda t: rng.random() * 2 - 1, 0.0, 0.18, 0.5, rel=0.8, sus=0.1)
    for i in range(400):
        j = int((0.03 + 0.12 * (i / 400.0)) * RATE)
        if j < len(b):
            b[j] += math.sin(2 * math.pi * (900 - 500 * i / 400.0) * i / RATE) * 0.35
    write_wav("sfx_swing.wav", b)

    # hit
    b = blank(0.3)
    mix(b, lambda t: math.sin(2 * math.pi * 180 * t) * math.exp(-t * 26), 0, 0.25, 0.9,
        rel=0.9, sus=0.2)
    mix(b, lambda t: (rng.random() * 2 - 1) * math.exp(-t * 55), 0, 0.16, 0.5,
        rel=0.9, sus=0.2)
    write_wav("sfx_hit.wav", b)

    # hurt (player)
    b = blank(0.45)
    mix(b, lambda t: (1.0 if (t * 620) % 1 < 0.5 else -1.0) * math.exp(-t * 9), 0, 0.4,
        0.6, rel=0.7, sus=0.3)
    mix(b, lambda t: math.sin(2 * math.pi * (420 - 220 * t) * t) * math.exp(-t * 14),
        0, 0.4, 0.5, rel=0.8, sus=0.2)
    write_wav("sfx_hurt.wav", b)

    # enemy hurt
    b = blank(0.25)
    mix(b, lambda t: (1.0 if (t * 900) % 1 < 0.3 else -1.0) * math.exp(-t * 22), 0, 0.2,
        0.55, rel=0.9, sus=0.15)
    write_wav("sfx_enemy_hurt.wav", b)

    # enemy die
    b = blank(0.5)
    mix(b, lambda t: (rng.random() * 2 - 1) * math.exp(-t * 11), 0, 0.45, 0.6,
        rel=0.85, sus=0.2)
    mix(b, lambda t: math.sin(2 * math.pi * (300 - 260 * t) * t) * math.exp(-t * 12),
        0, 0.45, 0.5, rel=0.85, sus=0.2)
    write_wav("sfx_enemy_die.wav", b)

    # pickup / ui confirm
    b = blank(0.35)
    mix(b, lambda t: math.sin(2 * math.pi * freq("E5") * t), 0.0, 0.09, 0.5, rel=0.4, sus=0.7)
    mix(b, lambda t: math.sin(2 * math.pi * freq("B5") * t), 0.08, 0.09, 0.5, rel=0.4, sus=0.7)
    mix(b, lambda t: math.sin(2 * math.pi * freq("E6") * t), 0.16, 0.16, 0.5, rel=0.6, sus=0.6)
    write_wav("sfx_pickup.wav", b)

    # menu move
    b = blank(0.1)
    mix(b, lambda t: (1.0 if (t * 1400) % 1 < 0.5 else -1.0), 0, 0.06, 0.4,
        rel=0.7, sus=0.3)
    write_wav("sfx_menu.wav", b)

    # door
    b = blank(0.7)
    mix(b, lambda t: math.sin(2 * math.pi * (140 + 90 * t) * t) * math.exp(-t * 4),
        0, 0.6, 0.6, rel=0.8, sus=0.3)
    mix(b, lambda t: (rng.random() * 2 - 1) * math.exp(-t * 7), 0, 0.3, 0.25,
        rel=0.9, sus=0.2)
    write_wav("sfx_door.wav", b)

    # heal
    b = blank(0.6)
    for i, n in enumerate(("C5", "E5", "G5", "C6")):
        mix(b, lambda t, f=freq(n): 0.5 * sine(t, f), i * 0.1, 0.4, 0.4,
            rel=0.6, sus=0.5)
    write_wav("sfx_heal.wav", b)

    # step
    b = blank(0.12)
    mix(b, lambda t: (rng.random() * 2 - 1) * math.exp(-t * 60), 0, 0.1, 0.35,
        rel=0.9, sus=0.15)
    write_wav("sfx_step.wav", b)

    # roar (boss)
    b = blank(1.1)
    mix(b, lambda t: (1.0 if (t * (70 + 30 * t)) % 1 < 0.5 else -1.0) * math.exp(-t * 2.2),
        0, 1.0, 0.7, rel=0.6, sus=0.5)
    mix(b, lambda t: math.sin(2 * math.pi * (55 + 25 * t) * t) * math.exp(-t * 2.0),
        0, 1.0, 0.8, rel=0.6, sus=0.5)
    mix(b, lambda t: (rng.random() * 2 - 1) * math.exp(-t * 3), 0, 0.7, 0.3,
        rel=0.7, sus=0.25)
    write_wav("sfx_roar.wav", b)

    # unlock / objective
    b = blank(0.9)
    for i, n in enumerate(("G4", "C5", "E5", "G5")):
        mix(b, lambda t, f=freq(n): 0.5 * tri(t, f), i * 0.12, 0.5, 0.4, rel=0.5, sus=0.6)
    write_wav("sfx_objective.wav", b)

    # low hearts warning
    b = blank(0.5)
    for i in range(2):
        mix(b, lambda t: 0.5 * sq(t, freq("A4"), 0.5), i * 0.22, 0.2, 0.45,
            rel=0.4, sus=0.6)
    write_wav("sfx_warn.wav", b)

    # splash / block
    b = blank(0.3)
    mix(b, lambda t: (rng.random() * 2 - 1) * math.exp(-t * 16), 0, 0.25, 0.4,
        rel=0.9, sus=0.15)
    write_wav("sfx_block.wav", b)

    # shove / push
    b = blank(0.35)
    mix(b, lambda t: math.sin(2 * math.pi * (110 + 60 * t) * t) * math.exp(-t * 11),
        0, 0.3, 0.5, rel=0.8, sus=0.25)
    write_wav("sfx_push.wav", b)


# --------------------------------------------------------------------------
def contact_sheet():
    """Debug helper: one image with every generated texture, for eyeballing."""
    names = ["tiles.png", "player.png", "npc_elder.png", "npc_tink.png", "npc_pip.png",
             "rust_tick.png", "gloom_moth.png", "boss.png", "bullet.png",
             "items.png", "portraits.png", "water.png"]
    imgs = []
    for n in names:
        p = os.path.join(TEX, n)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        bg = Image.new("RGBA", im.size, (30, 26, 44, 255))
        bg.alpha_composite(im)
        imgs.append((n, bg))
    if not imgs:
        return
    pad = 10
    W = 960
    sheet = Image.new("RGBA", (W, 4000), (18, 15, 28, 255))
    dd = ImageDraw.Draw(sheet)
    x, y, row_h = pad, pad, 0
    for n, im in imgs:
        if x + im.width > W - pad:
            x = pad
            y += row_h + pad + 10
            row_h = 0
        sheet.alpha_composite(im, (x, y))
        dd.text((x, y + im.height + 2), n, fill=(210, 210, 230, 255))
        x += im.width + pad
        row_h = max(row_h, im.height)
    sheet.crop((0, 0, W, y + row_h + pad + 10)).save(os.path.join(ROOT, "tools", "preview.png"))


if __name__ == "__main__":
    tile_sheet()
    water_sheet()
    player_sheet()
    npc_sheet("npc_elder", dict(hair=PAL["ash"], shirt=PAL["violet"], shirt2=PAL["night"],
                                pants=PAL["s1"], boot=PAL["black"]),
              extras=lambda d, f, p: d.rectangle([4, 2, 11, 5], fill=PAL["ash"]))
    npc_sheet("npc_tink", dict(hair=PAL["r3"], shirt=PAL["b2"], shirt2=PAL["b1"],
                               pants=PAL["s1"], boot=PAL["black"]),
              extras=lambda d, f, p: (
                  d.rectangle([3, 3, 12, 6], fill=PAL["s3"]),
                  d.rectangle([4, 4, 6, 6], fill=PAL["gold"]),
                  d.rectangle([9, 4, 11, 6], fill=PAL["gold"])))
    npc_sheet("npc_pip", dict(hair=PAL["gold"], shirt=PAL["g2"], shirt2=PAL["g1"],
                              pants=PAL["s1"], boot=PAL["black"]),
              extras=lambda d, f, p: None)
    tick_sheet()
    moth_sheet()
    boss_sheet()
    bullet_sheet()
    items_sheet()
    portraits_sheet(["elder", "tink", "pip", "corrosion", "box"])
    build_music()
    build_sfx()
    contact_sheet()
    print("done")
