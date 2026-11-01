# Denge simülasyonu

`sim.py`, GameState + TurnManager kurallarının Python karşılığıdır ve basit bir botla oyunu
baştan sona oynatır. Godot açmadan denge sayılarını denemek için:

```
python sim.py        # 300 oyun: kazanma/kayıp oranı, harita başına onarım ve boss tur sayısı
python sim.py 7      # 7 numaralı tohumla tek oyunu ayrıntılı yazdırır
```

`CFG` sözlüğü `data/balance.tres` ile, `MAPS` / `BOSSES` ise `data/maps` ve `data/bosses` ile
aynı sayıları kullanır. Oyunda bir sayıyı değiştirince burada da değiştir.
Not: Kurallar GDScript'te değişirse bu dosya elle güncellenmelidir.
