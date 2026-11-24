# Taşı Bakalım

Telefon için 3D, fizik tabanlı bir **eşya taşıma oyunu**. Televizyonu, koltuğu, gardırobu ve buzdolabını
dar merdivenlerden, kapılardan ve koridorlardan **çarpmadan** daireye taşı.

- Motor: **Godot 4.3+** (ücretsiz, üyelik gerekmez) · Dil: **GDScript**
- Hedef: Android (iOS ve masaüstü de çalışır)
- Dışarıdan hiçbir model, doku veya ses dosyası gerekmez: bina, karakter, eşyalar ve **tüm sesler/müzik kodla üretilir**.

---

## Hızlı başlangıç

1. [godotengine.org](https://godotengine.org/download) adresinden **Godot 4.3** (veya daha yeni 4.x) indir.
2. Godot'yu aç → **İçe Aktar** → bu klasördeki `project.godot` dosyasını seç.
3. İlk açılışta Godot projeyi içe aktarır (birkaç saniye). Ardından **F5** (Oynat).

Masaüstünde fare ile dokunmatik taklit edilir (sol tık = parmak). Klavye kısayolları aşağıda.

## Kontroller

| Telefon | Klavye | Ne yapar |
|---|---|---|
| Sol tarafa dokunup kaydır (joystick) | WASD / oklar | Yürü (az itersen yavaş yürür) |
| Sağ tarafta tek parmak kaydır | J/L, I/K | Eşyayı döndür (yatay: sağa/sola, dikey: öne/arkaya yatır) |
| **YATIR** (aç/kapa) | U/O | Üçüncü eksen: eşyayı kendi etrafında yan yatır |
| **KALDIR / İNDİR** (basılı tut) | E / Q | Eşyayı yükselt / alçalt |
| **HASSAS** (basılı tut) | Shift | Döndürme yavaşlar, ince ayar |
| **DÜZELT** | T | Eşyanın açısını sıfırla |
| **AL / BIRAK** | Boşluk / F | Eşyayı al, yavaşça yere bırak, kapı kapat |
| **MOLA** | R | Eşyayı bırak ve dinlen (dayanıklılık hızlı dolar) |
| İki parmak kaydır / sıkıştır | Sağ tık sürükle, tekerlek | Kamera döndür / yakınlaştır |
| **ARKA / ÜST / YAN** | 1 / 2 / 3 | Hazır kamera görünümleri (üstten görünümde duvarlar kesilir) |
| **II** | Esc / P | Duraklat |

## Oyunun özellikleri

- **15 bölüm**, 5 eşya grubu: koli → TV → büyük TV/cam sehpa → koltuk → gardırop → buzdolabı (sırtta)
- **Hasar sistemi:** çarpma hızına göre hasar, sürtünme hasarı, **hassas yüzler** (TV ekranı, cam üst yüz, aynalı kapak, buzdolabı kapağı)
- **Yakınlık uyarısı:** eşyanın bir yüzü duvara yaklaşınca o kenar **sarı** yanar
- **Geri bildirim:** titreşim, ses, kırmızı ekran parlaması, kamera sarsıntısı, hasar yazıları, eşyada çizik izleri
- **Ağırlık ve merdiven:** ağır eşyada ve merdivende yavaşlama; eşya merdiven eğimine göre otomatik yükselir
- **Dayanıklılık barı:** biterse eşya düşer ve hasar alır; **MOLA** ile dinlen
- **Sırtta taşıma** (buzdolabı): karakter öne eğilir, görüş alanı daralır
- **Dar geçiş mekaniği:** eşya ancak doğru açıyla dar kapı/koridordan geçer
- **Engeller:** merdivende gezen kedi, açık kalmış kapı (eşyayı bırakıp kapatabilirsin), alçak lambalar, ayakkabılık, saksı, koli yığını
- **Yön oku** (bir sonraki noktayı ve kaç kat kaldığını gösterir), ilk bölümde **adım adım eğitim**
- **Puanlama:** süre + sağlamlığa göre 1–3 yıldız, **Kusursuz Taşıyıcı** rozeti, en iyi süre kaydı
- **Kıyafetler:** yıldız topladıkça açılan 6 karakter kıyafeti
- **Ayarlar:** ses/müzik, hassasiyet, grafik kalitesi (pil dostu mod), titreşim, ters eksen, **solak modu**
- **Takıldım (kurtar):** hiçbir durumda kilitli kalmazsın; son noktaya döner, eşya eline verilir

## Proje yapısı

```
project.godot              Proje ayarları (mobil işleyici, yatay ekran, autoload'lar)
export_presets.cfg         Android dışa aktarma ayarı
data/items.json            EŞYALAR  (boyut, ağırlık, hassas yüzler, görünüm parçaları)
data/levels.json           BÖLÜMLER (kat sayısı, merdiven, tavan, kapılar, koridor, engeller)
shaders/building.gdshader  Bina gölgelendiricisi (üstten görünüm kesiti)
scenes/main.tscn           Başlangıç sahnesi
scripts/
  autoload/config.gd       TÜM FİZİK VE DENGE AYARLARI TEK YERDE
  autoload/game_state.gd   Kayıt sistemi, ilerleme, ayarlar, kıyafetler
  autoload/item_db.gd      Eşya verisini okur ve doğrular
  autoload/level_db.gd     Bölüm verisini okur ve doğrular
  autoload/audio_manager.gd Kodla sentezlenen sesler ve müzik
  autoload/haptics.gd      Titreşim
  core/level_builder.gd    Bölüm verisinden 3D binayı kurar
  core/mesh_batcher.gd     Binayı tek ağda birleştirir (telefonda hızlı)
  game/game.gd             Bölüm akışı, kazanma/kaybetme, eğitim, kurtarma
  game/player.gd           Karakter hareketi, dayanıklılık, etkileşim
  game/player_visual.gd    Karakter modeli ve animasyonları
  game/carry_controller.gd Tutuş açısı, kaldırma, hedef konum
  game/carry_item.gd       Taşınan eşya: çarpışma, hasar, yakınlık uyarısı
  game/damage_model.gd     Hasar/puan/dayanıklılık formülleri (test edilir)
  game/camera_rig.gd       Kamera
  game/cat.gd, swing_door.gd, goal_marker.gd  Engeller ve hedef
  input/                   Dokunmatik kontroller
  ui/                      Arayüz: HUD, menüler, ayarlar, sonuç ekranı
tests/run_tests.tscn       Otomatik testler
```

## Geliştirme

### Yeni eşya eklemek (kod değiştirmeden)
`data/items.json` içine yeni bir kayıt ekle: `id`, `name`, `size` [genişlik, yükseklik, derinlik], `weight`,
`fragility`, `fragile_faces` (örn. `{"front": 2.0}`), `carry` (`hands` veya `back`) ve görünüm `parts`.
Hatalı alanlar oyunu çökertmez; güvenli varsayılana döner ve konsola uyarı yazılır.

### Yeni bölüm eklemek (kod değiştirmeden)
`data/levels.json` listesine yeni kayıt ekle: `item`, `floors`, `stair_width`, `steps`, `rise`, `tread`,
`landing`, `ceiling`, `entrance`, `apt_door`, `corridor` (`turn`: none/left/right), `room`, `obstacles`,
`par_time`, `tips`. Bina bu değerlerden otomatik kurulur. Değerler oynanabilir aralıklara kırpılır.

### Dengeyi ayarlamak
Tüm hız, ağırlık, hasar, dayanıklılık, kamera ve puan eşikleri `scripts/autoload/config.gd` dosyasında.

### Testler
```
godot --headless --path . res://tests/run_tests.tscn
```
Hasar formülleri, veri doğrulama, bozuk kayıt dosyaları, 15 bölümün kurulumu (her yol noktasında zemin ve
oyuncuya yetecek boşluk var mı) ve kısa bir oynanış testi (eşya al, yürü, döndür, bırak) çalışır.
Çıkış kodu 0 ise tüm testler geçmiştir. Testler kayıt dosyana dokunmaz.

## Android'e çıkarma (APK)

1. Godot'da **Editör → Dışa Aktarma Şablonlarını Yönet → İndir ve Yükle**.
2. [Android SDK / JDK 17 kurulumu](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
   yap; Godot **Editör Ayarları → Dışa Aktar → Android** kısmında yolları göster.
3. Hata ayıklama anahtarı (debug keystore) Godot tarafından otomatik oluşturulur. Mağaza için kendi
   sürüm anahtarını oluştur ve **Proje → Dışa Aktar → Android → Keystore/Release** alanlarına gir.
4. **Proje → Dışa Aktar → Android → Projeyi Dışa Aktar** → `build/TasiBakalim.apk`.
5. Telefona kur ve oyna. Titreşim izni ön ayarda açık.

Google Play için AAB gerekir: ön ayarda **Gradle ile derle**yi aç ve dışa aktarma biçimini AAB seç.

## Kayıt sistemi
- Kayıt önce geçici dosyaya yazılır, doğrulanır, sonra asıl dosyanın yerine geçer (yarım kayıt olmaz).
- Önceki sağlam kayıt yedeklenir; asıl kayıt bozulursa yedek, o da yoksa varsayılan yüklenir.
- Okunan her değer tür ve aralık kontrolünden geçer. Uygulama arka plana atılınca otomatik kaydedilir.

## Sonraki güncellemeler için fikirler
Piyano, çamaşır makinesi, iki kişilik taşıma; Mixamo/Quaternius karakter modeli (`player_visual.gd` aynı
`update_anim()` arayüzüyle değiştirilebilir); Kenney/Quaternius mobilya modelleri (`items.json` → `parts`).
