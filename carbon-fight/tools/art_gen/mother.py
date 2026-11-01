"""Kül Ana / Doğa Ana 64x64 — aynı silüet, iki hal.

Doğa Ana: açık yeşil tenli, yapraklarla örülü saçlı, filizlenen dal taçlı tanrıça;
avuçlarının arasında üç renkli Denge Tohumu (Su / Toprak / Güneş) parlar.
Kül Ana: aynı figürün yanmış hali; kül grisi ten, lav çatlakları, közden saç telleri,
kara dal tacı, avuçlarının arasında tohumun koptuğu boş kızıl yuva.
f=0/1 idle kareleri (saç dalgalanır, közler yükselir).
"""
import math
from sprites import Spr

CX = 32


def _hair(s, f, P, burning):
    # başın arkasından omuzlara, oradan aşağı akan dalgalı kütle
    for y in range(7, 61):
        t = (y - 7) / 53.0
        half = 8.5 + 14 * math.sin(min(1.0, t * 1.4) * math.pi / 2)
        half += 1.6 * math.sin(y * 0.5 + (f * 1.6 if burning else f * 0.8))
        if t > 0.78:
            half -= (t - 0.78) * 26
        if y < 13:
            half = math.sqrt(max(0.0, 64 - (13 - y) ** 2 * 1.4)) + 1
        for x in range(int(round(CX - half)), int(round(CX + half)) + 1):
            s.px(x, y, P['hair'])
    # sivri uçlar
    for i, (x, y, l) in enumerate([(11, 52, 9), (16, 56, 7), (48, 56, 7), (53, 52, 9)]):
        sway = (1 if (i + f) % 2 else -1)
        for k in range(l):
            w = 1 if k < l // 2 else 0
            xx = x + (sway * k) // 3
            s.rect(xx - w, y + k, xx + w, y + k, P['hair'])
    # Kül Ana: saç kenarından yükselen alev dilleri
    if burning:
        for i, y in enumerate(range(16, 54, 6)):
            for side in (-1, 1):
                row = [x for x in range(64) if s.img.getpixel((x, y))[3] > 0]
                if not row:
                    continue
                ex = row[0] if side < 0 else row[-1]
                h = 3 + ((i + f + (side > 0)) % 3)
                for k in range(h):
                    xx = ex + side * (1 + k // 2)
                    s.px(xx, y - k, 'r' if k < h - 1 else 'o')
                    if k < h - 2:
                        s.px(xx - side, y - k, 'r')
    # yalnızca dış kısımda birkaç tel (yüz ve gövdeyi kirletmesin)
    for side in (-1, 1):
        for j, off in enumerate((12, 17)):
            for y in range(16, 58 - j * 3):
                t = (y - 16) / 42.0
                x = CX + side * (off * (0.62 + 0.5 * t) + 1.4 * math.sin(y * 0.42 + j * 2 + f * 1.6))
                x = int(round(x))
                if s.img.getpixel((x, y))[3] > 0:
                    s.px(x, y, P['hair2'] if j == 0 else P['hair3'])


def _leaves(s, f):
    """Saç kütlesini yaprak örgüsüne çevirir: koyu zemin üstünde küçük çift tonlu yapraklar."""
    dg = s.img.getpixel((CX, 30))
    for y in range(14, 60, 4):
        for x in range(4, 61, 5):
            xx = x + (2 if (y // 4) % 2 else 0)
            if s.img.getpixel((xx, y))[3] == 0 or s.img.getpixel((xx, y)) != dg:
                continue
            if s.img.getpixel((xx + 1, y - 1))[3] == 0:
                continue
            s.px(xx, y, 'g'); s.px(xx + 1, y - 1, 'lg')
            if (x + y + f) % 3 == 0:
                s.px(xx - 1, y + 1, 'g')


def _crown(s, f, green):
    if green:
        # Kül Ana'nın kara dal tacının canlanmış hali: aynı dallar, uçlarında yaprak ve tomurcuk
        for d in (-1, 1):
            bx = CX + d * 4
            pts = [(bx, 10), (bx + d * 2, 6), (bx + d * 3, 3), (bx + d * 6, 1)]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                s.line(x0, y0, x1, y1, 'dg')
            s.line(bx + d * 2, 6, bx + d * 5, 5, 'dg')
            s.pxs([(bx + d * 6, 1), (bx + d * 7, 1), (bx + d * 6, 0)], 'lg')
            s.pxs([(bx + d * 5, 5), (bx + d * 6, 4)], 'g')
            s.px(bx + d * 3, 4 - f % 2, 'lg')
        s.line(CX, 9, CX, 4, 'dg')
        s.pxs([(CX - 1, 3), (CX + 1, 3)], 'lg')
        s.px(CX, 2, 'y' if f == 0 else 'lg')
    else:
        for d in (-1, 1):
            bx = CX + d * 4
            pts = [(bx, 10), (bx + d * 2, 6), (bx + d * 3, 3), (bx + d * 6, 1)]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                s.line(x0, y0, x1, y1, 'dk')
            s.line(bx + d * 2, 6, bx + d * 5, 5, 'dk')
            s.px(bx + d * 6, 1, 'o' if f == 0 else 'y')
            s.px(bx + d * 5, 5, 'r')
        s.line(CX, 9, CX, 4, 'dk')
        s.px(CX, 3, 'y' if f == 0 else 'o')


def mother(f=0, green=False):
    s = Spr(64, 64)
    burning = not green
    if green:
        P = dict(hair='dg', hair2='g', hair3='g',
                 skin='lg', skin_sh='g', skin_hi='w',
                 dress='g', dress_sh='dg', dress_hi='lg',
                 sleeve='g', sleeve_sh='dg')
    else:
        P = dict(hair='k', hair2='r', hair3='o',
                 skin='gl', skin_sh='gr', skin_hi='w',
                 dress='dk', dress_sh='k', dress_hi='gr',
                 sleeve='dk', sleeve_sh='k')

    _hair(s, f, P, burning)
    if green:
        _leaves(s, f)

    # ---- elbise (akışkan, aşağı açılan)
    s.poly([(23, 34), (41, 34), (49, 63), (15, 63)], P['dress'])
    s.poly([(23, 36), (27, 36), (21, 63), (15, 63)], P['dress_sh'])
    s.poly([(38, 44), (41, 44), (46, 63), (41, 63)], P['dress_sh'])
    s.line(33, 48, 31, 63, P['dress_sh'])
    s.line(29, 50, 27, 63, P['dress_hi'])
    # etek ucu
    for x in range(15, 49, 4):
        if green:
            s.poly([(x, 63), (x + 2, 60), (x + 4, 63)], 'lg')
            s.px(x + 2, 61, 'y') if x % 8 == 3 else None
        else:
            h = 3 + ((x // 4 + f) % 3)
            s.poly([(x, 63), (x + 2, 63 - h), (x + 4, 63)], 'r')
            s.px(x + 2, 63 - h + 2, 'o')

    # ---- boyun, omuz, yaka
    s.rect(30, 29, 34, 34, P['skin'])
    s.rect(33, 30, 34, 33, P['skin_sh'])
    s.ell(32, 35, 9, 2.5, P['dress'])
    for x in range(24, 41, 2):
        if green:
            s.px(x, 34 + (x // 2) % 2, 'lg')
        else:
            s.px(x, 34 + (x // 2) % 2, 'r')
    s.ell(32, 34, 3, 1.3, P['skin'])

    # ---- kollar: omuzdan inen geniş yenler, avuçlar göğüs altında birleşir
    for d in (-1, 1):
        sx = CX + d * 9
        s.poly([(sx, 35), (sx + d * 3, 38), (CX + d * 6, 46), (CX + d * 3, 46), (CX + d * 4, 40), (sx - d * 2, 37)], P['sleeve'])
        s.line(sx + d * 2, 38, CX + d * 5, 45, P['sleeve_sh'])
        # yen ucu sarkması
        s.poly([(CX + d * 6, 44), (CX + d * 10, 49), (CX + d * 5, 47)], P['sleeve_sh'])
    # eller
    s.ell(28.5, 45.5, 2.6, 1.8, P['skin'])
    s.ell(35.5, 45.5, 2.6, 1.8, P['skin'])
    s.pxs([(30, 47), (34, 47)], P['skin_sh'])

    # ---- tohum / boş yuva (avuçların üstünde)
    if green:
        # üç renkli Denge Tohumu: sol üst Güneş, sağ üst Su, alt Toprak
        s.ell(32, 41, 4.4, 4.4, 'dk')
        s.ell(32, 41, 3.4, 3.4, 'lg')
        s.rect(29, 38, 31, 40, 'y'); s.rect(33, 38, 35, 40, 'lb')
        s.line(32, 38, 32, 41, 'w'); s.line(29, 41, 35, 41, 'w')
        s.px(30, 39, 'w')
        s.line(32, 36, 32, 35, 'g'); s.px(31, 34, 'lg'); s.px(33, 34, 'lg')
        for x, y in [(27, 39), (37, 39), (32, 33)]:
            s.px(x, y, 'y' if f == 0 else 'lg')
    else:
        s.ell(32, 42, 2.6, 2.6, 'r')
        s.ell(32, 42, 1.3, 1.3, 'k')
        s.px(32, 39, 'o')
        # lav çatlakları
        col = 'o' if f == 0 else 'y'
        s.line(31, 48, 29, 54, col); s.line(29, 54, 30, 59, col)
        s.line(37, 50, 40, 57, 'r'); s.line(40, 57, 39, 61, col)
        s.line(23, 52, 21, 58, 'r')
        s.px(29, 54, 'y'); s.px(40, 57, 'y')

    # ---- yüz
    s.ell(32, 21, 7, 8.5, P['skin'])
    s.rect(29, 28, 35, 29, P['skin'])
    for y in range(16, 28):
        s.px(38 if y < 25 else 37, y, P['skin_sh'])
    s.pxs([(35, 29), (34, 29)], P['skin_sh'])
    # ortadan ayrılmış perçem, yüzü çerçeveler
    s.poly([(24, 20), (25, 14), (29, 11), (32, 12), (35, 11), (39, 14), (40, 20), (38, 15), (32, 14), (26, 15)], P['hair'])
    s.line(26, 15, 31, 12, P['hair2'])
    s.line(33, 12, 38, 15, P['hair2'])
    s.line(24, 18, 24, 27, P['hair']); s.line(40, 18, 40, 27, P['hair'])

    if green:
        # huzurlu kapalı gözler, kirpik kavisleri
        s.pxs([(27, 21), (28, 22), (29, 22), (30, 21)], 'dk')
        s.pxs([(34, 21), (35, 22), (36, 22), (37, 21)], 'dk')
        s.pxs([(28, 18), (29, 18)], 'g'); s.pxs([(35, 18), (36, 18)], 'g')
        s.pxs([(27, 24), (28, 24), (36, 24), (37, 24)], 'o')
        s.pxs([(31, 26), (32, 27), (33, 26)], 'dg')
        s.px(32, 16, 'y')                  # alında tohum işareti
        s.px(33, 24, 'g')                  # burun gölgesi
        s.pxs([(28, 19), (36, 19)], P['skin_hi']) if False else None
    else:
        # çatık kaşlar, kor gözler
        s.line(26, 18, 30, 20, 'k'); s.line(38, 18, 34, 20, 'k')
        s.rect(27, 21, 30, 22, 'k'); s.rect(34, 21, 37, 22, 'k')
        s.rect(28, 21, 29, 21, 'y'); s.rect(35, 21, 36, 21, 'y')
        s.pxs([(28, 22), (29, 22), (35, 22), (36, 22)], 'o' if f == 0 else 'r')
        s.rect(30, 26, 34, 26, 'k'); s.pxs([(29, 27), (35, 27)], 'k')
        # yüz çatlakları
        s.line(27, 23, 26, 27, 'r'); s.px(26, 25, 'o')
        s.line(36, 24, 37, 27, 'o')
        s.px(32, 16, 'r'); s.px(32, 17, 'o')
        s.px(33, 24, 'gr')

    _crown(s, f, green)
    s.outline()

    # ---- çevre parçacıkları
    if green:
        for x, y, c in [(5, 14, 'lg'), (58, 10, 'y'), (6, 42, 'g'), (58, 38, 'lg'), (3, 27, 'y'), (61, 53, 'g')]:
            s.px(x, y, c)
        s.pxs([(8, 31), (9, 30), (9, 31)], 'lg')
        s.pxs([(56, 23), (55, 22), (55, 23)], 'g')
    else:
        r = f * 2
        for x, y, c in [(6, 20 - r, 'o'), (58, 14 - r, 'y'), (8, 44 - r, 'r'), (57, 40 - r, 'o'),
                        (4, 6 + r, 'gr'), (60, 28 + r, 'gr'), (51, 4 - f, 'r')]:
            s.px(x, y, c)
    return s
