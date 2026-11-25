# Handle With Care

Telefon için 3D, fizik tabanlı bir **eşya taşıma oyunu**. Televizyonu, koltuğu, gardırobu, çamaşır makinesini
ve buzdolabını dar merdivenlerden, kapılardan ve koridorlardan **çarpmadan** taşı; ev sahibi seni kapıda
karşılasın, teşekkür etsin ve sevinsin. **Oyunun tüm yazıları ve konuşmaları İngilizcedir.**

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
| Joystick yukarı / aşağı | W / S | İleri / geri yürü (az itersen yavaş) |
| Joystick sağ / sol | A / D | Karakteri olduğu yerde kontrollü döndür (FINE basılıyken daha yavaş) |
| Sağ tarafta tek parmak kaydır | J/L, I/K | Eşyayı döndür (yatay: sağa/sola, dikey: öne/arkaya yatır) |
| **ROLL** (aç/kapa) | U/O | Üçüncü eksen: eşyayı kendi etrafında yan yatır |
| **LIFT / LOWER** (basılı tut) | E / Q | Eşyayı yükselt / alçalt |
| **FINE** (basılı tut) | Shift | Döndürme yavaşlar, ince ayar |
| **RESET** | T | Eşyanın açısını sıfırla |
| **GRAB / DROP** | Boşluk / F | Eşyayı al, yavaşça yere bırak, kapı kapat (CLOSE) |
| **REST** | R | Eşyayı bırak ve dinlen (dayanıklılık hızlı dolar) |
| İki parmak kaydır / sıkıştır | Sağ tık sürükle, tekerlek | Kamerayı geçici çevir / yakınlaştır (ana kamera karakterin arkasına geri döner) |
| **BACK / TOP / SIDE** | 1 / 2 / 3 | Hazır kamera görünümleri. TOP ve SIDE seçilince kamera o açıda kalır; BACK'e basınca arkaya döner |
| **1P** (aç/kapa) | 4 | Birinci şahıs (göz) kamerası: iki parmak kaydır / sağ tık sürükle ile yalnızca kafa döner (sağa-sola ±83°, yukarı-aşağı); gövde, eller ve eşya sabit kalır. BACK bakışı ortalar; TOP/SIDE/LOOK üçüncü şahsa döner |
| **LOOK** (aç/kapa) | V / C | Serbest kamera: karakter durur; joystick/WASD kamerayı sahnede gezdirir, kaydırınca her yöne (yukarı/aşağı dahil) bakar, iki parmak yukarı/aşağı veya LIFT/LOWER (E/Q) yükseltir |
| **II** | Esc / P | Duraklat |

## Oyunun özellikleri

- **Oyun eski bir Türk apartmanının, "HİCRET APARTMANI"nın girişinde başlar:** pastel sıvalı cephe, mermer
  levha, mavi kapı numarası, telli camlı demir çift kanat kapı, diyafon, beton saçak; içeride mozaik basamaklar,
  düz demir parmaklıklı korkuluk ve plastik küpeşte, yağlı boyalı duvarlar, posta kutuları, sayaç dolabı, ilan
  panosu, otomatik merdiven ışığı düğmeleri, kapı önlerinde paspas ve ayakkabılar; balkonlarda çamaşır ipi,
  çanak anten, klima; çatıda su depoları ve antenler. 7–9 ve 13–15. bölümler renkli modern apartmanda geçer
  (`levels.json` → `"building": "turkish" | "modern"`).
- **Karakter görünen alanın her yerine gidebilir** (sokak, karşı kaldırım, binanın çevresi); kamera normal modda da
  yukarı bakabilir.
- **Yorulma ve ezilme:** ağır eşyayla uzun süre kalınca (beklerken de) karakter yavaş yavaş öne eğilir, dizleri
  bükülür, titrer ve yavaşlar. Gücü biterse 40 kg ve üzeri eşyaların (buzdolabı, çamaşır makinesi, gardırop)
  **altında ezilir**; TV ve küçük eşyalar sadece düşer.
- **Sesler:** neşeli döngüsel müzik (davul, bas, akor, marimba melodisi), 4 çeşit adım sesi, tok çarpma, ahşap
  çatırtısı, cam kırılması, sürtünme. `audio/<ad>.ogg` (veya .wav/.mp3) koyarak herhangi bir sesi gerçek kayıtla
  değiştirebilirsin: `music, step0..step3, thud, bump, crack, shatter, scrape, success, fail, meow...`
- **20 bölüm**: koli → TV → büyük TV/cam sehpa → koltuk → gardırop → **çamaşır makinesi** → buzdolabı (sırtta, 15. bölüm)
- **16–20: Absürt fabrika (GIANT GOODS CO.)** — adam tek başına dev bir fabrika salonunda kendi boyunun
  **5 katı** lastik ördek, **7 katı** cıvata ve oyuncak ayı, **10 katı** kurşun kalem ve buzdolabı taşır.
  Salon fabrika malzemelerinden bir **labirent**: konteyner yığınları, palet rafları, pres/kazan/pano
  sıraları, dev boru yığınları ve çelik bobinler duvardan duvara uzanır; açıklıklar sırayla sağda ve
  solda kalır, dev eşyayla zikzak çizersin (zemindeki oklar ve yön oku yolu gösterir). Ortadaki kapı
  eşyadan alçak/dar: eşyayı yatırıp ya da çevirip geçir, sonra tekrar dikip dev küvete, sergi standına,
  hediye kutusuna, deftere ya da dev mutfağa yerleştir. Dev eşya ağır ağır döner (ucu en fazla 3 m/s).
  Açıklık genişliği ve sıra aralıkları eşyanın ölçüsünden hesaplanır; her bölüm bir otomatik pilot
  testiyle baştan sona geçilerek doğrulanır. Köprülü vinç, forklift ve absürt tabelalar
  ("DAYS WITHOUT A GIANT ACCIDENT: 0")
- **Üç hedef türü:** `door` (daire kapısına teslim et), `room` (eve girip odaya taşı),
  `spot` (eşyayı tam yerine, iki dolabın/komodinin arasına, ön yüzü odaya bakacak şekilde yerleştir — hayalet görüntü yol gösterir).
  1–5. bölümler kapıya/odaya teslim; **6. bölümden itibaren her bölümde eve girip eşyayı yerine koymak gerekir**
  (TV ve koltuk oturma odasında abajurlu iki komodin arasına, gardırop yatak odasına, beyaz eşya mutfak/çamaşır odasına)
- **Ev içi:** daire koridoru ve odada eşya taşırken hız yarıya iner; dönüş, eşya çevirme ve kalkış/duruş daha yumuşak ve hassastır.
  Koridorda lambri, kilim yolluk, portmanto, ayna, diafon, sigorta kutusu, nazar boncuğu; odada avize, klima, kalorifer, saat, tablolar, konsol
- **Kurye aracı:** küçük eşyalarda girişte kurye motosikleti; büyük eşyalarda yol kenarında arka kapıları açık, içi kolili şirin bir kamyonet
- **Ev sahibi:** kapıda/odada bekler, yaklaşınca el sallar ("Hi! Over here, please!"), eşya çarpınca endişelenir
  ("Careful!"), teslimde zıplar, döner, sevinir ve teşekkür eder ("Thank you so much! I'm so happy!") + konfeti
- **Canlı görsellik:** kodla üretilen dokular (tuğla cephe, mermer basamak, halı yolluk, ahşap parke, fayans,
  duvar kâğıdı), 6 renkli tema, balkonlar, çiçekli pencereler, tenteli dükkânlar, park etmiş arabalar, bulutlar,
  parlama ve renk doygunluğu ayarı
- **Detaylı merdiven:** tornalı korkuluk dikmeleri, başlık babaları, yuvarlak ahşap trabzan, pirinç halı çubukları,
  duvar tutamakları ve dirsekleri, lambri, aplikler, sahanlık pencereleri ve tablolar
- **Fizik detayları:** eşya duvara/korkuluğa sürtünce **yüzeyde kalıcı çizik** kalır; sert çarpmada duvarda
  **çökme izi**, **toz bulutu**, **kopan sıva ve eşya parçaları**; eşya kırılınca **parçalara ayrılır**
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
shaders/building.gdshader  Bina gölgelendiricisi: kodla doku (tuğla, mermer, ahşap, fayans...) + kesit görünümü
shaders/ceiling.gdshader   Yarı saydam tavanlar
shaders/mark.gdshader      Duvar çizikleri ve darbe izleri
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
  game/cat.gd, swing_door.gd, goal_marker.gd  Engeller ve hedef (hayalet yerleştirme görüntüsü)
  game/homeowner.gd        Ev sahibi: karşılama, endişe, kutlama, teşekkür konuşmaları
  game/effects.gd          Çizikler, darbe izleri, toz, kopan parçalar, parçalanma, konfeti
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
`goal` (door / room / spot), `theme` (0–5 renk teması), `par_time`, `tips`. Bina bu değerlerden otomatik kurulur. Değerler oynanabilir aralıklara kırpılır.

### Dengeyi ayarlamak
Tüm hız, ağırlık, hasar, dayanıklılık, kamera ve puan eşikleri `scripts/autoload/config.gd` dosyasında.

### Testler
```
godot --headless --fixed-fps 60 --path . res://tests/run_tests.tscn
```
`--fixed-fps 60` fizik adımlarını beklemeden çalıştırır (sonuç aynı, birkaç saniyede biter).

Görünmeyen engel denetimi (gerçek görüntü motoru gerekir; Linux'ta `xvfb-run` ile):
```
godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/collision_audit.tscn
```
Her bölümdeki tüm çarpışma şekillerini görünür modellerle karşılaştırır, oyuncuyu ve eşyayı yol
boyunca ilerletir; yüzeyinde görünür model olmayan bir engel bulursa raporlar (0 = temiz).
Hasar formülleri, veri doğrulama, bozuk kayıt dosyaları, 20 bölümün kurulumu (her yol noktasında zemin ve
oyuncuya yetecek boşluk var mı), oynanış testleri (eşya al, yürü, döndür, bırak, yerleştir, birinci şahıs,
ezilme) ve fabrika labirentlerini dev eşyayla baştan sona geçen otomatik pilot çalışır.
Çıkış kodu 0 ise tüm testler geçmiştir. Testler kayıt dosyana dokunmaz.

## Android'e çıkarma (APK)

1. Godot'da **Editör → Dışa Aktarma Şablonlarını Yönet → İndir ve Yükle**.
2. [Android SDK / JDK 17 kurulumu](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
   yap; Godot **Editör Ayarları → Dışa Aktar → Android** kısmında yolları göster.
3. Hata ayıklama anahtarı (debug keystore) Godot tarafından otomatik oluşturulur. Mağaza için kendi
   sürüm anahtarını oluştur ve **Proje → Dışa Aktar → Android → Keystore/Release** alanlarına gir.
4. **Proje → Dışa Aktar → Android → Projeyi Dışa Aktar** → `build/HandleWithCare.apk`.
5. Telefona kur ve oyna. Titreşim izni ön ayarda açık.

Google Play için AAB gerekir: ön ayarda **Gradle ile derle**yi aç ve dışa aktarma biçimini AAB seç.

## Kayıt sistemi
- Kayıt önce geçici dosyaya yazılır, doğrulanır, sonra asıl dosyanın yerine geçer (yarım kayıt olmaz).
- Önceki sağlam kayıt yedeklenir; asıl kayıt bozulursa yedek, o da yoksa varsayılan yüklenir.
- Okunan her değer tür ve aralık kontrolünden geçer. Uygulama arka plana atılınca otomatik kaydedilir.

## Sonraki güncellemeler için fikirler
Piyano, çamaşır makinesi, iki kişilik taşıma; Mixamo/Quaternius karakter modeli (`player_visual.gd` aynı
`update_anim()` arayüzüyle değiştirilebilir); Kenney/Quaternius mobilya modelleri (`items.json` → `parts`).
