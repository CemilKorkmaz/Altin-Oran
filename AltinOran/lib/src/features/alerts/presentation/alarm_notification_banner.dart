import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../../rates/presentation/rates_page.dart';
import '../domain/price_alarm.dart';

/// Üstten kayan alarm bildirimi — 10 sn sonra otomatik kapanır, "Alarmı kaldır" ile kaldırılabilir.
class AlarmNotificationBanner {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required PriceAlarm alarm,
    required RateItem rate,
    String? goalTitle,
    VoidCallback? onRemoveAlarm,
  }) {
    final price = rate.lastPrice;
    if (price == null) return;
    _showImpl(
      context: context,
      assetName: rate.name,
      targetPrice: alarm.targetPrice,
      currentPrice: price,
      direction: alarm.direction,
      goalTitle: goalTitle,
      alarmId: alarm.id,
      onRemoveAlarm: onRemoveAlarm,
    );
  }

  /// Uygulama bildirimden açıldığında gösterilir (canlı fiyat yok).
  static void showFromPending(
    BuildContext context, {
    required String alarmId,
    required String assetName,
    required double targetPrice,
    required AlarmDirection direction,
    String? goalTitle,
    required VoidCallback onRemoveAlarm,
  }) {
    _showImpl(
      context: context,
      assetName: assetName,
      targetPrice: targetPrice,
      currentPrice: null,
      direction: direction,
      goalTitle: goalTitle,
      alarmId: alarmId,
      onRemoveAlarm: onRemoveAlarm,
    );
  }

  static void _showImpl({
    required BuildContext context,
    required String assetName,
    required double targetPrice,
    double? currentPrice,
    required AlarmDirection direction,
    String? goalTitle,
    required String alarmId,
    VoidCallback? onRemoveAlarm,
  }) {
    _timer?.cancel();
    _currentEntry?.remove();

    final overlay = Overlay.of(context);
    final isAbove = direction == AlarmDirection.above;
    final dirText = isAbove ? 'hedefinin üzerine çıktı' : 'hedefinin altına düştü';
    final emoji = isAbove ? '📈' : '📉';

    final entry = OverlayEntry(
      builder: (ctx) {
        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: -1, end: 0),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, value * 100),
                      child: Opacity(
                        opacity: value + 1,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: MediaQuery.of(ctx).size.width * 0.96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isAbove
                            ? [
                                const Color(0xFF059669),
                                const Color(0xFF047857),
                                const Color(0xFF065F46),
                              ]
                            : [
                                const Color(0xFFDC2626),
                                const Color(0xFFB91C1C),
                                const Color(0xFF991B1B),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: (isAbove ? const Color(0xFF059669) : const Color(0xFFDC2626))
                              .withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$assetName alarmı 🔔',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => dismiss(),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 22,
                                                color: Colors.white.withOpacity(0.95),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (currentPrice != null)
                                        Text(
                                          'Anlık fiyat: ₺${formatMoney(currentPrice)}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.98),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        goalTitle != null && goalTitle.isNotEmpty
                                            ? 'Hedefin "$goalTitle" için ₺${formatMoney(targetPrice)} $dirText.'
                                            : 'Hedef: ₺${formatMoney(targetPrice)} $dirText.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.92),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onRemoveAlarm != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        onRemoveAlarm();
                                        dismiss();
                                      },
                                      icon: const Icon(Icons.notifications_off_rounded, size: 18),
                                      label: const Text('Alarmı kaldır'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: Colors.white.withOpacity(0.8)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    _currentEntry = entry;

    _timer = Timer(const Duration(seconds: 10), () {
      dismiss();
    });
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}
