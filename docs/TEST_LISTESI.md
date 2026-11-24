# Taşı Bakalım – Elle Test Listesi

Önce otomatik testleri çalıştır (bilgisayarda, Godot yüklüyken):

```
godot --headless --path . res://tests/run_tests.tscn
```

Son satırda `SONUÇ: N geçti, 0 başarısız` görmelisin. Ardından aşağıdaki listeyi **telefonda** dene.
Her maddeyi işaretle; sorun olursa bölüm numarasını ve ne olduğunu not al.

## Aşama 1 – Temel sahne
- [ ] Oyun açılıyor, ana menü ve arka planda süzülen koliler görünüyor, müzik çalıyor
- [ ] OYNA → 1. bölüm yükleniyor, ekran kararıp açılıyor
- [ ] Sol tarafa dokununca joystick beliriyor; karakter akıcı yürüyor, az itince yavaş yürüyor
- [ ] İki parmakla kaydırınca kamera dönüyor, sıkıştırınca yakınlaşıyor
- [ ] ARKA / ÜST / YAN düğmeleri kamerayı yumuşakça çeviriyor

## Aşama 2 – Eşya taşıma
- [ ] Koliye yaklaşınca AL düğmesi aktif oluyor; basınca koli ele geliyor
- [ ] Sağ tarafta tek parmakla yatay kaydırma koliyi sağa/sola, dikey kaydırma öne/arkaya yatırıyor
- [ ] YATIR açıkken yatay kaydırma koliyi kendi etrafında yan yatırıyor (3. eksen)
- [ ] HASSAS basılıyken döndürme belirgin şekilde yavaşlıyor
- [ ] KALDIR / İNDİR basılı tutunca koli yükselip alçalıyor
- [ ] DÜZELT koliyi düz konuma getiriyor
- [ ] BIRAK koliyi yavaşça yere indiriyor (hasar yok)

## Aşama 3 – Çarpma ve hasar
- [ ] Koliyi duvara yavaşça değdirince az hasar (veya hiç), sertçe çarpınca çok hasar
- [ ] Çarpmada telefon titriyor, ses geliyor, ekran kısa süre kırmızı yanıyor, hasar yazısı çıkıyor
- [ ] Eşya duvara yaklaşınca yaklaşan kenar sarı yanıyor ve üstte "Dikkat: ..." yazıyor
- [ ] 3. bölümde TV'nin ekranı (ön yüz) daha fazla hasar alıyor
- [ ] Sağlamlık 0 olunca "kırıldı" ekranı çıkıyor; TEKRAR DENE çalışıyor

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

## Aşama 6 – Dayanıklılık ve sırtta taşıma (13–15. bölümler)
- [ ] Buzdolabı sırtta taşınıyor, karakter öne eğiliyor, ekran kenarları kararıyor (dar görüş)
- [ ] Dayanıklılık barı yürürken azalıyor, merdivende daha hızlı azalıyor
- [ ] Dayanıklılık bitince buzdolabı düşüyor ve hasar alıyor
- [ ] MOLA eşyayı bırakıyor, dayanıklılık hızla doluyor; tekrar AL ile devam ediliyor

## Aşama 7 – Bölüm sistemi ve puanlama
- [ ] Eşyayı yeşil HEDEF alanına bırakınca "TESLİM EDİLDİ" ve sonuç ekranı çıkıyor
- [ ] Yıldızlar sırayla doluyor; süre, sağlamlık ve çarpma sayısı doğru
- [ ] Hiç çarpmadan bitirince "KUSURSUZ TAŞIYICI" rozeti çıkıyor
- [ ] Sonraki bölümün kilidi açılıyor; BÖLÜMLER ekranında yıldızlar ve en iyi süre görünüyor
- [ ] Oyunu tamamen kapatıp açınca ilerleme duruyor
- [ ] Yıldız topladıkça KIYAFETLER'de yeni kıyafet açılıyor, giyilince karakter değişiyor

## Aşama 8 – Cilalama ve sağlamlık
- [ ] Duraklat (II) menüsü: Devam, Takıldım, Yeniden başla, Ayarlar, Bölümler çalışıyor
- [ ] "Takıldım" son noktaya götürüyor, eşyayı eline veriyor (+15 sn)
- [ ] Android geri tuşu oyunda duraklatıyor, duraklatmada devam ettiriyor, menüde geri gidiyor
- [ ] Uygulamayı arka plana atınca oyun duraklıyor; dönünce kaldığı yerden devam ediyor
- [ ] Ayarlar: ses/müzik kaydırıcıları, titreşim kapatma, solak modu (kontroller yer değiştiriyor), grafik kalitesi
- [ ] Düşük kalitede oyun daha akıcı; pil daha az ısınıyor
- [ ] Kedi merdivende gidip geliyor; önünü kapatınca miyavlıyor ve birkaç saniye sonra kenara atlıyor
- [ ] Açık kapıya eşyasız yaklaşınca KAPIYI KAPAT çıkıyor ve kapı kapanıyor
- [ ] 15 bölümün hepsi baştan sona bitirilebiliyor
