// lib/navigation/widgets/routing_card.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'transport_mode_selector.dart';
import 'search_field.dart';

class RoutingTopPanel extends StatelessWidget {
  final TextEditingController originController;
  final TextEditingController destinationController;
  final LatLng? selectedDestination;
  final LatLng? originLatLng;
  final bool isLoadingRoute;
  final ValueNotifier<String> modeNotifier;
  final Function(String) onModeChanged;
  final VoidCallback onSwap;
  final VoidCallback onClearDestination;
  final VoidCallback onClearOrigin;
  final VoidCallback onStartRouting;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onAddWaypoint;
  final int? waypointsLength;

  const RoutingTopPanel({
    Key? key,
    required this.originController,
    required this.destinationController,
    required this.selectedDestination,
    required this.originLatLng,
    required this.isLoadingRoute,
    required this.modeNotifier,
    required this.onModeChanged,
    required this.onSwap,
    required this.onClearDestination,
    required this.onClearOrigin,
    required this.onStartRouting,
    required this.onClose,
    required this.onMinimize,
    required this.onAddWaypoint,
    required this.waypointsLength,
  }) : super(key: key);

  // تابع داخلی برای تبدیل mode به نام فارسی
  String _getDisplayName(String mode) {
    switch (mode) {
      case "auto":
        return "ماشین";
      case "motorcycle":
        return "موتورسیکلت";
      case "truck":
        return "کامیون";
      case "bicycle":
        return "دوچرخه";
      case "pedestrian":
        return "پیاده";
      default:
        return "ماشین";
    }
  }

  @override
  Widget build(BuildContext context) {
    // تعداد نقاط بین‌راهی رو از parent می‌گیریم (بعداً پاس می‌دیم)
    final int waypointsCount = waypointsLength ?? 0;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // هدر: مینیمایز، بستن و خط کشویی
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: onMinimize,
                            icon: const Icon(Icons.minimize, color: Colors.grey, size: 28),
                            tooltip: "مینیمایز",
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                            tooltip: "بستن",
                          ),
                        ],
                      ),
                      Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const Opacity(opacity: 0, child: Icon(Icons.close)),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text("مسیریابی هوشمند", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // فیلد مبدأ
                  TextField(
                    controller: originController,
                    onTap: () => originController.text == "موقعیت فعلی" ? originController.clear() : null,
                    decoration: InputDecoration(
                      hintText: "مبدا",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: GestureDetector(
                        onTap: () async {
                          try {
                            Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                            final coords = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
                            originController.text = coords;
                            onClearOrigin();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("مبدا: موقعیت فعلی شما"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("موقعیت در دسترس نیست"), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: const Padding(padding: EdgeInsets.all(12.0), child: Icon(Icons.my_location, color: Colors.blue, size: 26)),
                      ),
                      suffixIcon: originLatLng != null
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: onClearOrigin)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // فیلد مقصد + دکمه افزودن waypoint در یک ردیف
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SearchField(
                          controller: destinationController,
                          hintText: waypointsCount > 0 ? "مقصد نهایی" : "مقصد",
                          isLoading: isLoadingRoute,
                          onClear: selectedDestination != null ? onClearDestination : null,
                          fillColor: Colors.grey,
                          prefixIcon: waypointsCount > 0 ? Icons.push_pin : Icons.location_on,
                          prefixIconColor: waypointsCount > 0 ? Colors.green.shade600 : Colors.red,
                          onSubmitted: (_) {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 56,
                        child: IconButton(
                          icon: Icon(Icons.add_circle, color: Colors.blue.shade600, size: 34),
                          tooltip: "افزودن نقطه بین‌راهی",
                          onPressed: selectedDestination != null ? onAddWaypoint : null, // فقط وقتی مقصد انتخاب شده فعال باشه
                        ),
                      ),
                    ],
                  ),

                  // نمایش تعداد نقاط بین‌راهی
                  if (waypointsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "نقاط بین‌راهی اضافه شده: $waypointsCount",
                          style: TextStyle(fontSize: 13.5, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // دکمه جابجایی مبدأ و مقصد
                  Center(
                    child: IconButton(
                      onPressed: selectedDestination != null ? onSwap : null,
                      icon: Icon(Icons.swap_vert, size: 36, color: selectedDestination != null ? Colors.blue : Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // انتخاب وسیله نقلیه
                  ValueListenableBuilder<String>(
                    valueListenable: modeNotifier,
                    builder: (context, mode, _) {
                      return TransportModeSelector(
                        selectedMode: mode,
                        onModeSelected: (newMode) {
                          modeNotifier.value = newMode;
                          onModeChanged(newMode);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // دکمه شروع مسیریابی
                  ValueListenableBuilder<String>(
                    valueListenable: modeNotifier,
                    builder: (context, currentMode, _) {
                      final String displayName = _getDisplayName(currentMode);
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (selectedDestination == null || isLoadingRoute) ? null : () {
                            onStartRouting();
                            onMinimize();
                          },
                          icon: isLoadingRoute
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.directions),
                          label: Text(isLoadingRoute ? "در حال رسم مسیر..." : "شروع مسیریابی با $displayName"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// در انتهای فایل routing_card.dart اضافه شود.

class RouteMarker extends StatelessWidget { // 👈 نام به RouteMarker تغییر کرد
  final String letter;
  final Color color;

  const RouteMarker({super.key, required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color, // رنگ زمینه (قرمز یا سبز)
        shape: BoxShape.circle, // شکل دایره
        border: Border.all(color: Colors.white, width: 2), // حاشیه سفید برای برجسته شدن
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// در routing_card.dart، در کنار RouteMarker

class WaypointMarker extends StatelessWidget {
  final int number;

  const WaypointMarker({super.key, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.blue.shade600, // رنگ زمینه آبی برای مقاصد بین راهی
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number', // نمایش شماره مقصد بین راهی
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}