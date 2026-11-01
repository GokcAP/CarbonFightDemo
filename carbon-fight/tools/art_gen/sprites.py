"""CarbonFight pixel art üretici (Sweetie 16 paleti).
Çıktılar art çözünürlüğündedir; Godot'da Nearest filtre ile tam sayı katında büyütülür."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"

PAL = dict(k='1a1c2c', pu='5d275d', r='b13e53', o='ef7d57', y='ffcd75', lg='a7f070', g='38b764',
           dg='257179', nb='29366f', b='3b5dc9', lb='41a6f6', c='73eff7', w='f4f4f4', gl='94b0c2',
           gr='566c86', dk='333c57')


def C(name):
    h = PAL[name]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Spr:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), C(c))

    def pxs(self, pts, c):
        for x, y in pts:
            self.px(x, y, c)

    def rect(self, x0, y0, x1, y1, c):  # dahil koordinatlar
        self.d.rectangle([x0, y0, x1, y1], fill=C(c))

    def ell(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, c)

    def poly(self, pts, c):
        self.d.polygon(pts, fill=C(c))

    def line(self, x0, y0, x1, y1, c, w=1):
        self.d.line([x0, y0, x1, y1], fill=C(c), width=w)

    def outline(self, c='k'):
        a = np.array(self.img)
        alpha = a[:, :, 3] > 0
        n = np.zeros_like(alpha)
        n[1:, :] |= alpha[:-1, :]
        n[:-1, :] |= alpha[1:, :]
        n[:, 1:] |= alpha[:, :-1]
        n[:, :-1] |= alpha[:, 1:]
        edge = n & ~alpha
        a[edge] = C(c)
        self.img = Image.fromarray(a)
        self.d = ImageDraw.Draw(self.img)

    def save(self, rel):
        path = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.img.save(path)
        return self.img


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


# ---------------------------------------------------------------- Binalar 32x32

def gunes_tarlasi():
    s = Spr(32, 32)
    s.rect(2, 22, 29, 29, 'g'); s.rect(2, 22, 29, 22, 'lg')
    s.pxs([(5, 26), (12, 28), (20, 25), (26, 27), (9, 24)], 'dg')
    # güneş
    s.ell(24, 6, 4, 4, 'y'); s.pxs([(23, 4), (22, 5)], 'w')
    s.pxs([(24, 0), (24, 12), (18, 6), (29, 6), (20, 2), (28, 2), (20, 10), (28, 10)], 'o')
    for bx, by in [(3, 17), (15, 17), (8, 25), (20, 25)]:
        s.line(bx + 3, by, bx + 3, by + 3, 'gr'); s.line(bx + 9, by, bx + 9, by + 3, 'gr')
        s.poly([(bx, by), (bx + 10, by), (bx + 12, by - 6), (bx + 2, by - 6)], 'b')
        s.line(bx + 2, by - 6, bx + 12, by - 6, 'c')
        s.line(bx + 1, by - 3, bx + 11, by - 3, 'lb')
        s.line(bx + 6, by, bx + 7, by - 6, 'lb')
        s.line(bx, by, bx + 10, by, 'nb')
    s.outline(); return s


def dikey_tarim():
    s = Spr(32, 32)
    s.rect(15, 1, 15, 4, 'gl'); s.px(15, 0, 'r')
    s.rect(8, 4, 23, 6, 'gr'); s.rect(8, 4, 23, 4, 'gl')
    s.rect(9, 7, 22, 29, 'dk')
    for i, y in enumerate(range(8, 28, 5)):
        s.rect(10, y, 21, y + 3, 'lb')
        s.rect(10, y, 12, y, 'c')
        s.rect(10, y + 2, 21, y + 3, 'g')
        for x in range(10 + (i % 2), 22, 2):
            s.px(x, y + 1, 'lg')
        s.px(14 + i, y + 2, 'y')
    s.rect(9, 7, 9, 29, 'gl')
    s.rect(13, 27, 18, 29, 'k'); s.rect(14, 27, 17, 29, 'nb')
    s.rect(5, 29, 26, 29, 'gr')
    s.outline(); return s


def mavi_karbon():
    s = Spr(32, 32)
    s.rect(2, 19, 29, 29, 'b')
    for y, off in [(21, 0), (24, 3), (27, 1)]:
        for x in range(2 + off, 30, 6):
            s.pxs([(x, y), (x + 1, y - 1), (x + 2, y - 1), (x + 3, y)], 'lb')
    s.pxs([(4, 20), (5, 19), (6, 19), (16, 20), (17, 19), (25, 20), (26, 19)], 'c')
    # mangrov
    for rx in (9, 13, 17, 21):
        s.line(15, 15, rx, 22, 'pu')
    s.rect(14, 10, 16, 18, 'pu')
    s.ell(15, 9, 9, 6, 'dg'); s.ell(13, 7, 6, 4, 'g'); s.ell(11, 6, 3, 2, 'lg')
    s.ell(24, 13, 4, 3, 'dg'); s.ell(23, 12, 2, 2, 'g'); s.line(24, 15, 24, 21, 'pu')
    # deniz çayırı
    for x, h in [(4, 5), (6, 7), (27, 6)]:
        s.line(x, 28, x, 28 - h, 'g'); s.px(x + 1, 28 - h, 'lg')
    s.outline(); return s


def yesil_cati():
    s = Spr(32, 32)
    s.rect(6, 15, 25, 29, 'gl'); s.rect(22, 15, 25, 29, 'gr')
    s.rect(9, 18, 13, 22, 'lb'); s.px(9, 18, 'c'); s.px(10, 18, 'c')
    s.rect(18, 18, 21, 22, 'lb'); s.px(18, 18, 'c')
    s.rect(14, 23, 17, 29, 'dk'); s.px(16, 26, 'y')
    s.poly([(3, 15), (28, 15), (22, 7), (9, 7)], 'g')
    s.line(3, 15, 28, 15, 'dg')
    for x, y in [(8, 7), (13, 5), (18, 5), (23, 7), (11, 9), (20, 9)]:
        s.ell(x, y, 3, 2, 'g'); s.px(x - 1, y - 1, 'lg'); s.px(x, y - 1, 'lg')
    s.pxs([(12, 6), (19, 4), (15, 9), (23, 8), (7, 10)], 'y')
    s.pxs([(16, 6), (9, 12), (25, 12)], 'r')
    s.rect(3, 29, 28, 29, 'dg')
    s.outline(); return s


def toplu_tasima():
    s = Spr(32, 32)
    s.line(4, 1, 27, 1, 'gr')
    s.line(12, 7, 16, 2, 'dk'); s.line(20, 7, 16, 2, 'dk')
    s.rect(6, 7, 25, 27, 'y')
    s.rect(6, 7, 25, 8, 'w')
    s.rect(6, 20, 25, 22, 'o')
    s.rect(8, 10, 23, 17, 'nb')
    s.rect(8, 10, 23, 10, 'lb'); s.line(9, 16, 14, 11, 'c'); s.line(11, 16, 16, 11, 'lb')
    s.line(15, 10, 15, 17, 'dk')
    s.ell(9, 24, 1.6, 1.6, 'w'); s.ell(22, 24, 1.6, 1.6, 'w')
    s.rect(13, 24, 18, 25, 'dk')
    s.rect(24, 9, 25, 27, 'o')
    s.rect(7, 28, 10, 29, 'k'); s.rect(21, 28, 24, 29, 'k')
    s.rect(2, 30, 29, 30, 'gr')
    s.outline(); return s


def komur_santrali():
    s = Spr(32, 32)
    for cx, cy, r, col in [(8, 6, 3, 'gr'), (11, 3, 3, 'gl'), (22, 4, 3, 'gr'), (25, 2, 2, 'gl'), (6, 3, 2, 'dk')]:
        s.ell(cx, cy, r, r, col)
    s.rect(6, 9, 10, 20, 'gl'); s.rect(6, 11, 10, 12, 'r'); s.rect(9, 9, 10, 20, 'gr')
    s.rect(20, 7, 24, 20, 'gl'); s.rect(20, 9, 24, 10, 'r'); s.rect(23, 7, 24, 20, 'gr')
    s.poly([(2, 29), (2, 18), (9, 14), (9, 18), (16, 14), (16, 18), (23, 14), (23, 18), (29, 18), (29, 29)], 'gr')
    s.line(2, 18, 9, 14, 'gl'); s.line(9, 18, 16, 14, 'gl'); s.line(16, 18, 23, 14, 'gl')
    for x in (5, 11, 17, 23):
        s.rect(x, 21, x + 2, 23, 'o'); s.px(x, 21, 'y')
    s.rect(13, 25, 17, 29, 'dk')
    s.rect(2, 29, 29, 29, 'dk')
    s.outline(); return s


# ---------------------------------------------------------------- Boss'lar 64x64, 2 kare

def termik_ejderha(f):
    s = Spr(64, 64); b = f  # 1 px nefes
    # kanatlar
    s.poly([(18, 34 - b), (2, 16 - b), (6, 30), (1, 36), (16, 44)], 'pu')
    s.poly([(46, 34 - b), (62, 16 - b), (58, 30), (63, 36), (48, 44)], 'pu')
    s.line(18, 34 - b, 4, 22 - b, 'r'); s.line(46, 34 - b, 60, 22 - b, 'r')
    # gövde
    s.ell(32, 46, 17, 13 + b * 0.5, 'r')
    s.ell(32, 49, 10, 9, 'o')
    for y in (44, 48, 52, 56):
        s.line(26, y, 38, y, 'y')
    s.rect(16, 56, 23, 61, 'pu'); s.rect(41, 56, 48, 61, 'pu')
    s.pxs([(16, 62), (19, 62), (22, 62), (42, 62), (45, 62), (48, 62)], 'w')
    # kömür sırt dikenleri
    for x, y in [(17, 36), (47, 36), (14, 42), (50, 42)]:
        s.poly([(x - 2, y + 2), (x, y - 3), (x + 2, y + 2)], 'dk')
    # kafa
    hy = 22 + b
    s.poly([(23, hy - 6), (15, hy - 18), (27, hy - 9)], 'w')
    s.poly([(41, hy - 6), (49, hy - 18), (37, hy - 9)], 'w')
    s.line(23, hy - 7, 17, hy - 16, 'gl'); s.line(41, hy - 7, 47, hy - 16, 'gl')
    s.ell(32, hy, 14, 11, 'r')
    s.ell(32, hy - 4, 10, 5, 'o')
    s.ell(32, hy + 6, 9, 5, 'o')
    s.pxs([(29, hy + 5), (35, hy + 5)], 'k')
    s.line(25, hy + 10, 39, hy + 10, 'pu')
    s.pxs([(27, hy + 9), (31, hy + 9), (33, hy + 9), (37, hy + 9)], 'w')
    for ex in (25, 39):
        s.rect(ex - 2, hy - 2, ex + 2, hy, 'y'); s.rect(ex - 1 if ex < 32 else ex, hy - 2, ex if ex < 32 else ex + 1, hy, 'k')
    s.line(22, hy - 5, 28, hy - 3, 'k'); s.line(42, hy - 5, 36, hy - 3, 'k')
    # ağız alevi
    if f:
        s.ell(32, hy + 14, 4, 3, 'o'); s.ell(32, hy + 14, 2, 2, 'y')
    else:
        s.ell(32, hy + 13, 2, 2, 'o')
    s.outline(); return s


def plastik_leviathan(f):
    s = Spr(64, 64)
    import math
    # gövde halkaları
    pts = []
    for i in range(40):
        t = i / 39
        x = 6 + t * 34
        y = 52 - t * 30 + math.sin(t * 7 + f * 0.8) * 5
        pts.append((x, y))
    for (x, y) in pts:
        s.ell(x, y, 6, 6, 'dg')
    for (x, y) in pts[::3]:
        s.ell(x - 1, y - 2, 2.2, 1.5, 'g')
    for i, (x, y) in enumerate(pts[4:34:6]):
        s.ell(x + 1, y + 2, 1.5, 1.5, 'c')
    # sırt yüzgeçleri
    for (x, y) in pts[5:36:7]:
        s.poly([(x - 3, y - 5), (x, y - 11), (x + 2, y - 5)], 'c')
    # plastik şişe
    bx, by = int(pts[14][0]) - 3, int(pts[14][1]) - 2
    s.rect(bx, by, bx + 6, by + 3, 'lb'); s.rect(bx, by, bx + 6, by, 'w'); s.rect(bx + 7, by + 1, bx + 8, by + 2, 'r')
    # poşet
    qx, qy = int(pts[26][0]) - 2, int(pts[26][1])
    s.poly([(qx, qy), (qx + 6, qy - 1), (qx + 5, qy + 5), (qx + 1, qy + 4)], 'w'); s.px(qx + 2, qy + 1, 'gl')
    # kafa
    hx, hy = 44, 18 + f
    s.ell(hx, hy, 13, 9, 'dg')
    s.ell(hx + 2, hy + 6, 10, 4, 'g')
    s.line(hx - 6, hy + 4, hx + 12, hy + 4, 'k')
    s.pxs([(x, hy + 5) for x in range(hx - 5, hx + 12, 3)], 'w')
    s.pxs([(x, hy + 3) for x in range(hx - 4, hx + 12, 3)], 'w')
    s.rect(hx - 4, hy - 4, hx - 1, hy - 2, 'y'); s.rect(hx - 3, hy - 4, hx - 2, hy - 2, 'r')
    s.line(hx - 6, hy - 6, hx, hy - 5, 'k')
    s.poly([(hx + 4, hy - 7), (hx + 12, hy - 14), (hx + 10, hy - 5)], 'c')
    s.ell(hx + 10, hy - 3, 1.5, 1, 'c')
    s.outline()
    # su
    for y in range(54, 64):
        for x in range(64):
            s.px(x, y, 'nb' if y > 57 else 'b')
    for x in range(0, 64, 8):
        xo = (x + f * 3) % 64
        s.pxs([(xo, 54), (xo + 1, 53), (xo + 2, 53), (xo + 3, 54)], 'lb')
        s.pxs([((xo + 4) % 64, 58), ((xo + 5) % 64, 58)], 'b')
    return s


def isi_adasi_golemi(f):
    s = Spr(64, 64); b = f
    # sıcak hava dalgaları
    for x in (24, 32, 40):
        xo = x + (1 if f else -1)
        s.pxs([(xo, 1), (xo + 1, 2), (xo, 3), (xo - 1, 4)], 'o')
    # bacaklar
    s.rect(20, 50, 28, 61, 'gr'); s.rect(36, 50, 44, 61, 'gr')
    s.rect(18, 59, 29, 62, 'dk'); s.rect(35, 59, 46, 62, 'dk')
    # kollar
    s.rect(5, 22 + b, 14, 42 + b, 'gr'); s.rect(3, 40 + b, 15, 50 + b, 'dk'); s.rect(4, 41 + b, 8, 42 + b, 'gr')
    s.rect(50, 22 + b, 59, 42 + b, 'gr'); s.rect(49, 40 + b, 61, 50 + b, 'dk'); s.rect(56, 41 + b, 60, 42 + b, 'gr')
    # gövde (asfalt)
    s.rect(14, 18 + b, 50, 51, 'dk')
    s.rect(14, 18 + b, 50, 19 + b, 'gr')
    s.rect(47, 20 + b, 50, 51, 'k')
    for x in range(17, 46, 6):
        s.rect(x, 34, x + 2, 35, 'y')
    s.pxs([(18, 24), (25, 28), (40, 25), (44, 44), (20, 46), (33, 41), (30, 22)], 'gr')
    # kızgın çatlaklar
    s.line(24, 22 + b, 28, 30, 'o'); s.line(28, 30, 26, 33, 'o'); s.line(38, 37, 42, 47, 'o'); s.line(42, 47, 40, 50, 'r')
    s.pxs([(27, 29), (41, 45)], 'y')
    # klima ünitesi
    s.rect(42, 10 + b, 55, 20 + b, 'w'); s.rect(42, 19 + b, 55, 20 + b, 'gl')
    s.ell(48, 15 + b, 3, 3, 'dk'); s.px(48, 15 + b, 'gl'); s.pxs([(47, 14 + b), (49, 16 + b)], 'gr')
    # kafa
    s.rect(24, 5 + b, 40, 18 + b, 'gr'); s.rect(24, 5 + b, 40, 6 + b, 'gl'); s.rect(38, 7 + b, 40, 18 + b, 'dk')
    s.rect(27, 10 + b, 31, 12 + b, 'o'); s.rect(33, 10 + b, 37, 12 + b, 'o')
    s.pxs([(28, 11 + b), (34, 11 + b)], 'y')
    s.line(26, 9 + b, 31, 9 + b, 'k'); s.line(33, 9 + b, 38, 9 + b, 'k')
    s.rect(28, 15 + b, 36, 16 + b, 'k')
    s.outline(); return s


# ---------------------------------------------------------------- İkonlar 16x16

def icon(name):
    s = Spr(16, 16)
    if name == "carbon":
        s.ell(6, 9, 4, 3.5, 'gr'); s.ell(10, 7, 4, 4, 'gr'); s.ell(11, 10, 3.5, 3, 'dk'); s.ell(8, 6, 2, 1.5, 'gl')
        s.rect(3, 10, 13, 12, 'gr'); s.rect(6, 11, 13, 12, 'dk')
    elif name == "temp":
        s.rect(6, 1, 9, 10, 'w'); s.rect(7, 4, 8, 10, 'r'); s.ell(7.5, 12, 3, 2.6, 'r'); s.px(6, 11, 'o')
        s.pxs([(10, 3), (10, 5), (10, 7)], 'gl')
    elif name == "welfare":
        s.line(8, 14, 8, 3, 'o')
        for y in (3, 6, 9):
            s.ell(6, y + 1, 1.6, 1.2, 'y'); s.ell(10, y + 1, 1.6, 1.2, 'y')
        s.ell(8, 2, 1, 1.5, 'y')
        s.line(4, 14, 12, 14, 'g')
    elif name == "ap":
        s.line(3, 12, 12, 3, 'gl', 2); s.line(4, 11, 12, 3, 'w'); s.px(13, 2, 'w')
        s.line(2, 9, 6, 13, 'o'); s.line(2, 13, 4, 11, 'pu', 2)
    elif name == "hp":
        s.ell(5, 6, 3, 3, 'r'); s.ell(10, 6, 3, 3, 'r'); s.poly([(2, 7), (13, 7), (7.5, 13)], 'r')
        s.pxs([(4, 4), (4, 5), (5, 4)], 'w'); s.px(10, 4, 'o')
    elif name == "armor":
        s.poly([(2, 2), (13, 2), (13, 8), (7.5, 14), (2, 8)], 'lb'); s.poly([(8, 2), (13, 2), (13, 8), (8, 13)], 'b')
        s.line(3, 3, 3, 8, 'c'); s.line(3, 3, 7, 3, 'c')
    elif name == "lock":
        s.rect(4, 3, 5, 8, 'gl'); s.rect(10, 3, 11, 8, 'gl'); s.rect(5, 2, 10, 3, 'gl')
        s.rect(3, 8, 12, 14, 'y'); s.rect(3, 8, 12, 8, 'w'); s.rect(7, 10, 8, 12, 'pu')
    elif name == "fire":
        s.poly([(3, 10), (5, 4), (7, 7), (8, 1), (11, 6), (13, 10), (8, 14)], 'r')
        s.ell(8, 10, 4, 4, 'r'); s.ell(8, 10.5, 3, 3, 'o'); s.ell(8, 11.5, 1.6, 2, 'y')
    elif name == "gunes":
        s.ell(7.5, 7.5, 3.5, 3.5, 'y'); s.pxs([(6, 5), (5, 6)], 'w')
        s.pxs([(7, 0), (8, 0), (7, 15), (8, 15), (0, 7), (0, 8), (15, 7), (15, 8), (2, 2), (13, 2), (2, 13), (13, 13)], 'o')
    elif name == "toprak":
        s.poly([(2, 13), (3, 6), (8, 2), (14, 2), (13, 8), (8, 13)], 'g'); s.line(3, 13, 12, 4, 'dg')
        s.line(5, 6, 8, 3, 'lg'); s.px(4, 7, 'lg')
    elif name == "su":
        s.poly([(7.5, 1), (12, 9), (3, 9)], 'lb'); s.ell(7.5, 10, 4.5, 4, 'lb'); s.ell(8.5, 11, 3, 2.6, 'b')
        s.pxs([(5, 9), (5, 10), (6, 8)], 'c')
    elif name == "fosil":
        s.rect(3, 2, 12, 14, 'dk'); s.rect(3, 4, 12, 5, 'gr'); s.rect(3, 11, 12, 12, 'gr'); s.rect(3, 2, 4, 14, 'gr')
        s.ell(9, 8, 1.4, 2, 'k')
    elif name == "rage":
        s.ell(7.5, 7.5, 6, 6, 'r'); s.ell(6, 5, 3, 2, 'o')
        s.line(3, 5, 6, 7, 'k'); s.line(12, 5, 9, 7, 'k'); s.pxs([(5, 8), (10, 8)], 'k')
        s.line(5, 11, 10, 11, 'k'); s.pxs([(4, 12), (11, 12)], 'k')
    elif name == "warn":
        s.poly([(7.5, 1), (14, 13), (1, 13)], 'y'); s.rect(7, 5, 8, 9, 'k'); s.rect(7, 11, 8, 11, 'k')
    elif name == "star":
        s.poly([(7.5, 1), (9.5, 6), (14, 6), (10.5, 9), (12, 14), (7.5, 11), (3, 14), (4.5, 9), (1, 6), (5.5, 6)], 'y')
        s.pxs([(7, 4), (7, 5), (6, 6)], 'w'); s.poly([(7.5, 11), (12, 14), (10.5, 9)], 'o')
    elif name == "skull":
        s.ell(7.5, 6.5, 5.5, 5, 'w'); s.rect(5, 10, 10, 13, 'w')
        s.rect(4, 6, 6, 8, 'k'); s.rect(9, 6, 11, 8, 'k'); s.pxs([(7, 9), (8, 9)], 'k'); s.pxs([(6, 13), (9, 13)], 'gl')
    s.outline(); return s


ICONS = ["carbon", "temp", "welfare", "ap", "hp", "armor", "lock", "fire", "gunes", "toprak", "su", "fosil",
         "rage", "warn", "star", "skull"]


# ---------------------------------------------------------------- Arka plan 320x180

def background():
    w, h = 320, 180
    s = Spr(w, h)
    a = np.zeros((h, w, 4), np.uint8)
    bands = [('k', 'dk', 0, 70), ('dk', 'nb', 70, 120), ('nb', 'dg', 120, 150)]
    for c0, c1, y0, y1 in bands:
        for y in range(y0, y1):
            t = (y - y0) / (y1 - y0)
            for x in range(w):
                a[y, x] = C(c1) if t > BAYER[y % 4, x % 4] else C(c0)
    rng = np.random.default_rng(7)
    for _ in range(60):
        x, y = rng.integers(0, w), rng.integers(0, 80)
        a[y, x] = C('gl' if rng.random() < 0.3 else 'gr')
    s.img = Image.fromarray(a); s.d = ImageDraw.Draw(s.img)
    # uzak tepeler
    import math
    for x in range(w):
        y = int(128 + math.sin(x * 0.03) * 6 + math.sin(x * 0.11) * 3)
        s.line(x, y, x, h, 'dg')
    # şehir silueti
    x = 0
    while x < w:
        bw = int(rng.integers(8, 22)); bh = int(rng.integers(14, 46))
        top = 150 - bh
        s.rect(x, top, x + bw - 1, h, 'dk')
        if rng.random() < 0.3:
            s.rect(x + bw // 2, top - 6, x + bw // 2, top, 'dk')
        for wy in range(top + 3, 148, 4):
            for wx in range(x + 2, x + bw - 2, 3):
                if rng.random() < 0.18:
                    s.px(wx, wy, 'y' if rng.random() < 0.7 else 'o')
        x += bw + int(rng.integers(0, 3))
    # bacalar ve duman
    for cx in (40, 210, 285):
        s.rect(cx, 112, cx + 4, 150, 'k'); s.rect(cx, 116, cx + 4, 117, 'r')
        for i in range(5):
            s.ell(cx + 2 + i * 4, 108 - i * 5, 3 + i, 2 + i * 0.6, 'gr' if i % 2 else 'dk')
    # zemin
    s.rect(0, 150, w, h, 'k')
    for x in range(0, w, 2):
        s.px(x + (x // 2) % 2, 150, 'dk')
    return s


# ---------------------------------------------------------------- main

if __name__ == "__main__":
    for name, fn in [("gunes_tarlasi", gunes_tarlasi), ("dikey_tarim", dikey_tarim), ("mavi_karbon", mavi_karbon),
                     ("yesil_cati", yesil_cati), ("toplu_tasima", toplu_tasima), ("komur_santrali", komur_santrali)]:
        fn().save(f"cards/{name}.png")
    for name, fn in [("termik_ejderha", termik_ejderha), ("plastik_leviathan", plastik_leviathan),
                     ("isi_adasi_golemi", isi_adasi_golemi)]:
        for f in (0, 1):
            fn(f).save(f"bosses/{name}_{f}.png")
    for n in ICONS:
        icon(n).save(f"icons/{n}.png")
    background().save("bg/city.png")
    print("ok")
