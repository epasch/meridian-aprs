import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'beaconing_service.dart';
import 'meridian_connection_task.dart';
import 'station_service.dart';
import 'tnc_service.dart';
import 'tx_service.dart';

// ---------------------------------------------------------------------------
// ForegroundServiceApi — injectable abstraction for testing
// ---------------------------------------------------------------------------

/// Injectable abstraction over [FlutterForegroundTask] static methods.
///
/// The default production implementation delegates to [FlutterForegroundTask]
/// directly. Inject a [ForegroundServiceApi] test double via the
/// [BackgroundServiceManager] constructor to avoid platform channel
/// dependencies in unit tests.
abstract interface class ForegroundServiceApi {
  Future<ServiceRequestResult> startService({
    required int serviceId,
    required String notificationTitle,
    required String notificationText,
    required VoidCallback callback,
  });

  Future<ServiceRequestResult> updateService({
    String? notificationTitle,
    String? notificationText,
  });

  Future<ServiceRequestResult> stopService();
}

class _DefaultForegroundServiceApi implements ForegroundServiceApi {
  const _DefaultForegroundServiceApi();

  @override
  Future<ServiceRequestResult> startService({
    required int serviceId,
    required String notificationTitle,
    required String notificationText,
    required VoidCallback callback,
  }) => FlutterForegroundTask.startService(
    serviceId: serviceId,
    notificationTitle: notificationTitle,
    notificationText: notificationText,
    callback: callback,
  );

  @override
  Future<ServiceRequestResult> updateService({
    String? notificationTitle,
    String? notificationText,
  }) => FlutterForegroundTask.updateService(
    notificationTitle: notificationTitle,
    notificationText: notificationText,
  );

  @override
  Future<ServiceRequestResult> stopService() =>
      FlutterForegroundTask.stopService();
}

/// State of the Android foreground service keepalive.
enum BackgroundServiceState {
  /// Service is not running. Normal foreground-app operation.
  stopped,

  /// Permission check or service startup in progress.
  starting,

  /// Foreground service is active; transports are being kept alive.
  running,

  /// Service is running but at least one transport dropped and is reconnecting.
  reconnecting,

  /// Service failed to start (permission denied, startup error, etc.).
  error,
}

/// Manages the Android foreground service that keeps APRS transport connections
/// alive while the app is backgrounded.
///
/// This service is Android-only. On all other platforms every public method
/// is a no-op and [state] remains [BackgroundServiceState.stopped].
///
/// **Architecture:**
/// The [flutter_foreground_task] [TaskHandler] runs in a background isolate
/// and cannot access Provider-hosted services. This manager therefore acts as
/// the sole bridge: it listens to [TncService], [StationService], and
/// [BeaconingService] on the main isolate, starts/stops the foreground service
/// lifecycle, and calls [FlutterForegroundTask.updateService] directly to push
/// notification content updates — no round-trip through the background isolate.
///
/// **Auto-start/stop:**
/// When [backgroundActivityEnabled] is true (the default), the service starts
/// automatically when beaconing activates in auto or smart mode, and stops
/// when beaconing deactivates. A service started via the manual toggle in the
/// Connection screen is not auto-stopped.
///
/// **TNC beaconing via IPC:**
/// The background isolate cannot access the live BLE/serial TNC connection.
/// When the background timer fires and [TxService.beaconToTnc] is true, the
/// background isolate sends a [send_tnc_beacon] IPC message to this manager,
/// which forwards it to [TxService.sendViaTncOnly]. The foreground service
/// wake lock keeps the CPU active so IPC delivery is prompt.
class BackgroundServiceManager extends ChangeNotifier
    with WidgetsBindingObserver {
  BackgroundServiceManager({
    required TncService tnc,
    required StationService station,
    required BeaconingService beaconing,
    required TxService tx,
    ForegroundServiceApi? taskApi,
  }) : _tnc = tnc,
       _station = station,
       _beaconing = beaconing,
       _tx = tx,
       _taskApi = taskApi ?? const _DefaultForegroundServiceApi() {
    _tnc.addListener(_onServiceStateChanged);
    _station.addListener(_onServiceStateChanged);
    _beaconing.addListener(_onServiceStateChanged);
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      // Load persisted backgroundActivityEnabled setting.
      SharedPreferences.getInstance().then((prefs) {
        _backgroundActivityEnabled = prefs.getBool(_keyBgActivity) ?? true;
        notifyListeners();
      });
    }
  }

  final TncService _tnc;
  final StationService _station;
  final BeaconingService _beaconing;
  final TxService _tx;
  final ForegroundServiceApi _taskApi;

  static const _keyBgActivity = 'bg_activity_enabled';

  BackgroundServiceState _state = BackgroundServiceState.stopped;
  String? _errorMessage;
  Timer? _updateDebounce;

  /// True when the service was started automatically (beaconing activated)
  /// rather than via the manual toggle. Auto-started services are also
  /// auto-stopped when beaconing deactivates.
  bool _autoStarted = false;

  /// True when an auto-start was attempted but [Permission.locationAlways]
  /// was not yet granted. The Connection screen surfaces a prompt to complete
  /// the permission flow.
  bool _needsPermission = false;

  bool _backgroundActivityEnabled = true;

  BackgroundServiceState get state => _state;
  String? get errorMessage => _errorMessage;

  bool get isRunning =>
      _state == BackgroundServiceState.running ||
      _state == BackgroundServiceState.reconnecting;

  /// Whether the background service auto-starts with beaconing.
  bool get backgroundActivityEnabled => _backgroundActivityEnabled;

  /// True when an auto-start is pending a [Permission.locationAlways] grant.
  /// The Connection screen uses this to show a permission prompt.
  bool get needsPermission => _needsPermission;

  // ---------------------------------------------------------------------------
  // Static initialisation — call once before runApp()
  // ---------------------------------------------------------------------------

  /// Initialises [FlutterForegroundTask] options. Safe to call on all
  /// platforms (no-op on non-Android).
  ///
  /// Must be called before any [requestStartService] call.
  static void initOptions() {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'meridian_connection',
        channelName: 'Connection',
        channelDescription:
            'Keeps APRS connections and beaconing active in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // onRepeatEvent fires every 60 s as a heartbeat.
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Enables or disables automatic background service management.
  ///
  /// When disabled, stops a running auto-started service immediately.
  /// Manually-started services are unaffected.
  Future<void> setBackgroundActivityEnabled(bool v) async {
    if (_backgroundActivityEnabled == v) return;
    _backgroundActivityEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBgActivity, v);
    if (!v && _autoStarted && isRunning) {
      await stopService();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Requests that the Android foreground service be started.
  ///
  /// If auto or smart beaconing is configured, prompts for
  /// [Permission.locationAlways] (background location) before starting.
  ///
  /// Returns `true` if the service is running after this call. Returns `false`
  /// and sets [state] to [BackgroundServiceState.error] if a required
  /// permission is denied or the service fails to start.
  ///
  /// On non-Android platforms this is a no-op that returns `false`.
  Future<bool> requestStartService(BuildContext context) async {
    if (!Platform.isAndroid) return false;
    if (isRunning) return true;

    // Was this triggered by completing an auto-start permission prompt?
    final wasAutoStartPending = _needsPermission;
    _needsPermission = false;

    _setState(BackgroundServiceState.starting);

    // Background location is required for GPS beaconing while backgrounded.
    if (_beaconing.mode != BeaconMode.manual) {
      final granted = await _requestBackgroundLocationPermission(context);
      if (!granted) {
        _errorMessage =
            'Background location permission is required for beaconing '
            'while the app is in the background.';
        _setState(BackgroundServiceState.error);
        return false;
      }
    }

    // POST_NOTIFICATIONS is needed to show the notification on Android 13+.
    // Non-fatal: the keepalive still works even if the notification is hidden.
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    final result = await _taskApi.startService(
      serviceId: 1701,
      notificationTitle: _buildTitle(),
      notificationText: _buildBody(),
      callback: startMeridianConnectionTask,
    );

    if (result is ServiceRequestSuccess) {
      // Preserve auto-start semantics if we're completing a pending auto-start.
      _autoStarted = wasAutoStartPending;
      _setState(BackgroundServiceState.running);
      return true;
    }

    _errorMessage = 'Failed to start background service.';
    _setState(BackgroundServiceState.error);
    return false;
  }

  /// Stops the Android foreground service.
  ///
  /// On non-Android platforms this is a no-op.
  Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    await _taskApi.stopService();
    _autoStarted = false;
    _setState(BackgroundServiceState.stopped);
  }

  // ---------------------------------------------------------------------------
  // App lifecycle — background/foreground handoff
  // ---------------------------------------------------------------------------

  /// Coordinates beacon timing between the main isolate and background isolate
  /// as the app moves between foreground and background.
  ///
  /// On [AppLifecycleState.paused]: suspends the main isolate beacon timer and
  /// instructs the background isolate to take over at the correct interval.
  ///
  /// On [AppLifecycleState.resumed]: stops the background isolate beacon and
  /// restores the main isolate timer from the last background beacon timestamp
  /// stored in [SharedPreferences].
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || !Platform.isAndroid || !isRunning) return;
    switch (state) {
      case AppLifecycleState.paused:
        if (_beaconing.isActive && _beaconing.mode != BeaconMode.manual) {
          // Suspend main isolate timer before the isolate is throttled.
          // The background isolate will pick up the interval from where we
          // left off using the last_beacon_ts timestamp.
          _beaconing.suspendTimerForBackground();
          FlutterForegroundTask.sendDataToTask({
            'type': 'start_beaconing',
            'last_beacon_ts':
                _beaconing.lastBeaconAt?.millisecondsSinceEpoch ?? 0,
          });
        }
      case AppLifecycleState.resumed:
        // Stop background isolate beacon — main isolate takes over.
        FlutterForegroundTask.sendDataToTask({'type': 'stop_beaconing'});
        // Sync the main BeaconingService timer from the background isolate's
        // last beacon timestamp (persisted to SharedPreferences).
        _resumeBeaconingFromBackground();
        // Reconnect APRS-IS if the TCP socket dropped while backgrounded.
        // Android may kill sockets on screen lock; the transport detects the
        // drop via onDone/onError but has no auto-reconnect of its own.
        if (_station.currentConnectionStatus == ConnectionStatus.disconnected) {
          _station.connectAprsIs(); // ignore: unawaited_futures
        }
      default:
        break;
    }
  }

  /// Reads the last background-beacon timestamp from [SharedPreferences] and
  /// calls [BeaconingService.resumeFromBackground] so the main isolate timer
  /// fires at the correct time.
  void _resumeBeaconingFromBackground() {
    if (!_beaconing.isActive) return;
    SharedPreferences.getInstance().then((prefs) {
      final bgTsMs = prefs.getInt('bg_last_beacon_ts');
      final mainTs = _beaconing.lastBeaconAt;
      final DateTime ts;
      if (bgTsMs != null) {
        final bgTs = DateTime.fromMillisecondsSinceEpoch(bgTsMs);
        // bg_last_beacon_ts may be stale from a previous session if no
        // background beacon fired during this background period (e.g. the user
        // came back before the interval elapsed). Use whichever is more recent.
        ts = (mainTs != null && mainTs.isAfter(bgTs)) ? mainTs : bgTs;
      } else {
        ts = mainTs ?? DateTime.now();
      }
      _beaconing.resumeFromBackground(ts);
    });
  }

  // ---------------------------------------------------------------------------
  // IPC — messages from background isolate
  // ---------------------------------------------------------------------------

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final msg = Map<String, dynamic>.from(data);
    switch (msg['type'] as String?) {
      case 'send_tnc_beacon':
        // Background isolate timer fired; forward the packet to the live TNC
        // connection which is maintained on this isolate.
        final aprsLine = msg['aprs_line'] as String?;
        if (aprsLine != null) {
          _tx.sendViaTncOnly(aprsLine); // ignore: unawaited_futures
        }
      case 'beacon_sent':
        // Background APRS-IS beacon confirmed. SharedPreferences is the
        // authoritative sync path; this message is informational only.
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-start / auto-stop
  // ---------------------------------------------------------------------------

  /// Starts the service silently if [Permission.locationAlways] is already
  /// granted. If the permission is missing, sets [needsPermission] so the
  /// Connection screen can surface a prompt.
  Future<void> _maybeAutoStart() async {
    if (!Platform.isAndroid) return;
    if (isRunning || !_backgroundActivityEnabled) return;
    if (!_beaconing.isActive || _beaconing.mode == BeaconMode.manual) return;

    // For GPS modes, background location must already be granted — we don't
    // pop a dialog here since this fires from a ChangeNotifier callback with
    // no BuildContext. If permission is missing, flag it for the UI.
    if (_beaconing.mode != BeaconMode.manual) {
      final status = await Permission.locationAlways.status;
      if (!status.isGranted) {
        _needsPermission = true;
        notifyListeners();
        return;
      }
    }

    await Permission.notification.request();

    final result = await _taskApi.startService(
      serviceId: 1701,
      notificationTitle: _buildTitle(),
      notificationText: _buildBody(),
      callback: startMeridianConnectionTask,
    );

    if (result is ServiceRequestSuccess) {
      _autoStarted = true;
      _needsPermission = false;
      _setState(BackgroundServiceState.running);
    } else {
      _errorMessage = 'Failed to start background service.';
      _setState(BackgroundServiceState.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal state tracking
  // ---------------------------------------------------------------------------

  void _onServiceStateChanged() {
    if (isRunning) {
      final tncReconnecting = _tnc.currentStatus == ConnectionStatus.connecting;
      final aprsReconnecting =
          _station.currentConnectionStatus == ConnectionStatus.connecting;
      final next = (tncReconnecting || aprsReconnecting)
          ? BackgroundServiceState.reconnecting
          : BackgroundServiceState.running;
      if (next != _state) _setState(next);
    }

    if (!kIsWeb && Platform.isAndroid) {
      final beaconingActive =
          _beaconing.isActive && _beaconing.mode != BeaconMode.manual;
      if (beaconingActive && !isRunning && _backgroundActivityEnabled) {
        _maybeAutoStart(); // ignore: unawaited_futures
      } else if (!beaconingActive && _autoStarted && isRunning) {
        stopService(); // ignore: unawaited_futures
      }
    }

    // Debounce: many rapid ChangeNotifier pings (BLE scanning, packet arrival)
    // must not spam updateService().
    _updateDebounce?.cancel();
    _updateDebounce = Timer(
      const Duration(milliseconds: 500),
      _pushNotificationUpdate,
    );

    notifyListeners();
  }

  Future<void> _pushNotificationUpdate() async {
    if (!isRunning) return;
    await _taskApi.updateService(
      notificationTitle: _buildTitle(),
      notificationText: _buildBody(),
    );
  }

  void _setState(BackgroundServiceState s) {
    _state = s;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Notification content builders
  // ---------------------------------------------------------------------------

  /// The notification title text for the current service state.
  ///
  /// Exposed for testing via [@visibleForTesting].
  @visibleForTesting
  String buildTitleForTest() => _buildTitle();

  /// The notification body text for the current service state.
  ///
  /// Exposed for testing via [@visibleForTesting].
  @visibleForTesting
  String buildBodyForTest() => _buildBody();

  /// Forces the internal state for unit testing without platform channel calls.
  @visibleForTesting
  void setStateForTest(BackgroundServiceState s) => _setState(s);

  String _buildTitle() {
    if (_state == BackgroundServiceState.reconnecting) {
      return 'Meridian — Reconnecting\u2026';
    }
    final tncOk = _tnc.currentStatus == ConnectionStatus.connected;
    final aprsOk =
        _station.currentConnectionStatus == ConnectionStatus.connected;
    if (tncOk && aprsOk) return 'Meridian — TNC + APRS-IS';
    if (tncOk) return 'Meridian — TNC connected';
    if (aprsOk) return 'Meridian — APRS-IS connected';
    return 'Meridian — Connected';
  }

  String _buildBody() {
    final beaconPart = _buildBeaconPart();
    final agoPart = _beaconing.lastBeaconAgo;
    if (agoPart != null && _beaconing.isActive) {
      return '$beaconPart · Last beacon: $agoPart';
    }
    return beaconPart;
  }

  String _buildBeaconPart() {
    if (!_beaconing.isActive) return 'Beaconing off';
    return switch (_beaconing.mode) {
      BeaconMode.auto =>
        'Auto beacon every ${_formatInterval(_beaconing.autoIntervalS)}',
      BeaconMode.smart => 'SmartBeaconing\u2122 active',
      BeaconMode.manual => 'Manual mode',
    };
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    return '${minutes}m';
  }

  // ---------------------------------------------------------------------------
  // Permission helper
  // ---------------------------------------------------------------------------

  Future<bool> _requestBackgroundLocationPermission(
    BuildContext context,
  ) async {
    final current = await Permission.locationAlways.status;
    if (current.isGranted) return true;
    if (!context.mounted) return false;

    // Show rationale before sending the user to Settings (Android 11+ always
    // redirects to Settings; the dialog explains what will happen).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Background location needed'),
        content: const Text(
          'To beacon your position while Meridian is in the background, '
          'tap Continue and select "Allow all the time" on the next screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final result = await Permission.locationAlways.request();
    return result.isGranted;
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _tnc.removeListener(_onServiceStateChanged);
    _station.removeListener(_onServiceStateChanged);
    _beaconing.removeListener(_onServiceStateChanged);
    _updateDebounce?.cancel();
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
      FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    }
    super.dispose();
  }
}
