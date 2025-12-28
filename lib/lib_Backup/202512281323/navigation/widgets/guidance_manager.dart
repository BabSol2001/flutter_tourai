// lib/navigation/widgets/guidance_manager.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'dart:async';
import 'dart:math' as math;

class GuidanceManager {
  final MapController mapController;
  final Function(Marker?) onUserMarkerUpdate;
  final Function(String instruction, IconData icon, double distance) onInstructionUpdate;
  final List<String> instructions;  // تغییر از dynamic به String
  final List<LatLng> routePoints;

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  int _currentInstructionIndex = 0;  // تغییر نام به instruction

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;

  GuidanceManager({
    required this.mapController,
    required this.onUserMarkerUpdate,
    required this.onInstructionUpdate,
    required this.instructions,
    required this.routePoints,
  }) {
    _initTTS();
  }

  // محاسبه فاصله دستی (بدون تغییر)
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    double lat1 = p1.latitude * math.pi / 180;
    double lat2 = p2.latitude * math.pi / 180;
    double dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    double dLon = (p2.longitude - p1.longitude) * math.pi / 180;

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
               math.cos(lat1) * math.cos(lat2) *
               math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  void _initTTS() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("fa-IR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // این تابع رو نگه داشتم ولی فعلاً استفاده نمی‌شه (چون type نداریم)
  IconData _getTurnIcon(int? type) {
    if (type == null) return Icons.arrow_upward;
    switch (type) {
      case 1: return Icons.arrow_upward;
      case 2: return Icons.turn_slight_right;
      case 3: return Icons.turn_right;
      case 4: return Icons.turn_sharp_right;
      case 5: return Icons.u_turn_right;
      case 6: return Icons.turn_slight_left;
      case 7: return Icons.turn_left;
      case 8: return Icons.turn_sharp_left;
      case 9: return Icons.u_turn_left;
      case 10: return Icons.merge;
      case 18: return Icons.location_on;
      default: return Icons.arrow_upward;
    }
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) await _flutterTts.stop();
    _isSpeaking = true;
    await _flutterTts.speak(text);
    _flutterTts.completionHandler = () => _isSpeaking = false;
  }

  void startGuidance() {
    if (instructions.isEmpty) return;

    _currentInstructionIndex = 0;

    // اولین دستور رو فوری نشون بده و بگو
    onInstructionUpdate(instructions[0], Icons.arrow_upward, 0);
    _speak(instructions[0]);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      final LatLng userLatLng = LatLng(position.latitude, position.longitude);

      // آپدیت مارکر موقعیت فعلی کاربر
      onUserMarkerUpdate(Marker(
        point: userLatLng,
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

      // حرکت نقشه به موقعیت کاربر
      mapController.move(userLatLng, 19);

      // اگر به آخر رسیدیم
      if (_currentInstructionIndex >= instructions.length - 1) {
        if (_currentInstructionIndex == instructions.length - 1) {
          onInstructionUpdate(instructions.last, Icons.location_on, 0);
          await _speak("رسیدید به مقصد!");
        }
        return;
      }

      // برای سادگی، هر بار که فاصله به نقطه بعدی کمتر از 100 متر شد، دستور بعدی رو بگو
      // (چون begin_shape_index نداریم، از فاصله به نقاط مسیر استفاده می‌کنیم)
      if (_currentInstructionIndex < instructions.length - 1) {
        int nextIndex = _currentInstructionIndex + 1;
        if (nextIndex < routePoints.length) {
          LatLng nextPoint = routePoints[nextIndex * 10];  // تقریبی (هر 10 نقطه یک دستور)
          double distance = _calculateDistance(userLatLng, nextPoint);
          if (distance < 100) {
            _currentInstructionIndex = nextIndex;
            String nextInstruction = instructions[nextIndex];
            onInstructionUpdate(nextInstruction, Icons.arrow_upward, distance);
            await _speak(nextInstruction);
          }
        }
      }
    });

    // چرخش نقشه بر اساس جهت
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        mapController.rotate(-event.heading!);
      }
    });
  }

  void stopGuidance() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _flutterTts.stop();
    onUserMarkerUpdate(null);
    onInstructionUpdate("راهبری متوقف شد", Icons.directions, 0);
  }

  void dispose() {
    stopGuidance();
  }
}