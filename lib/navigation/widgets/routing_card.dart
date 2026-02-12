// lib/navigation/widgets/routing_card.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert';

import 'transport_mode_selector.dart';

class RoutingTopPanel extends StatefulWidget {
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
  final Function(int) onPickFromMap; // حالا index = -1 یعنی مبدا
  final Function(List<TextEditingController>) onProvideControllers;
  final List<TextEditingController> initialControllers;
  final Function(String) onProfileChanged;
  final void Function(int index, LatLng location) onDestinationGeocoded;
  final Function(LatLng) onOriginGeocoded; // جدید: وقتی مبدا geocode شد

  const RoutingTopPanel({
    super.key,
    required this.originController,
    required this.destinationController,
    this.selectedDestination,
    this.originLatLng,
    required this.isLoadingRoute,
    required this.modeNotifier,
    required this.onModeChanged,
    required this.onSwap,
    required this.onClearDestination,
    required this.onClearOrigin,
    required this.onStartRouting,
    required this.onClose,
    required this.onMinimize,
    required this.onPickFromMap,
    required this.onProvideControllers,
    required this.initialControllers,
    required this.onProfileChanged,
    required this.onDestinationGeocoded,
    required this.onOriginGeocoded,
  });

  @override
  State<RoutingTopPanel> createState() => _RoutingTopPanelState();
}

class _RoutingTopPanelState extends State<RoutingTopPanel> {
  List<TextEditingController> destinationControllers = [];
  String _selectedProfile = "fastest";
  int _activeDestinationIndex = 0;

  @override
  void initState() {
    super.initState();
    destinationControllers = widget.initialControllers;

    if (destinationControllers.isEmpty) {
      destinationControllers.add(widget.destinationController);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onProvideControllers(destinationControllers);
    });
  }

  Future<void> _geocodeAndSet(String query, int index, TextEditingController controller) async {
    if (query.trim().isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=ir',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'TourAI/1.0'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final displayName = data[0]['display_name'];

          setState(() {
            controller.text = displayName;
          });

          if (index == -1) {
            // مبدا
            widget.onOriginGeocoded(LatLng(lat, lon));
          } else {
            // مقصد
            widget.onDestinationGeocoded(index, LatLng(lat, lon));
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("مکان پیدا شد"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("مکانی پیدا نشد"), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطای اینترنت یا سرور"), backgroundColor: Colors.red),
      );
    }
  }

  List<Widget> _buildDestinationFields() {
    List<Widget> fields = [];

    for (int i = 0; i < destinationControllers.length; i++) {
      final controller = destinationControllers[i];
      final hint = i == 0 ? "مقصد" : "نقطه بعدی ${i + 1}";

      fields.add(
        TextField(
          controller: controller,
          readOnly: false,
          textInputAction: TextInputAction.search,
          onTap: () {
            SystemChannels.textInput.invokeMethod('TextInput.show');
          },
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            prefixIcon: GestureDetector(
              onTap: () {
                _activeDestinationIndex = i;
                widget.onPickFromMap(i);
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.location_on, color: Colors.red, size: 26),
              ),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    if (destinationControllers.length > 1) {
                      setState(() {
                        destinationControllers.removeAt(i);
                      });
                      widget.onProvideControllers(destinationControllers);
                    } else {
                      widget.onClearDestination();
                    }
                  },
                ),
                if (i == destinationControllers.length - 1 && destinationControllers.length < 5)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                    tooltip: "افزودن نقطه بعدی",
                    onPressed: () {
                      setState(() {
                        destinationControllers = [
                          ...destinationControllers,
                          TextEditingController(),
                        ];
                      });
                      widget.onProvideControllers(destinationControllers);
                    },
                  ),
              ],
            ),
          ),
          onSubmitted: (query) {
            _geocodeAndSet(query, i, controller);
          },
        ),
      );

      if (i < destinationControllers.length - 1) {
        fields.add(const SizedBox(height: 12));
      }
    }

    return fields;
  }

  String _getDisplayName(String mode) {
    switch (mode) {
      case "auto": return "ماشین";
      case "motorcycle": return "موتورسیکلت";
      case "truck": return "کامیون";
      case "bicycle": return "دوچرخه";
      case "pedestrian": return "پیاده";
      default: return "ماشین";
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.grey, size: 28)),
                              IconButton(onPressed: widget.onMinimize, icon: const Icon(Icons.minimize, color: Colors.grey, size: 28)),
                            ],
                          ),
                          const Opacity(opacity: 0, child: Icon(Icons.close)),
                        ],
                      ),

                      const Center(
                        child: Text("مسیریابی هوشمند", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),

                      // مبدا
                      TextField(
                        controller: widget.originController,
                        readOnly: false,
                        textInputAction: TextInputAction.search,
                        onTap: () {
                          if (widget.originController.text == "موقعیت فعلی") {
                            widget.originController.clear();
                          }
                          SystemChannels.textInput.invokeMethod('TextInput.show');
                        },
                        onSubmitted: (query) {
                          _geocodeAndSet(query, -1, widget.originController);
                        },
                        decoration: InputDecoration(
                          hintText: "مبدا (آدرس یا مختصات)",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          prefixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // انتخاب مبدا از نقشه
                              GestureDetector(
                                onTap: () => widget.onPickFromMap(-1),
                                child: const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Icon(Icons.location_on, color: Colors.green, size: 26),
                                ),
                              ),
                              // موقعیت فعلی
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                                    final lat = position.latitude.toStringAsFixed(6);
                                    final lng = position.longitude.toStringAsFixed(6);
                                    widget.originController.text = "$lat, $lng";
                                    widget.onOriginGeocoded(LatLng(position.latitude, position.longitude));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("مبدا: موقعیت فعلی شما"), backgroundColor: Colors.green),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("موقعیت در دسترس نیست"), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Icon(Icons.my_location, color: Colors.blue, size: 24),
                                ),
                              ),
                            ],
                          ),
                          suffixIcon: widget.originController.text.isNotEmpty && widget.originController.text != "موقعیت فعلی"
                              ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                                  widget.originController.text = "موقعیت فعلی";
                                  widget.onClearOrigin();
                                })
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ..._buildDestinationFields(),

                      const SizedBox(height: 10),

                      Center(
                        child: IconButton(
                          onPressed: widget.selectedDestination != null ? widget.onSwap : null,
                          icon: Icon(Icons.swap_vert, size: 30, color: widget.selectedDestination != null ? Colors.blue : Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 10),

                      ValueListenableBuilder<String>(
                        valueListenable: widget.modeNotifier,
                        builder: (context, mode, _) {
                          return TransportModeSelector(
                            selectedMode: mode,
                            onModeSelected: (newMode) {
                              widget.modeNotifier.value = newMode;
                              widget.onModeChanged(newMode);
                              setState(() {
                                _selectedProfile = "fastest";
                                widget.onProfileChanged(_selectedProfile);
                              });
                            },
                            onProfileSelected: (newProfile) {
                              setState(() => _selectedProfile = newProfile);
                              widget.onProfileChanged(newProfile);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      ValueListenableBuilder<String>(
                        valueListenable: widget.modeNotifier,
                        builder: (context, currentMode, _) {
                          final String displayName = _getDisplayName(currentMode);
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: widget.isLoadingRoute ? null : () {
                                widget.onStartRouting();
                                widget.onMinimize();
                              },
                              icon: widget.isLoadingRoute
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.directions),
                              label: Text(widget.isLoadingRoute ? "در حال رسم مسیر..." : "شروع مسیریابی با $displayName"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}