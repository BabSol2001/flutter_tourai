// lib/navigation/widgets/guidance_simulator.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GuidanceSimulator {
  final MapController mapController;
  final Function(Marker?) onUserMarkerUpdate;
  final List<LatLng> routePoints;


  Timer? _simulationTimer;
  int _currentPointIndex = 0;
  bool _isRunning = false;

  GuidanceSimulator({
    required this.mapController,
    required this.onUserMarkerUpdate,
    required this.routePoints,
  });

  void startSimulation() {
    if (routePoints.isEmpty || _isRunning) return;

    _isRunning = true;
    _currentPointIndex = 0;

    // مارکر موقعیت از نقطه اول شروع کن
    _updateMarker(routePoints[0]);

    // هر 500 میلی‌ثانیه یک نقطه جلو برو (سرعت قابل تنظیم)
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_currentPointIndex >= routePoints.length - 1) {
        stopSimulation();
        return;
      }

      _currentPointIndex++;
      final LatLng currentPosition = routePoints[_currentPointIndex];

      _updateMarker(currentPosition);
      mapController.move(currentPosition, 19);
    });
  }

  void _updateMarker(LatLng position) {
    onUserMarkerUpdate(Marker(
      point: position,
      width: 50,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.green.shade800, width: 3),
          color: Colors.transparent,
        ),
        child: const Icon(Icons.circle_outlined, color: Colors.green, size: 40),
      ),
    ));
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _isRunning = false;
    onUserMarkerUpdate(null);  // مارکر رو پاک کن
  }

  bool get isRunning => _isRunning;

  void dispose() {
    stopSimulation();
  }
}