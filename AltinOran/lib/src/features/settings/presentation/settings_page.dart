import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/section_header.dart';
import '../application/settings_providers.dart';
import '../../transactions/application/transactions_providers.dart';
import '../../transactions/domain/investment_transaction.dart';
import '../../transactions/domain/transaction_serialization.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ayarlar'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(
              icon: Icons.tune_rounded,
              title: 'Genel',
              subtitle: 'Tema, para birimi, varsayılanlar',
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.color_lens_rounded),
                    title: const Text('Tema'),
                    subtitle: Text(
                      settings.themeMode == AppThemeMode.darkGold
                          ? 'Koyu (siyah & altın)'
                          : 'Açık (krem & altın)',
                    ),
                    trailing: DropdownButton<AppThemeMode>(
                      value: settings.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: AppThemeMode.light,
                          child: Text('Açık (krem & altın)'),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.darkGold,
                          child: Text('Koyu (siyah & sarı)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setThemeMode(v);
                      },
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('Görüntü para birimi'),
                    subtitle: const Text('TL / USD / EUR'),
                    trailing: DropdownButton<DisplayCurrency>(
                      value: settings.displayCurrency,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: DisplayCurrency.tl,
                          child: Text('TL'),
                        ),
                        DropdownMenuItem(
                          value: DisplayCurrency.usd,
                          child: Text('USD'),
                        ),
                        DropdownMenuItem(
                          value: DisplayCurrency.eur,
                          child: Text('EUR'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setDisplayCurrency(v);
                      },
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.scale_rounded),
                    title: const Text('Varsayılan gram altın ayarı'),
                    trailing: DropdownButton<GoldPurity>(
                      value: settings.defaultGramPurity,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: GoldPurity.carat24,
                          child: Text('24 Ayar'),
                        ),
                        DropdownMenuItem(
                          value: GoldPurity.carat22,
                          child: Text('22 Ayar'),
                        ),
                        DropdownMenuItem(
                          value: GoldPurity.carat18,
                          child: Text('18 Ayar'),
                        ),
                        DropdownMenuItem(
                          value: GoldPurity.carat14,
                          child: Text('14 Ayar'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setDefaultGramPurity(v);
                      },
                    ),
                  ),
                  const Divider(height: 0),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_rounded),
                    title: const Text('Fiyat alarmı bildirimi'),
                    subtitle:
                        const Text('Üstten kayan bildirim banner\'ını aç/kapat'),
                    value: settings.alarmBannerEnabled,
                    onChanged: (v) => notifier.setAlarmBannerEnabled(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(
              icon: Icons.security_rounded,
              title: 'Güvenlik',
              subtitle: 'Biyometrik kilit',
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_rounded),
                    title: const Text('Biyometrik kilit'),
                    subtitle: const Text(
                        'Uygulama açılırken parmak izi / Face ID ile kilitle'),
                    value: settings.biometricEnabled,
                    onChanged: (v) => notifier.setBiometricEnabled(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(
              icon: Icons.backup_rounded,
              title: 'Yedekleme',
              subtitle: 'Cloud, dışa/içe aktar',
            ),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.cloud_rounded),
                    title: Text('Cloud yedekleme'),
                    subtitle: Text('Daha sonra eklenecek'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.import_export_rounded),
                    title: const Text('Dışa aktar / içe aktar'),
                    subtitle: const Text('İşlemleri JSON veya CSV olarak paylaş / yükle'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showExportImportSheet(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showExportImportSheet(BuildContext context, WidgetRef ref) async {
  final transactions = ref.read(transactionsProvider);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Text('Dışa aktar (JSON)'),
            subtitle: Text('${transactions.length} işlem'),
            onTap: () async {
              Navigator.pop(ctx);
              await _exportJson(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_rounded),
            title: const Text('Dışa aktar (CSV)'),
            subtitle: Text('${transactions.length} işlem'),
            onTap: () async {
              Navigator.pop(ctx);
              await _exportCsv(context, ref);
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('İçe aktar'),
            subtitle: const Text('JSON veya CSV dosyası seç'),
            onTap: () async {
              Navigator.pop(ctx);
              await _importFile(context, ref);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
  final transactions = ref.read(transactionsProvider);
  if (transactions.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarılacak işlem yok.')),
      );
    }
    return;
  }
  try {
    final content = exportTransactionsToJson(transactions);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/birikim_portfoy_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(content);
    if (context.mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Birikim Portföy yedek');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarma hatası: $e')),
      );
    }
  }
}

Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
  final transactions = ref.read(transactionsProvider);
  if (transactions.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarılacak işlem yok.')),
      );
    }
    return;
  }
  try {
    final content = exportTransactionsToCsv(transactions);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/birikim_portfoy_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(content);
    if (context.mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Birikim Portföy yedek');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarma hatası: $e')),
      );
    }
  }
}

Future<void> _importFile(BuildContext context, WidgetRef ref) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;
    final file = result.files.single;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;
    final text = String.fromCharCodes(bytes);
    List<InvestmentTransaction> imported;
    if (file.extension?.toLowerCase() == 'csv' || (text.trim().isNotEmpty && !text.trim().startsWith('['))) {
      imported = importTransactionsFromCsv(text);
    } else {
      imported = importTransactionsFromJson(text);
    }
    if (imported.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosyada geçerli işlem bulunamadı.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İçe aktar'),
        content: Text(
          '${imported.length} işlem bulundu. Mevcut tüm işlemler silinip bunlarla değiştirilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, üzerine yaz'),
          ),
        ],
      ),
    );
    if (replace == true) {
      ref.read(transactionsProvider.notifier).replaceAll(imported);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${imported.length} işlem içe aktarıldı.')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İçe aktarma hatası: $e')),
      );
    }
  }
}

