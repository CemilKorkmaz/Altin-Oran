import json, urllib.request, urllib.parse, re
from pathlib import Path
key = re.search(r"defaultValue:\s*'([^']+)'", Path('lib/src/features/prices/application/api_config.dart').read_text()).group(1)
tests = {
    'Frankfurter USD/TRY': ('https://api.frankfurter.app/latest?from=USD&to=TRY', lambda d: isinstance(d.get('rates', {}).get('TRY'), (int, float))),
    'Binance BTC/USDT': ('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT', lambda d: float(d.get('price', 0)) > 0),
    'Canlidoviz': ('https://api.canlidoviz.com/web/items?marketId=1&type=1', lambda d: isinstance(d, (dict, list))),
    'MetalPriceAPI': ('https://api.metalpriceapi.com/v1/latest?' + urllib.parse.urlencode({'api_key':key,'base':'USD','currencies':'XAU,XAG,XPT,XPD'}), lambda d: d.get('success') is True and isinstance(d.get('rates'), dict)),
}
for name,(url, valid) in tests.items():
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'AltinOran-API-check/1.0'}),timeout=12) as res:
            data=json.load(res)
            print(f'::notice::{name}: ' + ('OK' if valid(data) else 'geçersiz/başarısız yanıt'))
    except Exception as exc:
        print(f'::notice::{name}: erişilemedi ({type(exc).__name__}{" " + str(exc.code) if hasattr(exc,"code") else ""})')
