import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/price_alarm.dart';
import 'pending_alarm_data.dart';
import '../../rates/presentation/rates_page.dart';

const String _keyAlarmId = 'pending_alarm_id';
const String _keyAssetName = 'pending_asset_name';
const String _keyTargetPrice = 'pending_target_price';
const String _keyDirection = 'pending_direction';
const String _keyGoalTitle = 'pending_goal_title';

const String _channelId = 'price_alarms';
const String _channelName = 'Fiyat alarmları';

/// Yerel bildirim altyapısı: tetiklenen alarmları sistem bildirimi olarak gösterir,
/// uygulama bildirimden açıldığında bekleyen alarm verisi sağlar.
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(PendingAlarmData)? _onNotificationTap;

  static void setOnNotificationTap(void Function(PendingAlarmData)? callback) {
    _instance._onNotificationTap = callback;
  }

  /// Plugin'i başlatır. main() içinde WidgetsFlutterBinding.ensureInitialized() sonrası çağrılmalı.
  static Future<void> init() async {
    if (_instance._initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);
    // ignore: discarded_futures
    await _instance._plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _instance._onSelect,
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _instance._plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Fiyat hedefine ulaşıldığında bildirim',
              importance: Importance.high,
              playSound: true,
            ),
          );
    }
    _instance._initialized = true;
  }

  void _onSelect(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _loadAndNotify(payload);
  }

  static Future<void> _loadAndNotify(String alarmId) async {
    final data = await loadPendingFromPrefs();
    if (data != null && data.alarmId == alarmId && _instance._onNotificationTap != null) {
      _instance._onNotificationTap!(data);
    }
  }

  /// Uygulama bildirimle mi açıldı bilgisini döndürür (cold start).
  static Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    return _instance._plugin.getNotificationAppLaunchDetails();
  }

  /// Tetiklenen alarm için yerel bildirim gösterir ve gösterilecek veriyi prefs'e yazar.
  static Future<void> showAlarmNotification({
    required PriceAlarm alarm,
    required RateItem rate,
    String? goalTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAlarmId, alarm.id);
    await prefs.setString(_keyAssetName, rate.name);
    await prefs.setDouble(_keyTargetPrice, alarm.targetPrice);
    await prefs.setString(_keyDirection, alarm.direction.name);
    if (goalTitle != null) {
      await prefs.setString(_keyGoalTitle, goalTitle);
    } else {
      await prefs.remove(_keyGoalTitle);
    }

    final dirText = alarm.direction == AlarmDirection.above ? 'üstüne çıktı' : 'altına düştü';
    final body = '₺${alarm.targetPrice} hedefinin $dirText.';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Fiyat hedefine ulaşıldığında bildirim',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final id = alarm.id.hashCode.abs() % 0x7FFFFFFF;
    await _instance._plugin.show(id, '${rate.name} alarmı 🔔', body, details, payload: alarm.id);
  }

  /// Prefs'teki bekleyen alarm verisini okuyup temizler (bildirimden açıldığında kullanılır).
  static Future<PendingAlarmData?> loadPendingFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmId = prefs.getString(_keyAlarmId);
    final assetName = prefs.getString(_keyAssetName);
    final targetPrice = prefs.getDouble(_keyTargetPrice);
    final directionStr = prefs.getString(_keyDirection);
    final goalTitle = prefs.getString(_keyGoalTitle);

    if (alarmId == null || assetName == null || targetPrice == null || directionStr == null) {
      return null;
    }
    final direction = AlarmDirection.values.byName(directionStr);

    await prefs.remove(_keyAlarmId);
    await prefs.remove(_keyAssetName);
    await prefs.remove(_keyTargetPrice);
    await prefs.remove(_keyDirection);
    await prefs.remove(_keyGoalTitle);

    return PendingAlarmData(
      alarmId: alarmId,
      assetName: assetName,
      targetPrice: targetPrice,
      direction: direction,
      goalTitle: goalTitle,
    );
  }
}
