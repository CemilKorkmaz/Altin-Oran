/**
 * Bigpara sayfasının ham HTML'ini indirip dosyaya yazar.
 * Parser'ı ayarlarken sayfa yapısını incelemek için: node fetch-html.js
 */

const fs = require('fs');
const BIGPARA_URL = 'https://bigpara.hurriyet.com.tr/altin/kapali-carsi-altin-fiyatlari/';

async function main() {
  const res = await fetch(BIGPARA_URL, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept-Language': 'tr-TR,tr;q=0.9',
    },
  });
  const html = await res.text();
  fs.writeFileSync('bigpara-sample.html', html, 'utf8');
  console.log('bigpara-sample.html yazıldı, uzunluk:', html.length);
}

main().catch((e) => console.error(e));
