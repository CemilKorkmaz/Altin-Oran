# Türkiye Odaklı Birikim/Portföy Uygulaması — API Önerileri

Uygulama: Alım-satım yapılmıyor; kullanıcı elindeki varlıkları ve tarih/fiyat bilgisini girerek portföy, toplam değer ve kâr/zarar takibi yapıyor. TL odaklı; USD/EUR bazında görüntüleme seçeneği var.

---

## 1) Döviz (USD/TRY, EUR/TRY)

| Alan | Frankfurter | TCMB EVDS | ExchangeRate-API |
|------|-------------|-----------|------------------|
| **API adı** | Frankfurter | TCMB EVDS | ExchangeRate-API |
| **Resmî site** | [frankfurter.app](https://www.frankfurter.app/docs/) | [evds2.tcmb.gov.tr](https://evds2.tcmb.gov.tr) | [exchangerate-api.com](https://www.exchangerate-api.com/) |
| **Base URL** | `https://api.frankfurter.app` | `https://evds2.tcmb.gov.tr/service/evds/` | `https://v6.exchangerate-api.com/v6/{key}/` |
| **Önerilen endpoint** | `/latest?from=USD&to=TRY` (EUR için ayrı) | `series=TP.DK.USD.A.YTL` (alış), satış ve EUR için ayrı seri kodları | `/latest/USD` veya `/pair/USD/TRY` |
| **Parametreler** | Yok (anahtar yok) | `series`, `startDate`, `endDate`, `type=json`, `key` (API anahtarı) | API key (ücretsiz planda) |
| **Ücretsiz / limit** | Ücretsiz, resmî limit yok; günlük ~16:00 CET güncelleme | Ücretsiz; kayıt + API anahtarı; EVDS kullanım koşullarına tabi | Ücretsiz: 1500 istek/ay, günlük 1 güncelleme; açık erişim (anahtarsız) günde ~1 istek |
| **Günlük low/high** | Hayır | Hayır (günlük tek resmî kur) | Hayır |
| **Tarihsel veri** | Evet (1999'dan itibaren) | Evet (tarih aralığı ile) | Sınırlı (ücretli planda daha iyi) |
| **Türkiye uygunluk** | TRY destekli, ECB referans kuru | Resmî TCMB kurları; Türkiye için en "resmî" kaynak | TRY destekli |
| **Risk / dezavantaj** | Tek günlük güncelleme; ECB bazlı (banka kuru değil) | Kayıt ve anahtar; bazen yanıt süresi / erişilebilirlik | Ücretsiz planda aylık kotası az; günlük 1 güncelleme |
| **Birincil öneri** | Evet (basit, anahtarsız, TRY) | Evet (resmî kur istiyorsan) | Hayır (Frankfurter yeterli) |
| **Fallback** | TCMB EVDS veya ExchangeRate-API | Frankfurter | Frankfurter |

**Özet:** Frankfurter ile devam etmek mantıklı: ücretsiz, anahtar yok, TRY ve EUR/TRY var. "Resmî" TCMB kuru istersen TCMB EVDS'i ikincil kaynak (fallback) veya seçenek olarak eklenebilir. TCMB için EVDS'e kayıt olup API anahtarı almak ve seri kodlarına göre (örn. TP.DK.USD.A.YTL, TP.DK.EUR.A.YTL) istek atmak gerekir.

---

## 2) Altın (gram altın TL, isteğe bağlı günlük düşük/yüksek, alış/satış, Türkiye odaklı)

| Alan | Kapalıçarşı API (Vercel) | MetalPriceAPI | TCMB altın | CollectAPI (altın) |
|------|---------------------------|---------------|------------|---------------------|
| **API adı** | Kapali-Carsi-Altin-API | MetalpriceAPI | TCMB EVDS (altın serileri) | CollectAPI – Altın, Döviz ve Borsa |
| **Resmî site** | [GitHub: rslcskn/Kapali-Carsi-Altin-API](https://github.com/rslcskn/Kapali-Carsi-Altin-API), canlı: [kapali-carsi-altin-api.vercel.app](https://kapali-carsi-altin-api.vercel.app) | [metalpriceapi.com](https://metalpriceapi.com) | [evds2.tcmb.gov.tr](https://evds2.tcmb.gov.tr) | [collectapi.com](https://collectapi.com/tr) (ekonomi / altın) |
| **Base URL** | `https://kapali-carsi-altin-api.vercel.app` | `https://api.metalpriceapi.com/v1/` | `https://evds2.tcmb.gov.tr/service/evds/` | CollectAPI dokümantasyonundaki base URL |
| **Önerilen endpoint** | Site üzerinde gram/çeyrek/yarım/tam altın tablosu var; repo'da JSON endpoint'i (varsa `/api` veya benzeri) kontrol edilmeli | `/v1/latest?api_key=...&base=TRY&currencies=XAU` (gram için ons→gram çevrimi) | Altın seri kodları (örn. külçe altın) – EVDS katalogundan seçilmeli | Dokümantasyondaki altın endpoint'i |
| **Parametreler** | Muhtemelen parametre yok (tek sayfa/scraping tabanlı) | `api_key`, `base`, `currencies` | `series`, `startDate`, `endDate`, `type`, `key` | Authorization header (token) |
| **Ücretsiz / limit** | Ücretsiz; 3. taraf Vercel projesi, limit belirsiz | Ücretsiz kotası var; aşımda ücret | TCMB kayıt + anahtar; kullanım koşulları | Ücretsiz deneme; sonrası ücretli paket |
| **Günlük low/high** | Kapalıçarşı sayfasında "değişim" var; API'de açık değil | Plana göre (genelde spot) | TCMB'de genelde günlük tek değer | Dokümantasyona bağlı |
| **Tarihsel veri** | Muhtemelen hayır | Evet (planla) | Evet (EVDS serileri) | Bilinmiyor |
| **Türkiye uygunluk** | Kapalıçarşı odaklı; gram/çeyrek/yarım/tam TL, alış/satış mantığı | Global spot; TRY bazlı fiyat verilebiliyor | Resmî TCMB altın (külçe vb.) | Türkiye piyasası için toplanmış veri |
| **Risk / dezavantaj** | 3. taraf, sürdürülme riski; scraping veya harici kaynağa dayalı olabilir | Ücretsiz kotası sınırlı; global spot (Kapalıçarşı değil) | Sadece belirli altın türleri; günlük | Ücretli aşamada maliyet |
| **Birincil öneri** | Türkiye odaklı MVP için evet (gram TL + alış/satış) | Placeholder yerine veya yedek (TRY + XAU) | Resmî seri istiyorsan | Ücret kabul edilebilirse alternatif |
| **Fallback** | MetalPriceAPI (TRY + XAU) | Kapalıçarşı API veya TCMB | Frankfurter + MetalPriceAPI (XAU→TRY) | - |

**Kapalıçarşı / GitHub notu:** GitHub'da "Kapali-Carsi-Altin-API" ve "Trunçgil Finans" gibi projeler Kapalıçarşı / Türkiye piyasası kaynaklı altın (ve bazen döviz) verisini JSON'a dönüştürüyor. Genelde:
- Tek bir canlı URL (ör. Vercel) üzerinden tablo veya JSON,
- Gram, çeyrek, yarım, tam altın TL,
- Alış/satış ve bazen "değişim" bilgisi  
veriyor. Doğrudan "resmî Kapalıçarşı API" yok; veriler 3. taraflarca derleniyor veya scraping ile toplanıyor. Kullanırsan: kaynağı (repo, Vercel) takip et, fallback (MetalPriceAPI veya TCMB) planla.

---

## 3) Gümüş (gram gümüş TL; gerekirse USD spot + USD/TRY)

| Alan | MetalPriceAPI | Metals-API |
|------|----------------|------------|
| **API adı** | MetalpriceAPI | Metals-API |
| **Resmî site** | [metalpriceapi.com](https://metalpriceapi.com/silver) | [metals-api.com](https://metals-api.com) |
| **Base URL** | `https://api.metalpriceapi.com/v1/` | `https://api.metals-api.com/` (veya dokümantasyondaki) |
| **Önerilen endpoint** | `/latest?api_key=...&base=USD&currencies=XAG` veya `base=TRY` (TRY destekliyse) | Latest / historical; XAG (gümüş) |
| **Parametreler** | `api_key`, `base`, `currencies` | API key, birim/para parametreleri |
| **Ücretsiz / limit** | Ücretsiz kota; aşım ücretli | Ücretsiz tier mevcut |
| **Günlük low/high** | Planlara göre | Zaman serisi / fluctuation endpoint'leri |
| **Tarihsel veri** | Evet | Evet |
| **Türkiye uygunluk** | TRY bazlı sunulabiliyorsa doğrudan; yoksa USD + Frankfurter USD/TRY ile TL | USD spot + Frankfurter ile TL |
| **Risk / dezavantaj** | Kota; global spot | Kota; dokümantasyon kontrolü gerekir |
| **Birincil öneri** | Evet (gümüş için) | Fallback |

**Mantık:** Önce MetalPriceAPI ile XAG'i TRY veya USD al; TRY yoksa **USD spot (XAG) + Frankfurter USD/TRY** ile gram gümüş TL hesapla (ons → gram çevrimi: 1 ons ≈ 31,1035 gr).

---

## 4) Platin / Paladyum (gram, TL)

| Alan | MetalPriceAPI | Metals-API |
|------|----------------|------------|
| **API adı** | MetalpriceAPI | Metals-API |
| **Resmî site** | [platinum](https://metalpriceapi.com/platinum), [palladium](https://metalpriceapi.com/palladium) | [metals-api.com](https://api.metals-api.com/) |
| **Base URL** | `https://api.metalpriceapi.com/v1/` | Dokümantasyondaki URL |
| **Önerilen endpoint** | `/latest?base=TRY&currencies=XPT,XPD` (veya USD + USD/TRY) | XPT (platin), XPD (paladyum) endpoint'leri |
| **Parametreler** | `api_key`, `base`, `currencies` | API key vb. |
| **Ücretsiz / limit** | Ücretsiz kota | Ücretsiz tier |
| **Günlük low/high** | Planlara göre | Var (fluctuation / time-series) |
| **Tarihsel veri** | Evet | Evet |
| **Türkiye uygunluk** | TRY varsa doğrudan; yoksa USD + Frankfurter | USD + Frankfurter ile TL |
| **Risk / dezavantaj** | Kota | Kota |
| **Birincil öneri** | Evet | Fallback |

Gram için: API genelde ons (troy) verir; **1 troy ons ≈ 31,1035 gr** ile bölerek gram fiyatı hesaplanır.

---

## 5) Kripto (BTC, ETH ve yaygın coinler; anlık fiyat, 24s değişim, isteğe bağlı low/high)

| Alan | Binance Public API | CoinGecko API |
|------|--------------------|----------------|
| **API adı** | Binance Public Market Data | CoinGecko (Demo/Free) |
| **Resmî site** | [binance-api-docs](https://binance-docs.github.io/apidocs/) | [coingecko.com/api](https://www.coingecko.com/api) |
| **Base URL** | `https://api.binance.com/api/v3/` | `https://api.coingecko.com/api/v3/` |
| **Önerilen endpoint** | `/ticker/price?symbol=BTCUSDT`; 24s istatistik: `/ticker/24hr`; mum: `/klines` (low/high) | `/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_24hr_change=true`; `/coins/markets` (daha detay) |
| **Parametreler** | `symbol` (örn. BTCUSDT, ETHUSDT) | `ids`, `vs_currencies`, `include_24hr_change`, `include_24hr_vol` vb. |
| **Ücretsiz / limit** | Anahtar yok (public); ağırlık bazlı limit (dakikada yüzlerce istek makul) | Demo: 30 çağrı/dk, 10.000/ay; anahtar bazen gerekmez |
| **Günlük low/high** | Evet (`/klines` veya 24hr ticker) | Sınırlı (market verisi ile) |
| **Tarihsel veri** | Evet (`/klines`) | Sınırlı |
| **Türkiye uygunluk** | Erişilebilir; fiyat USDT | Erişilebilir; USD bazlı |
| **Risk / dezavantaj** | Borsa fiyatı (spot); ağırlık limiti takibi gerekir | 24s değişim ve low/high için endpoint seçimi gerekir |
| **Birincil öneri** | Trading/portföy için anlık fiyat + 24s + low/high istiyorsan | Çok sayıda coin, basit fiyat + 24s değişim |
| **Fallback** | CoinGecko | Binance |

**Ne zaman hangisi:**  
- **Binance:** Anlık fiyat, 24s değişim ve low/high tek yerden, USDT bazlı; portföy/trading hissi için uygun.  
- **CoinGecko:** Çok sayıda coin, basit "fiyat + 24s değişim"; Binance'te listelenmeyen token'lar için.  
MVP için **Binance** yeterli; listelenmeyen coin'ler için **CoinGecko** fallback eklenebilir.

---

## 6) Türkiye'ye özel veri (banka altın, serbest piyasa / Kapalıçarşı, borsa/portallar)

| Alan | Özet |
|------|------|
| **Banka altın fiyatları** | TCMB veya bankaların resmî, genel kullanıma açık REST API'si yok. Doviz.com, tldoviz.com vb. siteler banka bazlı gram altın alış/satış gösteriyor; veri oradan toplanıyor (muhtemelen manuel veya scraping). |
| **Serbest piyasa / Kapalıçarşı** | Resmî "Kapalıçarşı API" yok. GitHub'daki projeler (Kapali-Carsi-Altin-API, Trunçgil Finans vb.) 3. taraf; bir kaynaktan (site/scraping) veriyi alıp JSON'a çeviriyor. |
| **Borsa / finans portalları** | Hisse.net, doviz.com, bigpara vb. genelde public API sunmuyor; kullanım şartları otomasyonu/scraping'i yasaklayabiliyor. |
| **Resmî/public API var mı?** | Döviz için TCMB EVDS; altın için TCMB'de sadece belirli seriler (külçe vb.). Banka bazlı "canlı gram altın" için resmî public API yok. |
| **Scraping gerekir mi?** | Resmî API ile yetinmeyeceksen, banka/Kapalıçarşı benzeri kaynaklar için evet; ama bu sitelerin kullanım şartlarına dikkat gerekir. |
| **Scraping önerilir mi?** | **Önerilmez.** Sebepler: (1) Kullanım şartları çoğu sitede otomasyonu/scraping'i yasaklıyor; (2) Türkiye'de veritabanı ve site içeriği fikri mülkiyet ve haksız rekabet kapsamında değerlendirilebiliyor; (3) HTML yapısı değişince uygulama kırılır; (4) Sürdürülebilirlik ve yasal risk yüksek. Tercih: 3. taraf "hazır" API'ler (Kapalıçarşı API, CollectAPI vb.) veya sadece resmî/lisanslı kaynaklar. |

---

## MVP için en doğru kombinasyon

- **Döviz:** Frankfurter (USD/TRY, EUR/TRY); anahtar yok, basit.  
- **Altın:** Kapalıçarşı API (Vercel/ GitHub projesi) – gram TL, alış/satış, Türkiye odaklı. Fallback: MetalPriceAPI (XAU, TRY veya USD+Frankfurter).  
- **Gümüş / Platin / Paladyum:** MetalPriceAPI (XAG, XPT, XPD); TRY veya USD + Frankfurter ile TL.  
- **Kripto:** Binance public (`/ticker/price`, `/ticker/24hr`); isteğe bağlı `/klines` ile low/high.  
- **Türkiye'ye özel ek kaynak:** Sadece hazır API (Kapalıçarşı projesi, gerekirse CollectAPI); scraping yapma.

---

## Üretim için en doğru kombinasyon

- **Döviz:** Frankfurter + **TCMB EVDS** (resmî kur istenen senaryolar için); EVDS'e kayıt ve API anahtarı.  
- **Altın:** **TCMB EVDS** (altın serileri) resmî kanal; kullanıcıya "Kapalıçarşı benzeri" his vermek için 3. taraf Kapalıçarşı API (veya CollectAPI) ek kaynak; her zaman **MetalPriceAPI** (veya benzeri) yedek.  
- **Gümüş / Platin / Paladyum:** MetalPriceAPI (veya Metals-API) + Frankfurter; yedek plan ve kota takibi.  
- **Kripto:** Binance birincil; CoinGecko fallback (Binance'te olmayan coin'ler).  
- **Yasal/sürdürülebilir:** Scraping kullanma; lisanslı/ resmî veya 3. taraf "API olarak sunulan" servisleri kullan; kullanım şartlarını oku.

---

## Türkiye odaklı altın uygulaması için önerilen veri mimarisi

1. **Birincil (Türkiye hissi):**  
   Kapalıçarşı / piyasa odaklı bir API (örn. GitHub'daki Kapali-Carsi-Altin-API veya benzeri) → gram, çeyrek, yarım, tam altın TL, alış/satış.  
   - Endpoint'i proje dokümantasyonundan/netleştir; yoksa "tek sayfa" ise sadece mevcut tabloyu kullanacak şekilde tasarlama (ileride JSON endpoint eklenebilir).

2. **Resmî kanal:**  
   TCMB EVDS altın serileri → "Resmî veri" etiketi için; kullanıcıya "TCMB" / "Merkez Bankası" olarak gösterilebilir.

3. **Global yedek:**  
   MetalPriceAPI (veya Metals-API) → XAU, TRY veya USD; TRY yoksa Frankfurter USD/TRY ile TL. Birincil kaynak cevap vermezse veya Kapalıçarşı verisi olmayan ürünler için.

4. **Akış:**  
   İstekte önce Kapalıçarşı (veya seçili Türkiye) kaynağı; timeout/hata durumunda sırayla TCMB (varsa) ve MetalPriceAPI + Frankfurter. Tüm kaynaklarda "son güncelleme" ve mümkünse "kaynak" (Kapalıçarşı / TCMB / Global) bilgisini sakla ve göster.

5. **Scraping:**  
   Uygulama içinde doğrudan site scraping'i yapma; sadece hazır API'leri (Vercel, CollectAPI vb.) kullan. Scraping yapacak bir servis kullanırsan ayrı, yasal ve etik açıdan sorumluluğu kabul edilen bir altyapı ve hukuki değerlendirme gerekir.

Bu doküman, "ne durumdayız?" ve "API'leri bağlama" adımında hangi kaynakların seçileceğini netleştirmek için projede referans olarak kullanılabilir.
