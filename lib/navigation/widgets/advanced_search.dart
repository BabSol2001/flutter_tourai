// lib/widgets/advanced_search.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart' show Distance;

const String baseUrl = "http://192.168.0.105:8000"; // عوضش کن!

class _AdvancedIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _AdvancedIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 56,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: color.withOpacity(0.7), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 46),
          ),
        ),
      ),
    );
  }
}

class AdvancedSearchSheet extends StatefulWidget {
  final LatLng centerLocation;
  final VoidCallback onClose;

  const AdvancedSearchSheet({
    Key? key,
    required this.centerLocation,
    required this.onClose,
  }) : super(key: key);

  @override
  State<AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<AdvancedSearchSheet> {
  bool _isLoading = false;
  bool _sortByDistance = true; // پیش‌فرض: مرتب‌شده
  List<Map<String, dynamic>> _results = [];
  final Distance distance = const Distance();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.7,
      maxChildSize: 0.98,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: CustomScrollView(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // هندل + عنوان
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    width: 60,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Text(
                      "جستجو در اطراف من",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // گرید آیکون‌ها
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 28,
                  crossAxisSpacing: 22,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildListDelegate([
                  _AdvancedIconButton(icon: Icons.coffee,               color: Colors.brown.shade700,   tooltip: "کافه",                   onTap: () => _search('amenity=cafe', "کافه")),
                  _AdvancedIconButton(icon: Icons.restaurant_menu,       color: Colors.orange.shade700,  tooltip: "رستوران",                onTap: () => _search('amenity=restaurant', "رستوران")),
                  _AdvancedIconButton(icon: Icons.local_gas_station,     color: Colors.red.shade600,     tooltip: "پمپ بنزین",              onTap: () => _search('amenity=fuel', "پمپ بنزین")),
                  _AdvancedIconButton(icon: Icons.medication,            color: Colors.teal.shade700,    tooltip: "داروخانه",               onTap: () => _search('amenity=pharmacy', "داروخانه")),

                  _AdvancedIconButton(icon: Icons.ev_station,            color: Colors.cyan.shade700,    tooltip: "ایستگاه شارژ برقی",      onTap: () => _search('amenity=charging_station', "شارژ برقی")),
                  _AdvancedIconButton(icon: Icons.electric_bike,         color: Colors.lime.shade700,    tooltip: "کرایه دوچرخه",          onTap: () => _search('amenity=bicycle_rental', "کرایه دوچرخه")),
                  _AdvancedIconButton(icon: Icons.local_hospital,        color: Colors.red.shade800,     tooltip: "بیمارستان",              onTap: () => _search('amenity=hospital', "بیمارستان")),
                  _AdvancedIconButton(icon: Icons.directions_bus,        color: Colors.purple.shade700,  tooltip: "ایستگاه اتوبوس",         onTap: () => _searchBusStops()),

                  _AdvancedIconButton(icon: Icons.train,                 color: Colors.deepPurple.shade700, tooltip: "ایستگاه مترو",          onTap: () => _search('railway=station AND (station=subway OR railway=subway)', "مترو")),
                  _AdvancedIconButton(icon: Icons.store_mall_directory,  color: Colors.blue.shade700,    tooltip: " محلیسوپرمارکت",             onTap: () => _search('shop=supermarket|shop=convenience', "سوپرمارکت")),
                  _AdvancedIconButton(icon: Icons.park,                  color: Colors.green.shade700,   tooltip: "پارک",                   onTap: () => _search('leisure=park', "پارک")),
                  _AdvancedIconButton(icon: Icons.mosque,                color: Colors.teal.shade800,    tooltip: "مسجد",                   onTap: () => _search('amenity=place_of_worship\nreligion=muslim', "مسجد")),

                  _AdvancedIconButton(icon: Icons.church,                color: Colors.pink.shade700,    tooltip: "کلیسا",                  onTap: () => _search('amenity=place_of_worship\nreligion=christian', "کلیسا")),

                  _AdvancedIconButton(icon: Icons.history_edu,           color: Colors.amber.shade800,   tooltip: "جاذبه تاریخی",           onTap: () => _search('historic=yes OR historic=* OR tourism=museum', "جاذبه تاریخی")),
                  _AdvancedIconButton(icon: Icons.account_balance,       color: Colors.indigo.shade700,  tooltip: "بانک و خودپرداز",        onTap: () => _search('amenity=bank|amenity=atm', "بانک/ATM")),
                  _AdvancedIconButton(icon: Icons.local_parking,         color: Colors.grey.shade700,    tooltip: "پارکینگ عمومی",         onTap: () => _search('amenity=parking', "پارکینگ")),
                  _AdvancedIconButton(
                    icon: FontAwesomeIcons.squareParking,
                    color: Colors.green.shade800,
                    tooltip: "پارکینگ رایگان کنار خیابان",
                    onTap: () => _search(
                      '(highway=street_parking OR (amenity=parking AND parking=street_side)) AND fee=no',
                      "پارکینگ رایگان کنار خیابان",
                    ),
                  ),

                  // فروشگاه زنجیره‌ای بزرگ
                  _AdvancedIconButton(
                    icon: Icons.storefront_outlined,
                    color: const Color(0xFFE64A19),
                    tooltip: "فروشگاه زنجیره‌ای بزرگ (جهانی)",
                    onTap: _searchChainStoresFromBackend,
                  ),
                ]),
              ),
            ),

            // لودینگ
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 4)),
                ),
              ),

            // نتایج + دکمه مرتب‌سازی
            if (_results.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // دکمه مرتب‌سازی + تعداد نتایج
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_results.length} نتیجه پیدا شد",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _sortByDistance = !_sortByDistance;
                                _sortResultsByDistance();
                              });
                            },
                            icon: Icon(
                              _sortByDistance ? Icons.location_on : Icons.location_off,
                              size: 15,
                              color: _sortByDistance ? Colors.red.shade600 : Colors.grey,
                            ),
                            label: Text(
                              _sortByDistance ? " بر اساس فاصله" : "ترتیب اولیه",
                              style: TextStyle(
                                fontSize: 13,
                                color: _sortByDistance ? Colors.red.shade600 : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // لیست نتایج
                      ..._results.map((place) {
                        final name = place['tags']?['name:fa'] ?? place['tags']?['name'] ?? "بدون نام";
                        final lat = place['lat'] ?? place['center']?['lat'];
                        final lon = place['lon'] ?? place['center']?['lon'];
                        final dist = lat != null && lon != null
                            ? distance(widget.centerLocation, LatLng(lat, lon)).toInt()
                            : 0;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(name, style: const TextStyle(fontSize: 15)),
                          subtitle: Text("$dist متر"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: widget.onClose,
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  void _search(String query, String title) => _searchCategory(query, title);

  // همه جستجوها بعد از پر کردن نتایج، این خط رو صدا می‌زنن
  void _sortResultsByDistance() {
    if (!_sortByDistance) return;

    final userPos = widget.centerLocation;

    _results.sort((a, b) {
      double latA = a['lat'] ?? a['center']?['lat'] ?? 0.0;
      double lonA = a['lon'] ?? a['center']?['lon'] ?? 0.0;
      double latB = b['lat'] ?? b['center']?['lat'] ?? 0.0;
      double lonB = b['lon'] ?? b['center']?['lon'] ?? 0.0;

      double distA = distance(userPos, LatLng(latA, lonA));
      double distB = distance(userPos, LatLng(latB, lonB));

      return distA.compareTo(distB);
    });

    setState(() {});
  }

  Future<void> _searchCategory(String query, String title) async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:25];
    (
      node[$query](around:3500,$lat,$lon);
      way[$query](around:3500,$lat,$lon);
      relation[$query](around:3500,$lat,$lon);
    );
    out center tags;
    """;

    try {
      final uri = Uri.parse("https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _results = List<Map<String, dynamic>>.from(data['elements']);
          _sortResultsByDistance(); // مرتب کن
        });
      }
    } catch (e) {
      // ساکت
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchBusStops() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:40];
    (
      node["highway"="bus_stop"](around:5000,$lat,$lon);
      node["amenity"="bus_station"](around:5000,$lat,$lon);
      node["public_transport"="platform"]["bus"="yes"](around:5000,$lat,$lon);
      node["highway"="bus_stop"]["shelter"="yes"](around:5000,$lat,$lon);
    );
    out center tags;
    """;

    try {
      final uri = Uri.parse("https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _results = List<Map<String, dynamic>>.from(data['elements']);
          _sortResultsByDistance(); // مرتب کن
        });
      }
    } catch (e) {
      // ساکت
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // تابع مخصوص سوپرمارکت معمولی — بدون مشکل پارسینگ
  Future<void> _searchSupermarket() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:40];
    (
      node["shop"="supermarket"](around:5000,$lat,$lon);
      node["shop"="convenience"](around:5000,$lat,$lon);
      way["shop"="supermarket"](around:5000,$lat,$lon);
      way["shop"="convenience"](around:5000,$lat,$lon);
    );
    out center tags;
    """;

    try {
      final uri = Uri.parse("https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _results = List<Map<String, dynamic>>.from(data['elements']);
          _sortResultsByDistance(); // مرتب هم میشه
        });
      }
    } catch (e) {
      print("خطا در سوپرمارکت: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchChainStoresFromBackend() async {
    setState(() {
      _isLoading = true;
      _results.clear();
      _sortResultsByDistance();
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;
    final url = '$baseUrl/api/v1/osm/search/chain-stores/?lat=$lat&lon=$lon&radius=5000';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['results'];

        setState(() {
          _results = items.map((e) => {
                "tags": {"name": e["name"], "name:fa": e["name"]},
                "lat": e["lat"],
                "lon": e["lon"],
              }).toList();
          _sortResultsByDistance(); // مرتب کن
        });
      } else {
        _fallbackChainSearch();
      }
    } catch (e) {
      _fallbackChainSearch();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _fallbackChainSearch() {
    _searchCategory(
      'shop=supermarket AND (name~"رفاه|شهروند|کوروش|جانبو|هایپراستار|افق کوروش|لولو|کارفور")',
      "فروشگاه زنجیره‌ای (آفلاین)",
    );
  }
}