# CarbonFight — Denge Tohumu

İklim temalı, izometrik pixel-art kart ve strateji oyunu. GameUp! Hackathon için Godot 4 ile yapıldı.

> Doğa Ana dünyayı Denge Tohumu ile dengede tutuyordu. Tohum üçe bölündü, parçalar kirlilikten doğan
> canavarların içine düştü ve Doğa Ana öfkeyle Kül'e dönüştü. Sen Eko-Lider'sin: haritaları onar,
> canavarları yen, parçaları geri al.


## Oynanış

- Her tur **1 kart** oynarsın: boş karoya yerleşir, aynı kartın üstüne birleşip seviye atlar, canavara
  bırakırsan **kurban vuruşu** yapar. İstemediğin kartı çöp kutusuna atabilirsin.
- Kartların **karbon** ve **refah** etkisi var. Karbon yükseldikçe **sıcaklık** artar; sıcaklık 2.0°C'ye
  ulaşırsa ya da refah biterse kaybedersin.
- Her haritada önce **onarım görevi** var (kirli bacaları söndür, çöpü temizle, asfaltı yeşillendir);
  bitince canavar uyanır. Kartların her tur ona vurur; aynı elementten komşu kartlar daha güçlü vurur.
- Dört diyar, dört canavar: **Termik Ejderha**, **Plastik Leviathan**, **Isı Adası Golemi** ve finalde **Kül**.
- Platformu fareyle tutup çevirebilir, her açıdan inceleyebilirsin.
- Türkçe ve İngilizce dil desteği; ilk oyunda adım adım eğitim.

## Çalıştırma

1. [Godot 4.7](https://godotengine.org/download) (standart sürüm, .NET gerekmez) indir.
2. Godot'da **İçe Aktar** → `carbon-fight/project.godot` dosyasını seç.
3. **F5** ile çalıştır.

## Proje yapısı

```
carbon-fight/
  scenes/        Ana menü, oyun ve emeği geçenler sahneleri
  scripts/       Oyun mantığı (game_state.gd, turn_manager.gd) ve arayüz (ui/)
  data/          Kartlar, canavarlar, haritalar ve denge ayarları (.tres)
  assets/        Sprite'lar, sesler, müzikler, yazı tipi, çeviriler, lisanslar
  tools/         Görsel/ses üreticileri, denge simülasyonu, çeviri ve demo kayıt araçları
demo/            Oyun içi demo videosu
```

Görselleri değiştirmek için `carbon-fight/assets/README.md`, çeviriler için
`carbon-fight/tools/i18n/README.md` dosyasına bak.

## Ekip

- Gökçe Apaydın
- Zeki Can Erdoğan

## Lisanslar

- Godot Engine — MIT License (`carbon-fight/assets/legal/GODOT_LICENSE.txt`)
- Yazı tipi: Pixelify Sans tabanlı *CarbonFight Pixel* — SIL Open Font License 1.1
  (`carbon-fight/assets/fonts/`)
- Renk paleti: Sweetie 16 — GrafxKid
- Ayrıntılar oyundaki **Emeği Geçenler → Lisanslar** ekranında.
