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
                  // دکمه‌های بالا - سمت چپ
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

                  // فیلد مبدأ - با آیکون موقعیت فعلی قابل کلیک
                  TextField(
                    controller: originController,
                    onTap: () {
                      if (originController.text == "موقعیت فعلی") {
                        originController.clear();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "مبدا",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: GestureDetector(
                        onTap: () async {
                          try {
                            Position position = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high,
                            );

                            final lat = position.latitude.toStringAsFixed(6);
                            final lng = position.longitude.toStringAsFixed(6);
                            final coords = "$lat, $lng";

                            originController.text = coords;
                            onClearOrigin(); // چون الان مبدأ = موقعیت فعلی هست

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("مبدا: موقعیت فعلی شما"),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("موقعیت در دسترس نیست"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(Icons.my_location, color: Colors.blue, size: 26),
                        ),
                      ),
                      suffixIcon: originLatLng != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: onClearOrigin,
                            )
                          : null,
                    ),
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 12),

                  // فیلد مقصد
                  SearchField(
                    controller: destinationController,
                    hintText: "مقصد",
                    isLoading: false,
                    onClear: selectedDestination != null ? onClearDestination : null,
                    fillColor: Colors.grey[100]!,
                    prefixIcon: Icons.location_on,
                    prefixIconColor: Colors.red,
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 16),

                  // دکمه جابجایی
                  Center(
                    child: IconButton(
                      onPressed: selectedDestination != null ? onSwap : null,
                      icon: Icon(
                        Icons.swap_vert,
                        size: 36,
                        color: selectedDestination != null ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // انتخاب نوع وسیله نقلیه
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

                  // دکمه شروع مسیریابی — متنش همیشه با تغییر حالت آپدیت میشه
                  ValueListenableBuilder<String>(
                    valueListenable: modeNotifier,
                    builder: (context, currentMode, _) {
                      final String displayName = _getDisplayName(currentMode);

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: selectedDestination == null || isLoadingRoute
                              ? null
                              : () {
                                  onStartRouting();
                                  onMinimize();
                                },
                          icon: isLoadingRoute
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.directions),
                          label: Text(
                            isLoadingRoute ? "در حال رسم مسیر..." : "شروع مسیریابی با $displayName",
                          ),
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