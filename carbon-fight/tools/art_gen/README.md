# Pixel art ve ses üreticileri

Godot bu klasörü yok sayar (`tools/.gdignore`).

```
pip install pillow numpy
python sprites.py ../../assets/sprites   # bina, boss, ikon, arka plan PNG'leri
python sfx.py ../../assets/sfx           # 8-bit ses efektleri + müzik döngüsü
```

Palet: Sweetie 16. Sprite'lar art çözünürlüğünde (bina 32x32, boss 64x64, ikon 16x16,
arka plan 320x180) kaydedilir; oyun bunları Nearest filtreyle 2x büyütür.
Elle çizilmiş sprite'larla değiştirmek için aynı dosya adı ve boyutla üzerine yazman yeterli.

Hikaye sürümü için ek sprite'lar (Kül Ana, Doğa Ana, tohum parçaları, karolar, 4 harita arka planı):

```
python sprites_story.py ../../assets/sprites
```

2.5D (izometrik) tahta için yer tutucular (karolar, harita zeminleri, binalar, UI çerçeveleri):

```
python iso_sprites.py ../../assets
```

Dikkat: Aynı adlı dosyaların üzerine yazar. Ölçüler ve çapa noktaları: `assets/README.md`.
