# Altın Fiyat API (Bigpara)

[Bigpara Kapalı Çarşı Altın Fiyatları](https://bigpara.hurriyet.com.tr/altin/kapali-carsi-altin-fiyatlari/) sayfasını her **2 dakikada bir** çeker, HTML'den fiyatları parse edip kendi REST API'n üzerinden JSON olarak sunar.

## Mimari

- **Fetcher**: Önce düz `fetch`; sayfa JS ile render ediliyorsa **Puppeteer** (headless Chrome) ile sayfa açılıp render edilmiş HTML alınır.
- **Parser**: Cheerio + ham HTML regex ile gram altın (ve diğer türler) çıkarılır.
- **Cache**: Son sonuç bellek içinde tutulur; 1.30 dk–2.30 dk aralıklarla yenilenir.
- **REST**: `GET /api/prices/gold` — uygulama sadece bu API'ya istek atar.

Bigpara sayfası JavaScript ile yüklendiği için Puppeteer gerekebilir; ilk kurulumda `npm install` ile yüklenir.

## Kurulum

```bash
cd gold-api
npm install
npm start
```

Varsayılan port: **3030**. Değiştirmek için: `PORT=4000 npm start`

## Endpoint'ler

### `GET /api/prices/gold`

Son çekilen altın fiyatlarını döner.

**Örnek yanıt:**

```json
{
  "ok": true,
  "fetchedAt": "2026-02-25T12:00:00.000Z",
  "items": [
    {
      "name": "ALTIN (TL/GR)",
      "alis": 7301.06,
      "satis": 7301.96,
      "changePercent": 1.68,
      "time": "23:59"
    },
    {
      "name": "Çeyrek Altın",
      "alis": 12156,
      "satis": 12273,
      "changePercent": 1.25,
      "time": "14:49"
    }
  ],
  "byKey": {
    "gram_altin": { "alis": 7301.06, "satis": 7301.96, "changePercent": 1.68, "time": "23:59", "name": "ALTIN (TL/GR)" },
    "ceyrek": { "alis": 12156, "satis": 12273, "changePercent": 1.25, "time": "14:49", "name": "Çeyrek Altın" }
  }
}
```

- **items**: Tüm satırlar (isim, alış, satış, % değişim, saat)
- **byKey**: Uygulama için normalize anahtarlar: `gram_altin`, `ceyrek`, `yarim`, `cumhuriyet`, `tam`, `bilezik_22`, `ons` vb.

Hata durumunda `ok: false` ve `error` alanı dolu gelir; `items` boş olabilir.

### `GET /health`

Sunucunun ayakta olduğunu kontrol: `{ "ok": true, "time": "..." }`

### `GET /debug`

Son çekim durumu: `hasItems`, `hasGramAltin`, `error`, `source` (fetch/puppeteer), `fetchedAt`. Backend çalışıyor ama fiyat gelmiyorsa buradan kontrol edin.

## Flutter tarafında kullanım

Backend'i bir sunucuya deploy edip (Vercel, Railway, VPS vb.) base URL'i uygulamada kullanın. Örnek:

```dart
final baseUrl = 'https://your-gold-api.vercel.app';
final res = await http.get(Uri.parse('$baseUrl/api/prices/gold'));
final data = jsonDecode(res.body);
if (data['ok'] == true && data['byKey'] != null) {
  final gram = data['byKey']['gram_altin'];
  if (gram != null) {
    final alis = (gram['alis'] as num?)?.toDouble();
    final satis = (gram['satis'] as num?)?.toDouble();
    // ...
  }
}
```

## Deploy (Vercel)

Serverless kullanacaksanız 2 dakikalık cron için harici bir cron servisi (örn. cron-job.org) ile `GET https://your-app.vercel.app/api/prices/gold` adresini 2 dakikada bir çağırıp cache'ı güncelleyebilirsiniz; ya da bu projeyi 7/24 çalışan bir sunucuda (Railway, Fly.io, VPS) `node server.js` ile çalıştırın.

## Çalışmıyorsa

1. Backend çalışıyor mu: tarayıcıda `http://localhost:3030/health` aç → `{"ok":true,...}` gelmeli.
2. Fiyat geliyor mu: `http://localhost:3030/debug` → `hasGramAltin: true` ve `error: null` olmalı.
3. İlk çekim 20–30 sn sürebilir (Puppeteer ilk açılış). Sonraki yenilemeler cache'den hızlı döner.
4. Flutter (Android emulator): Backend aynı PC'deyse varsayılan `http://10.0.2.2:3030`. iOS sim: `http://localhost:3030`. Gerçek cihaz: PC'nin yerel IP'si (örn. `http://192.168.1.x:3030`).

## Not

- Veri kaynağı: Hürriyet Bigpara. Kullanım koşullarına uygun kullanın.
- Sayfa HTML'i değişirse `parser.js` içindeki seçicileri güncellemeniz gerekebilir.
