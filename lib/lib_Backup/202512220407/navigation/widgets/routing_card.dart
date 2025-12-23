// lib/navigation/widgets/routing_card.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'transport_mode_selector.dart';
import 'search_field.dart';

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
  final Function(int) onPickFromMap; // ← این رو داشتی، نگه داشتم
  final Function(List<TextEditingController>) onProvideControllers;
  final List<TextEditingController> initialControllers;
  final Function(String profile) onProfileChanged; // ← جدید

  const RoutingTopPanel({
    Key? key,
    required this.originController,
    required this.destinationController,
    this.selectedDestination,
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
    required this.onPickFromMap, // ← اضافه شد به constructor
    required this.onProvideControllers,
    required this.initialControllers,
    required this.onProfileChanged,
  }) : super(key: key);

  @override
  State<RoutingTopPanel> createState() => _RoutingTopPanelState();
}

class _RoutingTopPanelState extends State<RoutingTopPanel> {
  List<TextEditingController> destinationControllers = [];
  String _selectedProfile = "fastest"; // پیش‌فرض

  int _activeDestinationIndex = 0;

  @override
@override
void initState() {
  super.initState();
  // به جای add کردن فقط اولی، از لیست کامل استفاده کن
  destinationControllers = widget.initialControllers;

  // اگر لیست خالی بود، حداقل اولی رو اضافه کن (برای اولین بار)
  if (destinationControllers.isEmpty) {
    destinationControllers.add(widget.destinationController);
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    widget.onProvideControllers(destinationControllers);
  });
}
  List<Widget> _buildDestinationFields() {
    List<Widget> fields = [];

    for (int i = 0; i < destinationControllers.length; i++) {
      final controller = destinationControllers[i];
      final isFirst = i == 0;
      final hint = isFirst ? "مقصد" : "نقطه بعدی ${i}";

      fields.add(
        TextField(
          controller: controller,
          readOnly: true,
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
                // ۱. مینیمایز کردن پنل
                //widget.onMinimize();
                // ۲. ذخیره ایندکس فیلد فعال
                _activeDestinationIndex = i;
                // ۳. اطلاع دادن به صفحه اصلی برای فعال کردن حالت انتخاب از نقشه
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
                    } else {
                      widget.onClearDestination();
                    }
                  },
                ),
                if (i == destinationControllers.length - 1)
                  // 👈 فقط اگر کمتر از ۵ تا بود، دکمه + رو نشون بده
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
          onTap: () {
            // بعداً برای جستجوی متنی
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: widget.onMinimize,
                            icon: const Icon(Icons.minimize, color: Colors.grey, size: 28),
                            tooltip: "مینیمایز",
                          ),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                            tooltip: "بستن",
                          ),
                        ],
                      ),
                      const Opacity(opacity: 0, child: Icon(Icons.close)),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Text("مسیریابی هوشمند", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  TextField(
                    controller: widget.originController,
                    onTap: () {
                      if (widget.originController.text == "موقعیت فعلی") {
                        widget.originController.clear();
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      prefixIcon: GestureDetector(
                        onTap: () async {
                          try {
                            Position position = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high,
                            );
                            final lat = position.latitude.toStringAsFixed(6);
                            final lng = position.longitude.toStringAsFixed(6);
                            final coords = "$lat, $lng";
                            widget.originController.text = coords;
                            widget.onClearOrigin();
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
                          child: Icon(Icons.my_location, color: Colors.blue, size: 20),
                        ),
                      ),
                      suffixIcon: widget.originLatLng != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: widget.onClearOrigin,
                            )
                          : null,
                    ),
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 5),

                  ..._buildDestinationFields(),

                  const SizedBox(height: 10),

                  Center(
                    child: IconButton(
                      onPressed: widget.selectedDestination != null ? widget.onSwap : null,
                      icon: Icon(
                        Icons.swap_vert,
                        size: 30,
                        color: widget.selectedDestination != null ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),

                  ValueListenableBuilder<String>(
                    valueListenable: widget.modeNotifier,
                    builder: (context, mode, _) {
                      return TransportModeSelector(
                        selectedMode: mode,
                        onModeSelected: (newMode) {
                          widget.modeNotifier.value = newMode;
                          widget.onModeChanged(newMode);
                          setState(() {
                            _selectedProfile = "fastest"; // ریست پروفایل وقتی mode عوض می‌شه
                            widget.onProfileChanged(_selectedProfile); // منتقل به صفحه اصلی
                          });
                        },

                        onProfileSelected: (newProfile) {
                          setState(() {
                            _selectedProfile = newProfile;
                          });
                          widget.onProfileChanged(newProfile); // منتقل به صفحه اصلی
                        },

                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  ValueListenableBuilder<String>(
                    valueListenable: widget.modeNotifier,
                    builder: (context, currentMode, _) {
                      final String displayName = _getDisplayName(currentMode);
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.selectedDestination == null || widget.isLoadingRoute
                              ? null
                              : () {
                                  widget.onStartRouting();
                                  widget.onMinimize();
                                },
                          icon: widget.isLoadingRoute
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.directions),
                          label: Text(
                            widget.isLoadingRoute ? "در حال رسم مسیر..." : "شروع مسیریابی با $displayName",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 10),
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