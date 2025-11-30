import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class RoutingCardContent extends StatelessWidget {
  final ScrollController scrollController;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final LatLng? selectedDestination;
  final LatLng? originLatLng;
  final bool isSearchingOrigin;
  final bool isSearchingDestination;
  final bool isLoadingRoute;
  final String selectedMode;
  final Function(String) onModeChanged;
  final VoidCallback onSwap;
  final VoidCallback onClearDestination;
  final VoidCallback onClearOrigin;
  final VoidCallback onStartRouting;
  final String modeName;

  const RoutingCardContent({
    required this.scrollController,
    super.key,
    required this.originController,
    required this.destinationController,
    required this.selectedDestination,
    required this.originLatLng,
    required this.isSearchingOrigin,
    required this.isSearchingDestination,
    required this.isLoadingRoute,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onSwap,
    required this.onClearDestination,
    required this.onClearOrigin,
    required this.onStartRouting,
    required this.modeName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(), // این خط باعث میشه وقتی کیبورد بازه، منو کاملاً بالا بیاد
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان
          const Row(
            children: [
              Icon(Icons.directions, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text("مسیریابی هوشمند", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),

          // مبدا
          TextField(
            controller: originController,
            decoration: InputDecoration(
              hintText: "از کجا؟ (موقعیت فعلی)",
              prefixIcon: const Icon(Icons.my_location, color: Colors.green),
              suffixIcon: isSearchingOrigin
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : (originLatLng != null
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: onClearOrigin)
                      : null),
              filled: true,
              fillColor: Colors.green[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // مقصد
          TextField(
            controller: destinationController,
            decoration: InputDecoration(
              hintText: "کجا می‌خوای بری؟",
              prefixIcon: const Icon(Icons.location_on, color: Colors.red),
              suffixIcon: isSearchingDestination
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : (selectedDestination != null
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: onClearDestination)
                      : null),
              filled: true,
              fillColor: Colors.red[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 16),
          // دکمه سواپ
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onSwap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                child: const Icon(Icons.swap_vert, color: Colors.white, size: 28),
              ),
            ),
          ),

          const SizedBox(height: 20),
          // انتخاب وسیله نقلیه
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              {"mode": "auto", "icon": Icons.directions_car},
              {"mode": "motorcycle", "icon": Icons.motorcycle},
              {"mode": "truck", "icon": Icons.local_shipping},
              {"mode": "bicycle", "icon": Icons.directions_bike},
              {"mode": "pedestrian", "icon": Icons.directions_walk},
            ].map((m) {
              final bool isSelected = selectedMode == m["mode"];
              return GestureDetector(
                onTap: () => onModeChanged(m["mode"] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[200],
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Icon(
                    m["icon"] as IconData,
                    color: isSelected ? Colors.white : Colors.black87,
                    size: 30,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 30),
          // دکمه شروع مسیریابی
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: isLoadingRoute || selectedDestination == null ? null : onStartRouting,
              icon: isLoadingRoute
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.navigation),
              label: Text(
                isLoadingRoute ? "در حال رسم مسیر..." : "شروع مسیریابی با $modeName",
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 8,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}