import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool _isConnected = true;
  bool _isInitialized = false;

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  void initialize() {
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          print('🌐 Connectivity stream error: $error');
          _isConnected = false;
          notifyListeners();
        },
      );
      // Check initial connectivity status
      _checkInitialConnectivity();
      _isInitialized = true;
    } catch (e) {
      print('🌐 Error initializing connectivity service: $e');
      _isConnected = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      print('🌐 Initial connectivity check: $result');
      _updateConnectionStatus(result);
    } catch (e) {
      print('🌐 Error checking initial connectivity: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected =
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;

    // Debug print to see connectivity changes
    print('🌐 Connectivity changed: $result, isConnected: $_isConnected');

    // Only notify if status changed
    if (wasConnected != _isConnected) {
      print(
        '🌐 Connection status changed: ${wasConnected ? "Connected" : "Disconnected"} -> ${_isConnected ? "Connected" : "Disconnected"}',
      );
      notifyListeners();
    }
  }

  // Method to manually set connectivity status for testing
  void setConnectivityStatus(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      print(
        '🌐 Manual connectivity change: ${isConnected ? "Connected" : "Disconnected"}',
      );
      notifyListeners();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

// Global connectivity service instance
final connectivityService = ConnectivityService();
