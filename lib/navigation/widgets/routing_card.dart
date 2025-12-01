import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class RoutingCardContent extends StatelessWidget {
  final ScrollController scrollController;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final LatLng? selectedDestination;
  final LatLng? originLatLng;
  final bool isLoadingRoute;
  final String selectedMode;
  final Function(String) onModeChanged;
  final VoidCallback onSwap;
  final VoidCallback onClearDestination;
  final VoidCallback onClearOrigin;
  final VoidCallback onStartRouting;
  final String modeName;

  const RoutingCardContent({
    Key? key,
    required this.scrollController,
    required this.originController,
    required this.destinationController,
    required this.selectedDestination,
    required this.originLatLng,
    required this.isLoadingRoute,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onSwap,
    required this.onClearDestination,
    required this.onClearOrigin,
    required this.onStartRouting,
    required this.modeName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // عنوان
        const Text(
          "مسیریابی هوشمند",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // مبدا
        TextField(
          controller: originController,
          readOnly: true,
          decoration: InputDecoration(
            hintText: "مبدا",
            prefixIcon: const Icon(Icons.my_location, color: Colors.blue),
            suffixIcon: originLatLng != null
                ? IconButton(icon: const Icon(Icons.clear), onPressed: onClearOrigin)
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),

        // مقصد
        TextField(
          controller: destinationController,
          readOnly: true,
          decoration: InputDecoration(
            hintText: "مقصد را انتخاب کنید",
            prefixIcon: const Icon(Icons.location_on, color: Colors.red),
            suffixIcon: selectedDestination != null
                ? IconButton(icon: const Icon(Icons.clear), onPressed: onClearDestination)
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),

        // دکمه جابجایی
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: selectedDestination != null ? onSwap : null,
              icon: const Icon(Icons.swap_vert, size: 32),
              color: selectedDestination != null ? Colors.blue : Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // انتخاب نوع وسیله
        const Text("نوع وسیله نقلیه:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            "auto", "motorcycle", "truck", "bicycle", "pedestrian"
          ].map((mode) {
            final isSelected = selectedMode == mode;
            final name = {
              "auto": "ماشین",
              "motorcycle": "موتور",
              "truck": "کامیون",
              "bicycle": "دوچرخه",
              "pedestrian": "پیاده",
            }[mode]!;
            final icon = {
              "auto": Icons.directions_car,
              "motorcycle": Icons.motorcycle,
              "truck": Icons.local_shipping,
              "bicycle": Icons.directions_bike,
              "pedestrian": Icons.directions_walk,
            }[mode]!;

            return GestureDetector(
              onTap: () => onModeChanged(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: isSelected ? Colors.white : Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // دکمه شروع مسیریابی
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: selectedDestination == null ? null : isLoadingRoute ? null : onStartRouting,
            icon: isLoadingRoute
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.directions),
            label: Text(isLoadingRoute ? "در حال رسم مسیر..." : "شروع مسیریابی با $modeName"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}