# Google E-Tablo Aylık Sayfa Otomasyonu

Bu kurulum her ay yeni kıraathane sayfasını oluşturur, tarihleri doğru aya
çevirir ve aylık giriş alanlarını temizler. Formüller, biçimlendirme, işçi
isimleri, maaş baremleri ve sabit gider başlıkları korunur.

## Bir Defalık Kurulum

1. Palaoğlu Google E-Tablo dosyasını açın.
2. `Uzantılar > Apps Script` menüsünü açın.
3. Editördeki mevcut örnek kodu silin.
4. `scripts/google_sheets_monthly_setup.gs` dosyasının tamamını yapıştırın.
5. Kaydedin ve Apps Script sekmesini kapatın.
6. E-Tabloyu yenileyin.
7. Üst menüde `Palaoğlu > Aylık otomasyonu kur` seçeneğini çalıştırın.
8. Google izin ekranını bir kez onaylayın.

Otomasyon her gün saat 01.00 civarında çalışır. Ayın sayfası zaten varsa hiçbir
değişiklik yapmaz; yeni ayın ilk çalışmasında önceki ayı kopyalayarak yeni
sayfayı hazırlar.

`Palaoğlu > Gelecek ayın sayfasını oluştur` seçeneğiyle yeni sayfa önceden de
oluşturulabilir.
