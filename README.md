# Palaoğlu Kasa Takip

Flutter Web / PWA olarak hazırlanmış koyu temalı kasa takip uygulaması.
Ana veri kaynağı Firebase Auth ve Cloud Firestore'dur. Google Sheet ve Apps Script kullanılmaz.

## Dosya Yapısı

```text
lib/
  main.dart
  app.dart
  firebase_options.dart
  core/
    theme/
    utils/
    constants/
  features/
    auth/
    dashboard/
    entry/
    report/
    employees/
  data/
    models/
    repositories/
web/
firestore.rules
firebase.json
netlify.toml
```

## Kurulum

1. Flutter SDK kur.
   - Windows için Flutter'ı indir.
   - Flutter klasörünü örneğin `C:\src\flutter` içine çıkar.
   - `C:\src\flutter\bin` yolunu Windows PATH'e ekle.
   - Yeni terminal açıp `flutter doctor` çalıştır.

2. Firebase CLI kur.
   - Node.js kurulu değilse önce Node.js LTS kur.
   - Terminalde `npm install -g firebase-tools` çalıştır.
   - `firebase login` ile Google hesabına giriş yap.

3. FlutterFire CLI kur.
   - Terminalde `dart pub global activate flutterfire_cli` çalıştır.
   - Dart pub cache bin yolunu PATH'e ekle.

4. Firebase Console'da proje oluştur.
   - Proje adı örnek: `Palaoğlu Kasa Takip`.
   - Web app ekle.
   - Firebase Auth > Sign-in method > Email/Password aktif et.
   - Firestore Database oluştur.
   - Başlangıç için production mode seçip sonra `firestore.rules` içeriğini yayınla.

5. Firebase ayarlarını üret.
   - Proje klasöründe şu komutu çalıştır:

```bash
flutterfire configure
```

Bu işlem gerçek Firebase değerleriyle `lib/firebase_options.dart` dosyasını günceller.

6. Paketleri indir.

```bash
flutter pub get
```

7. Chrome'da test et.

```bash
flutter run -d chrome
```

8. Web build al.

```bash
flutter build web --release
```

9. Netlify deploy.
   - Netlify'da yeni site oluştur.
   - Manuel deploy için `build/web` klasörünü sürükleyip bırak.
   - Git ile bağlarsan build command: `flutter build web --release`
   - Publish directory: `build/web`

10. iPhone'da kullan.
   - Safari ile yayınlanan siteyi aç.
   - Paylaş butonuna bas.
   - Ana Ekrana Ekle seç.

## Firebase Console'da Kullanıcı Oluşturma

1. Firebase Console > Authentication > Users ekranına gir.
2. Add user ile Onur ve Melek kullanıcılarını oluştur.
3. Her kullanıcı için UID değerini kopyala.
4. Firestore > `users` collection içinde UID ile aynı document id oluştur.

Onur admin örneği:

```json
{
  "uid": "ONUR_AUTH_UID",
  "email": "onur@example.com",
  "displayName": "Onur",
  "role": "admin",
  "active": true,
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

Melek kullanıcı örneği:

```json
{
  "uid": "MELEK_AUTH_UID",
  "email": "melek@example.com",
  "displayName": "Melek",
  "role": "user",
  "active": true,
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

Not: Firestore Console'da `createdAt` ve `updatedAt` alanlarını Timestamp tipiyle ekleyebilirsin. Zorunlu değiller.

## Firestore Collections

### users/{uid}

```json
{
  "uid": "...",
  "email": "onur@example.com",
  "displayName": "Onur",
  "role": "admin",
  "active": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### transactions/{id}

```json
{
  "id": "...",
  "date": "2026-05-20",
  "monthKey": "2026-05",
  "type": "ciro",
  "category": "Ciro",
  "person": "",
  "amount": 120000,
  "description": "Günlük satış",
  "createdByUid": "...",
  "createdByName": "Onur",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "status": "active"
}
```

### employees/{id}

```json
{
  "id": "bolat",
  "name": "Bolat",
  "salary": 34000,
  "active": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "updatedByUid": "...",
  "updatedByName": "Onur"
}
```

### deleted_transactions/{id}

Silinen kayıt önce buraya kopyalanır, sonra `transactions` içinden kaldırılır.

```json
{
  "id": "...",
  "originalTransactionId": "...",
  "date": "2026-05-20",
  "monthKey": "2026-05",
  "type": "masraf",
  "category": "Kira",
  "person": "",
  "amount": 35000,
  "description": "Mayıs kira",
  "createdByUid": "...",
  "createdByName": "Onur",
  "deletedByUid": "...",
  "deletedByName": "Onur",
  "deletedAt": "Timestamp",
  "originalCreatedAt": "Timestamp"
}
```

## Personel İlk Kurulum

Admin ile giriş yaptıktan sonra:

1. Ana ekranda Personel Ayarları'na gir.
2. Personel listesi boşsa Varsayılanları ekle butonuna bas.
3. Varsayılan personeller:
   - Bolat: 34.000 TL
   - Mehmet: 32.000 TL
   - Hasan Ali: 30.000 TL
   - Ramazan: 30.000 TL
   - Hidayet: 28.000 TL
   - Ekstra: 0 TL

Personel silinmez; aktif/pasif yapılır. Pasif personel yeni işçi ödeme formunda görünmez, geçmiş raporlarda görünür.

## Firestore Security Rules

Başlangıç güvenlik kuralı `firestore.rules` içinde hazırdır:

- Auth olmayan okuyamaz/yazamaz.
- Kullanıcı sadece kendi `users/{uid}` profilini okuyabilir.
- `transactions` okuma/yazma aktif kullanıcılara açıktır.
- `employees` yazma sadece admin rolüne açıktır.
- `deleted_transactions` oluşturma aktif kullanıcılara açıktır.
- `deleted_transactions` okuma sadece admin rolüne açıktır.

Kuralları yayınlamak için:

```bash
firebase deploy --only firestore:rules
```

## Test Adımları

1. `flutter run -d chrome` ile uygulamayı aç.
2. Login ekranının geldiğini kontrol et.
3. Firebase Auth'ta oluşturduğun Onur hesabıyla giriş yap.
4. Firestore `users/{uid}` profilinden ad ve rolün otomatik geldiğini kontrol et.
5. Personel Ayarları'ndan varsayılan personelleri oluştur.
6. Ciro kaydı ekle.
7. Masraf kaydı ekle.
8. İşçi ödemesi ekle.
9. Bankaya yatan kaydı ekle.
10. Borç / alacak kaydı ekle.
11. Ana ekranda seçili ay kayıtlarının canlı göründüğünü kontrol et.
12. Bir kaydı sil; `deleted_transactions` içine taşındığını kontrol et.
13. Melek hesabıyla giriş yap; Personel Ayarları butonunun görünmediğini kontrol et.
14. Admin ile yeni personel ekle.
15. Maaş baremini değiştir.
16. Aylık raporda barem aşımı ve kalan maaş durumlarını kontrol et.
17. Masraf kategorilerinin progress/donut görünümünü kontrol et.
18. İşçi ödemelerinin progress görünümünü kontrol et.
19. WhatsApp Ay Özeti Gönder butonuyla WhatsApp bağlantısının açıldığını kontrol et.
20. `flutter build web --release` komutunun başarılı olduğunu kontrol et.

## Güncelleme Yayınlama

Kodda değişiklik yapıldıktan sonra GitHub Desktop içinde:

1. Değişiklikleri kontrol et.
2. Summary alanına kısa açıklama yaz.
3. `Commit to main` bas.
4. `Push origin` bas.
5. GitHub `Actions` sekmesinde yeşil tik gelmesini bekle.

Yayın adresi:

```text
https://onuronozer.github.io/palaoglu-kasa-takip-app/
```

## Ödeme Kaynağı Mantığı

Masraf ve işçi ödemelerinde ödeme kaynağı seçilir:

```text
Kasadan Ödendi
Şahsi Hesaptan Ödendi
Bankadan Ödendi
```

Hesaplama:

- Aylık Masraf: tüm masrafları toplar.
- İşçi Ödemeleri: tüm işçi ödemelerini toplar.
- Kar / Zarar: cirodan tüm masraf ve işçi ödemelerini düşer.
- Kasa Nakit: cirodan sadece kasadan ödenen masraf ve işçi ödemelerini, ayrıca bankaya yatanı düşer.

Örnek:

```text
Ciro: 10.000 TL
Elektrik: 2.000 TL, Şahsi Hesaptan Ödendi

Aylık Masraf: 2.000 TL
Kar / Zarar: 8.000 TL
Kasa Nakit: 10.000 TL
```

Eski kayıtlar ödeme kaynağı alanı boşsa otomatik `Kasadan Ödendi` kabul edilir.

## Kayıt Dökümü ve Düzeltme

Ana ekrandaki `Kayıt Dökümü` ekranından seçili ay kayıtları görülebilir:

```text
Ciro
Masraf
İşçi
Banka
Borç / Alacak
```

Her kayıtta tarih, kategori/kişi, açıklama, tutar, kaydeden ve ödeme kaynağı görünür. `Düzenle` butonuyla yanlış girilen tarih, tutar, kategori, kişi, açıklama veya ödeme kaynağı düzeltilebilir.

## Rapor Notları

- `Ciro - Masraf Trendi` günlük tarih yanılmasına sebep olabileceği için kaldırıldı.
- Rapor ekranına `Masraf Dökümü` eklendi.
- Masraf dökümünde tarih, kategori, açıklama, ödeme kaynağı, tutar ve kaydeden görünür.
- Pasif personelin o ay hiç işçi ödemesi yoksa raporda ve WhatsApp özetinde görünmez.
- Pasif personelin o ay ödemesi varsa geçmiş kayıt bozulmasın diye raporda görünmeye devam eder.

## Toplu Giriş

Ana ekrandaki `Toplu Giriş` ekranında:

- Günlük ciro tutarları gün gün yazılabilir.
- İşçi ödemeleri satır satır eklenebilir.
- Karışık toplu giriş ile ciro, masraf, işçi, banka, borç/alacak kayıtları aynı ekranda tek seferde kaydedilebilir.

## Palaoğlu Tarım Modülü

Uygulamaya girişten sonra iki işletme seçimi gelir:

```text
Palaoğlu Kıraathanesi
Palaoğlu Tarım
```

Tarım modülünde kullanılan Firestore koleksiyonları:

```text
tuccarlar
satislar
tahsilatlar
giderler
```

Tarım özellikleri:

- Tüccar ekleme ve cari bakiye takibi.
- Satış girme: ürün, kayısı çeşidi, kg, kg fiyatı ve toplam tutar.
- Satış kaydı eklenince `tuccarlar/{id}.guncel_bakiye` otomatik artar.
- Tahsilat girme: alınan tutar tüccar bakiyesinden otomatik düşer.
- Bahçe gideri girme: mazot, ilaç, gübre, budama, işçilik, su, elektrik.
- Toplu giriş: satış, tahsilat ve gider satırları tek ekrandan kaydedilebilir.
- Tarım raporu: satış cirosu, tahsilat, kalan alacak, net durum, ürün satışları, gider kategorileri ve tüccar cari dökümü.

Firebase Rules yayınlanırken `firestore.rules` içindeki `tuccarlar`, `satislar`, `tahsilatlar`, `giderler` kurallarının Firebase Console > Firestore > Rules ekranına eklenmesi gerekir.
