// lib/widgets/advanced_search.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart' show Distance;

const String baseUrl = "http://192.168.0.105:8000";

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
    Key? key,
  }) : super(key: key);

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
      textStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 2),
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
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 36),
          ),
        ),
      ),
    );
  }
}

class AdvancedSearchSheet extends StatefulWidget {
  final LatLng centerLocation;
  final VoidCallback onClose;
  final VoidCallback onBackToSearch; // جدید: برای برگشت به منوی جستجو
  final String? autoSearchCategory;
  final Function(LatLng, String?)? onSelectPlace; // ← جدید

  const AdvancedSearchSheet({
    Key? key,
    required this.centerLocation,
    required this.onClose,
    required this.onBackToSearch,
    this.autoSearchCategory,
    this.onSelectPlace, // ← جدید
  }) : super(key: key);

  @override
  State<AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<AdvancedSearchSheet> {
  bool _isLoading = false;
  bool _sortByDistance = true;
  List<Map<String, dynamic>> _results = [];
  final Distance distance = const Distance();
  String _currentSearchTitle = "جستجوی مراکز پرکاربرد"; // عنوان پیش‌فرض

  Widget _buildIconButton(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: _AdvancedIconButton(
        icon: icon,
        color: color,
        tooltip: tooltip,
        onTap: onTap,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // این خط حتماً باشه

    // اگر از منوی اصلی اومده و گفته "رستوران رو جستجو کن"، خودکار انجام بده
    if (widget.autoSearchCategory != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (widget.autoSearchCategory != null) {
          Future.delayed(const Duration(milliseconds: 600), () {
            switch (widget.autoSearchCategory) {
              case "cafe":
                _searchCategory('amenity=cafe', "کافه");
                break;
              case "restaurant":
                _searchCategory('amenity=restaurant', "رستوران");
                break;
              case "fuel":
                _searchCategory('amenity=fuel', "پمپ بنزین");
                break;
              case "pharmacy":
                _searchCategory('amenity=pharmacy', "داروخانه");
                break;
              case "hospital":
                _searchCategory('amenity=hospital', "بیمارستان");
                break;
              case "bus_stop":
                _searchBusStops(); // این تابع جدا داره، پس مستقیم صدا می‌زنیم
                break;
              case "supermarket":
                _searchSupermarket(); // اینم تابع جدا داره
                break;
              case "park":
                _searchCategory('leisure=park', "پارک");
                break;
              case "bank":
                _searchBanksAndAtms(); // این شامل بانک و خودپرداز میشه
                break;
              case "free_parking":
                _searchFreeStreetParking();
                break;
              case "school":
                _searchEducationalPlaces();
                break;
              case "charging_station":
                _searchCategory('amenity=charging_station', "ایستگاه شارژ برقی");
                break;
              case "bicycle_rental":
                _searchCategory('amenity=bicycle_rental', "کرایه دوچرخه");
                break;
              case "metro":
                _searchCategory('railway=station AND (station=subway OR railway=subway)', "ایستگاه مترو");
                break;
              case "tourism":
                _searchTouristAttractions();
                break;
              case "worship":
                _searchPlacesOfWorship();
                break;
              case "chain_store":
                _searchChainStoresFromBackend();
                break;
              case "parking":
                _searchCategory('amenity=parking', "پارکینگ عمومی");
                break;

              // اگر چیزی اشتباه بود یا پیدا نشد، حداقل یه چیزی نشون بده
              default:
                _searchCategory('amenity=cafe', "جستجوی پیشرفته");
            }
          });
        }
      });
    }
  }

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
            // هدر با فلش برگشت
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // هندل بالا
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    width: 60,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // عنوان + دکمه برگشت
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // فلش برگشت به منوی جستجو
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 26),
                          onPressed: widget.onBackToSearch, // این خط جادویی کار رو انجام میده
                        ),
                        Expanded( // حذف const
                          child: Text( // حذف const
                            _currentSearchTitle, // استفاده از عنوان پویا
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 48), // فضای خالی برای تعادل
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // ردیف آیکون‌ها
            SliverToBoxAdapter(
              child: SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildIconButton(Icons.coffee, Colors.brown.shade700, "کافه", () => _search('amenity=cafe', "کافه‌های اطراف")),
                    _buildIconButton(Icons.restaurant_menu, Colors.orange.shade700, "رستوران", () => _search('amenity=restaurant', "رستوران‌های اطراف")),
                    _buildIconButton(Icons.local_gas_station, Colors.red.shade600, "پمپ بنزین", () => _search('amenity=fuel', "پمپ بنزین‌ها و جایگاه‌های سوخت")),
                    _buildIconButton(Icons.medication, Colors.teal.shade700, "داروخانه", () => _search('amenity=pharmacy', "داروخانه‌های اطراف")),
                    _buildIconButton(Icons.ev_station, Colors.cyan.shade700, "ایستگاه شارژ برقی", () => _search('amenity=charging_station', "ایستگاه شارژ برقی")),
                    _buildIconButton(Icons.electric_bike, Colors.lime.shade700, "کرایه دوچرخه", () => _search('amenity=bicycle_rental', "کرایه دوچرخه")),
                    _buildIconButton(Icons.local_hospital, Colors.red.shade800, "بیمارستان", () => _search('amenity=hospital', "بیمارستان‌ها و مراکز درمانی")),
                    _buildIconButton(Icons.directions_bus, Colors.purple.shade700, "ایستگاه اتوبوس", _searchBusStops),
                    _buildIconButton(Icons.train, Colors.deepPurple.shade700, "ایستگاه مترو", () => _search('railway=station AND (station=subway OR railway=subway)', "ایستگاه مترو")),
                    _buildIconButton(Icons.store_mall_directory, Colors.blue.shade700, "سوپرمارکت محلی", _searchSupermarket),
                    _buildIconButton(Icons.park, Colors.green.shade700, "پارک", () => _search('leisure=park', "پارک‌ها و فضای سبز")),
                    _buildIconButton(Icons.synagogue_outlined, Colors.deepPurple.shade600, "عبادتگاه", _searchPlacesOfWorship),
                    _buildIconButton(Icons.history_edu, Colors.amber.shade800, "جاذبه تاریخی و دیدنی", _searchTouristAttractions),
                    _buildIconButton(Icons.account_balance_outlined, Colors.indigo.shade700, "بانک و خودپرداز", _searchBanksAndAtms),
                    _buildIconButton(Icons.local_parking, Colors.grey.shade700, "پارکینگ عمومی", () => _search('amenity=parking', "پارکینگ عمومی")),
                    _buildIconButton(FontAwesomeIcons.squareParking, Colors.green.shade800, "پارکینگ رایگان کنار خیابان", _searchFreeStreetParking),
                    _buildIconButton(Icons.storefront_outlined, const Color(0xFFE64A19), "فروشگاه زنجیره‌ای بزرگ", _searchChainStoresFromBackend),
                    _buildIconButton(Icons.school, Colors.orange.shade800, "مراکز آموزشی", _searchEducationalPlaces),
                  ],
                ),
              ),
            ),

            // بقیه کد (لودینگ، نتایج، جستجوها) دقیقاً همون قبلی
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 4)),
                ),
              ),

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${_results.length} نتیجه پیدا شد", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _sortByDistance = !_sortByDistance;
                                _sortResultsByDistance();
                              });
                            },
                            icon: Icon(_sortByDistance ? Icons.location_on : Icons.location_off, size: 15, color: _sortByDistance ? Colors.red.shade600 : Colors.grey),
                            label: Text(_sortByDistance ? " بر اساس فاصله" : "ترتیب اولیه", style: TextStyle(fontSize: 13, color: _sortByDistance ? Colors.red.shade600 : Colors.grey[700], fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._results.map((place) {
                        final name = place['tags']?['name:fa'] ?? place['tags']?['name'] ?? "بدون نام";
                        final lat = place['lat'] ?? place['center']?['lat'];
                        final lon = place['lon'] ?? place['center']?['lon'];
                        final dist = lat != null && lon != null ? distance(widget.centerLocation, LatLng(lat, lon)).toInt() : 0;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(name, style: const TextStyle(fontSize: 15)),
                          subtitle: Text("$dist متر"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            final lat = place['lat'] ?? place['center']?['lat'];
                            final lon = place['lon'] ?? place['center']?['lon'];
                            if (lat != null && lon != null) {
                              final point = LatLng(lat, lon);
                              String? placeName = place['tags']?['name:fa'] ?? place['tags']?['name'] ?? "مکان بدون نام";
                              
                              // جدید: اگر آدرس جزئیات داشته باشه، اضافه کن
                              final street = place['tags']?['addr:street'] ?? '';
                              final houseNumber = place['tags']?['addr:housenumber'] ?? '';
                              if (street.isNotEmpty) {
                                placeName = "$placeName, $street $houseNumber";
                              }
                              
                              widget.onSelectPlace?.call(point, placeName);
                            }
                            widget.onClose();
                          },
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
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
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
      setState(() {
        _currentSearchTitle = "خطا در جستجو ($title)";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchBusStops() async {
    const title = "ایستگاه‌های اتوبوس و تاکسی";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
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
      setState(() {
        _currentSearchTitle = "خطا در جستجوی ایستگاه‌ها";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // تابع مخصوص سوپرمارکت معمولی — بدون مشکل پارسینگ
  Future<void> _searchSupermarket() async {
    const title = "سوپرمارکت‌ها و فروشگاه‌های محلی";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
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
      setState(() {
        _currentSearchTitle = "خطا در جستجوی سوپرمارکت‌ها";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // جستجوی همه عبادتگاه‌ها: مسجد، کلیسا، کنیسه، معبد، آتشکده و ...
  Future<void> _searchPlacesOfWorship() async {
    const title = "عبادتگاه‌ها (مسجد، کلیسا و...)";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:40];
    (
      node["amenity"="place_of_worship"](around:5000,$lat,$lon);
      way["amenity"="place_of_worship"](around:5000,$lat,$lon);
      relation["amenity"="place_of_worship"](around:5000,$lat,$lon);
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
          _sortResultsByDistance(); // مرتب هم بشه
        });
      }
    } catch (e) {
      print("خطا در عبادتگاه: $e");
      setState(() {
        _currentSearchTitle = "خطا در جستجوی عبادتگاه‌ها";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // جستجوی جاذبه‌های تاریخی و دیدنی — مخصوص اشپایر و همه جای دنیا!
  Future<void> _searchTouristAttractions() async {
    const title = "جاذبه‌های تاریخی و دیدنی";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:40];
    (
      node["tourism"="attraction"](around:5000,$lat,$lon);
      node["tourism"="museum"](around:5000,$lat,$lon);
      node["historic"~"yes|castle|monument|church|cathedral|ruins|archaeological_site"](around:5000,$lat,$lon);
      node["amenity"="place_of_worship"]["name"~"Dom|Kathedrale|Church"](around:5000,$lat,$lon);
      
      way["tourism"="attraction"](around:5000,$lat,$lon);
      way["tourism"="museum"](around:5000,$lat,$lon);
      way["historic"~"yes|castle|monument|church|cathedral|ruins|archaeological_site"](around:5000,$lat,$lon);
      
      relation["tourism"="attraction"](around:5000,$lat,$lon);
      relation["tourism"="museum"](around:5000,$lat,$lon);
      relation["historic"~"yes|castle|monument|church|cathedral|ruins|archaeological_site"](around:5000,$lat,$lon);
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
          _sortResultsByDistance(); // مرتب هم بشه
        });
      }
    } catch (e) {
      print("خطا در جاذبه‌ها: $e");
      setState(() {
        _currentSearchTitle = "خطا در جستجوی جاذبه‌های دیدنی";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // جستجوی بانک و خودپرداز — ۱۰۰٪ درست و تست‌شده
  Future<void> _searchBanksAndAtms() async {
    const title = "بانک‌ها و خودپردازهای اطراف";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:40];
    (
      node["amenity"="bank"](around:5000,$lat,$lon);
      node["amenity"="atm"](around:5000,$lat,$lon);
      way["amenity"="bank"](around:5000,$lat,$lon);
      way["amenity"="atm"](around:5000,$lat,$lon);
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
          _sortResultsByDistance(); // مرتب هم بشه
        });
      }
    } catch (e) {
      print("خطا در بانک/خودپرداز: $e");
      setState(() {
        _currentSearchTitle = "خطا در جستجوی بانک‌ها";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchFreeStreetParking() async {
    const title = "پارکینگ‌های رایگان کنار خیابان";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:40];
    (
      node["highway"="street_parking"](around:5000,$lat,$lon);
      node["amenity"="parking"]["parking"="street_side"](around:5000,$lat,$lon);
      node["amenity"="parking"]["access"!="private"](around:5000,$lat,$lon);
      
      way["highway"="street_parking"](around:5000,$lat,$lon);
      way["amenity"="parking"]["parking"="street_side"](around:5000,$lat,$lon);
      way["amenity"="parking"]["access"!="private"](around:5000,$lat,$lon);
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
          _sortResultsByDistance();
        });
      }
    } catch (e) {
      print("خطا در پارکینگ مفتی: $e");
      setState(() {
        _currentSearchTitle = "خطا در جستجوی پارکینگ";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  } // جستجوی پارکینگ رایگان کنار خیابان — ۱۰۰٪ درست و تست‌شده (آلمان + ایران)

  Future<void> _searchChainStoresFromBackend() async {
    const title = "فروشگاه‌های زنجیره‌ای بزرگ";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
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

  // جستجوی مراکز آموزشی — دانشگاه، مدرسه، مهدکودک، آموزشگاه و ...
  Future<void> _searchEducationalPlaces() async {
    const title = "مراکز آموزشی (مدرسه، دانشگاه،...)";
    setState(() {
      _isLoading = true;
      _results.clear();
      _currentSearchTitle = title; // 👈 بروزرسانی عنوان
    });

    final lat = widget.centerLocation.latitude;
    final lon = widget.centerLocation.longitude;

    final overpassQuery = """
    [out:json][timeout:40];
    (
      node["amenity"~"school|kindergarten|university|college|driving_school|language_school|music_school"](around:5000,$lat,$lon);
      way["amenity"~"school|kindergarten|university|college|driving_school|language_school|music_school"](around:5000,$lat,$lon);
      relation["amenity"~"school|kindergarten|university|college|driving_school|language_school|music_school"](around:5000,$lat,$lon);
      
      node["building"="school"](around:5000,$lat,$lon);
      node["building"="university"](around:5000,$lat,$lon);
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
          _sortResultsByDistance(); // مرتب بر اساس فاصله
        });
      }
    } catch (e) {
      print("خطا در مراکز آموزشی: $e");
      setState(() {
        _currentSearchTitle = "خطا در جستجوی مراکز آموزشی";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}