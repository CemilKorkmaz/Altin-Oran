import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/gold_price_providers.dart';
import '../domain/supported_asset.dart';

/// Canlı karta eklenecek varlığı katalogdan seçme veya "Başka coin ekle".
class SelectAssetForLivePage extends ConsumerWidget {
  const SelectAssetForLivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allSupportedAssetsProvider);
    final selectedIds = ref.watch(liveSelectedAssetIdsProvider);
    final alreadyAdded = selectedIds.toSet();

    final byCategory = <AssetCategory, List<SupportedAsset>>{};
    for (final a in all) {
      byCategory.putIfAbsent(a.category, () => []).add(a);
    }

    final categories = [
      AssetCategory.gold,
      AssetCategory.silver,
      AssetCategory.platinum,
      AssetCategory.metal,
      AssetCategory.crypto,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canlı fiyata varlık ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...categories.where((c) => byCategory.containsKey(c)).map((cat) {
            final list = byCategory[cat]!
                .where((a) => !alreadyAdded.contains(a.id))
                .toList();
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    categoryLabel(cat),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...list.map((asset) => _AssetTile(
                      asset: asset,
                      onTap: () {
                        ref.read(liveSelectedAssetIdsProvider.notifier).state =
                            [...selectedIds, asset.id];
                        ref.read(selectedLiveAssetIdProvider.notifier).state =
                            asset.id;
                        Navigator.of(context).pop();
                      },
                    )),
                const SizedBox(height: 16),
              ],
            );
          }),
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.2),
              child: const Icon(Icons.add_rounded, color: Colors.green),
            ),
            title: const Text('Başka coin ekle'),
            subtitle: const Text('Binance sembolü ile (örn. BTCUSDT)'),
            onTap: () => _showAddCustomCoinDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showAddCustomCoinDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final symbolController = TextEditingController(text: 'USDT');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coin ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ad (örn. Bitcoin)',
                hintText: 'Bitcoin',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              decoration: const InputDecoration(
                labelText: 'Binance sembolü',
                hintText: 'BTCUSDT',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              var symbol = symbolController.text.trim().toUpperCase();
              if (name.isEmpty) return;
              if (symbol.isEmpty) symbol = 'BTCUSDT';
              if (!symbol.endsWith('USDT')) symbol = '${symbol.replaceAll('USDT', '')}USDT';
              final id = 'custom_${symbol.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
              final asset = SupportedAsset(
                id: id,
                name: name,
                category: AssetCategory.crypto,
                symbol: symbol,
                unitLabel: symbol.replaceAll('USDT', ''),
              );
              final custom = List<SupportedAsset>.from(ref.read(customCoinsProvider));
              custom.add(asset);
              ref.read(customCoinsProvider.notifier).state = custom;
              ref.read(liveSelectedAssetIdsProvider.notifier).state = [
                ...ref.read(liveSelectedAssetIdsProvider),
                id,
              ];
              ref.read(selectedLiveAssetIdProvider.notifier).state = id;
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.onTap});

  final SupportedAsset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(asset.name),
        subtitle: asset.symbol != null ? Text(asset.symbol!) : null,
        trailing: const Icon(Icons.add_circle_outline),
        onTap: onTap,
      ),
    );
  }
}
