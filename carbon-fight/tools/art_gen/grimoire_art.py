"""Denge Grimuarı (büyü kitabı) pixel art: kapalı kapak ve açık kitap.

Kullanım:  python grimoire_art.py ../../assets/sprites/book
Çıktılar (oyun 3x büyütür; sayfa içerik alanları scripts/ui/grimoire.gd ile aynı olmalı):
  cover.png  160x200  deri kapak, altın çerçeve, ortada Denge Tohumu amblemi, kilit kayışı
  open.png   320x200  açık kitap: deri kenar, iki parşömen sayfa, cilt gölgesi, ayraç kurdelesi
"""
import math
import os
import random
import sys

from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"


def hx(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


INK = hx("1a1c2c")
GOLD, GOLD_D, GOLD_L = hx("ffcd75"), hx("b8862f"), hx("fff0a8")
LEATHER = [hx("4a2338"), hx("43203a"), hx("3a1a2c")]
LEATHER_D = hx("2a1220")


def leather(img, rng, x0, y0, x1, y1):
    px = img.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            n = (math.sin(x * 0.7 + y * 0.3) + math.sin(y * 1.3 - x * 0.2)) * 0.5
            c = LEATHER[0] if n > 0.4 else (LEATHER[2] if n < -0.5 else LEATHER[1])
            if rng.random() < 0.04:
                c = LEATHER_D
            px[x, y] = c


def frame(img, x0, y0, x1, y1, outer=GOLD, inner=GOLD_D):
    px = img.load()
    for x in range(x0, x1 + 1):
        px[x, y0] = outer
        px[x, y1] = inner
        px[x, y0 + 2] = inner
        px[x, y1 - 2] = outer
    for y in range(y0, y1 + 1):
        px[x0, y] = outer
        px[x1, y] = inner
        px[x0 + 2, y] = inner
        px[x1 - 2, y] = outer


def corner_metal(img, cx, cy, sx, sy):
    """Köşe süsü: altın üçgen + perçin. sx/sy köşenin yönü (+1/-1)."""
    px = img.load()
    for i in range(10):
        for j in range(10 - i):
            x, y = cx + sx * i, cy + sy * j
            px[x, y] = GOLD if (i + j) % 7 else GOLD_L
            if i + j == 9:
                px[x, y] = GOLD_D
    px[cx + sx * 3, cy + sy * 3] = INK
    px[cx + sx * 2, cy + sy * 2] = GOLD_L


def emblem(img, cx, cy, r):
    """Denge Tohumu: üçe bölünmüş daire (güneş / su / toprak), altın halka, yapraklar, ışınlar."""
    px = img.load()
    for y in range(cy - r - 12, cy + r + 4):
        for x in range(cx - r - 4, cx + r + 5):
            d = math.hypot(x - cx, y - cy)
            if d <= r - 4:
                ang = math.degrees(math.atan2(y - cy, x - cx))
                if 30 < ang < 150:
                    c = hx("38b764")  # toprak (alt)
                elif ang <= 30 and ang > -90:
                    c = hx("41a6f6")  # su (sağ)
                else:
                    c = hx("f4c542")  # güneş (sol)
                # bölme çizgileri
                for a in (30, 150, -90):
                    da = abs(((ang - a + 180) % 360) - 180)
                    if da * math.pi / 180 * d < 0.9:
                        c = hx("f4f4f4")
                px[x, y] = c
            elif d <= r - 2:
                px[x, y] = INK
            elif d <= r:
                px[x, y] = GOLD if y < cy else GOLD_D
            elif d <= r + 1.5:
                px[x, y] = INK
    for i in range(12):  # ışın noktaları
        a = i * math.pi / 6
        for k in (r + 4, r + 6):
            px[int(cx + math.cos(a) * k), int(cy + math.sin(a) * k)] = hx("ef7d57") if k == r + 6 else GOLD
    for side in (-1, 1):  # yapraklar
        for i in range(9):
            for j in range(-2, 3):
                x = cx + side * (2 + i)
                y = cy - r - 2 - i // 2 + j - (3 - abs(i - 4)) // 2
                if abs(j) <= 2 - abs(i - 4) // 2:
                    px[x, y] = hx("a7f070") if side < 0 else hx("38b764")
        px[cx, cy - r - 1] = hx("257179")
        px[cx, cy - r - 2] = hx("257179")


def cover():
    rng = random.Random(4)
    w, h = 160, 200
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    leather(img, rng, 0, 0, w, h)
    px = img.load()
    for y in range(h):  # cilt sırtı
        for x in range(14):
            px[x, y] = LEATHER_D if x < 12 else INK
    for by in (26, 64, 136, 174):
        for x in range(12):
            px[x, by] = GOLD_D
            px[x, by + 1] = GOLD
    frame(img, 22, 10, 150, 189)
    frame(img, 26, 14, 146, 185, GOLD_D, GOLD_D)
    for cx, cy, sx, sy in ((15, 1, 1, 1), (158, 1, -1, 1), (15, 198, 1, -1), (158, 198, -1, -1)):
        corner_metal(img, cx, cy, sx, sy)
    emblem(img, 86, 112, 26)
    for i in range(8):  # rünler
        a = i * math.pi / 4 + math.pi / 8
        x, y = int(86 + math.cos(a) * 40), int(112 + math.sin(a) * 40)
        for dx, dy in ((0, 0), (0, 1), (1, 1), (0, 2), (-1, 2)) if i % 2 else ((0, 0), (1, 0), (0, 1), (0, 2), (1, 2)):
            px[x + dx, y + dy] = GOLD_D
    for y in range(96, 128):  # kilit kayışı
        for x in range(148, 160):
            px[x, y] = GOLD_D if y in (96, 127) else hx("6b4b45")
    for y in range(106, 118):
        for x in range(146, 156):
            px[x, y] = GOLD if (x + y) % 5 else GOLD_L
    for y in range(109, 115):
        for x in range(148, 153):
            px[x, y] = hx("b13e53") if y > 110 else hx("ff8a7a")
    for x in range(w):  # dış çizgi
        px[x, 0] = INK
        px[x, h - 1] = INK
    for y in range(h):
        px[w - 1, y] = INK
    return img


def page(img, rng, x0, y0, x1, y1, spine_left):
    px = img.load()
    base, mid, edge, shade = hx("ecdcae"), hx("e3cf9b"), hx("d9c38c"), hx("b89a62")
    for y in range(y0, y1):
        for x in range(x0, x1):
            d_edge = min(x - x0, x1 - 1 - x, y - y0, y1 - 1 - y)
            d_spine = (x - x0) if spine_left else (x1 - 1 - x)
            c = base
            if rng.random() < 0.08:
                c = mid if rng.random() < 0.7 else hx("f3e7c2")
            if d_edge < 4:
                c = edge
            if d_edge < 1:
                c = shade
            if d_spine < 10:
                t = 1 - d_spine / 10
                c = shade if t > 0.75 else (edge if t > 0.35 else c)
            px[x, y] = c
    for _ in range(3):  # lekeler
        sx, sy, r = rng.randrange(x0 + 15, x1 - 15), rng.randrange(y0 + 20, y1 - 20), rng.randrange(4, 9)
        for y in range(sy - r, sy + r):
            for x in range(sx - r, sx + r):
                if math.hypot(x - sx, y - sy) < r and rng.random() < 0.5:
                    px[x, y] = mid
    # ince iç çerçeve ve köşe elmasları
    ix0, iy0, ix1, iy1 = x0 + 8, y0 + 8, x1 - 9, y1 - 9
    for x in range(ix0, ix1 + 1):
        px[x, iy0] = shade
        px[x, iy1] = shade
    for y in range(iy0, iy1 + 1):
        px[ix0, y] = shade
        px[ix1, y] = shade
    for cx, cy in ((ix0, iy0), (ix1, iy0), (ix0, iy1), (ix1, iy1)):
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            px[cx + dx, cy + dy] = hx("7a1f2b")


def open_book():
    rng = random.Random(9)
    w, h = 320, 200
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    leather(img, rng, 0, 0, w, h)
    px = img.load()
    # sayfa yığını (dış kenarlar)
    for y in range(8, 194):
        for i, x in enumerate(range(6, 11)):
            px[x, y] = hx("c8b07a") if i % 2 else hx("f0e3bc")
        for i, x in enumerate(range(309, 314)):
            px[x, y] = hx("c8b07a") if i % 2 else hx("f0e3bc")
    page(img, rng, 10, 6, 158, 194, spine_left=False)
    page(img, rng, 162, 6, 310, 194, spine_left=True)
    for y in range(4, 196):  # cilt
        for x in range(158, 162):
            px[x, y] = LEATHER_D if x in (159, 160) else INK
        if y % 8 == 0:
            px[159, y] = GOLD_D
            px[160, y] = GOLD_D
    for cx, cy, sx, sy in ((1, 1, 1, 1), (318, 1, -1, 1), (1, 198, 1, -1), (318, 198, -1, -1)):
        corner_metal(img, cx, cy, sx, sy)
    for y in range(186, 200):  # ayraç kurdelesi: sağ sayfanın altından dışarı sarkar
        for x in range(236, 241):
            if not (x == 238 and y > 196):  # çatallı uç
                px[x, y] = hx("b13e53") if x not in (236, 240) else hx("7a1f2b")
    for x in range(w):
        px[x, 0] = INK
        px[x, h - 1] = INK
    for y in range(h):
        px[0, y] = INK
        px[w - 1, y] = INK
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    cover().save(os.path.join(OUT, "cover.png"))
    open_book().save(os.path.join(OUT, "open.png"))
    print("ok:", OUT)


if __name__ == "__main__":
    main()
