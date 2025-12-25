// lib/navigation/widgets/search_sheet.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import 'history_manager.dart';
import 'share.dart';
import 'advanced_search.dart';

class SearchSheet extends StatefulWidget {
  final TextEditingController searchController;
  final bool isSearching;
  final VoidCallback onClearSearch;
  final VoidCallback onPickFromMap;
  final Future<void> Function({bool force}) onUseCurrentLocation;
  final Future<void> Function(String) onSearchPoint;
  final void Function({String? autoSearch}) onOpenAdvancedSearch;
  final VoidCallback onOpenRoutingPanel;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final LatLng? selectedDestination; // اختیاری شد
  final String selectedMode; // اختیاری شد با پیش‌فرض
  final ValueNotifier<String> modeNotifier; // اختیاری شد
  final TextEditingController? destinationController; // اختیاری شد
  final VoidCallback onShowSnackBar; // اختیاری شد
  final SearchHistoryManager historyManager;

  const SearchSheet({
    Key? key,
    required this.searchController,
    required this.isSearching,
    required this.onClearSearch,
    required this.onPickFromMap,
    required this.onUseCurrentLocation,
    required this.onSearchPoint,
    required this.onOpenAdvancedSearch,
    required this.onOpenRoutingPanel,
    required this.onMinimize,
    required this.onClose,
    this.selectedDestination,
    this.selectedMode = "auto",
    required this.modeNotifier,
    this.destinationController,
    required this.onShowSnackBar,
    required this.historyManager,
  }) : super(key: key);

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  late List<String> history;

  @override
  void initState() {
    super.initState();
    history = widget.historyManager.history;
  }

  Widget _buildIconButton(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: _AdvancedIconButton(
        icon: icon,
        color: color,
        tooltip: tooltip,
        onTap: onTap,
      ),
    );
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
              borderRadius: BorderRadius.circular(20),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // دکمه‌های مینیمایز و بستن
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.grey, size: 28),
                              tooltip: "مینیمایز",
                              onPressed: widget.onMinimize,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                              tooltip: "بستن",
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                        const SizedBox(width: 60),
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
                    const SizedBox(height: 5),
                    const Text(
                      "جستجو و مسیریابی",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),

                    // فیلد جستجو
                    TextField(
                      controller: widget.searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: "نام مکان، آدرس یا نقطه معروف...",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.my_location, color: Colors.blue),
                              tooltip: "موقعیت فعلی من",
                              onPressed: () async {
                                await widget.onUseCurrentLocation(force: true);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.location_on_outlined, color: Colors.red),
                              tooltip: "انتخاب از روی نقشه",
                              onPressed: widget.onPickFromMap,
                            ),
                            if (widget.isSearching)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: widget.onClearSearch,
                              ),
                          ],
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (query) {
                        if (query.trim().isNotEmpty) {
                          widget.onSearchPoint(query);
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    // تاریخچه
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("تاریخچه جستجو", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextButton(
                                onPressed: () async {
                                  await widget.historyManager.clearHistory();
                                  setState(() => history = []);
                                },
                                child: const Text("پاک کردن همه", style: TextStyle(color: Colors.red, fontSize: 13)),
                              ),
                            ],
                          ),
                          const Divider(height: 1),
                          ...history.take(4).map((query) => _HistoryTile(
                                query: query,
                                onTap: () {
                                  widget.searchController.text = query;
                                  widget.onSearchPoint(query);
                                  Navigator.of(context).pop();
                                },
                                onRemove: () async {
                                  await widget.historyManager.removeHistoryItem(query);
                                  setState(() => history = widget.historyManager.history);
                                },
                              )),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    SizedBox(
                      height: 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildIconButton(Icons.coffee, Colors.brown.shade700, "کافه", () => widget.onOpenAdvancedSearch(autoSearch: "cafe")),
                          _buildIconButton(Icons.restaurant_menu, Colors.orange.shade700, "رستوران", () => widget.onOpenAdvancedSearch(autoSearch: "restaurant")),
                          _buildIconButton(Icons.local_gas_station, Colors.red.shade600, "پمپ بنزین", () => widget.onOpenAdvancedSearch(autoSearch: "fuel")),
                          _buildIconButton(Icons.medication, Colors.teal.shade700, "داروخانه", () => widget.onOpenAdvancedSearch(autoSearch: "pharmacy")),
                          _buildIconButton(Icons.local_hospital, Colors.red.shade800, "بیمارستان", () => widget.onOpenAdvancedSearch(autoSearch: "hospital")),
                          _buildIconButton(Icons.directions_bus, Colors.purple.shade700, "ایستگاه اتوبوس", () => widget.onOpenAdvancedSearch(autoSearch: "bus_stop")),
                          _buildIconButton(Icons.store_mall_directory, Colors.blue.shade700, "سوپرمارکت", () => widget.onOpenAdvancedSearch(autoSearch: "supermarket")),
                          _buildIconButton(Icons.park, Colors.green.shade700, "پارک", () => widget.onOpenAdvancedSearch(autoSearch: "park")),
                          _buildIconButton(Icons.account_balance_outlined, Colors.indigo.shade700, "بانک", () => widget.onOpenAdvancedSearch(autoSearch: "bank")),
                          _buildIconButton(FontAwesomeIcons.squareParking, Colors.green.shade800, "پارکینگ رایگان", () => widget.onOpenAdvancedSearch(autoSearch: "free_parking")),
                          _buildIconButton(Icons.school, Colors.orange.shade800, "مدرسه و دانشگاه", () => widget.onOpenAdvancedSearch(autoSearch: "school")),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _IconActionButton(
                          icon: Icons.directions,
                          color: Colors.blue.shade600,
                          onTap: () async {
                            final q = widget.searchController.text.trim();
                            if (q.isEmpty) return;
                            await widget.onSearchPoint(q);
                            widget.destinationController?.text = q;
                            widget.modeNotifier.value = widget.selectedMode;
                            Navigator.of(context).pop();
                            widget.onOpenRoutingPanel();
                          },
                        ),
                        _IconActionButton(
                          icon: Icons.search_rounded,
                          color: Colors.green.shade600,
                          onTap: () {
                            final q = widget.searchController.text.trim();
                            if (q.isNotEmpty) {
                              widget.onSearchPoint(q);
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                        _IconActionButton(
                          icon: Icons.share,
                          color: Colors.purple.shade600,
                          onTap: () {
                            if (widget.selectedDestination == null) {
                              widget.onShowSnackBar();
                              return;
                            }
                            ShareLocationButton.shareLocationStatic(
                              location: widget.selectedDestination!,
                              placeName: widget.searchController.text.trim().isNotEmpty ? widget.searchController.text.trim() : null,
                              message: "اینجا را پیدا کردم!",
                            );
                          },
                        ),
                        _IconActionButton(
                          icon: Icons.smart_toy,
                          color: Colors.deepPurple.shade600,
                          onTap: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.smart_toy, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text("جستجو با هوش مصنوعی به‌زودی فعال می‌شود!"),
                                  ],
                                ),
                                backgroundColor: Colors.deepPurple,
                                duration: Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ویجت‌های کمکی
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}

class _AdvancedIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _AdvancedIconButton({required this.icon, required this.color, required this.onTap, required this.tooltip, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 56,
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: color.withOpacity(0.7), width: 2.2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Icon(icon, color: color, size: 36),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _HistoryTile({required this.query, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            const Icon(Icons.history, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              tooltip: "حذف از تاریخچه",
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}