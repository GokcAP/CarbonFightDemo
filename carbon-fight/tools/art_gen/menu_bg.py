"""Ana menü arka planı (pixel art, 320x180): iyileşen vadi ↔ kirli şehir, ortada yarısı kurumuş Denge Ağacı.

Kullanım:  python menu_bg.py ../../assets/sprites/menu
Çıktılar (oyun 4x büyütür, hareketleri scripts/ui/menu_background.gd verir):
  sky.png          320x180  gökyüzü (solda şafak, sağda is)
  clouds_far.png   640x60   uzak bulutlar (yatayda döşenebilir)
  clouds_near.png  640x60   yakın bulutlar (yatayda döşenebilir)
  land.png         320x180  dağlar, vadi, nehir, ağaç, şehir, zemin (üstü saydam)
Koordinatlar (ağaç tacı, bacalar, nehir) menu_background.gd ile aynı olmalı.
"""
import math
import os
import random
import sys

from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
W, H = 320, 180
HORIZON = 118
TREE = (160, 72)        # taç merkezi
TREE_R = 30
CHIMNEYS = [(229, 62), (259, 56), (297, 66)]  # baca ağızları (x, y)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hx(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def dith(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16


def band(stops, t, x, y):
    t = min(max(t, 0.0), 1.0)
    f = t * (len(stops) - 1)
    i = int(f)
    if i >= len(stops) - 1:
        return stops[-1]
    return stops[i + 1] if f - i > dith(x, y) else stops[i]


def river_center(y):
    return 70 - (y - HORIZON) * 0.95 + 6 * math.sin(y * 0.12)


def river_half(y):
    return 1 + (y - HORIZON) * 0.11


def outline(img, color=hx("1a1c2c")):
    px = img.load()
    w, h = img.size
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 255:
                    edge.append((x, y))
                    break
    for p in edge:
        px[p] = color


# --- Gökyüzü ---------------------------------------------------------------------

def sky():
    img = Image.new("RGBA", (W, H))
    px = img.load()
    left = [hx(c) for c in ("1a1c2c", "29366f", "3b5dc9", "41a6f6", "73eff7")]
    right = [hx(c) for c in ("1a1c2c", "333c57", "5d275d", "b13e53", "ef7d57")]
    for y in range(H):
        for x in range(W):
            mix = min(max((x - 110) / 110, 0.0), 1.0)
            stops = right if mix > dith(x + 1, y + 2) else left
            px[x, y] = band(stops, y / HORIZON, x, y)
    return img


# --- Bulutlar --------------------------------------------------------------------

def clouds(seed, count, color, shade, alpha, ymin, ymax, size):
    rng = random.Random(seed)
    w, h = 640, 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for _ in range(count):
        cx, cy = rng.randrange(w), rng.randrange(ymin, ymax)
        length, thick = rng.randrange(size, size * 3), rng.randrange(3, 7)
        for i in range(length):
            bump = int(thick * (0.6 + 0.4 * math.sin(i * 0.35 + cx)))
            for j in range(-bump, 2):
                x, y = (cx + i) % w, cy + j
                if 0 <= y < h:
                    px[x, y] = hx(shade if j == 1 else color, alpha)
    return img


# --- Arazi -----------------------------------------------------------------------

def land():
    rng = random.Random(7)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = c

    # Uzak dağlar
    for x in range(W):
        top = int(96 + 8 * math.sin(x * 0.031) + 5 * math.sin(x * 0.083 + 1.7) + 3 * math.sin(x * 0.19))
        for y in range(top, HORIZON + 1):
            c = hx("333c57") if x < 170 else hx("3a2c4e")
            if y == top:
                c = hx("566c86") if x < 170 else hx("5d275d")
            put(x, y, c)

    # Sol: yeşil tepeler
    for x in range(0, 175):
        top = int(110 + 5 * math.sin(x * 0.07) + 3 * math.sin(x * 0.17 + 2))
        for y in range(top, 131):
            put(x, y, band([hx("38b764"), hx("257179"), hx("257179")], (y - top) / 14, x, y))
        if x % 9 == 0 and x < 150:  # küçük ağaçlar
            th = rng.randrange(5, 9)
            for dy in range(th):
                for dx in range(-2, 3):
                    if abs(dx) <= (dy + 1) // 2:
                        put(x + dx, top - th + dy, hx("a7f070") if dx < 0 and dy < 3 else hx("38b764"))
            put(x, top, hx("5d275d"))

    # Sağ: gri şehir
    x = 196
    while x < W:
        bw, bh = rng.randrange(8, 16), rng.randrange(14, 42)
        top = 124 - bh
        for yy in range(top, 125):
            for xx in range(x, min(x + bw, W)):
                c = hx("566c86") if xx == x else hx("333c57")
                if yy == top:
                    c = hx("94b0c2")
                put(xx, yy, c)
        for yy in range(top + 3, 120, 4):  # pencereler
            for xx in range(x + 2, min(x + bw - 1, W), 3):
                if rng.random() < 0.45:
                    put(xx, yy, hx("ffcd75"))
        x += bw + rng.randrange(0, 3)
    for cx, cy in CHIMNEYS:  # bacalar
        for yy in range(cy, 125):
            for xx in range(cx - 2, cx + 3):
                c = hx("1a1c2c") if xx in (cx - 2, cx + 2) else hx("333c57")
                if (yy - cy) % 9 in (3, 4):
                    c = hx("b13e53")
                put(xx, yy, c)
    # Şehrin üstünde turuncu is
    for yy in range(96, 126):
        for xx in range(190, W):
            if px[xx, yy][3] == 0 and ((yy - 96) / 30) > dith(xx, yy) * 1.6:
                put(xx, yy, hx("b13e53", 120))

    # Zemin
    for y in range(124, H):
        for x in range(W):
            t = (y - 124) / (H - 124)
            if x < 160 - (y - 124) * 0.6:
                c = band([hx("38b764"), hx("257179"), hx("1f4a3a")], t, x, y)
            elif x > 160 + (y - 124) * 0.6:
                c = band([hx("566c86"), hx("333c57"), hx("262b3f")], t, x, y)
            else:
                c = band([hx("94b0c2"), hx("566c86")], t, x, y)  # taş yol
            put(x, y, c)
    for _ in range(160):  # sol: çiçekler ve çimen, sağ: kor çatlakları
        x, y = rng.randrange(W), rng.randrange(128, H)
        if x < 150 - (y - 124) * 0.6:
            put(x, y, hx(rng.choice(["a7f070", "f27fb2", "ffcd75", "f4f4f4"])))
        elif x > 170 + (y - 124) * 0.6:
            for i in range(rng.randrange(2, 6)):
                put(x + i, y + (i % 2), hx("ef7d57" if i % 3 else "b13e53"))

    # Nehir (sol)
    for y in range(HORIZON, H):
        c, half = river_center(y), river_half(y)
        for x in range(int(c - half), int(c + half) + 1):
            edge = abs(x - c) > half - 1
            put(x, y, hx("41a6f6") if edge else hx("3b5dc9"))

    # Denge Ağacı (ortada): gövde + yarısı yeşil, yarısı kuru taç
    tx, ty = TREE
    tree = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tp = tree.load()
    # Gövde ve kökler
    for y in range(ty + 8, 129):
        half = 3 + (y - ty - 8) // 10 + (3 if y > 124 else 0)
        for x in range(tx - half, tx + half + 1):
            tp[x, y] = hx("6b4b45") if x < tx else hx("4a3530")
    # Ana dallar (taç bunların üstüne oturur)
    for dx, dy in ((-14, -14), (13, -15), (-5, -22), (6, -24)):
        for i in range(24):
            x = int(tx + dx * i / 23)
            y = int(ty + 10 + dy * i / 23)
            for w in (0, 1):
                tp[x + w, y] = hx("4a3530")
    # Taç: yuvarlak kümeler. Solda canlı yaprak, sağda kurumuş kül yaprakları ve közler;
    # ortada iki taraf titreşimli (dither) karışır.
    blobs = [(-16, -2, 13), (-6, -14, 14), (8, -15, 13), (17, -3, 12), (0, -2, 15),
             (-22, 8, 9), (22, 8, 9), (-9, 6, 11), (10, 6, 11)]
    leaf = [hx("a7f070"), hx("38b764"), hx("257179")]
    dead = [hx("94b0c2"), hx("566c86"), hx("333c57")]
    for y in range(ty - 32, ty + 20):
        for x in range(tx - 34, tx + 35):
            inside = False
            for bx, by, r in blobs:
                n = 1.0 + 0.12 * math.sin(x * 1.3 + y * 0.7)
                if math.hypot(x - tx - bx, y - ty - by) < r * n:
                    inside = True
                    break
            if not inside:
                continue
            shade = (y - ty + 30) / 52
            side = (x - tx + 6) / 12  # 0 = tam canlı, 1 = tam kuru
            alive = side < dith(x, y)
            c = band(leaf if alive else dead, shade, x, y)
            if not alive and (x * 7 + y * 13) % 23 == 0:
                c = hx("ef7d57")  # kor
            if not alive and (x * 5 + y * 3) % 11 == 0:
                continue  # kurumuş tarafta seyrek boşluklar
            tp[x, y] = c
    # Kurumuş taraftan dışarı uzanan çıplak dallar
    for sx, sy, ex, ey in ((tx + 26, ty - 8, tx + 34, ty - 16), (tx + 22, ty + 12, tx + 31, ty + 16),
                           (tx + 12, ty - 26, tx + 16, ty - 33)):
        for i in range(10):
            x = int(sx + (ex - sx) * i / 9)
            y = int(sy + (ey - sy) * i / 9)
            tp[x, y] = hx("333c57")
    outline(tree)
    img.alpha_composite(tree)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    sky().save(os.path.join(OUT, "sky.png"))
    clouds(1, 10, "566c86", "333c57", 170, 8, 40, 14).save(os.path.join(OUT, "clouds_far.png"))
    clouds(2, 7, "94b0c2", "566c86", 200, 18, 52, 20).save(os.path.join(OUT, "clouds_near.png"))
    land().save(os.path.join(OUT, "land.png"))
    print("ok:", OUT)


if __name__ == "__main__":
    main()
