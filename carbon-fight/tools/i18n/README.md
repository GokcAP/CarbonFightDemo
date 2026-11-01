# Çeviriler (Türkçe / English)

Oyunun ana dili Türkçe. Koddaki Türkçe metinler aynı zamanda çeviri anahtarıdır (`tr("...")`).
İngilizce çeviriler `assets/i18n/en.po` dosyasında. Oyuncu dili Ayarlar menüsünden (Esc) değiştirir.

## Yeni metin ekleyince

1. Kodda metni `tr("...")` içine yaz (`%d`, `%s` yer tutucuları çeviride aynı sırada kalmalı).
   Kart, boss ve harita `.tres` metinleri otomatik toplanır.
2. Eksikleri listele (proje klasöründen):

   ```
   godot --headless --path . -s res://tools/i18n/extract.gd
   ```

   - `tools/i18n/missing_en.txt`: `en.po` içinde çevirisi olmayan metinler.
   - `tools/i18n/messages.pot`: tüm metinlerin şablonu.
3. Eksikleri `assets/i18n/en.po` dosyasına `msgid` / `msgstr` çifti olarak ekle.
   Poedit gibi bir PO düzenleyici de kullanabilirsin.

Çevirisi olmayan metin Türkçe görünür; oyun bozulmaz.

Emeği geçenler metni ayrı dosyada: `assets/legal/credits.bbcode` (Türkçe) ve
`assets/legal/credits_en.bbcode` (İngilizce). Birini değiştirirsen diğerini de güncelle.

## Yeni dil eklemek

1. `messages.pot` dosyasını `assets/i18n/<kod>.po` olarak kopyala ve çevir (ör. `de.po`).
2. `project.godot` → `internationalization/locale/translations` listesine ekle.
3. `scripts/settings.gd` → `LANGUAGES` sözlüğüne `"<kod>": "<dilin kendi adı>"` ekle.
