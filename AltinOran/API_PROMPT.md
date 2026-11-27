# API Seçimi İçin Prompt (Yapay Zekâya Sorulacak Metin)

Aşağıdaki metni kopyalayıp başka bir yapay zekâya (örn. ChatGPT, Claude) yapıştırarak **hangi API'lerin kullanılması gerektiğini, nelerin çekilmesi gerektiğini** sorabilirsin. Gerekli veriler ve teknik bağlam burada özetlenmiştir.

---

## Kopyala-yapıştır için metin (Türkçe)

```
Bir Flutter mobil uygulaması (Birikim & Portföy) geliştiriyorum. Kullanıcılar altın, gümüş, döviz, kripto vb. alım-satım kaydediyor; canlı fiyatlarla portföy değeri ve kâr/zarar görüntüleniyor, fiyat alarmları kuruluyor. Uygulama Türkiye pazarına yönelik; fiyatlar mümkünse TL (TRY) cinsinden olmalı.

Şu an kullandığım / ihtiyacım olan veriler:

1) Döviz kurları (TL bazlı)
   - USD/TRY ve EUR/TRY anlık kurlar.
   - Şu an: Frankfurter API (api.frankfurter.app) kullanıyorum, ücretsiz. Bunu sürdürmek mantıklı mı, yoksa daha iyi (güncel / Türkiye odaklı) bir ücretsiz veya düşük maliyetli API önerir misin?

2) Altın fiyatları (TL)
   - Gram altın (24 ayar) TL/gr.
   - İsteğe bağlı: günlük en düşük / en yüksek (Kurlar sayfasında göstermek için).
   - Şu an: MetalPriceAPI (api.metalpriceapi.com) altyapısı var ama API anahtarı placeholder; gerçek anahtar eklendiğinde XAU, TRY base ile çekiliyor. Bu API’yi mi kullanmalıyım, yoksa Türkiye’ye özel (Kapalıçarşı, banka) veya daha uygun fiyatlı/ücretsiz bir alternatif var mı?

3) Gümüş fiyatları (TL veya USD’den TRY’ye çevrilebilir)
   - Gram gümüş TL/gr (veya USD/gr + USD/TRY ile çarpılabilir).
   - İsteğe bağlı: günlük en düşük / en yüksek.

4) Platin ve paladyum fiyatları
   - Gram platin, gram paladyum; TL veya USD biriminde (TRY’ye çevrilebilir).
   - İsteğe bağlı: günlük low/high.

5) Kripto paralar
   - BTC, ETH ve diğer popüler coin’ler için anlık fiyat (USD veya USDT).
   - Uygulama içinde USD/TRY ile TL’ye çevrilebilir.
   - Binance API (api.binance.com) ticker/price kullanmayı düşünüyorum; ücretsiz ve sık kullanılıyor. Binance’i önerir misin, yoksa CoinGecko / başka bir ücretsiz API daha mı uygun?

Kısıtlar ve tercihler:
- Mümkünse ücretsiz veya düşük koteli ücretsiz API’ler.
- Flutter/Dart ile HTTP GET ile tüketebileceğim REST API’ler.
- Türkiye’de erişilebilir (engelli veya kısıtlı servisler olmasın).
- Rate limit: Uygulama kullanıcı başına dakikada birkaç istek (refresh, alarm kontrolü); aşırı yüksek limit gerekmez.
- Altın/gümüş için “Kapalıçarşı” veya “banka” kuru kullanılabilir; borsa (ör. COMEX) fiyatı da kabul edilebilir, hangi kaynağın daha kolay entegre edildiğine göre seçeceğim.

Çıktı olarak istediğim:
- Her veri türü (döviz, altın, gümüş, platin, paladyum, kripto) için önerdiğin API’nin adı, base URL’i, kullanılacak endpoint(ler), gerekli parametreler (API key nerede, hangi parametreler).
- Ücretsiz koteleri ve rate limit’leri kısa özet.
- Varsa Türkiye’ye özel (TL veya TRY bazlı) resmi/yarı resmi API’ler (TCMB, özel piyasa verisi vb.).
- Günlük en düşük/en yüksek (OHLC benzeri) veriyi hangi API’lerin sunduğu.
```

---

## İngilizce versiyon (API dokümantasyonu İngilizce olan modellere göre)

```
I'm building a Flutter mobile app (Birikim & Portföy) for portfolio tracking: users log gold, silver, forex, crypto buys/sells and see live values and PnL in TRY. The app targets the Turkish market; prices should be in TRY when possible.

I need API recommendations for:

1) Forex: USD/TRY and EUR/TRY spot rates. Currently using Frankfurter (free). Should I keep it or use a better free/low-cost API for TRY?

2) Gold: Gram gold (24k) in TRY. Optional: daily low/high. Currently have MetalPriceAPI integration (placeholder key). Prefer Turkey-oriented or cheap/free alternatives if any.

3) Silver: Gram silver in TRY (or USD + USD/TRY). Optional: daily low/high.

4) Platinum & palladium: Per gram in TRY or USD. Optional: daily low/high.

5) Crypto: Spot prices in USD/USDT for BTC, ETH, etc. (we convert to TRY with USD/TRY). Considering Binance public API; alternatives like CoinGecko?

Constraints: Prefer free or low-quota APIs; REST, consumable via HTTP GET from Flutter/Dart; reachable from Turkey; moderate rate limits (a few requests per minute per user). For metals, Turkey “Kapalıçarşı” or bank rates are acceptable; exchange (e.g. COMEX) is fine if easier to integrate.

Please recommend for each category: API name, base URL, endpoints, required params (e.g. API key), free tier/rate limits, and which ones provide daily low/high (OHLC-like) data. If you know any official or Turkey-specific APIs (e.g. central bank) for TRY or local rates, include those.
```

---

## Uygulama tarafında beklenen veri özeti

| Veri | Birim | Kaynak (şu an) | İhtiyaç |
|------|--------|-----------------|---------|
| USD/TRY | 1 USD = X TRY | Frankfurter | Anlık kur |
| EUR/TRY | 1 EUR = X TRY | Frankfurter | Anlık kur |
| Gram altın (24 ayar) | TL/gr | MetalPriceAPI (placeholder) | Anlık; isteğe bağlı: günlük low/high |
| Gram gümüş | TL/gr | Mock | Gerçek API gerekli |
| Gram platin | TL/gr | Mock | Gerçek API gerekli |
| Gram paladyum | TL/gr | Mock | Gerçek API gerekli |
| BTC, ETH, … | USD veya USDT | Mock (Binance altyapı düşünülüyor) | Ticker/price endpoint |

Bu tabloyu da istersen promptun sonuna ekleyebilirsin: “Aşağıdaki tabloya göre her satır için uygun API ve endpoint öner.”
