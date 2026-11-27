import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/application/notification_service.dart';
import '../../alerts/application/price_alarm_providers.dart';
import '../../alerts/presentation/alarm_notification_banner.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../rates/presentation/rates_page.dart';
import '../../portfolio/presentation/portfolio_page.dart';
import '../../stats/presentation/stats_page.dart';
import '../../goals/presentation/goals_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../settings/application/settings_providers.dart';
import '../../transactions/presentation/add_transaction_page.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  int _index = 0;
  bool _launchChecked = false;

  final _pages = const [
    DashboardPage(),
    RatesPage(),
    PortfolioPage(),
    GoalsPage(),
    _MorePage(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.setOnNotificationTap((data) {
      if (mounted) {
        ref.read(pendingAlarmProvider.notifier).state = data;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLaunchFromNotification());
  }

  Future<void> _checkLaunchFromNotification() async {
    if (_launchChecked || !mounted) return;
    _launchChecked = true;
    final details = await NotificationService.getLaunchDetails();
    if (!mounted) return;
    if (details?.didNotificationLaunchApp == true) {
      final data = await NotificationService.loadPendingFromPrefs();
      if (data != null && mounted) {
        ref.read(pendingAlarmProvider.notifier).state = data;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingAlarmProvider, (prev, next) {
      if (next == null || !context.mounted) return;
      AlarmNotificationBanner.showFromPending(
        context,
        alarmId: next.alarmId,
        assetName: next.assetName,
        targetPrice: next.targetPrice,
        direction: next.direction,
        goalTitle: next.goalTitle,
        onRemoveAlarm: () {
          ref.read(priceAlarmsProvider.notifier).removeAlarm(next.alarmId);
          ref.read(pendingAlarmProvider.notifier).state = null;
        },
      );
      ref.read(pendingAlarmProvider.notifier).state = null;
    });

    final showFab = _index == 0 || _index == 2;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: showFab ? 70 : 0,
                  child: _pages[_index],
                ),
                if (showFab)
                  Positioned(
                    right: 20,
                    bottom: 12,
                    child: FilledButton.icon(
                      onPressed: () {
                        final defaultPurity = ref.read(appSettingsProvider).defaultGramPurity;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AddTransactionPage(presetGoldPurity: defaultPurity),
                        ));
                      },
                      icon: const Icon(CupertinoIcons.add, size: 19),
                      label: const Text('İşlem ekle'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .94),
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: ClipRect(child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: SafeArea(
              top: false,
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                iconSize: 22,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                items: const [
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), activeIcon: Icon(CupertinoIcons.house_fill), label: 'Ana sayfa'),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), activeIcon: Icon(CupertinoIcons.chart_bar_fill), label: 'Kurlar'),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.creditcard), activeIcon: Icon(CupertinoIcons.creditcard_fill), label: 'Birikim'),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.flag), activeIcon: Icon(CupertinoIcons.flag_fill), label: 'Hedefler'),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.ellipsis_circle), activeIcon: Icon(CupertinoIcons.ellipsis_circle_fill), label: 'Diğer'),
                ],
              ),
            ))),
          ),
        ],
      ),
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(bottom: false, child: Scaffold(
      appBar: AppBar(title: const Text('Daha fazlası')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), children: [
        Text('BİRİKİMİNİZ', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          _MoreRow(icon: CupertinoIcons.chart_pie, title: 'İstatistikler', subtitle: 'Birikiminize daha yakından bakın', page: const StatsPage()),
          Divider(height: 1, indent: 72, color: theme.dividerColor),
          _MoreRow(icon: CupertinoIcons.settings, title: 'Ayarlar', subtitle: 'Görünüm, para birimi ve yedekleme', page: const SettingsPage()),
        ])),
        const SizedBox(height: 24),
        Text('ALTIN ORAN', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(CupertinoIcons.sparkles, color: theme.colorScheme.primary, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Birikiminize alan açın', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Tüm varlıklarınız, tek bir yerde.', style: theme.textTheme.bodySmall),
          ])),
        ]))),
      ]),
    ));
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.icon, required this.title, required this.subtitle, required this.page});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 20, color: theme.colorScheme.primary)),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Icon(CupertinoIcons.chevron_forward, size: 17, color: theme.colorScheme.outline),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
    );
  }
}
