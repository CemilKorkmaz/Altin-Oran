import 'package:flutter/material.dart';
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

/// Ekranda sürüklenebilir FAB: basılı tutup kaydırınca konumu değişir.
/// bodySize: Scaffold body alanının boyutu (alt çizgi = nav bar üstü).
class _DraggableFab extends StatefulWidget {
  const _DraggableFab({required this.onPressed, required this.bodySize});

  final VoidCallback onPressed;
  final Size bodySize;

  @override
  State<_DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<_DraggableFab> {
  Offset _offset = Offset.zero;
  bool _initialized = false;
  static const double _kFabWidth = 176;
  static const double _kFabHeight = 48;
  static const double _kPadding = 16;
  /// Alt sınır: body'nin en altı (nav bar üst çizgisi) — FAB tam çizgiye kadar inebilir.
  static const double _kMinMarginAboveNav = 0;

  void _initPosition(Size bodySize, EdgeInsets padding) {
    if (_initialized) return;
    _initialized = true;
    final bottomLimit = bodySize.height - _kFabHeight - _kPadding - _kMinMarginAboveNav;
    _offset = Offset(
      bodySize.width - _kFabWidth - _kPadding,
      bottomLimit,
    );
    _clampOffset(bodySize, padding);
  }

  void _clampOffset(Size bodySize, EdgeInsets padding) {
    final topLimit = padding.top + _kPadding;
    final bottomLimit = bodySize.height - _kFabHeight - _kPadding - _kMinMarginAboveNav;
    _offset = Offset(
      _offset.dx.clamp(_kPadding, bodySize.width - _kFabWidth - _kPadding),
      _offset.dy.clamp(topLimit, bottomLimit),
    );
  }

  void _onPanUpdate(Size bodySize, EdgeInsets padding, DragUpdateDetails details) {
    setState(() {
      _offset += details.delta;
      _clampOffset(bodySize, padding);
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    _initPosition(widget.bodySize, padding);
    _clampOffset(widget.bodySize, padding);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: Material(
        elevation: 8,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: widget.onPressed,
          onPanUpdate: (details) => _onPanUpdate(widget.bodySize, padding, details),
            child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.black87, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Yatırım Ekle / Sat',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: Theme.of(context).textTheme.titleSmall?.fontSize ?? 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bodySize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Stack(
                  children: [
                    _pages[_index],
                    if (showFab)
                      _DraggableFab(
                        onPressed: () {
                          final defaultPurity = ref.read(appSettingsProvider).defaultGramPurity;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddTransactionPage(
                                presetGoldPurity: defaultPurity,
                              ),
                            ),
                          );
                        },
                        bodySize: bodySize,
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: SafeArea(
              top: false,
              child: BottomNavigationBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
                  BottomNavigationBarItem(icon: Icon(Icons.trending_up_rounded), label: 'Kurlar'),
                  BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Birikimlerim'),
                  BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'İstatistik'),
                  BottomNavigationBarItem(icon: Icon(Icons.flag_rounded), label: 'Hedefler'),
                  BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ayarlar'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

