// lib/navigation/widgets/guidance_simulator.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GuidanceSimulator {
  final MapController mapController;
  final Function(Marker?) onUserMarkerUpdate;
  final List<LatLng> routePoints;
  final Function(LatLng position) onPositionUpdate;  // ← جدید: موقعیت رو به GuidanceManager بده

  Timer? _simulationTimer;
  int _currentPointIndex = 0;
  bool _isRunning = false;

  GuidanceSimulator({
    required this.mapController,
    required this.onUserMarkerUpdate,
    required this.routePoints,
    required this.onPositionUpdate,
  });

  void startSimulation({Duration stepDuration = const Duration(milliseconds: 5500)}) {
    if (routePoints.isEmpty || _isRunning) return;

    _isRunning = true;
    _currentPointIndex = 0;

    final LatLng startPosition = routePoints[0];
    _updateMarker(startPosition);
    onPositionUpdate(startPosition);  // موقعیت اولیه رو بفرست

    _simulationTimer = Timer.periodic(stepDuration, (timer) {
      if (_currentPointIndex >= routePoints.length - 1) {
        stopSimulation();
        return;
      }

      _currentPointIndex++;
      final LatLng currentPosition = routePoints[_currentPointIndex];

      _updateMarker(currentPosition);
      mapController.move(currentPosition, 19);
      onPositionUpdate(currentPosition);  // ← موقعیت جدید رو به GuidanceManager بفرست
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
    onUserMarkerUpdate(null);
  }

  bool get isRunning => _isRunning;

  void dispose() {
    stopSimulation();
  }
}