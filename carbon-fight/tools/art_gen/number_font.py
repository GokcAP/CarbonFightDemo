"""Okunur rakamlı oyun fontu: Pixelify Sans + kalın, net pixel rakamlar (0-9, +, -).

Kullanım:  python number_font.py ../../assets/fonts
Girdi:  PixelifySans.ttf (SIL OFL 1.1)   Çıktı: CarbonFightPixel.ttf (aynı lisansla, yeni adla)

Rakamlar 125 birimlik ızgaraya çizilir (1000 birim/em): 16 pikselde 2, 24 pikselde 3, 32 pikselde 4 ekran
pikseline tam oturur; bu yüzden her boyutta keskin ve kalın görünür. Harfler değişmez.
"""
import os
import sys

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

DIR = sys.argv[1] if len(sys.argv) > 1 else "."
SRC = os.path.join(DIR, "PixelifySans.ttf")
DST = os.path.join(DIR, "CarbonFightPixel.ttf")
FAMILY = "CarbonFight Pixel"

U = 125          # bir "piksel" (font birimi)
ADVANCE = 5 * U  # 4 sütun rakam + 1 sütun boşluk

GLYPHS = {
    "0": [".##.", "#..#", "#.##", "##.#", "#..#", ".##."],
    "1": ["..#.", ".##.", "..#.", "..#.", "..#.", ".###"],
    "2": [".##.", "#..#", "...#", "..#.", ".#..", "####"],
    "3": ["###.", "...#", ".##.", "...#", "...#", "###."],
    "4": ["#..#", "#..#", "#..#", "####", "...#", "...#"],
    "5": ["####", "#...", "###.", "...#", "...#", "###."],
    "6": [".##.", "#...", "###.", "#..#", "#..#", ".##."],
    "7": ["####", "...#", "..#.", ".#..", ".#..", ".#.."],
    "8": [".##.", "#..#", ".##.", "#..#", "#..#", ".##."],
    "9": [".##.", "#..#", "#..#", ".###", "...#", ".##."],
    "+": ["....", "....", ".#..", "###.", ".#..", "...."],
    "-": ["....", "....", "....", "###.", "....", "...."],
}


def outlines(rows):
    """Dolu hücrelerin birleşik dış/iç hatları (hücreler arasında dikiş kalmasın).
    Kenarlar dolu taraf sağda kalacak yönde (TrueType: dış hat saat yönünde) birleştirilir."""
    h = len(rows)
    filled = {(c, h - 1 - r) for r, row in enumerate(rows) for c, ch in enumerate(row) if ch == "#"}
    edges = {}
    for x, y in filled:
        if (x - 1, y) not in filled:
            edges.setdefault((x, y), []).append((x, y + 1))          # sol kenar yukarı
        if (x, y + 1) not in filled:
            edges.setdefault((x, y + 1), []).append((x + 1, y + 1))  # üst kenar sağa
        if (x + 1, y) not in filled:
            edges.setdefault((x + 1, y + 1), []).append((x + 1, y))  # sağ kenar aşağı
        if (x, y - 1) not in filled:
            edges.setdefault((x + 1, y), []).append((x, y))          # alt kenar sola
    loops = []
    while edges:
        start = next(iter(edges))
        loop = [start]
        cur = start
        while True:
            nxt = edges[cur].pop()
            if not edges[cur]:
                del edges[cur]
            if nxt == start:
                break
            loop.append(nxt)
            cur = nxt
        # aynı doğrultudaki ara noktaları at
        pts = [p for i, p in enumerate(loop)
               if not ((loop[i - 1][0] == p[0] == loop[(i + 1) % len(loop)][0])
                       or (loop[i - 1][1] == p[1] == loop[(i + 1) % len(loop)][1]))]
        loops.append(pts)
    return loops


def draw(rows):
    pen = TTGlyphPen(None)
    for loop in outlines(rows):
        pen.moveTo((loop[0][0] * U, loop[0][1] * U))
        for x, y in loop[1:]:
            pen.lineTo((x * U, y * U))
        pen.closePath()
    return pen.glyph()


def strip_kerning(font, names):
    """Yeniden çizilen karakterleri kerning'den çıkar: eski şekillere göre ayarlanmış aralıklar
    yeni rakamlarda noktayı rakamın altına itiyor, rakamları sıkıştırıyordu."""
    if "GPOS" not in font:
        return
    for lookup in font["GPOS"].table.LookupList.Lookup:
        if lookup.LookupType != 2:
            continue
        for st in lookup.SubTable:
            if st.Format == 1:
                keep_glyphs, keep_sets = [], []
                for g1, pair_set in zip(st.Coverage.glyphs, st.PairSet):
                    if g1 in names:
                        continue
                    pair_set.PairValueRecord = [r for r in pair_set.PairValueRecord if r.SecondGlyph not in names]
                    pair_set.PairValueCount = len(pair_set.PairValueRecord)
                    keep_glyphs.append(g1)
                    keep_sets.append(pair_set)
                st.Coverage.glyphs = keep_glyphs
                st.PairSet = keep_sets
                st.PairSetCount = len(keep_sets)
            elif st.Format == 2:
                st.Coverage.glyphs = [g for g in st.Coverage.glyphs if g not in names]
                for class_def in (st.ClassDef1, st.ClassDef2):
                    for g in names:
                        class_def.classDefs.pop(g, None)


def main():
    font = TTFont(SRC)
    cmap = font.getBestCmap()
    glyf, hmtx = font["glyf"], font["hmtx"]
    gvar = font["gvar"] if "gvar" in font else None
    strip_kerning(font, {cmap[ord(ch)] for ch in GLYPHS})
    for ch, rows in GLYPHS.items():
        name = cmap[ord(ch)]
        glyph = draw(rows)
        glyf[name] = glyph
        glyph.recalcBounds(glyf)
        width = len(rows[0]) * U if ch.isdigit() else 4 * U
        hmtx[name] = (ADVANCE if ch.isdigit() else width, 0)
        if gvar is not None:
            gvar.variations[name] = []  # kalınlık ekseninde rakamlar sabit kalsın
    # OFL: değiştirilmiş font orijinal adı kullanmaz.
    for rec in font["name"].names:
        if rec.nameID in (1, 16):
            rec.string = FAMILY
        elif rec.nameID == 4:
            rec.string = FAMILY + " Regular"
        elif rec.nameID == 6:
            rec.string = FAMILY.replace(" ", "") + "-Regular"
        elif rec.nameID == 3:
            rec.string = FAMILY.replace(" ", "") + ";modified-from-PixelifySans"
    font.save(DST)
    print("ok:", DST)


if __name__ == "__main__":
    main()
