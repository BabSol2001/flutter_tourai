// lib/navigation/widgets/guidance_manager.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_map/flutter_map.dart';  // فقط این برای LatLng و MapController
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;

class GuidanceManager {
  final MapController mapController;
  final Function(Marker?) onUserMarkerUpdate;
  final Function(String instruction, IconData icon) onInstructionUpdate;
  final List<String> instructions;  // لیست دستورات متنی فارسی/انگلیسی
  final List<LatLng> routePoints;

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  int _currentInstructionIndex = 0;

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

  // محاسبه فاصله دستی
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
    await _flutterTts.setLanguage("en-US");  // انگلیسی بهتر می‌خونه متن‌های فعلی
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // تشخیص نوع پیچ از متن دستور (چون type نداریم)
  IconData _getTurnIconFromText(String instructionText) {
    final lowerText = instructionText.toLowerCase();

    if (lowerText.contains("right") || lowerText.contains("راست")) {
      return Icons.turn_right;
    } else if (lowerText.contains("sharp right") || lowerText.contains("تند راست")) {
      return Icons.turn_sharp_right;
    } else if (lowerText.contains("slight right") || lowerText.contains("کمی راست")) {
      return Icons.turn_slight_right;
    } else if (lowerText.contains("left") || lowerText.contains("چپ")) {
      return Icons.turn_left;
    } else if (lowerText.contains("sharp left") || lowerText.contains("تند چپ")) {
      return Icons.turn_sharp_left;
    } else if (lowerText.contains("slight left") || lowerText.contains("کمی چپ")) {
      return Icons.turn_slight_left;
    } else if (lowerText.contains("u-turn") || lowerText.contains("دور بزن")) {
      return lowerText.contains("right") ? Icons.u_turn_right : Icons.u_turn_left;
    } else if (lowerText.contains("destination") || lowerText.contains("مقصد") || lowerText.contains("your destination")) {
      return Icons.location_on;
    } else {
      return Icons.arrow_upward;
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
    String firstInstruction = instructions[0];
    onInstructionUpdate(firstInstruction, _getTurnIconFromText(firstInstruction));
    _speak(firstInstruction);

    // دنبال کردن موقعیت کاربر (مارکر و حرکت نقشه)
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final LatLng userLatLng = LatLng(position.latitude, position.longitude);

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

      mapController.move(userLatLng, 19);
    });

    // تایمر برای تغییر دستورات (هر 25 ثانیه یک دستور جدید)
    Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_currentInstructionIndex >= instructions.length - 1) {
        // آخرین دستور یا فراتر از آن
        String finalInstruction = instructions.isNotEmpty ? instructions.last : "رسیدید به مقصد!";
        onInstructionUpdate(finalInstruction, Icons.location_on);
        _speak("رسیدید به مقصد!");
        timer.cancel();
        return;
      }

      _currentInstructionIndex++;
      String nextInstruction = instructions[_currentInstructionIndex];
      onInstructionUpdate(nextInstruction, _getTurnIconFromText(nextInstruction));
      _speak(nextInstruction);
    });

    // چرخش نقشه بر اساس جهت گوشی
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
    onInstructionUpdate("راهبری متوقف شد", Icons.directions);
  }

  void dispose() {
    stopGuidance();
  }
}