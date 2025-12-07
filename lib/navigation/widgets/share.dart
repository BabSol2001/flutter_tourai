// lib/widgets/share.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

/// دکمه اشتراک‌گذاری مکان — قابل استفاده در همه جای اپ
/// فقط LatLng بده، همه چیز خودش انجام میشه
class ShareLocationButton extends StatelessWidget {
  final LatLng location;
  final String? placeName;           // اختیاری: نام مکان (مثلاً "کافه نادری")
  final String message;              // پیام بالا (مثلاً "بیا پیشم")
  final Color? backgroundColor;
  final double? height;

  const ShareLocationButton({
    Key? key,
    required this.location,
    this.placeName,
    this.message = "من الان اینجام",
    this.backgroundColor,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 48,
      child: ElevatedButton.icon(
        onPressed: () => ShareLocationButton.shareLocationStatic(
          location: location,
          placeName: placeName,
          message: message,
        ),
        icon: const Icon(Icons.share, size: 18),
        label: const Text("اشتراک"),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.purple.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  static Future<void> shareLocationStatic({
    required LatLng location,
    String? placeName,
    String message = "من الان اینجام",
  }) async {
    final lat = location.latitude.toStringAsFixed(6);
    final lng = location.longitude.toStringAsFixed(6);
    final coords = "$lat, $lng";

    final title = placeName?.trim().isNotEmpty == true ? placeName!.trim() : "موقعیت من";

    final shareText = """
$message

$title
مختصات: $coords

نقشه‌ها:
Google Maps → https://maps.google.com/?q=$lat,$lng
Waze → https://waze.com/ul?ll=$lat,$lng&navigate=yes
نشان (بلد) → https://neshan.org/maps/places/@$lat,$lng,15z
    """.trim();

    await Share.share(shareText, subject: title);
  }
}
