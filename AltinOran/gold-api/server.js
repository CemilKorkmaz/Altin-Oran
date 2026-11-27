/**
 * Altın fiyat API sunucusu
 * Bigpara sayfasını her 2 dakikada bir çeker (Puppeteer ile render), parse eder, /api/prices/gold ile JSON sunar.
 */

const express = require('express');
const cors = require('cors');
const cheerio = require('cheerio');
const { parseBigparaGoldTable, parseAllFromRawHtml, normalizeKey } = require('./parser.js');

const BIGPARA_URL = 'https://bigpara.hurriyet.com.tr/altin/kapali-carsi-altin-fiyatlari/';
const INTERVAL_MIN_SEC = 90;   // 1 dk 30 sn
const INTERVAL_MAX_SEC = 150;  // 2 dk 30 sn

const app = express();
const PORT = process.env.PORT || 3030;

// Cache: son parse edilen veri + zaman
let cache = {
  items: [],
  normalized: {},
  fetchedAt: null,
  error: null,
  source: null, // 'fetch' | 'puppeteer'
};

/** Önce düz fetch dene (hızlı). Başarısızsa Puppeteer ile render edilmiş HTML al. */
async function fetchPage() {
  const htmlFetch = await fetchPageWithFetch();
  if (htmlFetch && htmlFetch.length > 5000 && /ALTIN|7\.\d{3},\d{2}|gram/i.test(htmlFetch)) {
    return { html: htmlFetch, source: 'fetch' };
  }
  const htmlBrowser = await fetchPageWithPuppeteer();
  return { html: htmlBrowser, source: htmlBrowser ? 'puppeteer' : null };
}

async function fetchPageWithFetch() {
  try {
    const res = await fetch(BIGPARA_URL, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
      },
    });
    if (!res.ok) return null;
    return await res.text();
  } catch (_) {
    return null;
  }
}

async function fetchPageWithPuppeteer() {
  let browser;
  try {
    const puppeteer = require('puppeteer');
    if (!puppeteer) return null;
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    });
    const page = await browser.newPage();
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    await page.goto(BIGPARA_URL, { waitUntil: 'networkidle2', timeout: 25000 });
    await new Promise(r => setTimeout(r, 2000));
    const html = await page.content();
    await browser.close();
    return html;
  } catch (err) {
    console.error('Puppeteer error:', err.message);
    if (browser) try { await browser.close(); } catch (_) {}
    return null;
  }
}

function buildNormalized(items) {
  const out = {};
  for (const row of items) {
    const key = normalizeKey(row.name);
    if (key) out[key] = { alis: row.alis, satis: row.satis, changePercent: row.changePercent, time: row.time, name: row.name };
    // Gram altın ana gösterim için: "ALTIN (TL/GR)" veya "Gram Altın" eşleşmesi
    if ((row.name || '').includes('TL/GR') && !row.name.includes('22') && !row.name.includes('18') && !row.name.includes('14')) {
      out.gram_altin = out.gram_altin || { alis: row.alis, satis: row.satis, changePercent: row.changePercent, time: row.time, name: row.name };
    }
  }
  return out;
}

// Ham HTML'den tüm ürünleri (altın türleri, gümüş, platin) regex ile çıkar.
function mergeItems(existing, fromRaw) {
  const byName = new Map(existing.map(r => [r.name, r]));
  for (const row of fromRaw) {
    if (!byName.has(row.name)) byName.set(row.name, row);
  }
  return Array.from(byName.values());
}

async function refresh() {
  try {
    cache.error = null;
    const { html, source } = await fetchPage();
    if (!html) {
      cache.error = 'Sayfa alınamadı (fetch ve puppeteer başarısız)';
      return;
    }
    cache.source = source;
    const $ = cheerio.load(html);
    let items = parseBigparaGoldTable($);

    if (items.length === 0) {
      $('h3').each((_, h3) => {
        const name = $(h3).text().trim();
        if (!name || name.includes('SERBEST') || name.includes('GÜMÜŞ')) return;
        const parent = $(h3).closest('li, div[class], section').length ? $(h3).closest('li, div[class], section').first() : $(h3).parent();
        const vals = parent.find('li').map((__, li) => $(li).text().trim()).get();
        if (vals.length >= 4) {
          const time = vals.find(v => /^\d{1,2}:\d{2}$/.test(v)) || null;
          const pct = vals.find(v => v.includes('%'));
          const changePercent = pct ? parseFloat(pct.replace(',', '.').replace('%', '').trim()) : null;
          const nums = vals.map(v => parseFloat(v.replace(/\s/g, '').replace(/\./g, '').replace(',', '.'))).filter(n => Number.isFinite(n) && n > 0);
          const alis = nums[1] ?? null;
          const satis = nums[0] ?? null;
          if (alis != null || satis != null) {
            items.push({ name, alis, satis, changePercent, time });
          }
        }
      });
    }

    const rawRows = parseAllFromRawHtml(html);
    items = mergeItems(items, rawRows);

    cache.items = items;
    cache.normalized = buildNormalized(items);
    cache.fetchedAt = new Date().toISOString();
  } catch (err) {
    cache.error = err.message;
    console.error('Bigpara fetch error:', err.message);
  }
}

// Yenileme: 1 dk 30 sn → 1 dk 31 sn → … → 2 dk 30 sn → tekrar 1 dk 30 sn
let nextIntervalSec = INTERVAL_MIN_SEC;

function scheduleNext() {
  const ms = nextIntervalSec * 1000;
  setTimeout(async () => {
    await refresh();
    nextIntervalSec = nextIntervalSec >= INTERVAL_MAX_SEC ? INTERVAL_MIN_SEC : nextIntervalSec + 1;
    scheduleNext();
  }, ms);
}

refresh().then(() => scheduleNext());

app.use(cors());
app.get('/api/prices/gold', (req, res) => {
  res.set('Cache-Control', 'public, max-age=60');
  res.json({
    ok: !cache.error && cache.items.length > 0,
    fetchedAt: cache.fetchedAt,
    error: cache.error || undefined,
    source: cache.source || undefined,
    items: cache.items,
    byKey: cache.normalized,
  });
});

app.get('/health', (req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

app.get('/debug', (req, res) => {
  res.json({
    hasItems: cache.items.length > 0,
    hasGramAltin: !!cache.normalized.gram_altin,
    error: cache.error || null,
    source: cache.source || null,
    fetchedAt: cache.fetchedAt,
    itemCount: cache.items.length,
  });
});

app.listen(PORT, () => {
  console.log(`Gold API http://localhost:${PORT} — GET /api/prices/gold`);
});
