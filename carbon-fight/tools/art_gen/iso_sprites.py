"""CarbonFight 2.5D (izometrik) yer tutucu üretici: karolar, harita zeminleri, binalar, UI çerçeveleri.

Kullanım:  python iso_sprites.py ../../assets
Tüm çıktılar art çözünürlüğündedir (oyun 2x büyütür). Ölçüler ve çapa noktaları: assets/README.md
Kendi çizimlerini aynı ad ve boyutla üzerine yazman yeterli; bu script yalnızca eksik/yer tutucu üretir.
"""
import os
import sys
import random
import numpy as np
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "out"
SPRITES = os.path.join(ROOT, "sprites")
ISO = os.path.join(SPRITES, "iso")
BUILD = os.path.join(SPRITES, "buildings")
UI = os.path.join(ROOT, "ui")

OUTLINE = (26, 28, 44, 255)

# Karo: üst elmas 64x32, yan yüz kalınlığı 8 -> 64x40
TW, TH, DEPTH = 64, 32, 8
# Tahtada karolar arası boşluk (yatay; dikeyde yarısı). scripts/ui/iso_board.gd GAP ile aynı olmalı.
GAP = 12


def hexc(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3],)


def add_outline(img, color=OUTLINE):
    a = np.array(img)
    alpha = a[:, :, 3] > 0
    n = np.zeros_like(alpha)
    n[1:, :] |= alpha[:-1, :]
    n[:-1, :] |= alpha[1:, :]
    n[:, 1:] |= alpha[:, :-1]
    n[:, :-1] |= alpha[:, 1:]
    a[n & ~alpha] = color
    return Image.fromarray(a).copy()


def diamond(cx, cy, hw, hh):
    return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def in_diamond(x, y, cx, cy, hw, hh):
    return abs(x + 0.5 - cx) / hw + abs(y + 0.5 - cy) / hh <= 1.0


# --- Karolar ve zeminler ---------------------------------------------------------

MAPS = {
    # id: (üst renk, desen rengi, zemin rengi, dekor renkleri)
    "dumanli_vadi": ("5a7d4f", "4a6b42", "6e8a5c", ["3d5c3a", "94b0c2", "566c86"]),
    "solgun_korfez": ("c9b78a", "b3a276", "d6c79c", ["41a6f6", "73eff7", "8a7a5c"]),
    "gri_sehir": ("7a8494", "6a7382", "8b94a3", ["566c86", "333c57", "ffcd75"]),
    "kul_ormani": ("6b4b45", "5a3d38", "7a5650", ["ef7d57", "333c57", "b13e53"]),
}
DEFAULT_MAP = ("5f8a5a", "527a4e", "73975f", ["3d5c3a", "94b0c2", "566c86"])


def iso_block_img(w, h, cx, cy, hw, hh, depth, top, pattern=None, rng=None):
    """Kalınlığı olan elmas blok (karo / ada)."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            # Üst yüz
            if in_diamond(x, y, cx, cy, hw, hh):
                c = top
                if pattern is not None and (x // 2 + y) % 6 == 0 and rng.random() < 0.5:
                    c = pattern
                # sol üst kenar aydınlık
                d = abs(x + 0.5 - cx) / hw + abs(y + 0.5 - cy) / hh
                if d > 0.92 and y < cy:
                    c = shade(top, 1.18)
                px[x, y] = c
                continue
            # Yan yüzler: alt kenarın altında depth kadar
            for k in range(1, depth + 1):
                if in_diamond(x, y - k, cx, cy, hw, hh) and y - k >= cy:
                    left = x < cx
                    c = shade(top, 0.62 if left else 0.45)
                    if k == depth:
                        c = shade(c, 0.8)
                    px[x, y] = c
                    break
    return add_outline(img)


def make_tile(top_hex, pat_hex, seed):
    rng = random.Random(seed)
    w, h = TW, TH + DEPTH
    img = iso_block_img(w, h, TW / 2, TH / 2, TW / 2 - 1, TH / 2 - 0.5, DEPTH - 1, hexc(top_hex), hexc(pat_hex), rng)
    return img


def make_ground(top_hex, decor, seed):
    """Tahtanın altındaki ada: 3x3 tahtadan bir karo daha geniş elmas, 16 kalınlık.
    Boyut ve merkez GAP'e bağlı (GAP=12 -> 288x160, merkez (144, 72)); iso_board.gd GROUND_CENTER ile aynı."""
    rng = random.Random(seed)
    board_hw = (TW + GAP) + TW // 2  # 3x3 tahtanın yarı genişliği
    cx = board_hw + 36
    cy = cx // 2
    w, h = cx * 2, cy * 2 + 16
    top = hexc(top_hex)
    img = iso_block_img(w, h, cx, cy, cx - 1, cy - 0.5, 15, top, shade(top, 0.9), rng)
    px = img.load()
    # Dekor: tahtanın dışına (adanın kenar şeridine) küçük ağaç/kaya/çim noktaları
    for _ in range(int(600 * (cx / 128) ** 2)):
        x, y = rng.randrange(8, w - 8), rng.randrange(6, cy * 2 - 6)
        if not in_diamond(x, y, cx, cy, cx - 8, cy - 6) or in_diamond(x, y, cx, cy, board_hw + 1, board_hw / 2 + 0.5):
            continue
        c = hexc(rng.choice(decor))
        kind = rng.random()
        if kind < 0.45:  # çim tutamı
            for dx, dy in ((0, 0), (1, -1), (2, 0)):
                px[x + dx, y + dy] = c
        elif kind < 0.75:  # kaya
            for dx in range(3):
                for dy in range(2):
                    px[x + dx, y + dy] = c
            px[x + 1, y - 1] = shade(c, 1.25)
        else:  # küçük ağaç
            trunk = hexc("5d275d")
            px[x, y] = trunk
            px[x, y - 1] = trunk
            for dx in range(-2, 3):
                for dy in range(-5, -1):
                    if abs(dx) + abs(dy + 3) <= 2:
                        px[x + dx, y + dy] = c
    return add_outline(img)


def square_to_diamond(src, w=TW, h=TH):
    """Kare karo dokusunu izometrik elmasa yansıt (mevcut 44x44 karolardan üretmek için)."""
    s = src.convert("RGBA")
    sw, sh = s.size
    sp = s.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            if not in_diamond(x, y, w / 2, h / 2, w / 2, h / 2):
                continue
            fx, fy = (x + 0.5 - w / 2) / w, (y + 0.5) / h
            u, v = fx + fy, fy - fx
            if 0 <= u < 1 and 0 <= v < 1:
                op[x, y] = sp[int(u * sw), int(v * sh)]
    return out


# --- Binalar (64x64 tuval; zemin elması alt yarıda, merkez (32, 48)) -----------------

def block(d, cx, by, hw, height, color, top=None):
    """Zemin merkezi (cx, by) olan, yarı genişliği hw ve yüksekliği height olan izometrik kutu."""
    hh = hw / 2
    L, B, R, T = (cx - hw, by), (cx, by + hh), (cx + hw, by), (cx, by - hh)
    up = lambda p: (p[0], p[1] - height)
    d.polygon([L, B, up(B), up(L)], fill=color)
    d.polygon([B, R, up(R), up(B)], fill=shade(color, 0.72))
    d.polygon([up(T), up(R), up(B), up(L)], fill=top or shade(color, 1.22))


def window_rows(d, cx, by, hw, height, color, every=5):
    hh = hw / 2
    for h in range(4, int(height) - 2, every):
        for i in range(3, int(hw) - 1, 4):
            d.rectangle([cx - hw + i, by + i * hh / hw - h - 1, cx - hw + i + 1, by + i * hh / hw - h], fill=color)
            d.rectangle([cx + hw - i - 1, by + i * hh / hw - h - 1, cx + hw - i, by + i * hh / hw - h],
                        fill=shade(color, 0.75))


def new_building():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def b_gunes_tarlasi():
    img, d = new_building()
    block(d, 32, 48, 26, 3, hexc("38b764"))
    for k in (-12, 0, 12):  # panel sıraları
        cx, cy = 32 + k * 0.5, 45 + k * 0.25 - 4
        block(d, cx + k * 0.5, cy + k * 0.25, 9, 4, hexc("29366f"), hexc("41a6f6"))
    return add_outline(img)


def b_dikey_tarim():
    img, d = new_building()
    block(d, 32, 48, 16, 38, hexc("94b0c2"), hexc("a7f070"))
    window_rows(d, 32, 48, 16, 38, hexc("38b764"), 5)
    return add_outline(img)


def b_mavi_karbon():
    img, d = new_building()
    block(d, 32, 48, 26, 2, hexc("c9b78a"))
    block(d, 32, 47, 17, 1, hexc("3b5dc9"), hexc("41a6f6"))
    for x, y in ((20, 44), (40, 40), (30, 37), (44, 47)):
        d.line([x, y, x, y - 4], fill=hexc("38b764"))
        d.point((x + 1, y - 3), fill=hexc("a7f070"))
    return add_outline(img)


def b_yesil_cati():
    img, d = new_building()
    block(d, 32, 48, 20, 16, hexc("b13e53"), hexc("38b764"))
    window_rows(d, 32, 48, 20, 16, hexc("ffcd75"), 6)
    for x in (26, 32, 38):
        d.point((x, 28 + abs(x - 32) // 2), fill=hexc("a7f070"))
    return add_outline(img)


def b_toplu_tasima():
    img, d = new_building()
    block(d, 32, 48, 26, 2, hexc("566c86"))
    block(d, 30, 47, 14, 10, hexc("ef7d57"), hexc("ffcd75"))
    window_rows(d, 30, 47, 14, 10, hexc("73eff7"), 6)
    d.rectangle([46, 30, 47, 44], fill=hexc("94b0c2"))
    d.rectangle([44, 28, 49, 31], fill=hexc("3b5dc9"))
    return add_outline(img)


def b_komur_santrali():
    img, d = new_building()
    block(d, 30, 48, 20, 14, hexc("566c86"), hexc("94b0c2"))
    window_rows(d, 30, 48, 20, 14, hexc("ef7d57"), 6)
    for cx, h in ((38, 34), (44, 28)):
        block(d, cx, 44 - (cx - 38) // 2, 4, h, hexc("333c57"), hexc("1a1c2c"))
        d.rectangle([cx - 4, 44 - (cx - 38) // 2 - h + 6, cx + 4, 44 - (cx - 38) // 2 - h + 7], fill=hexc("b13e53"))
    for x, y, r in ((36, 6, 3), (41, 3, 4), (47, 9, 3)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=hexc("94b0c2"))
    return add_outline(img)


def b_pedestal(icon_path):
    """Özel kartlar (tohum, parçalar): kaide + mevcut 32x32 ikon."""
    img, d = new_building()
    block(d, 32, 48, 14, 6, hexc("566c86"), hexc("94b0c2"))
    if os.path.exists(icon_path):
        icon = Image.open(icon_path).convert("RGBA")
        img.alpha_composite(icon, (16, 9))
    return add_outline(img)


BUILDINGS = {
    "gunes_tarlasi": b_gunes_tarlasi,
    "dikey_tarim": b_dikey_tarim,
    "mavi_karbon": b_mavi_karbon,
    "yesil_cati": b_yesil_cati,
    "toplu_tasima": b_toplu_tasima,
    "komur_santrali": b_komur_santrali,
}
PEDESTALS = ["denge_tohumu", "shard_gunes", "shard_su", "shard_toprak"]


# --- UI çerçeveleri (9-slice, kenar payı 4) -------------------------------------------

def frame(bg, border, size=16):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    n = size
    for y in range(n):
        for x in range(n):
            if (x in (0, n - 1)) and (y in (0, n - 1)):
                continue
            dd = min(x, y, n - 1 - x, n - 1 - y)
            lit = dd == x or dd == y
            if dd == 0:
                c = OUTLINE
            elif dd == 1 and border is not None:
                c = shade(border, 1.25) if lit else shade(border, 0.75)
            elif dd == (2 if border is not None else 1):
                c = shade(bg, 1.12) if lit else shade(bg, 0.7)
            else:
                c = bg
            px[x, y] = c
    return img


def save(img, *path):
    p = os.path.join(*path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    print("ok:", os.path.relpath(p, ROOT))


def main():
    # Karolar ve zeminler
    save(make_tile(DEFAULT_MAP[0], DEFAULT_MAP[1], 1), ISO, "tile.png")
    save(make_ground(DEFAULT_MAP[2], DEFAULT_MAP[3], 2), ISO, "ground.png")
    for i, (mid, (top, pat, ground, decor)) in enumerate(MAPS.items()):
        save(make_tile(top, pat, 10 + i), ISO, f"tile_{mid}.png")
        save(make_ground(ground, decor, 20 + i), ISO, f"ground_{mid}.png")

    # Zemin katmanları: mevcut kare karolardan elmasa
    tiles_dir = os.path.join(SPRITES, "tiles")
    for name in ("asphalt", "green", "altar", "hot"):
        src = os.path.join(tiles_dir, name + ".png")
        if os.path.exists(src):
            save(square_to_diamond(Image.open(src)), ISO, f"overlay_{name}.png")

    # Ayakta duran nesneler (64x64, zemin merkezi (32, 48))
    for name in ("smoke", "trash"):
        src = os.path.join(tiles_dir, name + ".png")
        if os.path.exists(src):
            s = Image.open(src).convert("RGBA")
            canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            canvas.alpha_composite(s, ((64 - s.width) // 2, 50 - s.height))
            save(canvas, ISO, f"prop_{name}.png")

    # Binalar
    for cid, fn in BUILDINGS.items():
        save(fn(), BUILD, f"{cid}.png")
    for cid in PEDESTALS:
        save(b_pedestal(os.path.join(SPRITES, "cards", cid + ".png")), BUILD, f"{cid}.png")

    # UI çerçeveleri
    save(frame(hexc("333c57", 235), hexc("566c86")), UI, "panel.png")
    save(frame(hexc("257179"), hexc("a7f070")), UI, "button_normal.png")
    save(frame(hexc("38b764"), hexc("f4f4f4")), UI, "button_hover.png")
    save(frame(hexc("29366f"), hexc("73eff7")), UI, "button_pressed.png")
    save(frame(hexc("333c57"), hexc("566c86")), UI, "button_disabled.png")
    # Kart çerçevesi gri tonlu: oyun kartın rengiyle boyar (modulate).
    save(frame(hexc("484848"), hexc("f4f4f4")), UI, "card_frame.png")


if __name__ == "__main__":
    main()
