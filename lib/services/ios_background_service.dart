import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:live_activities/live_activities.dart';

import '../core/connection/connection_registry.dart';
import 'beaconing_service.dart';

/// iOS background service state — mirrors [BackgroundServiceState] on Android.
enum BackgroundServiceState { stopped, running, error }

/// Data payload pushed to the Live Activity on each state change.
class LiveActivityContent {
  final List<String> connectedTransportNames;
  final DateTime? lastBeaconAt;
  final bool beaconingActive;
  final String serviceStateLabel;

  const LiveActivityContent({
    required this.connectedTransportNames,
    this.lastBeaconAt,
    required this.beaconingActive,
    required this.serviceStateLabel,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'connectedTransports': connectedTransportNames,
      'beaconingActive': beaconingActive,
      'serviceStateLabel': serviceStateLabel,
    };
    // NSUserDefaults rejects null — omit the key entirely when there is no
    // beacon timestamp yet rather than inserting a null value.
    if (lastBeaconAt != null) {
      map['lastBeaconTimestamp'] = lastBeaconAt!.millisecondsSinceEpoch;
    }
    return map;
  }

  factory LiveActivityContent.fromRegistryAndBeaconing(
    ConnectionRegistry registry,
    BeaconingService beaconing,
  ) {
    final names = registry.connected.map((c) => c.displayName).toList();
    return LiveActivityContent(
      connectedTransportNames: names,
      lastBeaconAt: beaconing.lastBeaconAt,
      beaconingActive: beaconing.isActive,
      serviceStateLabel: names.isEmpty ? 'Disconnected' : 'Connected',
    );
  }
}

/// iOS-only background service. Manages Live Activity lifecycle and
/// signals the UI layer when background location permission is needed.
///
/// Analogous to [BackgroundServiceManager] on Android, but simpler: iOS keeps
/// the process alive via UIBackgroundModes (voip + bluetooth-central + location)
/// rather than a foreground service, so no separate background isolate is needed.
class IosBackgroundService extends ChangeNotifier {
  IosBackgroundService() : assert(Platform.isIOS);

  final _liveActivities = LiveActivities();
  String? _activityId;
  BackgroundServiceState _state = BackgroundServiceState.stopped;

  /// Set to true when background location permission is needed.
  /// The UI layer watches this flag and shows a [CupertinoAlertDialog],
  /// then calls [clearBackgroundLocationPrompt] to reset it.
  bool needsBackgroundLocationPrompt = false;

  BackgroundServiceState get state => _state;
  bool get isRunning => _state == BackgroundServiceState.running;

  Future<void> initialize() async {
    await _liveActivities.init(
      appGroupId: 'group.com.meridianaprs.meridianAprs',
    );
  }

  /// Called when [ConnectionRegistry] changes state.
  Future<void> onConnectionsChanged(LiveActivityContent content) async {
    if (content.connectedTransportNames.isNotEmpty) {
      _setState(BackgroundServiceState.running);
      await _startOrUpdateLiveActivity(content);
    } else {
      _setState(BackgroundServiceState.stopped);
      await _endLiveActivity();
    }
  }

  /// Called when [BeaconingService] mode or state changes.
  Future<void> onBeaconingChanged(
    BeaconMode mode,
    LiveActivityContent content,
  ) async {
    if (mode == BeaconMode.auto || mode == BeaconMode.smart) {
      await _requestBackgroundLocationIfNeeded();
    }
    if (_activityId != null) {
      await _startOrUpdateLiveActivity(content);
    }
  }

  /// Push a Live Activity update without changing connection state.
  Future<void> updateLiveActivity(LiveActivityContent content) async {
    if (_activityId != null) {
      await _startOrUpdateLiveActivity(content);
    }
  }

  // Stable key used as the activityId argument to createActivity.
  static const _kActivityKey = 'meridian_aprs_status';

  Future<void> _startOrUpdateLiveActivity(LiveActivityContent content) async {
    if (_activityId == null) {
      _activityId = await _liveActivities.createActivity(
        _kActivityKey,
        content.toMap(),
        removeWhenAppIsKilled: true,
        iOSEnableRemoteUpdates: false,
      );
    } else {
      await _liveActivities.updateActivity(_activityId!, content.toMap());
    }
  }

  Future<void> _endLiveActivity() async {
    if (_activityId != null) {
      await _liveActivities.endActivity(_activityId!);
      _activityId = null;
    }
  }

  /// Checks whether background location ("Always") permission is granted.
  /// If not, sets [needsBackgroundLocationPrompt] and notifies listeners.
  /// Does not invoke the system permission dialog — that is the UI layer's job.
  Future<void> _requestBackgroundLocationIfNeeded() async {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      needsBackgroundLocationPrompt = true;
      notifyListeners();
    }
  }

  /// Called by the UI layer after it has consumed [needsBackgroundLocationPrompt].
  void clearBackgroundLocationPrompt() {
    needsBackgroundLocationPrompt = false;
  }

  void _setState(BackgroundServiceState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _endLiveActivity();
    super.dispose();
  }
}
