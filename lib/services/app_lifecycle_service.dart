import 'dart:async';

import 'package:local_keep/services/app_logger.dart';
import 'package:local_keep/services/auto_lock_coordinator.dart';

/// Manages skip-lock flags for file picking / preview with hard timeouts.
class AppLifecycleService {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  final _coordinator = AutoLockCoordinator();
  Timer? _previewGracePeriodTimer;
  Timer? _pickingTimeoutTimer;
  Timer? _previewTimeoutTimer;

  static const Duration _previewGracePeriod = Duration(seconds: 3);
  static const Duration _maxPickDuration = Duration(minutes: 5);
  static const Duration _maxPreviewDuration = Duration(minutes: 5);

  bool get isPickingFile => _coordinator.isPickingFile;
  bool get isPreviewingFile => _coordinator.isPreviewingFile;
  bool get shouldSkipLock => _coordinator.shouldSkipLock;

  void setPickingFile(bool value) {
    _pickingTimeoutTimer?.cancel();
    _pickingTimeoutTimer = null;
    _coordinator.setPickingFile(value);
    AppLogger.d('isPickingFile=$value');

    if (value) {
      _pickingTimeoutTimer = Timer(_maxPickDuration, () {
        AppLogger.d('File picking flag timed out — clearing');
        _coordinator.setPickingFile(false);
      });
    }
  }

  void setPreviewingFile(bool value, {bool withGracePeriod = false}) {
    _previewGracePeriodTimer?.cancel();
    _previewGracePeriodTimer = null;
    _previewTimeoutTimer?.cancel();
    _previewTimeoutTimer = null;

    if (!value && withGracePeriod) {
      AppLogger.d(
        'Preview grace period ${_previewGracePeriod.inSeconds}s',
      );
      _previewGracePeriodTimer = Timer(_previewGracePeriod, () {
        _coordinator.setPreviewingFile(false);
        AppLogger.d('isPreviewingFile=false (after grace)');
      });
    } else {
      _coordinator.setPreviewingFile(value);
      AppLogger.d('isPreviewingFile=$value');
      if (value) {
        _previewTimeoutTimer = Timer(_maxPreviewDuration, () {
          AppLogger.d('File preview flag timed out — clearing');
          _coordinator.setPreviewingFile(false);
        });
      }
    }
  }

  void startFilePicking() => setPickingFile(true);

  void endFilePicking() => setPickingFile(false);

  void startFilePreviewing() => setPreviewingFile(true);

  void endFilePreviewing({bool withGracePeriod = true}) {
    setPreviewingFile(false, withGracePeriod: withGracePeriod);
  }

  void dispose() {
    _previewGracePeriodTimer?.cancel();
    _pickingTimeoutTimer?.cancel();
    _previewTimeoutTimer?.cancel();
    _previewGracePeriodTimer = null;
    _pickingTimeoutTimer = null;
    _previewTimeoutTimer = null;
  }
}
