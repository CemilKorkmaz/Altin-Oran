/**
 * Bigpara Kapalı Çarşı sayfasından altın fiyatlarını parse eder.
 * Sayfa: https://bigpara.hurriyet.com.tr/altin/kapali-carsi-altin-fiyatlari/
 *
 * HTML yapısı değişebilir; birkaç olası yapı denenir.
 */

const parseNumber = (str) => {
  if (str == null || str === '') return null;
  const s = String(str).replace(/\s/g, '').replace(/\./g, '').replace(',', '.');
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : null;
};

const parsePercent = (str) => {
  if (str == null || str === '') return null;
  const s = String(str).replace(/\s/g, '').replace(',', '.').replace('%', '');
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : null;
};

/**
 * Cheerio ile yüklenmiş HTML'den altın tablosunu çıkarır.
 * Tablo başlıkları: Altın Fiyatları, Alış, Satış, %, Saat
 * @param {import('cheerio').CheerioAPI} $
 * @returns {{ name: string, alis: number|null, satis: number|null, changePercent: number|null, time: string|null }[]}
 */
function parseBigparaGoldTable($) {
  const rows = [];
  const seen = new Set();

  // Yöntem 1: table tbody tr - her satırda th (isim) + td'ler (alış, satış, %, saat)
  $('table tbody tr').each((_, tr) => {
    const cells = $(tr).find('th, td');
    if (cells.length < 3) return;
    const texts = cells.map((_, el) => $(el).text().trim()).get();
    const name = texts[0];
    if (!name || name.length < 2) return;
    if (seen.has(name)) return;
    seen.add(name);
    // Sütun sırası sayfaya göre: bazen Alış, Satış, %, Saat veya ters
    let alis = null, satis = null, changePercent = null, time = null;
    for (let i = 1; i < texts.length; i++) {
      const t = texts[i];
      if (/^\d{1,2}:\d{2}$/.test(t)) time = t;
      else if (t.includes('%')) changePercent = parsePercent(t);
      else if (parseNumber(t) != null) {
        if (alis == null) alis = parseNumber(t);
        else if (satis == null) satis = parseNumber(t);
      }
    }
    if (alis != null || satis != null || name.toLowerCase().includes('altın') || name.toLowerCase().includes('bilezik') || name.toLowerCase().includes('çeyrek')) {
      rows.push({ name, alis, satis, changePercent, time });
    }
  });

  if (rows.length > 0) return rows;

  // Yöntem 2: Kart/block yapısı - h3 + ardından gelen 4 değer (Saat, %, Satış, Alış - sayfa sırasına göre)
  $('h3').each((_, h3) => {
    const name = $(h3).text().trim();
    if (!name || name.length < 2) return;
    if (seen.has(name)) return;
    const container = $(h3).parent();
    const values = container.find('li, .value, td, span').map((_, el) => $(el).text().trim()).get().filter(Boolean);
    let alis = null, satis = null, changePercent = null, time = null;
    for (const t of values) {
      if (/^\d{1,2}:\d{2}$/.test(t)) time = t;
      else if (t.includes('%')) changePercent = parsePercent(t);
      else {
        const n = parseNumber(t);
        if (n != null && n > 0 && n < 1e7) {
          if (alis == null) alis = n;
          else if (satis == null) satis = n;
        }
      }
    }
    if (alis != null || satis != null) {
      seen.add(name);
      rows.push({ name, alis, satis, changePercent, time });
    }
  });

  if (rows.length > 0) return rows;

  // Yöntem 3: Liste yapısı — "Kapalı Çarşı Altın Fiyatları" bölümünde h3 + aynı blokta 4 li (Saat, %, Satış, Alış)
  $('section, .gold-table, [class*="altin"], [class*="fiyat"]').each((_, block) => {
    const $block = $(block);
    $block.find('h3').each((__, h3) => {
      const name = $(h3).text().trim();
      if (!name || name.includes('GÜMÜŞ') || name.includes('SERBEST PİYASA')) return;
      const $row = $(h3).closest('li, tr, div[class]').length ? $(h3).closest('li, tr, div[class]').first() : $(h3).parent();
      const lis = $row.find('li').map((__, li) => $(li).text().trim()).get();
      if (lis.length >= 4) {
        const time = lis.find(v => /^\d{1,2}:\d{2}$/.test(v)) || null;
        const pctStr = lis.find(v => v.includes('%'));
        const changePercent = pctStr ? parsePercent(pctStr) : null;
        const numbers = lis.map(v => parseNumber(v)).filter(n => n != null && n > 0 && n < 1e7);
        const alis = numbers[1] ?? numbers[0] ?? null;
        const satis = numbers[0] ?? numbers[1] ?? null;
        if ((alis != null || satis != null) && !seen.has(name)) {
          seen.add(name);
          rows.push({ name, alis, satis, changePercent, time });
        }
      }
    });
  });

  if (rows.length > 0) return rows;

  // Yöntem 4: Body metninden regex — "ALTIN (TL/GR)" veya "Gram" + 7.301,06 7.301,96
  const bodyText = $('body').text();
  const gramMatch = bodyText.match(/ALTIN\s*\(TL\/GR\)[\s\S]*?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/);
  if (gramMatch) {
    const alis = parseNumber(gramMatch[1]);
    const satis = parseNumber(gramMatch[2]);
    if (alis != null && satis != null) {
      return [{ name: 'ALTIN (TL/GR)', alis, satis, changePercent: null, time: null }];
    }
  }

  return rows;
}

/**
 * Uygulama için normalize edilmiş anahtar: gram_altin, ceyrek, yarim, cumhuriyet, tam, bilezik_22, ons vb.
 */
function normalizeKey(name) {
  const n = (name || '').toLowerCase();
  if (n.includes('tl/gr') && !n.includes('22') && !n.includes('18') && !n.includes('14')) return 'gram_altin';
  if (n.includes('çeyrek') || n.includes('ceyrek')) return 'ceyrek';
  if (n.includes('yarım') || n.includes('yarim')) return 'yarim';
  if (n.includes('cumhuriyet')) return 'cumhuriyet';
  if (n.includes('tam altın') || n.includes('tam altin')) return 'tam';
  if (n.includes('22') && n.includes('bilezik')) return 'bilezik_22';
  if (n.includes('22 ayar') && n.includes('tl/gr')) return 'gram_22';
  if (n.includes('18 ayar')) return 'gram_18';
  if (n.includes('14 ayar')) return 'gram_14';
  if (n.includes('ons') && !n.includes('euro') && !n.includes('kg')) return 'ons';
  if (n.includes('has altın') || n.includes('has altin')) return 'has_altin';
  if (n.includes('gümüş') || n.includes('gumus')) {
    if (n.includes('tl/gr') || n.includes('tl\/gr')) return 'silver_gram';
    if (n.includes('$/ons') || n.includes('dolar') || n.includes('$')) return 'silver_ons';
    return 'silver_gram';
  }
  if (n.includes('platin')) {
    if (n.includes('tl/gr') || n.includes('tl\/gr')) return 'platinum_gram';
    if (n.includes('ons')) return 'platinum_ons';
    return 'platinum_gram';
  }
  return null;
}

/**
 * Ham HTML metninden bilinen tüm ürünleri regex ile çıkarır (altın türleri, gümüş, platin).
 * Sayfa yapısı bozuk olsa bile metinde geçen isim + sayı çiftlerini toplar.
 */
function parseAllFromRawHtml(html) {
  if (!html || typeof html !== 'string') return [];
  const body = html.replace(/\s+/g, ' ');
  const rows = [];
  const seen = new Set();

  const patterns = [
    { name: 'ALTIN (TL/GR)', re: /ALTIN\s*\(TL\/GR\)[\s\S]{0,800}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 1000, max: 50000 },
    { name: 'Çeyrek Altın', re: /Çeyrek\s*Altın[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 1000, max: 50000 },
    { name: 'Yarım Altın', re: /Yarım\s*Altın[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 5000, max: 100000 },
    { name: 'Cumhuriyet Altını', re: /Cumhuriyet\s*Altını[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 10000, max: 100000 },
    { name: 'Tam Altın', re: /Tam\s*Altın[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 10000, max: 100000 },
    { name: '22 Ayar Bilezik', re: /22\s*Ayar\s*Bilezik[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 1000, max: 50000 },
    { name: 'Altın (ONS)', re: /Altın\s*\(ONS\)[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 1000, max: 10000 },
    { name: 'Gümüş (TL/GR)', re: /Gümüş\s*\(TL\/GR\)[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 10, max: 500 },
    { name: 'Gümüş ($/ONS)', re: /Gümüş\s*\(\$\/ONS\)[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 10, max: 500 },
    { name: '18 Ayar Altın TL/Gr', re: /18\s*Ayar\s*Altın\s*TL\/Gr[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 1000, max: 50000 },
    { name: '22 Ayar Altın TL/Gr', re: /22\s*Ayar\s*Altın\s*TL\/Gr[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 1000, max: 50000 },
    { name: '14 Ayar Altın TL/Gr', re: /14\s*Ayar\s*Altın\s*TL\/Gr[\s\S]{0,600}?(\d[\d.\s,]+\d)\s*(\d[\d.\s,]+\d)/i, min: 1000, max: 50000 },
  ];

  for (const { name, re, min, max } of patterns) {
    if (seen.has(name)) continue;
    const m = body.match(re);
    if (m && m[1] && m[2]) {
      const a = parseNumber(m[1]);
      const b = parseNumber(m[2]);
      if (a != null && b != null && a >= min && a <= max && b >= min && b <= max) {
        const alis = Math.min(a, b);
        const satis = Math.max(a, b);
        seen.add(name);
        rows.push({ name, alis, satis, changePercent: null, time: null });
      }
    }
  }
  return rows;
}

module.exports = {
  parseBigparaGoldTable,
  parseAllFromRawHtml,
  normalizeKey,
  parseNumber,
  parsePercent,
};
