# CarbonFight görselleri: değiştirme rehberi

Her görsel **sabit bir dosya adından** okunur. Kendi çizimini (Aseprite, Photoshop vb.) aynı ad ve
boyutla bu klasöre koyman yeterli; kodda değişiklik gerekmez. Godot dosyayı otomatik yeniden içe aktarır.

- **Ölçek:** Her şey *art pikseli* cinsinden çizilir; oyun Nearest filtreyle **2×** büyütür
  (`UIStyle.PX`). Yani 64×32 bir karo ekranda 128×64 görünür.
- **Palet:** Sweetie 16 (zorunlu değil, mevcut görsellerle uyum için önerilir).
- **Arka plan:** Boş alanlar şeffaf (PNG, alfa kanalı) olmalı.
- **Kod tarafı:** Dosya yolları tek yerde toplanır: `scripts/ui/art.gd`.
- **Yer tutucular:** `tools/art_gen/iso_sprites.py` ile üretilir. Script yeniden çalıştırılırsa
  aynı adlı dosyaların **üzerine yazar**; kendi çizimlerini ekledikten sonra çalıştırma.

## İzometrik geometri (2.5D)

```
Karo (tile)                 Bina / nesne tuvali (64x64)
	  ____                   +----------------+  y=0
   _-‾    ‾-_                |                |
  <    ●     >  32 px        |    (bina)      |  üst yarı: bina gövdesi taşabilir
   ‾-_    _-‾                |                |
	  ‾‾‾‾                   |      __        |  y=32
  |   yan   | 8 px           |   _-‾  ‾-_     |
  +---------+                |  <   ●    >    |  alt yarı = karonun elması,
	 64 px                   |   ‾-_  _-‾     |  ● = (32, 48) karo merkezi
							 +----------------+  y=64
```

- Karo elması 2:1 oranında: 64×32. Yan yüzlerin kalınlığı 8 px.
- Bina tuvalinin **alt 32 satırı karonun elmasıyla birebir çakışır**. Binayı elmasın içine "otur",
  gövdesi yukarı uzasın. Elmasın merkezi tuvalde (32, 48).

## Dosyalar

### Tahta (`sprites/iso/`)

| Dosya | Boyut | Ne | Not |
|---|---|---|---|
| `tile.png` | 64×40 | Genel karo (üst elmas 64×32 + 8 px yan yüz) | Haritaya özel dosya yoksa kullanılır |
| `tile_<harita_id>.png` | 64×40 | Haritaya özel karo | `dumanli_vadi`, `solgun_korfez`, `gri_sehir`, `kul_ormani` |
| `ground.png` | 288×160 | Tahtanın altındaki ada (karolar arası 12 px boşluklu tahtadan geniş, 16 px kalınlık) | Tahta merkezi (144, 72) |
| `ground_<harita_id>.png` | 288×160 | Haritaya özel ada | Ortadaki 216×108'lik elmas karolarla örtülür; dekoru kenarlara koy |
| `overlay_asphalt.png` | 64×32 | Asfalt zemin (Gri Şehir) | Elmas, karonun üstüne çizilir |
| `overlay_green.png` | 64×32 | Yeşil Alan | |
| `overlay_altar.png` | 64×32 | Sunak (final) | |
| `overlay_hot.png` | 64×32 | Sıcak slot (Golem) | Yarı saydam olabilir |
| `prop_smoke.png` | 64×64 | Duman bulutu | Bina tuvali gibi; binanın üstüne çizilir |
| `prop_trash.png` | 64×64 | Çöp yığını | Bina tuvali gibi |

### Binalar (`sprites/buildings/`): 64×64, bina tuvali kuralıyla

Dosya adı kartın `id`'si: `gunes_tarlasi`, `dikey_tarim`, `mavi_karbon`, `yesil_cati`, `toplu_tasima`,
`komur_santrali`, `denge_tohumu`, `shard_su`, `shard_toprak`, `shard_gunes`.

Bina dosyası yoksa slot, kartın 32×32 ikonunu (`sprites/cards/<id>.png`) karonun ortasında ayakta gösterir.

### Kart, boss, ikon (önceki sürümden, değişmedi)

| Klasör | Boyut | Ne |
|---|---|---|
| `sprites/cards/<id>.png` | 32×32 | Eldeki kartın resmi |
| `sprites/bosses/<id>_0.png`, `_1.png` | 64×64 | Boss, 2 kare bekleme animasyonu |
| `sprites/icons/<ad>.png` | 16×16 | Stat, element ve durum ikonları |
| `sprites/bg/<ad>.png` | 320×180 | Harita arka planı (`data/maps/*.tres` içinde seçilir) |

### Arayüz çerçeveleri (`ui/`): 9-slice

Kenar payı **4 px**: köşedeki 4×4 alan sabit kalır, kenarlar ve orta kısım uzatılır.
Boyut en az 9×9 olmalı; yer tutucular 16×16.

| Dosya | Nerede |
|---|---|
| `panel.png` | Sol/sağ paneller, diyalog kutusu |
| `button_normal.png`, `button_hover.png`, `button_pressed.png`, `button_disabled.png` | Tüm butonlar |
| `card_frame.png` | Eldeki kart çerçevesi. **Gri tonlu çiz**: oyun kartın rengiyle boyar (beyaz = tam kart rengi) |

Bir çerçeve dosyasını silersen oyun kodla çizilen eski çerçeveye döner.

### Font ve ses

- `fonts/PixelifySans.ttf`: Türkçe karakter destekli pixel font (`project.godot` → gui/theme/custom_font).
- `sfx/<ad>.wav`: ses efektleri ve müzik (`scripts/sfx.gd`).

## Yerleşimi değiştirmek

- **Tahta ölçüleri:** `scripts/ui/iso_board.gd` (`TILE`, `OVERHANG`, `GROUND_CENTER`).
- **Slot katmanları ve sırası:** `scripts/ui/slot.gd` (`_ready`).
- **Ekran düzeni:** `scripts/main.gd` (`_build_*_column`).
- **Renkler:** `scripts/ui/ui_style.gd`.
