# Birikim & Portföy — Proje Dokümanı (Detaylı Prompt)

Bu dosya uygulamanın vizyonu, yapılanlar, hedefler ve yapılacaklar dahil tam proje özetidir. Yeni geliştirici veya AI asistanı bu metni referans alarak devam edebilir.

---

## 1. Uygulama Özeti

**İsim:** Birikim & Portföy  
**Platform:** Flutter (Android / iOS)  
**Hedef kitle:** Ev kullanıcısı; birikim ve portföy takibi (altın, döviz, kripto, hisse vb.)

**Temel amaç:** Kullanıcının yaptığı alış/satış işlemlerini kaydetmesi, canlı fiyatlarla portföy değerini ve kâr/zararı görmesi, fiyat alarmları kurması, hedefler belirlemesi ve istatistiklerini takip etmesi.

---

## 2. Teknoloji ve Mimari

- **Framework:** Flutter (Dart 3.x)
- **State yönetimi:** Riverpod (Provider, StateNotifierProvider, StateProvider)
- **Navigasyon:** Navigator.push / MaterialPageRoute (shell altında sayfa indeksi)
- **Tema:** `AppThemeMode`: `light` (açık), `darkGold` (lacivert/sarı koyu). Varsayılan: darkGold.
- **Veri:** Şu an tamamen yerel (hafıza + SharedPreferences ayarlar). Cloud yedekleme “daha sonra” planında.
- **Paketler (öne çıkanlar):** flutter_riverpod, fl_chart, http, local_auth, path_provider, share_plus, file_picker, shared_preferences, flutter_local_notifications, intl

**Klasör yapısı (features):**

- **alerts:** Fiyat alarmları (PriceAlarm), bildirim banner’ı, yerel bildirim altyapısı (NotificationService, PendingAlarmData)
- **dashboard:** Ana sayfa, canlı fiyat kartı, birikim özeti, varlık dağılımı kartları
- **goals:** Hedefler (maden miktarı veya kâr hedefi), ilerleme, tamamlanma popup’ı
- **portfolio:** Birikimlerim listesi, varlık detayı, işlem geçmişi, “Sat” butonu, global işlem numaralandırma (Alış 1, Alış 2, Satış 1…)
- **prices:** Altın fiyatı, USD/TRY, EUR/TRY, desteklenen varlıklar (SupportedAsset), asset_price_service
- **rates:** Kurlar sayfası (canlı kur listesi, filtreler, pull-to-refresh, alarm/favori butonları)
- **settings:** Tema, görüntü para birimi, varsayılan gram ayarı, alarm banner aç/kapa, biyometrik kilit, dışa/içe aktar (JSON/CSV), Cloud yedekleme (placeholder)
- **shell:** Alt navigasyon, sürüklenebilir FAB “Yatırım Ekle / Sat”
- **stats:** İstatistikler sayfası, zaman filtreleri (Bugün, Bu hafta, Son 7 gün, Bu ay, Bu yıl, Tümü), maliyet ve toplam kâr/zarar grafikleri, aylık kâr/zarar bar grafiği
- **transactions:** InvestmentTransaction domain, ekleme/düzenleme sayfası, serileştirme (JSON/CSV), import/export

---

## 3. Yapılanlar (Tamamlanan Özellikler)

### 3.1 Genel

- Riverpod ile state yönetimi; sayfalar ConsumerWidget / ConsumerStatefulWidget
- Tema: Açık (light) ve koyu lacivert/sarı (darkGold), varsayılan darkGold
- Alt navigasyon: Ana Sayfa, Kurlar, Birikimlerim, İstatistik, Hedefler, Ayarlar
- Sürüklenebilir FAB: “Yatırım Ekle / Sat” — sürüklenebilir, alt sınıra kadar, siyah ikon/yazı
- SafeArea(bottom: false) ve uygun padding ile içerik nav bar üst çizgisine kadar; “ölü alan” kaldırıldı
- Ortak bileşenler: SectionHeader, EmptyStateView; pull-to-refresh (Dashboard, Kurlar, vb.)

### 3.2 Ana Sayfa (Dashboard)

- Canlı gram altın (24 ayar) fiyat kartı; “Canlı” göstergesi + “Yenile” butonu simetrik
- Birikim & Portföy özeti; Genel Özet (toplam değer, kâr/zarar halkası)
- Varlık dağılımı: maden bazlı, döviz bazlı, coin/hisse bazlı (güncel değere göre yüzde); karta tıklanınca genel dağılım detay sayfası
- Görüntü para birimi (TL/USD/EUR) ayara göre formatlama (formatDisplayCurrency)
- Reklam/duyuru barı: Genel Özet başlığının üstünde, kompakt
- Fiyat alarmları bu sayfada da kontrol edilir; tetiklenince banner gösterilir

### 3.3 Kurlar Sayfası

- Liste: Dolar → Euro → Altınlar sırası; genişleyen kartlar (alış/satış, günlük düşük/yüksek, kapanış, Alarm Oluştur, Favorilere Ekle)
- Filtreler: Tümü, Döviz, Altın/Maden, Diğer; Kapalı Çarşı / Banka
- Başlık: “Kurlar” + “Canlı” göstergesi; sağda favori, pasta grafik, bar grafik (İstatistik’e gider), arama
- Kırmızı bel ikonu (alarm); pull-to-refresh (altın, USD/TRY, EUR/TRY)
- Altın/maden filtresinde döviz (fx_) hariç tutulur

### 3.4 Birikimlerim (Portföy)

- Varlık listesi: Kurlar ile uyumlu semboller (Au, Ag, Pt, Pd, USD, EUR, BTC, ETH) ve renkler
- Sıralama: Anlık kâr/zarar potansiyeline göre yüksekten düşüğe
- Her satırda “Sat” chip’i; varlık detay sayfasında altta ortada büyük “Sat” butonu
- İşlem geçmişi: Tarih grupları (Bugün, Dün, “6 Mart 2026”); global numaralandırma (Alış 1, Alış 2, Satış 1…)
- Gram altın/bilezik işlemlerinde ayar (22 Ayar, 24 Ayar) gösterimi
- AddTransactionPage: presetGoldPurity, presetCustomAssetId ile “Sat” akışında ön seçim

### 3.5 İstatistikler

- Zaman filtreleri: Bugün, Bu hafta, Son 7 gün, Bu ay, Bu yıl, Tümü
- Grafik 1: Maliyet (maliyet bazı) zaman içinde
- Grafik 2: Toplam kâr/zarar (gerçekleşen + gerçekleşmeyen) zaman içinde
- Grafik 3: Aylık kâr/zarar bar grafiği
- X ekseni: 8’e kadar noktada tüm tarihler etiketlenir; “Dönem: dd/MM - dd/MM”; “Tümü”de ilk işlem tarihinden başlar
- Boş/az veri durumları için EmptyStateView

### 3.6 Hedefler

- Hedef türleri: Maden (varlık miktarı) veya Kâr (portföy kâr hedefi)
- Herhangi bir varlık türü için miktar hedefi; gram altın/bilezik için ayar seçimi (24/22/18/14 veya “gram bazında toplam”)
- Hedefe isteğe bağlı fiyat alarmı bağlama (PriceAlarm.goalId)
- Tamamlanan hedef: Popup (“Hedef tamamlandı!”) + SnackBar; kartta “Tamamlandı” chip’i
- completedGoalCelebrationShownProvider ile aynı hedef için tekrarlı kutlama engeli

### 3.7 Fiyat Alarmları

- Model: PriceAlarm (assetId, assetName, direction: above/below, targetPrice, goalId, lastTriggeredPrice)
- Hysteresis: Fiyat hedefin diğer tarafına geçince lastTriggeredPrice sıfırlanır; tekrar tetiklenince yeniden bildirim
- Alarm tetiklenince: Uygulama içi banner (10 sn otomatik kapanır) + “Alarmı kaldır” butonu
- Banner UX: Yön (yukarı/aşağı) için farklı renk (yeşil/kırmızı), emoji (📈/📉), 🔔
- Yerel bildirim altyapısı: NotificationService (flutter_local_notifications); tetiklenince sistem bildirimi + payload (alarmId)
- Uygulama bildirimden açıldığında: Pending alarm SharedPreferences’ten okunur, banner tekrar gösterilir, “Alarmı kaldır” ile kaldırılır
- POST_NOTIFICATIONS (Android 13+) AndroidManifest’te tanımlı

### 3.8 Ayarlar

- Tema: Açık / Koyu (lacivert)
- Görüntü para birimi: TL, USD, EUR
- Varsayılan gram ayarı: 24/22/18/14 (yeni işlemde ön seçim)
- Alarm banner’ı aç/kapa
- Biyometrik kilit: Açılışta isteğe bağlı (local_auth)
- Dışa/içe aktar: JSON ve CSV (transaction_serialization); paylaşım (share_plus), dosya seçimi (file_picker)
- Cloud yedekleme: Placeholder (“daha sonra”)

### 3.9 Diğer

- USD/EUR işlemleri PnL ve dağılıma dahil; dashboard’da USD/EUR seçenekleri (ör. 30 TL mock)
- Biyometrik geçiş: BiometricGate, ayardan açılıp kapatılır
- Para formatı: formatMoney, formatSignedTl, formatDisplayCurrency (TL/USD/EUR)

---

## 4. Yapılacaklar ve Hedefler

### 4.1 Öncelikli / Kısa Vadeli

- **Bildirim izni:** İlk alarm kurulurken veya ayarlardan bildirim izni isteme (Android 13+); altyapı hazır, izin akışı eklenebilir.
- **Gerçek API’ler:** Altın için altyapı var; USD/TRY, EUR/TRY (Frankfurter) kullanılıyor. Gümüş/platin gerçek API; Kurlar’da günlük düşük/yüksek alanlarının API’den doldurulması.
- **Linter:** withOpacity → withValues, deprecated Flutter API’lerinin temizlenmesi; prefer_const_constructors vb. (isteğe bağlı).

### 4.2 Orta Vadeli

- **Cloud yedekleme:** Ayarlardaki placeholder’ın gerçek senkronizasyon (hesap, yedekleme/geri yükleme) ile değiştirilmesi.
- **Onboarding:** İlk açılışta kısa tanıtım ekranları.
- **Birim testleri:** PnL, dağılım, alarm hysteresis, hedef ilerleme mantığı için unit testler.
- **Kurlar bar grafik butonu:** İstatistik’e gitmek yerine Kurlar’a özel grafik sayfası açılması (karar verilecek).

### 4.3 Uzun Vadeli / Fikirler

- OS seviye bildirimde “Alarmı kaldır” aksiyonu (notification action).
- Hedef/haber hatırlatıcıları.
- Çoklu dil (i18n).
- Widget (ana ekran widget’ı).

---

## 5. Önemli Domain ve Teknik Notlar

- **AssetType:** gramAltin, ceyrek, yarim, tam, cumhuriyet, bilezik22, onsAltin, gumus, platin, paladyum, usd, eur, btc, eth, otherCrypto, stock.
- **GoldPurity:** carat24, carat22, carat18, carat14 (gram altın/bilezik için).
- **InvestmentTransaction:** amount, unitPrice, dateTime, direction (buy/sell), purchaseChannel, priceSource, goldPurity, customAssetId (otherCrypto vb.).
- **Portföy değeri:** Varlık bazında kalan miktar × güncel fiyat (veya maliyet); altın eşdeğeri gram ve TL maliyet hesapları transactions_providers / asset_price_service ile.
- **Goal:** type = assetAmount | profit; assetAmount için assetType, targetAmount, isteğe bağlı goldPurity; profit için targetProfitTl; linkedAlarmId ile PriceAlarm’a bağ.
- **PriceAlarm:** direction above/below, targetPrice, lastTriggeredPrice (hysteresis), isActive; tetiklenince NotificationService.showAlarmNotification + SharedPreferences’e yazılır; bildirimden açılışta pendingAlarmProvider ile banner tekrar gösterilir.
- **İşlem serileştirme:** transaction_serialization.dart; JSON/CSV export/import; replaceAll ile mevcut listeyi değiştirme.

---

## 6. Dosya Yolları (Özet)

| Amaç | Dosya |
|------|--------|
| Uygulama girişi, tema, biometric gate | `lib/main.dart`, `lib/src/app.dart` |
| Shell, FAB, pending alarm dinleyici | `lib/src/features/shell/presentation/home_shell_page.dart` |
| Ana sayfa, dağılım, canlı fiyat | `lib/src/features/dashboard/presentation/dashboard_page.dart` |
| Kurlar listesi ve filtreler | `lib/src/features/rates/presentation/rates_page.dart` |
| Birikimler, Sat, işlem geçmişi | `lib/src/features/portfolio/presentation/portfolio_page.dart` |
| İstatistik grafikleri | `lib/src/features/stats/presentation/stats_page.dart`, `stats_providers.dart` |
| Hedefler CRUD, tamamlanma popup | `lib/src/features/goals/presentation/goals_page.dart`, `goals_providers.dart` |
| Alarm modeli, tetikleme mantığı | `lib/src/features/alerts/domain/price_alarm.dart`, `price_alarm_providers.dart` |
| Banner + 10 sn + Alarmı kaldır | `lib/src/features/alerts/presentation/alarm_notification_banner.dart` |
| Yerel bildirim, pending | `lib/src/features/alerts/application/notification_service.dart`, `pending_alarm_data.dart` |
| Ayarlar, export/import | `lib/src/features/settings/presentation/settings_page.dart`, `settings_providers.dart` |
| İşlem ekleme/düzenleme | `lib/src/features/transactions/presentation/add_transaction_page.dart` |
| Para birimi formatı | `lib/src/features/settings/currency_display.dart` |
| Tema | `lib/src/core/theme/app_theme.dart` |

---

## 7. Kullanım Notları (Geliştirici / AI)

- Yeni özellik eklerken mevcut Riverpod provider’ları ve domain modellerini (InvestmentTransaction, PriceAlarm, Goal, AppSettings) kullan; tutarlı isimlendirme (Türkçe UI, İngilizce kod).
- UI metinleri Türkçe; formatMoney/formatDisplayCurrency ile para gösterimi.
- Alarm tetikleme: checkAndTrigger (price_alarm_providers); banner + NotificationService.showAlarmNotification birlikte çağrılır (dashboard, portfolio, rates, stats).
- Bu doküman güncellenebilir; büyük özellik veya mimari değişiklikten sonra “Yapılanlar” ve “Yapılacaklar” bölümlerini revize et. Güncel kısa durum ve "ne durumdayız?" özeti için **DURUM.md** dosyasına bak.
