# Güncel Durum — "Ne durumdayız?" Özeti

Bu dosya proje durumunu ve sıradaki adımları not alır. Kullanıcı "ne durumdayız?" dediğinde buradan özet verilir.

---

## Son not (kullanıcı talebi)

- **Test bekleyen:**  
  İstatistikler ekranı ve alarmlar henüz test edilmedi.  
  - **İstatistikler:** Grafiklerde her güne nokta; 1. tıklama = o günün değeri (maliyet/kâr) kutu içinde; aynı noktaya 2. tıklama = gün detay popup (işlemler, maliyet, kâr/zarar, sağ üst kapatma). Aylık kâr/zarar bar grafiği düzenlendi (sıfır çizgisi, çubuk yönü, boşluk).  
  - **Alarmlar:** 10 sn banner, "Alarmı kaldır", tekrar tetikleme (hysteresis), yerel bildirim altyapısı, bildirimden açıldığında banner tekrar + Alarmı kaldır.

- **Yapılan (API entegrasyonu):**  
  - **Döviz:** Frankfurter (USD/TRY, EUR/TRY) zaten kullanılıyordu; değişiklik yok.  
  - **Altın:** Önce Kapalıçarşı (Vercel projesi) deneniyor; yanıt/JSON yoksa MetalPriceAPI (key varsa), yoksa mock.  
  - **Kripto:** Binance public API ile gerçek fiyat; TL için USD/TRY (Frankfurter) ile çarpılıyor.  
  - **Gümüş / Platin / Paladyum:** MetalPriceAPI (XAG, XPT, XPD) USD + USD/TRY ile TL; key yoksa mock.  
  - **Config:** `api_config.dart` — MetalPriceAPI key `--dart-define=METALPRICEAPI_KEY=xxx` ile verilebilir.

- **Sıradaki adım:**  
  İstatistikler ve alarmları test et; MetalPriceAPI key ile gümüş/platin/paladyum gerçek fiyata geçer. Kapalıçarşı projesi JSON endpoint sunuyorsa altın da otomatik gerçek veri alır.

---

## "Ne durumdayız?" denildiğinde söylenecekler

1. **Yapılanlar:** İstatistik grafikleri (nokta + 1. tıklama değer / 2. tıklama gün detay popup + aylık bar), alarm (10 sn banner, Alarmı kaldır, tekrar tetikleme, yerel bildirim), **API entegrasyonu** (Frankfurter döviz, Kapalıçarşı+MetalPriceAPI altın, Binance kripto, MetalPriceAPI gümüş/platin/paladyum).
2. **Test:** İstatistikler ve alarmlar test edilecek.
3. **Sırada:** MetalPriceAPI key ekleyerek gümüş/platin/paladyum gerçek fiyat; Kapalıçarşı JSON endpoint’i (varsa) ile altın.
