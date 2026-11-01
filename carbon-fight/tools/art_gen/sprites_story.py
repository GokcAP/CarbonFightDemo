"""Hikaye sürümü sprite'ları: Kül Ana / Doğa Ana, tohum parçaları, harita karoları, arka planlar."""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprites as S
from sprites import Spr, C, BAYER

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
S.OUT = OUT


def save(spr, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    spr.img.save(path)


# ---------------------------------------------------------------- Kül Ana / Doğa Ana 64x64
# Çizim mother.py içinde (aynı silüet, iki hal).
from mother import mother  # noqa: E402


# ---------------------------------------------------------------- Parçalar ve tohum 32x32

def shard(main, light, dark):
    s = Spr(32, 32)
    s.ell(16, 16, 13, 13, 'k') if False else None
    for r, col in [(13, dark), (10, main)]:
        pass
    s.poly([(16, 2), (24, 10), (21, 28), (11, 28), (8, 12)], main)
    s.poly([(16, 2), (24, 10), (17, 14)], light)
    s.poly([(8, 12), (16, 2), (17, 14), (11, 28)], light if False else main)
    s.poly([(17, 14), (24, 10), (21, 28)], dark)
    s.line(16, 3, 12, 12, 'w'); s.px(13, 9, 'w')
    s.outline()
    for x, y in [(4, 6), (27, 5), (28, 22), (3, 24)]:
        s.px(x, y, light)
    return s


def seed():
    s = Spr(32, 32)
    s.ell(16, 21, 9, 8, 'y'); s.ell(14, 19, 5, 4, 'w'); s.ell(18, 24, 6, 4, 'o')
    s.line(16, 13, 16, 6, 'g', 2)
    s.ell(11, 7, 5, 3, 'g'); s.ell(10, 6, 3, 1.5, 'lg')
    s.ell(21, 5, 5, 3, 'g'); s.ell(22, 4, 3, 1.5, 'lg')
    s.pxs([(13, 22), (19, 20), (16, 25)], 'lb'); s.pxs([(15, 18), (20, 23)], 'r')
    s.outline()
    for x, y in [(4, 14), (28, 12), (27, 27), (5, 28)]:
        s.px(x, y, 'lg')
    return s


# ---------------------------------------------------------------- Karolar 44x44 (slot içi, 2x = 88 px)

def tile_asphalt():
    s = Spr(44, 44)
    rng = np.random.default_rng(5)
    s.rect(0, 0, 43, 43, 'dk')
    for _ in range(70):
        s.px(int(rng.integers(0, 44)), int(rng.integers(0, 44)), 'k' if rng.random() < 0.5 else 'gr')
    for x in range(2, 44, 10):
        s.rect(x, 21, x + 5, 22, 'y')
    s.line(8, 6, 14, 12, 'k'); s.line(14, 12, 13, 16, 'k')
    for x in (30, 34, 38):
        s.pxs([(x, 4), (x + 1, 3), (x, 2)], 'o')
    return s


def tile_green():
    s = Spr(44, 44)
    rng = np.random.default_rng(9)
    s.rect(0, 0, 43, 43, 'dg')
    for _ in range(90):
        x, y = int(rng.integers(0, 44)), int(rng.integers(1, 44))
        s.px(x, y, 'g'); s.px(x, y - 1, 'lg' if rng.random() < 0.3 else 'g')
    for _ in range(8):
        x, y = int(rng.integers(2, 42)), int(rng.integers(2, 42))
        s.px(x, y, 'y' if rng.random() < 0.5 else 'w')
    return s


def tile_altar():
    s = Spr(44, 44)
    s.ell(22, 24, 19, 15, 'dk'); s.ell(22, 22, 17, 13, 'gr'); s.ell(22, 21, 13, 9, 'gl')
    s.ell(22, 21, 9, 6, 'gr')
    for a in range(0, 360, 45):
        x = 22 + int(round(15 * math.cos(math.radians(a)))); y = 22 + int(round(11 * math.sin(math.radians(a))))
        s.px(x, y, 'w')
    return s


def overlay_smoke(f=0):
    s = Spr(44, 44)
    for cx, cy, r in [(12, 14, 9), (26, 10, 10), (34, 22, 9), (18, 28, 11), (30, 34, 8), (8, 34, 6)]:
        s.ell(cx, cy, r, r * 0.8, 'gl')
    for cx, cy, r in [(14, 12, 4), (27, 8, 4), (20, 26, 5)]:
        s.ell(cx, cy, r, r * 0.7, 'w')
    for cx, cy, r in [(36, 25, 5), (31, 37, 4), (10, 36, 3)]:
        s.ell(cx, cy, r, r * 0.8, 'gr')
    a = np.array(s.img); a[:, :, 3] = np.where(a[:, :, 3] > 0, 150, 0); s.img = Image.fromarray(a)
    return s


def overlay_hot():
    s = Spr(44, 44)
    for x in range(4, 44, 9):
        for y in range(6, 44, 14):
            s.pxs([(x, y), (x + 1, y - 1), (x + 2, y - 2), (x + 1, y - 3), (x, y - 4), (x + 1, y - 5)], 'o')
    a = np.array(s.img)
    tint = np.zeros_like(a); tint[:, :] = C('r'); tint[:, :, 3] = 60
    out = np.where(a[:, :, 3:4] > 0, a, tint); s.img = Image.fromarray(out.astype(np.uint8))
    return s


def trash_token():
    s = Spr(32, 32)
    s.poly([(6, 28), (5, 16), (10, 12), (14, 14), (13, 28)], 'gr'); s.line(7, 17, 11, 15, 'gl')
    s.rect(15, 14, 21, 28, 'lb'); s.rect(16, 11, 20, 13, 'lb'); s.rect(16, 9, 20, 10, 'r'); s.line(16, 15, 16, 26, 'c')
    s.poly([(20, 28), (22, 18), (27, 17), (28, 28)], 'w'); s.px(23, 20, 'gl'); s.line(22, 18, 24, 15, 'w')
    s.rect(9, 24, 12, 27, 'o')
    s.outline(); return s


# ---------------------------------------------------------------- İkonlar 16x16

def icons():
    out = {}
    for name, (m, l, d) in {"shard_su": ('lb', 'c', 'b'), "shard_toprak": ('g', 'lg', 'dg'), "shard_gunes": ('y', 'w', 'o')}.items():
        s = Spr(16, 16)
        s.poly([(8, 1), (13, 5), (11, 14), (5, 14), (3, 6)], m); s.poly([(8, 1), (13, 5), (9, 7)], l)
        s.poly([(9, 7), (13, 5), (11, 14)], d); s.px(7, 4, 'w')
        s.outline(); out[name] = s
    s = Spr(16, 16); s.ell(8, 10, 4.5, 4, 'y'); s.ell(7, 9, 2, 1.5, 'w'); s.line(8, 6, 8, 3, 'g')
    s.ell(5, 3, 2.5, 1.5, 'g'); s.ell(11, 3, 2.5, 1.5, 'lg'); s.outline(); out["seed"] = s
    s = Spr(16, 16); s.rect(3, 6, 6, 14, 'gl'); s.rect(3, 8, 6, 8, 'r'); s.rect(8, 9, 13, 14, 'gr')
    s.ell(5, 3, 2, 2, 'gr'); s.ell(8, 2, 2, 1.5, 'dk'); s.rect(10, 11, 11, 12, 'o'); s.outline(); out["chimney"] = s
    s = Spr(16, 16); s.rect(4, 5, 11, 14, 'gr'); s.rect(3, 3, 12, 4, 'gl'); s.rect(6, 1, 9, 2, 'gl')
    s.line(6, 7, 6, 12, 'dk'); s.line(9, 7, 9, 12, 'dk'); s.outline(); out["trash"] = s
    s = Spr(16, 16)
    for cx, cy, r in [(5, 10, 3), (11, 6, 2.5), (10, 12, 1.6), (4, 3, 1.4)]:
        s.ell(cx, cy, r, r, 'lb'); s.px(int(cx - r / 2), int(cy - r / 2), 'w')
    s.outline(); out["bubble"] = s
    s = Spr(16, 16); s.ell(5, 9, 4, 3, 'gl'); s.ell(10, 7, 4, 4, 'gl'); s.ell(11, 10, 3, 2.5, 'gr'); s.ell(8, 6, 2, 1.5, 'w')
    s.outline(); out["smoke"] = s
    s = Spr(16, 16); s.ell(7.5, 9, 6, 4.5, 'gr'); s.ell(7.5, 8, 4, 3, 'gl'); s.ell(7.5, 7, 2, 1.4, 'y'); s.px(7, 6, 'w')
    s.outline(); out["altar"] = s
    s = Spr(16, 16); s.rect(2, 2, 13, 13, 'dk'); s.pxs([(4, 4), (9, 6), (6, 11), (11, 10)], 'k'); s.rect(3, 7, 5, 8, 'y'); s.rect(9, 7, 11, 8, 'y')
    s.outline(); out["asphalt"] = s
    s = Spr(16, 16); s.rect(3, 3, 12, 13, 'w'); s.rect(3, 3, 12, 4, 'gl'); s.line(5, 7, 10, 7, 'gr'); s.line(5, 9, 10, 9, 'gr'); s.line(5, 11, 8, 11, 'gr')
    s.rect(2, 2, 13, 2, 'o'); s.rect(2, 13, 13, 14, 'o'); s.outline(); out["quest"] = s
    s = Spr(16, 16); s.ell(7.5, 7.5, 6, 6, 'lb'); s.line(7, 2, 7, 13, 'w'); s.line(2, 7, 13, 7, 'w'); s.line(3, 3, 12, 12, 'c'); s.line(12, 3, 3, 12, 'c')
    s.outline(); out["cool"] = s
    return out


# ---------------------------------------------------------------- Arka planlar 320x180

def gradient(bands, w=320, h=180):
    a = np.zeros((h, w, 4), np.uint8)
    for c0, c1, y0, y1 in bands:
        for y in range(y0, y1):
            t = (y - y0) / max(1, (y1 - y0))
            for x in range(w):
                a[y, x] = C(c1) if t > BAYER[y % 4, x % 4] else C(c0)
    s = Spr(w, h); s.img = Image.fromarray(a); s.d = ImageDraw.Draw(s.img)
    return s


def bg_vadi():
    s = gradient([('dk', 'gr', 0, 90), ('gr', 'gl', 90, 130)])
    rng = np.random.default_rng(11)
    for x in range(320):
        y = int(95 + math.sin(x * 0.02) * 18 + math.sin(x * 0.07) * 6)
        s.line(x, y, x, 180, 'dk')
        y2 = int(125 + math.sin(x * 0.03 + 2) * 10)
        s.line(x, y2, x, 180, 'pu')
    for cx in (60, 150, 250):
        s.rect(cx, 105, cx + 6, 150, 'k'); s.rect(cx, 110, cx + 6, 112, 'r')
        for i in range(7):
            s.ell(cx + 3 + i * 5, 100 - i * 7, 4 + i, 3 + i * 0.7, 'gr' if i % 2 else 'dk')
    s.rect(0, 150, 320, 180, 'k')
    for x in range(0, 320, 3):
        if rng.random() < 0.3:
            s.px(x, 151, 'o')
    for x in range(0, 320, 40):
        s.line(x, 158, x + 25, 160, 'dk')
    return s


def bg_korfez():
    s = gradient([('nb', 'b', 0, 70), ('b', 'dg', 70, 105)])
    rng = np.random.default_rng(12)
    for x in range(320):
        y = int(100 + math.sin(x * 0.025) * 5)
        s.line(x, y, x, 112, 'dg')
    for y in range(112, 180):
        for x in range(320):
            c = 'nb' if y > 140 else 'b'
            if (x + y * 3) % 23 == 0:
                c = 'lb'
            s.px(x, y, c)
    for y in range(116, 176, 9):
        for x in range(int(rng.integers(0, 20)), 320, 28):
            s.pxs([(x, y), (x + 1, y - 1), (x + 2, y - 1), (x + 3, y)], 'lb')
    for _ in range(22):
        x, y = int(rng.integers(0, 316)), int(rng.integers(116, 176))
        s.rect(x, y, x + 2, y + 1, 'w' if rng.random() < 0.5 else 'r')
    for x in (30, 270):
        s.poly([(x, 112), (x + 30, 112), (x + 15, 96)], 'dk')
    return s


def bg_orman():
    s = gradient([('pu', 'r', 0, 80), ('r', 'o', 80, 120)])
    rng = np.random.default_rng(13)
    for i in range(26):
        x = int(rng.integers(0, 320)); h = int(rng.integers(40, 80)); base = 150
        s.rect(x + 3, base - h // 3, x + 5, base, 'k')
        s.poly([(x - 6, base - h // 3), (x + 4, base - h), (x + 14, base - h // 3)], 'k' if i % 3 else 'pu')
        if rng.random() < 0.5:
            s.ell(x + 4, base - h + 6, 2, 3, 'y')
    for _ in range(80):
        x, y = int(rng.integers(0, 320)), int(rng.integers(0, 120))
        s.px(x, y, 'o' if rng.random() < 0.6 else 'y')
    s.rect(0, 150, 320, 180, 'k')
    for x in range(0, 320, 6):
        if rng.random() < 0.4:
            s.pxs([(x, 150), (x + 1, 149)], 'g' if rng.random() < 0.3 else 'r')
    return s


if __name__ == "__main__":
    for f in (0, 1):
        save(mother(f), f"bosses/kul_ana_{f}.png")
    save(mother(0, green=True), "bosses/doga_ana.png")
    save(shard('lb', 'c', 'b'), "cards/shard_su.png")
    save(shard('g', 'lg', 'dg'), "cards/shard_toprak.png")
    save(shard('y', 'w', 'o'), "cards/shard_gunes.png")
    save(seed(), "cards/denge_tohumu.png")
    save(tile_asphalt(), "tiles/asphalt.png")
    save(tile_green(), "tiles/green.png")
    save(tile_altar(), "tiles/altar.png")
    save(overlay_smoke(), "tiles/smoke.png")
    save(overlay_hot(), "tiles/hot.png")
    save(trash_token(), "tiles/trash.png")
    for n, sp in icons().items():
        save(sp, f"icons/{n}.png")
    save(bg_vadi(), "bg/vadi.png")
    save(bg_korfez(), "bg/korfez.png")
    save(bg_orman(), "bg/orman.png")
    S.background().save("bg/sehir.png")
    print("ok")
