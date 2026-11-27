import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../prices/application/gold_price_providers.dart';
import '../../prices/domain/gold_price.dart';
import '../../prices/domain/supported_asset.dart';
import '../application/transactions_providers.dart';
import '../domain/investment_transaction.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({
    super.key,
    this.existing,
    this.presetAssetType,
    this.presetDirection,
    this.presetChannel,
    this.presetGoldPurity,
    this.presetCustomAssetId,
    this.titleOverride,
  });

  /// Düzenleme modu için mevcut işlem.
  final InvestmentTransaction? existing;

  /// Yeni işlem eklerken varsayılan varlık türü.
  final AssetType? presetAssetType;

  /// Yeni işlem eklerken varsayılan yön (alış / satış).
  final TransactionDirection? presetDirection;

  /// Yeni işlem eklerken varsayılan kanal.
  final PurchaseChannel? presetChannel;

  /// Belirli bir varlık için satış açarken varsayılan ayar (örn. 24/22).
  final GoldPurity? presetGoldPurity;

  /// Özel varlık (coin/hisse) için id.
  final String? presetCustomAssetId;

  /// Başlık metnini isteğe göre değiştirmek için.
  final String? titleOverride;

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

enum _UiAssetCategory { gold, currency, coin, other }

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  AssetType? _selectedAssetType;
  String? _selectedCustomAssetId;
  GoldPurity _selectedGoldPurity = GoldPurity.carat24;
  _UiAssetCategory _category = _UiAssetCategory.gold;
  PurchaseChannel? _selectedPurchaseChannel;
  late TransactionDirection _direction;
  final _amountController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  bool _useManualPrice = false;
  PriceSource? _selectedPriceSource;
  bool _isFetchingPrice = false;
  DateTime? _selectedDateTime;
  late bool _isEditing;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _isEditing = true;
      _category = _categoryForAsset(existing.assetType);
      _selectedAssetType = existing.assetType;
      _selectedCustomAssetId = existing.customAssetId;
      _selectedGoldPurity = existing.goldPurity ?? GoldPurity.carat24;
      _selectedPurchaseChannel = existing.purchaseChannel;
      _direction = existing.direction;
      _amountController.text = existing.amount.toString();
      _priceController.text = existing.unitPrice.toStringAsFixed(2);
      _noteController.text = existing.note ?? '';
      _useManualPrice = existing.isManualPrice;
      _selectedPriceSource = existing.priceSource;
      _selectedDateTime = existing.dateTime;
    } else {
      _isEditing = false;
      _selectedAssetType = widget.presetAssetType ?? AssetType.gramAltin;
      _selectedCustomAssetId = widget.presetCustomAssetId;
      _selectedGoldPurity = widget.presetGoldPurity ?? GoldPurity.carat24;
      _category = _categoryForAsset(_selectedAssetType!);
      _selectedPurchaseChannel = widget.presetChannel;
      _direction = widget.presetDirection ?? TransactionDirection.buy;
      _selectedDateTime = DateTime.now();
      // Yeni işlem eklerken varsayılan olarak fiyatı manuel girme açık olsun.
      _useManualPrice = true;
      _selectedPriceSource = null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(_UiAssetCategory cat) {
    setState(() {
      _category = cat;
      _selectedAssetType = _defaultAssetForCategory(cat);
      _selectedCustomAssetId = null;
    });
  }

  void _onAssetOptionSelected(AssetType type, String? customAssetId) {
    setState(() {
      _selectedAssetType = type;
      _selectedCustomAssetId = customAssetId;
    });
  }

  void _onGoldPurityChanged(GoldPurity purity) {
    setState(() {
      _selectedGoldPurity = purity;
    });
  }

  void _onUseManualPriceChanged(bool value) {
    setState(() {
      _useManualPrice = value;
      // Otomatik fiyat moduna geçerken, manuel senaryoya özel kanallar seçiliyse temizle.
      if (!_useManualPrice &&
          (_selectedPurchaseChannel == PurchaseChannel.kuyumcuMagaza ||
              _selectedPurchaseChannel == PurchaseChannel.kuyumcuOnline ||
              _selectedPurchaseChannel == PurchaseChannel.aileArkadas ||
              _selectedPurchaseChannel == PurchaseChannel.isverenPrimIkramiye)) {
        _selectedPurchaseChannel = null;
      }
    });
  }

  void _onPriceSourceChanged(PriceSource? value) {
    setState(() {
      _selectedPriceSource = value;
    });
  }

  void _save() {
    setState(() => _saveError = null);

    final missing = <String>[];
    if (_selectedAssetType == null) missing.add('Varlık türü');
    if (_selectedAssetType == AssetType.otherCrypto &&
        _selectedCustomAssetId == null) {
      missing.add('Coin seçimi');
    }
    if (_selectedPurchaseChannel == null) missing.add('Alış/Satış kanalı');
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      missing.add('Miktar');
    } else if (double.tryParse(amountStr.replaceAll(',', '.')) == null) {
      missing.add('Miktar (geçerli bir sayı girin)');
    }
    final priceStr = _priceController.text.trim();
    if (priceStr.isEmpty) {
      missing.add('Birim fiyat');
    } else if (double.tryParse(priceStr.replaceAll(',', '.')) == null) {
      missing.add('Birim fiyat (geçerli bir sayı girin)');
    }
    final isGold = _isGoldAssetType(_selectedAssetType);
    if (isGold && !_useManualPrice && _selectedPriceSource == null) {
      missing.add('Fiyat kaynağı (veya manuel fiyat seçin)');
    }

    if (missing.isNotEmpty) {
      setState(() {
        _saveError = 'Lütfen şu alanları doldurunuz: ${missing.join(", ")}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_saveError!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountStr.replaceAll(',', '.'))!;
    final price = double.tryParse(priceStr.replaceAll(',', '.'))!;
    if (amount <= 0 || price <= 0) {
      setState(() {
        _saveError = 'Miktar ve birim fiyat 0\'dan büyük olmalıdır.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_saveError!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_direction == TransactionDirection.sell) {
      final holdings = _calculateHoldings(ref.read(transactionsProvider));
      final key = _HoldingKey(
        _selectedAssetType!,
        _isGoldAssetType(_selectedAssetType)
            ? _selectedGoldPurity
            : null,
        _selectedAssetType == AssetType.otherCrypto ? _selectedCustomAssetId : null,
      );
      final available = holdings[key] ?? 0;
      if (available <= 0 || amount > available) {
        setState(() {
          _saveError =
              'Elinde bu varlıktan en fazla ${available.toStringAsFixed(4)} birim var. '
              'Bu miktardan fazla satış yapamazsın.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveError!),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final dateTime = _selectedDateTime ?? DateTime.now();

    // Manuel fiyat kullanılıyorsa kaynak boş, değilse seçili olmalı.
    final isGoldAsset = _isGoldAssetType(_selectedAssetType);
    final isManualPrice =
        !isGoldAsset || _useManualPrice || _selectedPriceSource == null;
    final priceSource =
        isGoldAsset && !isManualPrice ? _selectedPriceSource : null;

    final tx = InvestmentTransaction(
      id: _isEditing
          ? widget.existing!.id
          : DateTime.now().microsecondsSinceEpoch.toString(),
      assetType: _selectedAssetType!,
      amount: amount,
      unitPrice: price,
      dateTime: dateTime,
      purchaseChannel: _selectedPurchaseChannel!,
      direction: _direction,
      priceSource: priceSource,
      isManualPrice: isManualPrice,
      goldPurity: isGoldAsset
          ? (_selectedAssetType == AssetType.onsAltin
              ? GoldPurity.carat24
              : _selectedGoldPurity)
          : null,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      customAssetId: _selectedAssetType == AssetType.otherCrypto ? _selectedCustomAssetId : null,
    );

    final notifier = ref.read(transactionsProvider.notifier);
    if (_isEditing) {
      notifier.update(tx);
    } else {
      notifier.add(tx);
    }

    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDateTime ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        final base = _selectedDateTime ?? now;
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          base.hour,
          base.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _selectedDateTime ?? now;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked != null) {
      setState(() {
        final base = _selectedDateTime ?? now;
        _selectedDateTime = DateTime(
          base.year,
          base.month,
          base.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _fetchAutoPrice() async {
    if (_selectedPriceSource == null) return;
    setState(() => _isFetchingPrice = true);

    try {
      // Seçilen kaynağa göre hangi bölgeden veri alınacağını ayarla.
      final region = regionForSource(_selectedPriceSource!);
      ref.read(selectedRegionProvider.notifier).state = region;

      await ref.read(goldPriceProvider.notifier).refresh();
      final state = ref.read(goldPriceProvider);
      final price = state.price?.pricePerGram;
      if (price != null) {
        _priceController.text = price.toStringAsFixed(2);
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingPrice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final timeFormatter = DateFormat('HH:mm');
    final hasDateTime = _selectedDateTime != null;
    final dateLabel =
        hasDateTime ? dateFormatter.format(_selectedDateTime!) : 'Tarih seç';
    final timeLabel =
        hasDateTime ? timeFormatter.format(_selectedDateTime!) : 'Saat seç';

    final title = widget.titleOverride ??
        (_isEditing ? 'İşlemi Düzenle' : 'Yatırım Ekle / Sat');

    final transactions = ref.watch(transactionsProvider);
    final holdings = _calculateHoldings(transactions);
    final hasAnyHoldings = holdings.values.any((value) => value > 0);
    final canSell = !(_direction == TransactionDirection.sell && !hasAnyHoldings);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              if (_saveError != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'İşlem türü',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: _direction == TransactionDirection.buy
                            ? const Color(0xFF22C55E)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _direction = TransactionDirection.buy;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 24,
                                  color: _direction == TransactionDirection.buy
                                      ? Colors.white
                                      : const Color(0xFF22C55E),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Alış',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _direction == TransactionDirection.buy
                                        ? Colors.white
                                        : const Color(0xFF22C55E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: _direction == TransactionDirection.sell
                            ? const Color(0xFFEF4444)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _direction = TransactionDirection.sell;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 24,
                                  color: _direction == TransactionDirection.sell
                                      ? Colors.white
                                      : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Satış',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _direction == TransactionDirection.sell
                                        ? Colors.white
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (canSell) ...[
                const Text('Varlık türü'),
                const SizedBox(height: 8),
                _buildCategoryBar(context),
                const SizedBox(height: 8),
                _buildAssetSubTypeBar(context, ref, holdings),
                if (_category == _UiAssetCategory.coin &&
                    _selectedAssetType == AssetType.otherCrypto) ...[
                  const SizedBox(height: 12),
                  _buildOtherCoinPicker(context, ref),
                ],
                // Ons Altında gerçekte sadece 24 ayar vardır; ayar seçeneği gösterme
                if (_isGoldAssetType(_selectedAssetType) &&
                    _selectedAssetType != AssetType.onsAltin) ...[
                  const SizedBox(height: 12),
                  const Text('Altın ayarı'),
                  const SizedBox(height: 8),
                  _buildGoldPurityBar(context, holdings),
                ],
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'Satış yapabileceğin bir varlık bulunmuyor. '
                  'Önce birikim eklemelisin.',
                ),
                const SizedBox(height: 8),
              ],
              if (canSell) ...[
                const SizedBox(height: 16),
                Text(
                  _direction == TransactionDirection.buy
                      ? 'Alış kanalı'
                      : 'Satış kanalı',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PurchaseChannel>(
                  value: _selectedPurchaseChannel,
                  decoration: const InputDecoration(
                    hintText: 'Nereden?',
                  ),
                  items: [
                    // Fiyatı manuel giriyorsa tüm kanallar mantıklı.
                    if (_useManualPrice) ...const [
                      DropdownMenuItem(
                        value: PurchaseChannel.kuyumcuMagaza,
                        child: Text('Kuyumcu (mağaza)'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.kuyumcuOnline,
                        child: Text('Kuyumcu (online / web)'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.aileArkadas,
                        child: Text('Aile / arkadaş arası'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.bankaMobil,
                        child: Text('Banka mobil / internet şubesi'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.bankaSube,
                        child: Text('Banka şubesi'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.dovizBurosu,
                        child: Text('Döviz bürosu'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.borsaViop,
                        child: Text('Borsa / VİOP'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.onlineAltinPlatformu,
                        child: Text('Online altın platformu'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.kriptoBorsasi,
                        child: Text('Kripto borsası (tokenize altın vb.)'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.isverenPrimIkramiye,
                        child: Text('İşveren (prim / ikramiye olarak)'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.diger,
                        child: Text('Diğer'),
                      ),
                    ] else ...const [
                      // Fiyat kaynağı seçiliyse fiyatı piyasadan alıyoruz:
                      // Kuyumcu / aile / işveren gibi senaryoları gizle.
                      DropdownMenuItem(
                        value: PurchaseChannel.bankaMobil,
                        child: Text('Banka mobil / internet şubesi'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.bankaSube,
                        child: Text('Banka şubesi'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.dovizBurosu,
                        child: Text('Döviz bürosu'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.borsaViop,
                        child: Text('Borsa / VİOP'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.onlineAltinPlatformu,
                        child: Text('Online altın platformu'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.kriptoBorsasi,
                        child: Text('Kripto borsası (tokenize altın vb.)'),
                      ),
                      DropdownMenuItem(
                        value: PurchaseChannel.diger,
                        child: Text('Diğer'),
                      ),
                    ],
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPurchaseChannel = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Miktar'),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Örn. 10',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tarih ve saat'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(dateLabel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text(timeLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPriceSection(context),
                const SizedBox(height: 16),
                const Text('Not (opsiyonel)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Bu işlemle ilgili kısa bir not ekleyebilirsin',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetOption {
  const _AssetOption(this.type, this.label, this.customAssetId);
  final AssetType type;
  final String label;
  final String? customAssetId;
}

bool _isGoldAssetType(AssetType? type) {
  if (type == null) return false;
  switch (type) {
    case AssetType.gramAltin:
    case AssetType.ceyrek:
    case AssetType.yarim:
    case AssetType.tam:
    case AssetType.cumhuriyet:
    case AssetType.bilezik22:
    case AssetType.onsAltin:
      return true;
    default:
      return false;
  }
}

_UiAssetCategory _categoryForAsset(AssetType type) {
  if (_isGoldAssetType(type) || type == AssetType.gumus || type == AssetType.platin || type == AssetType.paladyum) {
    return _UiAssetCategory.gold;
  }
  switch (type) {
    case AssetType.usd:
    case AssetType.eur:
      return _UiAssetCategory.currency;
    case AssetType.btc:
    case AssetType.eth:
    case AssetType.otherCrypto:
      return _UiAssetCategory.coin;
    default:
      return _UiAssetCategory.other;
  }
}

class _HoldingKey {
  const _HoldingKey(this.assetType, this.goldPurity, [this.customAssetId]);

  final AssetType assetType;
  final GoldPurity? goldPurity;
  final String? customAssetId;

  @override
  bool operator ==(Object other) {
    return other is _HoldingKey &&
        other.assetType == assetType &&
        other.goldPurity == goldPurity &&
        other.customAssetId == customAssetId;
  }

  @override
  int get hashCode => Object.hash(assetType, goldPurity, customAssetId);
}

Map<_HoldingKey, double> _calculateHoldings(
    List<InvestmentTransaction> transactions) {
  final Map<_HoldingKey, double> amountsPerKey = {};

  for (final tx in transactions) {
    final key = _HoldingKey(tx.assetType, tx.goldPurity, tx.customAssetId);
    final sign = tx.direction == TransactionDirection.buy ? 1.0 : -1.0;
    final current = amountsPerKey[key] ?? 0;
    final next = current + sign * tx.amount;
    amountsPerKey[key] = next > 0 ? next : 0;
  }

  return amountsPerKey;
}

extension _AddTransactionPageStateUi on _AddTransactionPageState {
  Widget _buildCategoryBar(BuildContext context) {
    Widget chip(_UiAssetCategory cat, String label, IconData icon) {
      final selected = _category == cat;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor:
                  selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              foregroundColor: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
            onPressed: () => _onCategoryChanged(cat),
            icon: Icon(icon, size: 18),
            label: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_UiAssetCategory.gold, 'Madenler', Icons.circle_rounded),
        chip(_UiAssetCategory.currency, 'Döviz', Icons.attach_money_rounded),
        chip(_UiAssetCategory.coin, 'Coin', Icons.currency_bitcoin_rounded),
        chip(_UiAssetCategory.other, 'Diğer', Icons.more_horiz_rounded),
      ],
    );
  }

  AssetType _defaultAssetForCategory(_UiAssetCategory cat) {
    switch (cat) {
      case _UiAssetCategory.gold:
        return AssetType.gramAltin;
      case _UiAssetCategory.currency:
        return AssetType.usd;
      case _UiAssetCategory.coin:
        return AssetType.btc;
      case _UiAssetCategory.other:
        return AssetType.stock;
    }
  }

  Widget _buildAssetSubTypeBar(
      BuildContext context, WidgetRef ref, Map<_HoldingKey, double> holdings) {
    final options = <_AssetOption>[];
    switch (_category) {
      case _UiAssetCategory.gold:
        options.addAll([
          _AssetOption(AssetType.gramAltin, 'Gram Altın', null),
          _AssetOption(AssetType.ceyrek, 'Çeyrek', null),
          _AssetOption(AssetType.yarim, 'Yarım', null),
          _AssetOption(AssetType.tam, 'Tam', null),
          _AssetOption(AssetType.cumhuriyet, 'Cumhuriyet', null),
          _AssetOption(AssetType.bilezik22, 'Bilezik', null),
          _AssetOption(AssetType.onsAltin, 'Ons Altın', null),
          _AssetOption(AssetType.gumus, 'Gümüş', null),
          _AssetOption(AssetType.platin, 'Platin', null),
          _AssetOption(AssetType.paladyum, 'Paladyum', null),
        ]);
        break;
      case _UiAssetCategory.currency:
        options.addAll([
          _AssetOption(AssetType.usd, 'Dolar (USD)', null),
          _AssetOption(AssetType.eur, 'Euro (EUR)', null),
        ]);
        break;
      case _UiAssetCategory.coin:
        if (_direction == TransactionDirection.sell) {
          _addCoinOptionsForSell(options, holdings, ref);
        } else {
          options.addAll([
            _AssetOption(AssetType.btc, 'Bitcoin (BTC)', null),
            _AssetOption(AssetType.eth, 'Ethereum (ETH)', null),
            _AssetOption(AssetType.otherCrypto, 'Diğer Coin', null),
          ]);
        }
        break;
      case _UiAssetCategory.other:
        options.addAll([
          _AssetOption(AssetType.stock, 'Hisse / Fon', null),
        ]);
        break;
    }

    if (_direction == TransactionDirection.sell) {
      options.removeWhere((opt) =>
          !_hasHoldingsForAssetOption(holdings, opt.type, opt.customAssetId));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final selected = _selectedAssetType == opt.type &&
              (opt.customAssetId == null ||
                  _selectedCustomAssetId == opt.customAssetId);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt.label),
              selected: selected,
              onSelected: (_) => _onAssetOptionSelected(opt.type, opt.customAssetId),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _addCoinOptionsForSell(
      List<_AssetOption> options,
      Map<_HoldingKey, double> holdings,
      WidgetRef ref) {
    ref.watch(customCoinsProvider); // Sadece custom değişince yeniden build; liste ref ile döngü olmasın
    final allAssets = ref.read(allSupportedAssetsProvider);
    for (final entry in holdings.entries) {
      if (entry.value <= 0) continue;
      final k = entry.key;
      if (k.assetType == AssetType.btc) {
        options.add(_AssetOption(AssetType.btc, 'Bitcoin (BTC)', null));
      } else if (k.assetType == AssetType.eth) {
        options.add(_AssetOption(AssetType.eth, 'Ethereum (ETH)', null));
      } else if (k.assetType == AssetType.otherCrypto && k.customAssetId != null) {
        final name = allAssets
            .where((a) => a.id == k.customAssetId)
            .map((a) => a.name)
            .firstOrNull;
        options.add(_AssetOption(
          AssetType.otherCrypto,
          name ?? k.customAssetId!,
          k.customAssetId,
        ));
      }
    }
    options.sort((a, b) => a.label.compareTo(b.label));
  }

  Widget _buildOtherCoinPicker(BuildContext context, WidgetRef ref) {
    ref.watch(customCoinsProvider); // Sadece custom değişince yeniden build; liste ref ile döngü olmasın
    final allAssets = ref.read(allSupportedAssetsProvider);
    final cryptoList = allAssets
        .where((a) =>
            a.isCrypto &&
            a.id != 'crypto_btc' &&
            a.id != 'crypto_eth')
        .toList();
    SupportedAsset? selectedAsset;
    if (_selectedCustomAssetId != null) {
      try {
        selectedAsset = cryptoList.firstWhere(
            (a) => a.id == _selectedCustomAssetId);
      } catch (_) {}
    }

    return DropdownButtonFormField<SupportedAsset>(
      value: selectedAsset,
      decoration: const InputDecoration(
        labelText: 'Hangi coin?',
        hintText: 'Seçin',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<SupportedAsset>(
          value: null,
          child: Text('— Coin seçin —'),
        ),
        ...cryptoList.map((a) => DropdownMenuItem<SupportedAsset>(
              value: a,
              child: Text('${a.name} (${a.symbol ?? a.id})'),
            )),
      ],
      onChanged: (SupportedAsset? a) {
        _onAssetOptionSelected(
            AssetType.otherCrypto, a?.id);
      },
    );
  }

  bool _hasHoldingsForAssetOption(
      Map<_HoldingKey, double> holdings, AssetType type, String? customId) {
    for (final e in holdings.entries) {
      if (e.key.assetType == type &&
          e.key.customAssetId == customId &&
          e.value > 0) return true;
    }
    return false;
  }

  bool _hasHoldingsForPurity(Map<_HoldingKey, double> holdings,
      AssetType? asset, GoldPurity purity) {
    if (asset == null) return false;
    for (final entry in holdings.entries) {
      if (entry.key.assetType == asset &&
          entry.key.goldPurity == purity &&
          entry.value > 0) {
        return true;
      }
    }
    return false;
  }

  Widget _buildGoldPurityBar(
      BuildContext context, Map<_HoldingKey, double> holdings) {
    String label(GoldPurity p) {
      switch (p) {
        case GoldPurity.carat24:
          return '24 Ayar';
        case GoldPurity.carat22:
          return '22 Ayar';
        case GoldPurity.carat18:
          return '18 Ayar';
        case GoldPurity.carat14:
          return '14 Ayar';
      }
    }

    final purities = GoldPurity.values.where((p) {
      if (_direction != TransactionDirection.sell) return true;
      return _hasHoldingsForPurity(holdings, _selectedAssetType, p);
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: purities.map((p) {
          final selected = _selectedGoldPurity == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label(p)),
              selected: selected,
              onSelected: (_) => _onGoldPurityChanged(p),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriceSection(BuildContext context) {
    final isGold = _isGoldAssetType(_selectedAssetType);

    if (!isGold) {
      // Diğer tüm varlıklar için sadece manuel fiyat.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Birim fiyat'),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              hintText: 'Örn. 30.00',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fiyatı manuel girmek istiyorum'),
          subtitle: const Text(
            'İşaretlersen birim fiyatı kendin yazarsın. '
            'İşaretlemezsen seçtiğin kaynaktan otomatik fiyat getirilmeye çalışılır.',
          ),
          value: _useManualPrice,
          onChanged: _onUseManualPriceChanged,
        ),
        const SizedBox(height: 8),
        if (_useManualPrice) ...[
          const Text('Birim fiyat'),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              hintText: 'Örn. 2500',
            ),
          ),
        ] else ...[
          DropdownButtonFormField<PriceSource>(
            value: _selectedPriceSource,
            decoration: const InputDecoration(
              labelText: 'Fiyat kaynağı',
              hintText: 'Seçiniz',
            ),
            items: const [
              DropdownMenuItem(
                value: PriceSource.kapalicarsi,
                child: Text('Kapalıçarşı (spot)'),
              ),
              DropdownMenuItem(
                value: PriceSource.bankalar,
                child: Text('Bankalar (altın hesabı)'),
              ),
              DropdownMenuItem(
                value: PriceSource.kitco,
                child: Text('Kitco'),
              ),
              DropdownMenuItem(
                value: PriceSource.comex,
                child: Text('COMEX'),
              ),
              DropdownMenuItem(
                value: PriceSource.bloomberg,
                child: Text('Bloomberg'),
              ),
            ],
            onChanged: _onPriceSourceChanged,
          ),
          const SizedBox(height: 16),
          const Text('Birim fiyat'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceController,
                  readOnly: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Örn. 2500',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isFetchingPrice || _selectedPriceSource == null
                    ? null
                    : _fetchAutoPrice,
                icon: _isFetchingPrice
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_rounded),
                label: const Text('Fiyatı getir'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}


