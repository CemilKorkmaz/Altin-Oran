# Altın Oran

Flutter kaynak projesi [`AltinOran/`](AltinOran/) içinde. Drive'daki iki sürüm karşılaştırıldı: AltinOran1, fiyat ekranları ve gold-api geliştirmelerini içerdiği için temel alındı. AltinOran2'ye özgü kaynak dosyası bulunmadı.

## Önemli: geliştirme durumu

Bu proje henüz kullanıma hazır bir finans uygulaması olarak doğrulanmadı. İşlemler, hedefler ve alarmlar şu anda yalnızca bellekte tutulur; uygulama kapandığında kaybolabilir. Bu nedenle gerçek portföy verilerini kaydetmek veya yatırım kararı vermek için kullanmayın. Fiyat kaynakları ve alarmlar cihazda doğrulanmadı.

- Gram ve ziynet altını için uygulama bağımsız Gramhane JSON API'sini kullanır; verinin kaynağı ve son zamanı gösterilir, 20 dakikadan eski değerler gecikmeli işaretlenir. API dış hizmettir, erişimi ve doğruluğu garanti edilmez.
- `gold-api` ayrı bir sunucudur; APK ile birlikte otomatik çalışmaz. Gerçek cihazdan erişilebilen HTTPS sunucu adresi `--dart-define=BIGPARA_GOLD_API_URL=https://...` ile verilebilir.
- Kullanıcının isteğiyle MetalPriceAPI anahtarı tekrar uygulamaya eklendi; açık kaynak kodundan ve APK dosyasından görülebilir. GitHub Actions ortamında MetalPriceAPI ve Frankfurter yanıt verdi; erişim ve kota zamanla değişebilir.
- Android release yapılandırması şu anda debug imzası kullanır; test amaçlıdır ve kalıcı dağıtım/Play Store imzası değildir.
- API erişimi, lisans/kullanım şartları, fiyat doğruluğu ve cihaz testleri ayrıca doğrulanmalıdır. Kripto için Binance ve gerektiğinde Binance US kullanılır; her varlık her borsada bulunmayabilir. Kripto USDT fiyatları yaklaşık olarak USD kabul edilerek TL’ye çevrilir.

## Kontrol ve APK oluşturma

Flutter 3.41.2, Java 17 ve Android SDK ile:

```sh
cd AltinOran
flutter pub get
flutter test
flutter build apk --release
```

APK: `AltinOran/build/app/outputs/flutter-apk/app-release.apk`. GitHub Actions aynı kontrolleri çalıştırıp yalnızca başarılıysa test APK'sını artifact olarak saklar.
