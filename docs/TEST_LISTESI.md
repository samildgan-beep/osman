# Handle With Care – Elle Test Listesi

Önce otomatik testleri çalıştır (bilgisayarda, Godot yüklüyken):

```
godot --headless --path . res://tests/run_tests.tscn
```

Son satırda `SONUÇ: N geçti, 0 başarısız` görmelisin. Ardından aşağıdaki listeyi **telefonda** dene.
Her maddeyi işaretle; sorun olursa bölüm numarasını ve ne olduğunu not al.

## Aşama 1 – Temel sahne
- [ ] Oyun açılıyor, ana menü ve arka planda süzülen koliler görünüyor, müzik çalıyor
- [ ] PLAY → 1. bölüm yükleniyor, ekran kararıp açılıyor
- [ ] Sol tarafa dokununca joystick beliriyor; karakter akıcı yürüyor, az itince yavaş yürüyor
- [ ] İki parmakla kaydırınca kamera dönüyor, sıkıştırınca yakınlaşıyor
- [ ] BACK / TOP / SIDE düğmeleri kamerayı yumuşakça çeviriyor

## Aşama 2 – Eşya taşıma
- [ ] Koliye yaklaşınca GRAB düğmesi aktif oluyor; basınca koli ele geliyor
- [ ] Sağ tarafta tek parmakla yatay kaydırma koliyi sağa/sola, dikey kaydırma öne/arkaya yatırıyor
- [ ] ROLL açıkken yatay kaydırma koliyi kendi etrafında yan yatırıyor (3. eksen)
- [ ] FINE basılıyken döndürme belirgin şekilde yavaşlıyor
- [ ] LIFT / LOWER basılı tutunca koli yükselip alçalıyor
- [ ] RESET koliyi düz konuma getiriyor
- [ ] DROP koliyi yavaşça yere indiriyor (hasar yok)

## Aşama 3 – Çarpma ve hasar
- [ ] Koliyi duvara yavaşça değdirince az hasar (veya hiç), sertçe çarpınca çok hasar
- [ ] Çarpmada telefon titriyor, ses geliyor, ekran kısa süre kırmızı yanıyor, hasar yazısı çıkıyor
- [ ] Eşya duvara yaklaşınca yaklaşan kenar sarı yanıyor ve üstte "Dikkat: ..." yazıyor
- [ ] 3. bölümde TV'nin ekranı (ön yüz) daha fazla hasar alıyor
- [ ] Sağlamlık 0 olunca "kırıldı" ekranı çıkıyor; TRY AGAIN çalışıyor

## Aşama 4 – Merdiven ve kat
- [ ] Karakter merdivenlerde takılmadan çıkıp iniyor
- [ ] Merdivende ve ağır eşyayla belirgin yavaşlıyor
- [ ] Eşya merdiven eğimine göre kendiliğinden biraz yükseliyor
- [ ] Korkuluklar karakteri boşluğa düşürmüyor
- [ ] Üstteki yeşil ok doğru yönü ve "N kat yukarı" bilgisini gösteriyor
- [ ] Binaya girince duvarlar baş hizasından kesiliyor, tavan yarı saydam görünüyor

## Aşama 5 – Dar geçiş mekaniği (7–9. bölümler)
- [ ] Koltuk dar kapıdan yan (yanlış açı) giremiyor, takılınca karakter ilerleyemiyor
- [ ] Koltuğu uzun tarafı kapıya bakacak şekilde çevirince geçiyor
- [ ] Koridor dönüşünde koltuğu dikine kaldırınca dönebiliyor
- [ ] Takılınca geri çekilmek eşyayı kurtarıyor (kilitlenme yok)

## Aşama 6 – Dayanıklılık ve sırtta taşıma (16–18. bölümler)
- [ ] Buzdolabı sırtta taşınıyor, karakter öne eğiliyor, ekran kenarları kararıyor (dar görüş)
- [ ] Dayanıklılık barı yürürken azalıyor, merdivende daha hızlı azalıyor
- [ ] Dayanıklılık bitince buzdolabı düşüyor ve hasar alıyor
- [ ] REST eşyayı bırakıyor, dayanıklılık hızla doluyor; tekrar GRAB ile devam ediliyor

## Aşama 7 – Bölüm sistemi ve puanlama
- [ ] Eşyayı yeşil HEDEF alanına bırakınca "DELIVERED!" ve sonuç ekranı çıkıyor
- [ ] Yıldızlar sırayla doluyor; süre, sağlamlık ve çarpma sayısı doğru
- [ ] Hiç çarpmadan bitirince "PERFECT MOVER" rozeti çıkıyor
- [ ] Sonraki bölümün kilidi açılıyor; LEVELS ekranında yıldızlar ve en iyi süre görünüyor
- [ ] Oyunu tamamen kapatıp açınca ilerleme duruyor
- [ ] Yıldız topladıkça OUTFITS'de yeni kıyafet açılıyor, giyilince karakter değişiyor

## Aşama 8 – Cilalama ve sağlamlık
- [ ] Duraklat (II) menüsü: Devam, Takıldım, Yeniden başla, Ayarlar, Bölümler çalışıyor
- [ ] "Takıldım" son noktaya götürüyor, eşyayı eline veriyor (+15 sn)
- [ ] Android geri tuşu oyunda duraklatıyor, duraklatmada devam ettiriyor, menüde geri gidiyor
- [ ] Uygulamayı arka plana atınca oyun duraklıyor; dönünce kaldığı yerden devam ediyor
- [ ] Ayarlar: ses/müzik kaydırıcıları, titreşim kapatma, solak modu (kontroller yer değiştiriyor), grafik kalitesi
- [ ] Düşük kalitede oyun daha akıcı; pil daha az ısınıyor
- [ ] Kedi merdivende gidip geliyor; önünü kapatınca miyavlıyor ve birkaç saniye sonra kenara atlıyor
- [ ] Açık kapıya eşyasız yaklaşınca CLOSE çıkıyor ve kapı kapanıyor
- [ ] 18 bölümün hepsi baştan sona bitirilebiliyor

## Yeni: görsellik, ev sahibi, yerleştirme
- [ ] Sokak renkli: tuğla cephe, çiçekli pencereler, balkonlar, tenteler, arabalar, bulutlar
- [ ] Basamaklar mermer görünümlü, ortada halı yolluk ve pirinç çubuklar var; korkuluk dikmeleri ve babalar detaylı
- [ ] Eşyayı duvara/korkuluğa sürtünce duvarda çizik izi kalıyor
- [ ] Sert çarpmada duvarda çökme izi, toz bulutu ve kopan parçalar görünüyor
- [ ] Eşya kırılınca parçalara ayrılıyor, ev sahibi üzülüyor
- [ ] Ev sahibi yaklaşınca el sallıyor ve İngilizce sesleniyor; eşya çarpınca "Careful!" diyor
- [ ] Teslimde ev sahibi zıplıyor, dönüyor, "Thank you so much! I'm so happy!" diyor, konfeti patlıyor
- [ ] `door` bölümlerinde kapının önüne bırakmak yetiyor; `room` bölümlerinde odaya girmek gerekiyor
- [ ] `spot` bölümlerinde (13–15 çamaşır makinesi) hayalet görüntü var; ters bırakınca "Almost! ... FRONT facing the room" uyarısı çıkıyor, doğru yönde bırakınca bölüm bitiyor
- [ ] Oyundaki tüm yazılar İngilizce

## Yeni: HİCRET APARTMANI, serbest kamera, yorulma, sesler
- [ ] Oyun, eski Türk apartmanının giriş kapısının önünde başlıyor; kapının üstündeki mermer levhada "HİCRET APARTMANI" yazıyor, yanında mavi kapı numarası var
- [ ] Giriş: telli camlı demir çift kanat kapı içeri açık, diyafon, beton saçak ve lamba görünüyor
- [ ] Merdiven: mozaik basamaklar, düz demir parmaklık, koyu plastik küpeşte, yağlı boyalı duvar; kapı önlerinde ayakkabılar
- [ ] 7–9 ve 13–15. bölümlerde önceki renkli modern apartman kullanılıyor
- [ ] Karakter sokağın karşısına, binanın yanlarına ve arkasına kadar yürüyebiliyor; arkadaki binaların içinden geçemiyor
- [ ] LOOK (veya V) ile serbest kamera: karakter duruyor, joystick kamerayı gezdiriyor, kaydırınca yukarı/aşağı bakılıyor, LIFT/LOWER yükseltiyor; tekrar basınca kamera karaktere dönüyor
- [ ] Buzdolabıyla uzun süre bekleyince karakter yavaş yavaş öne eğiliyor, dizleri bükülüyor, titriyor
- [ ] Güç bitince buzdolabı/çamaşır makinesi/gardırobun altında eziliyor ("Crushed under the ...!"), ev sahibi "Oh no! Are you okay?!" diyor
- [ ] TV ve koliyle güç bitince sadece eşya düşüyor (ezilme yok)
- [ ] Müzik neşeli ve döngü sınırında tıklama yok; adım, çarpma, çatırtı ve cam kırılma sesleri duyuluyor
