// lib/navigation/widgets/routing_card.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'transport_mode_selector.dart';
import 'search_field.dart';

class RoutingTopPanel extends StatefulWidget {
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
  final VoidCallback onClose;

  const RoutingTopPanel({
    Key? key,
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
    required this.onClose,
  }) : super(key: key);

  @override
  State<RoutingTopPanel> createState() => _RoutingTopPanelState();
}

class _RoutingTopPanelState extends State<RoutingTopPanel> {
  late String _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.selectedMode;
  }

  @override
  void didUpdateWidget(RoutingTopPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMode != widget.selectedMode) {
      _currentMode = widget.selectedMode;
    }
  }

  void _updateMode(String mode) {
    setState(() => _currentMode = mode);
    widget.onModeChanged(mode); // آپدیت state اصلی
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
                BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const Spacer(),
                      IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("مسیریابی هوشمند", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  SearchField(
                    controller: widget.originController,
                    hintText: "مبدا",
                    isLoading: false,
                    onClear: widget.originLatLng != null ? widget.onClearOrigin : null,
                    fillColor: Colors.grey[100]!,
                    prefixIcon: Icons.my_location,
                    prefixIconColor: Colors.blue,
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 12),

                  SearchField(
                    controller: widget.destinationController,
                    hintText: "مقصد",
                    isLoading: false,
                    onClear: widget.selectedDestination != null ? widget.onClearDestination : null,
                    fillColor: Colors.grey[100]!,
                    prefixIcon: Icons.location_on,
                    prefixIconColor: Colors.red,
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: IconButton(
                      onPressed: widget.selectedDestination != null ? widget.onSwap : null,
                      icon: Icon(Icons.swap_vert, size: 36, color: widget.selectedDestination != null ? Colors.blue : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // اینجا از _currentMode استفاده می‌کنیم → همیشه آپدیت میشه
                  TransportModeSelector(
                    selectedMode: _currentMode,
                    onModeSelected: _updateMode,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.selectedDestination == null || widget.isLoadingRoute ? null : widget.onStartRouting,
                      icon: widget.isLoadingRoute
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.directions),
                      label: Text(widget.isLoadingRoute ? "در حال رسم مسیر..." : "شروع مسیریابی با ${widget.modeName}"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
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