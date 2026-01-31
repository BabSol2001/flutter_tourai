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
  final List<Map<String, dynamic>> maneuvers;  // ← درست: لیست map
  final List<LatLng> routePoints;
  final String vehicleMode;
  

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  int _currentManeuverIndex = 0;
  int _lastSpokenManeuverIndex = -1;  // ← جدید: آخرین دستوری که صدا زده شده

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;

  GuidanceManager({
    required this.mapController,
    required this.onUserMarkerUpdate,
    required this.onInstructionUpdate,
    required this.maneuvers,
    required this.routePoints,
    required this.vehicleMode,
  }) {
    _initTTS();
  }

  Map<String, dynamic> _getGuidanceDistances() {
    switch (vehicleMode) {
      case "pedestrian":
        return {"pre": 80.0, "main": 30.0};     // پیاده: نزدیک
      case "bicycle":
        return {"pre": 150.0, "main": 50.0};    // دوچرخه: متوسط
      case "motorcycle":
      case "auto":
        return {"pre": 400.0, "main": 100.0};   // ماشین/موتور: بیشتر
      case "truck":
        return {"pre": 800.0, "main": 200.0};   // کامیون/اتوبان: خیلی زود
      default:
        return {"pre": 300.0, "main": 80.0};
    }
  }




  void _initTTS() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("fa-IR");  // فارسی برای دستورات فارسی
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  IconData _getVehicleIcon() {
    switch (vehicleMode) {
      case "auto":
        return Icons.directions_car_outlined;
      case "truck":
        return Icons.local_shipping_outlined;
      case "motorcycle":
        return Icons.motorcycle_outlined;
      case "bicycle":
        return Icons.directions_bike_outlined;
      case "pedestrian":
        return Icons.directions_walk_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

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
      case 18: return Icons.location_on;
      default: return Icons.arrow_upward;
    }
  }

  void _speak(String text) {
    if (_isSpeaking) {
      _flutterTts.stop();
    }
    _isSpeaking = true;
    _flutterTts.speak(text).then((_) {
      _isSpeaking = false;
    }).catchError((error) {
      _isSpeaking = false;
    });
  }

  void startGuidance() {
    if (maneuvers.isEmpty || routePoints.isEmpty) return;

    _currentManeuverIndex = 0;

    var first = maneuvers[0];
    String firstInstruction = first['instruction'] ?? "مستقیم بروید";
    IconData firstIcon = _getTurnIcon(first['type']);
    double firstDistance = (first['length'] ?? 0).toDouble();
    onInstructionUpdate(firstInstruction, firstIcon, firstDistance);
    _speak(firstInstruction);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
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

      if (_currentManeuverIndex >= maneuvers.length - 1) {
        return;
      }

      var current = maneuvers[_currentManeuverIndex];
      int beginIndex = current['begin_shape_index'] ?? 0;
      beginIndex = beginIndex.clamp(0, routePoints.length - 1);
      LatLng triggerPoint = routePoints[beginIndex];

      double distance = calculateDistance(userLatLng, triggerPoint);

      // پیش‌آگهی
      if (distance < 150 && distance > 50 && _currentManeuverIndex < maneuvers.length - 1) {
        var next = maneuvers[_currentManeuverIndex + 1];
        String pre = next['verbal_pre_transition_instruction'] ?? 
                    "به زودی ${next['instruction'] ?? 'بپیچید'}";
        if (!_isSpeaking) {
          _speak(pre);
        }
      }

      // عبور از پیچ
      if (distance < 30) {
        _currentManeuverIndex++;
        if (_currentManeuverIndex < maneuvers.length) {
          var next = maneuvers[_currentManeuverIndex];
          String nextInstruction = next['instruction'] ?? "ادامه دهید";
          IconData nextIcon = _getTurnIcon(next['type']);
          double nextDistance = (next['length'] ?? 0).toDouble();
          onInstructionUpdate(nextInstruction, nextIcon, nextDistance);
          _speak(nextInstruction);
        }
      }

      // مقصد
      if (_currentManeuverIndex >= maneuvers.length - 1) {
        onInstructionUpdate("رسیدید به مقصد!", Icons.location_on, 0);
        _speak("رسیدید به مقصد!");
      }
    });

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

  double calculateDistance(LatLng p1, LatLng p2) {  // حذف _
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

void updateUserPosition(LatLng position) {
  // این متد موقعیت رو مثل GPS واقعی پردازش می‌کنه
  // تمام منطق داخل listen رو اینجا کپی کن (بدون stream)

final distances = _getGuidanceDistances();
final double preDistance = distances['pre']!;   // پیش‌آگهی
final double mainDistance = distances['main']!; // دستور اصلی

  // آپدیت مارکر
  onUserMarkerUpdate(Marker(
    point: position,
    width: 50,
    height: 50,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red, width: 5),
        color: Colors.transparent,
      ),

          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                _getVehicleIcon(),  // ← اینجا عوض شد
                color: Colors.black,
                size: 30,
                shadows: const [
              Shadow(
                color: Color.fromRGBO(0, 0, 0, 0.6),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ],
      ),
    ),
  ));

  mapController.move(position, 19);

  if (_currentManeuverIndex >= maneuvers.length - 1) {
    return;
  }

  var current = maneuvers[_currentManeuverIndex];
  int beginIndex = current['begin_shape_index'] ?? 0;
  beginIndex = beginIndex.clamp(0, routePoints.length - 1);
  LatLng triggerPoint = routePoints[beginIndex];

  double distance = calculateDistance(position, triggerPoint);

  // پیش‌آگهی
  if (distance < preDistance && distance > mainDistance && _currentManeuverIndex + 1 < maneuvers.length) {
    int nextIndex = _currentManeuverIndex + 1;
    if (_lastSpokenManeuverIndex < nextIndex) {  // فقط اگر قبلاً نگفته باشیم
      var next = maneuvers[nextIndex];
      String pre = next['verbal_pre_transition_instruction'] ?? 
                  "به زودی ${next['instruction'] ?? 'بپیچید'}";

      String distanceText = distance > 1000 
          ? "${(distance / 1000).toStringAsFixed(1)} کیلومتر"
          : "${distance.toStringAsFixed(0)} متر";

      _speak("در $distanceText آینده $pre");
      _lastSpokenManeuverIndex = nextIndex;  // علامت بزن که گفته شد
    }
  }

  // دستور اصلی
  if (distance < mainDistance) {
    if (_lastSpokenManeuverIndex <= _currentManeuverIndex) {  // فقط اگر قبلاً نگفته باشیم
      var current = maneuvers[_currentManeuverIndex];
      String instruction = current['instruction'] ?? "ادامه دهید";

      String remainingText = distance > 1000 
          ? "${(distance / 1000).toStringAsFixed(1)} کیلومتر"
          : "${distance.toStringAsFixed(0)} متر";

      String speakText = distance < 50 
          ? instruction 
          : "$remainingText دیگر $instruction";

      _speak(speakText);
      _lastSpokenManeuverIndex = _currentManeuverIndex;
    }

    // عبور از پیچ (بعد از گفتن دستور، اندیس رو افزایش بده)
    _currentManeuverIndex++;
    if (_currentManeuverIndex < maneuvers.length) {
      var next = maneuvers[_currentManeuverIndex];
      String nextInstruction = next['instruction'] ?? "مستقیم بروید";
      IconData nextIcon = _getTurnIcon(next['type']);
      double nextLength = (next['length'] ?? 0).toDouble();
      onInstructionUpdate(nextInstruction, nextIcon, nextLength);
    }
  }

  // مقصد
  if (_currentManeuverIndex >= maneuvers.length - 1) {
    onInstructionUpdate("رسیدید به مقصد!", Icons.location_on, 0);
    _speak("رسیدید به مقصد!");
  }
}
}