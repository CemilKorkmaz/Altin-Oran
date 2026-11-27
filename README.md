# Altın Oran

Flutter kaynak projesi [`AltinOran/`](AltinOran/) içinde. Drive'daki iki sürüm karşılaştırıldı: AltinOran1, fiyat ekranları ve gold-api geliştirmelerini içerdiği için temel alındı. AltinOran2'ye özgü kaynak dosyası bulunmadı.

## Önemli: geliştirme durumu

Bu proje henüz kullanıma hazır bir finans uygulaması olarak doğrulanmadı. İşlemler, hedefler ve alarmlar şu anda yalnızca bellekte tutulur; uygulama kapandığında kaybolabilir. Bu nedenle gerçek portföy verilerini kaydetmek veya yatırım kararı vermek için kullanmayın. Fiyat kaynakları ve alarmlar cihazda doğrulanmadı.

- `gold-api` ayrı bir sunucudur; APK ile birlikte otomatik çalışmaz. Gerçek cihazdan erişilebilen HTTPS sunucu adresi `--dart-define=BIGPARA_GOLD_API_URL=https://...` ile verilebilir.
- MetalPriceAPI anahtarı koddaki varsayılandan kaldırıldı. `--dart-define` ile uygulamaya gömülen anahtar gizli değildir; üretimde anahtarları güvenli bir sunucuda tutun. Anahtar olmadan bazı maden fiyatları kullanılamaz.
- Android release yapılandırması şu anda debug imzası kullanır; test amaçlıdır ve kalıcı dağıtım/Play Store imzası değildir.
- API erişimi, lisans/kullanım şartları, fiyat doğruluğu ve cihaz testleri ayrıca doğrulanmalıdır. Kur verisi ve kripto da üçüncü taraf servislere bağlıdır.

## Kontrol ve APK oluşturma

Flutter 3.41.2, Java 17 ve Android SDK ile:

```sh
cd AltinOran
flutter pub get
flutter test
flutter build apk --release
```

APK: `AltinOran/build/app/outputs/flutter-apk/app-release.apk`. GitHub Actions aynı kontrolleri çalıştırıp yalnızca başarılıysa test APK'sını artifact olarak saklar.
