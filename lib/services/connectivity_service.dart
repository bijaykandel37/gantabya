import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device currently has a network connection.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    _sub = _connectivity.onConnectivityChanged.listen(_update);
    _connectivity.checkConnectivity().then(_update);
  }

  final _connectivity = Connectivity();
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _online = true;

  bool get isOnline => _online;

  void _update(List<ConnectivityResult> results) {
    final online =
        results.any((r) => r != ConnectivityResult.none) && results.isNotEmpty;
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
