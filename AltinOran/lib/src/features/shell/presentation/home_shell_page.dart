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
    StatsPage(),
    GoalsPage(),
    SettingsPage(),
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
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
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
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_pie), activeIcon: Icon(CupertinoIcons.chart_pie_fill), label: 'İstatistik'),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.flag), activeIcon: Icon(CupertinoIcons.flag_fill), label: 'Hedefler'),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), activeIcon: Icon(CupertinoIcons.settings_solid), label: 'Ayarlar'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
