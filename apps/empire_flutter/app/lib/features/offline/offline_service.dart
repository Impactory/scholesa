import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// OfflineService listens to connectivity changes and exposes offline state.
class OfflineService extends ChangeNotifier {
  OfflineService() {
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivity);
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _updateOffline(_isDisconnected(results));
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    _updateOffline(_isDisconnected(results));
  }

  bool _isDisconnected(List<ConnectivityResult> results) {
    // Treat none/other as offline; wifi/mobile/ethernet/vpn as online.
    return results.every((r) =>
        r == ConnectivityResult.none ||
        r == ConnectivityResult.other ||
        r == ConnectivityResult.bluetooth);
  }

  void _updateOffline(bool offline) {
    if (_isOffline == offline) return;
    _isOffline = offline;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
