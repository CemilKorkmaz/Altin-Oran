/// API anahtarları ve base URL'ler.
/// Anahtarları kaynak kodda saklamayın. İstemciye derlenen anahtar gizli değildir.
String get metalPriceApiKey => const String.fromEnvironment(
  'METALPRICEAPI_KEY',
  defaultValue: '',
);

/// Kapalıçarşı altın API base (3. taraf proje; JSON endpoint varsa kullanılır).
const String kapalicarsiBaseUrl = 'https://kapali-carsi-altin-api.vercel.app';

/// Bigpara HTML parse backend (gold-api). Boş ise bu kaynak kullanılmaz.
/// Yerel backend: Android emulator 10.0.2.2:3030, iOS/sim localhost:3030
String get bigparaGoldApiBaseUrl {
  const url = String.fromEnvironment(
    'BIGPARA_GOLD_API_URL',
    defaultValue: '',
  );
  return url.trim();
}
