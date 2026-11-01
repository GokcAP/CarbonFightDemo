# Fontlar

- `PixelifySans.ttf`: orijinal Pixelify Sans (SIL Open Font License 1.1, bkz. `OFL.txt`).
- `CarbonFightPixel.ttf`: oyunun kullandığı font. Pixelify Sans'ın harfleri aynen korunmuş,
  rakamları (0-9) ve +/- işaretleri daha okunur olması için yeniden çizilmiştir. OFL gereği
  değiştirilmiş sürüm farklı adla ve aynı lisansla dağıtılır.

Rakamları değiştirmek için `tools/art_gen/number_font.py` içindeki desenleri düzenleyip çalıştır:

```
python number_font.py ../../assets/fonts
```
