import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class NavigationMapScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const NavigationMapScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen>
    with TickerProviderStateMixin {
  // نقشه و موقعیت فعلی
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  Marker? _currentLocationMarker;

  // مقصد
  LatLng? _selectedDestination;
  Marker? _destinationMarker;
  final TextEditingController _destinationController = TextEditingController();
  bool _isSearchingDestination = false;

  // مبدا (دستی یا موقعیت فعلی)
  final TextEditingController _originController = TextEditingController();
  LatLng? _originLatLng;
  bool _isSearchingOrigin = false;

  // انیمیشن‌ها
  double _currentMapRotation = 0.0;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  late AnimationController _routingController;
  late Animation<double> _routingHeight;
  bool _isRoutingExpanded = false;

  // مسیر و لودینگ
  List<Polyline> _routePolylines = [];
  bool _isLoadingRoute = false;

  // وسیله نقلیه
  String _selectedEngine = "valhalla";
  String _selectedMode = "auto";

  static const String baseUrl = "http://192.168.0.105:8000"; // IP خودت رو بذار

  final List<Map<String, dynamic>> transportModes = [
    {"mode": "auto",       "engine": "valhalla", "name": "ماشین",       "icon": Icons.directions_car},
    {"mode": "motorcycle", "engine": "valhalla", "name": "موتور",       "icon": Icons.motorcycle},
    {"mode": "truck",      "engine": "valhalla", "name": "کامیون",      "icon": Icons.local_shipping},
    {"mode": "bicycle",    "engine": "valhalla", "name": "دوچرخه",      "icon": Icons.directions_bike},
    {"mode": "pedestrian", "engine": "valhalla", "name": "پیاده",       "icon": Icons.directions_walk},
  ];

  @override
  void initState() {
    super.initState();
    _originController.text = "موقعیت فعلی";
    //_destinationController.text = "موزه تکنیک اشپایر";
    // این خط رو حذف کن یا کامنت کن:
  // _selectedDestination = const LatLng(49.311389, 8.447222); // این خط مشکل اصلی بود!
  // در عوض فقط مارکر اولیه رو نشون بده، ولی متغیر رو خالی بذار 
    _setupAnimations();
    _getCurrentLocation();
  }

  void _setupAnimations() {
    _mapController.mapEventStream.listen((event) {
      _currentMapRotation = _mapController.camera.rotation;
    });

    _rotationController = AnimationController(duration: const Duration(milliseconds: 750), vsync: this);
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic));
    _rotationAnimation.addListener(() {
      _mapController.rotate(_rotationAnimation.value);
      _currentMapRotation = _rotationAnimation.value;
    });

    _routingController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _routingHeight = Tween<double>(begin: 70, end: 520).animate(CurvedAnimation(parent: _routingController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _rotationController.dispose();
    _routingController.dispose();
    super.dispose();
  }

  void _resetNorth() {
    _rotationAnimation = Tween<double>(begin: _currentMapRotation, end: 0)
        .animate(CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic));
    _rotationController.reset();
    _rotationController.forward();
  }

  Future<void> _getCurrentLocation({bool force = false}) async {
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("GPS خاموش است!");
      setState(() => _isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
        _currentLocationMarker = Marker(
          point: LatLng(pos.latitude, pos.longitude),
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
          width: 40, height: 40,
        );
      });
      if (force) _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _selectedDestination = point;
      _destinationMarker = Marker(
        point: point,
        width: 50,   // این دو خط اضافه شد
        height: 50,  // بدون اینا مارکر نمیاد!
        child: const Icon(Icons.location_on, color: Colors.red, size: 50),
      );
    });
    _reverseGeocode(point, isDestination: true);
  }

  Future<void> _reverseGeocode(LatLng point, {required bool isDestination}) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&accept-language=fa');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        String name = data['display_name']?.split(',')[0] ?? "مکان انتخاب‌شده";
        if (isDestination) {
          _destinationController.text = name.length > 35 ? "${name.substring(0, 35)}..." : name;
        } else {
          _originController.text = name.length > 35 ? "${name.substring(0, 35)}..." : name;
          _originLatLng = point;
        }
      }
    } catch (_) {}
  }

  // جستجوی مبدا
  Future<void> _searchOrigin(String query) async {
    if (query.trim().isEmpty || query == "موقعیت فعلی") {
      setState(() => _originLatLng = null);
      _originController.text = "موقعیت فعلی";
      return;
      return;
    }
    setState(() => _isSearchingOrigin = true);
    await _searchPlace(query, isDestination: false);
    setState(() => _isSearchingOrigin = false);
  }

  // جستجوی مقصد
  Future<void> _searchDestination(String query) async {
  if (query.trim().isEmpty) return;

  setState(() => _isSearchingDestination = true);

  try {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=json'
      '&limit=1'
      '&addressdetails=1'
      '&accept-language=de,en'  // چون آلمان هستی، اول آلمانی بعد انگلیسی
    );

    print("جستجوی مقصد: $query → $url");  // لاگ خیلی مهم

    final response = await http.get(url, headers: {
      'User-Agent': 'TourAI-App/1.0 (your-email@example.com)', // حتماً اینو بذار!
    }).timeout(const Duration(seconds: 12));

    print("پاسخ Nominatim (${response.statusCode}): ${response.body}");

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        final displayName = data[0]['display_name'] as String;

        // فقط یک بار setState و همه چیز رو اینجا ست کن!
        setState(() {
          _selectedDestination = LatLng(lat, lon);
          _destinationController.text = displayName.length > 40 
              ? "${displayName.substring(0, 37)}..."
              : displayName;

          _destinationMarker = Marker(
            point: LatLng(lat, lon),
            width: 50,
            height: 50,
            child: const Icon(Icons.location_on, color: Colors.red, size: 50),
          );
        });

        _mapController.move(LatLng(lat, lon), 15);
        _showSnackBar("مقصد پیدا شد: ${displayName.split(',').first}", success: true);

        // اگر الان مبدا هم آماده باشه → خودکار مسیریابی شروع کن!
        if (_currentPosition != null || _originLatLng != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _startRouting());
        }

        return; // موفق بود → خارج شو
      }
    }
  } catch (e) {
    print("خطا در جستجوی مقصد: $e");
    _showSnackBar("خطا در جستجو: $e");
  } finally {
    if (mounted) {
      setState(() => _isSearchingDestination = false);
    }
  }

  // اگر تا اینجا رسید یعنی پیدا نشد
  _showSnackBar("مقصد پیدا نشد! نام دقیق‌تری وارد کنید");
}

  Future<void> _searchPlace(String query, {required bool isDestination}) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&accept-language=fa');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final pos = LatLng(lat, lon);
          String name = data[0]['display_name'].split(',')[0];

          setState(() {
            if (isDestination) {
              _selectedDestination = pos;
              _destinationController.text = name.length > 35 ? "${name.substring(0, 32)}..." : name;

              _destinationMarker = Marker(
                point: pos,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_on, color: Colors.red, size: 50),
              );
            } else {
              _originLatLng = pos;
              _originController.text = name.length > 35 ? "${name.substring(0, 32)}..." : name;
            }
          });

          _mapController.move(pos, 15);
          _showSnackBar("مکان پیدا شد: $name", success: true);

          // این خط جادویی اضافه شد!
          if (isDestination && _selectedDestination != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startRouting(); // خودکار مسیریابی شروع می‌شه
            });
          }
        } else {
          _showSnackBar("مکانی پیدا نشد");
        }
      }
    } catch (e) {
      _showSnackBar("خطا در جستجو: $e");
    }
  }

  void _swapOriginAndDestination() {
    if (_selectedDestination == null) return;
    setState(() {
      final tempText = _originController.text;
      final tempLatLng = _originLatLng;

      _originController.text = _destinationController.text;
      _originLatLng = _selectedDestination;

      _destinationController.text = tempText;
      _selectedDestination = tempLatLng;

      _destinationMarker = _originLatLng != null
          ? Marker(point: _originLatLng!, child: const Icon(Icons.location_on, color: Colors.red, size: 50))
          : null;
    });
  }

  void _fitRouteToScreen() {
    if (_routePolylines.isEmpty) return;
    final points = _routePolylines.first.points;
    double minLat = points[0].latitude, maxLat = points[0].latitude;
    double minLng = points[0].longitude, maxLng = points[0].longitude;
    for (var p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(80)));
  }

  void _showSnackBar(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      backgroundColor: success ? Colors.green : null,
    ));
  }

  Future<void> _startRouting() async {

    // اگر فقط متن نوشته شده و مختصات نداریم → اول جستجو کن!
  if (_selectedDestination == null && _destinationController.text.trim().isNotEmpty) {
    print("مختصات مقصد موجود نیست، در حال جستجوی خودکار...");
    await _searchDestination(_destinationController.text);
    // اگر بعد از جستجو هنوز null بود → یعنی واقعاً پیدا نشد
    if (_selectedDestination == null) {
      _showSnackBar("مقصد پیدا نشد! لطفاً نام دقیق‌تری وارد کنید");
      return;
    }
  }

  if (_selectedDestination == null) {
    _showSnackBar("مقصد را انتخاب کنید");
    return;
  }

  // بقیه کدهای قبلی (لاگ، درخواست به سرور و ...)

    if (_selectedDestination == null) {
      _showSnackBar("مقصد را انتخاب کنید");
      return;
    }

    setState(() => _isLoadingRoute = true);
    _routePolylines.clear();

    if (_currentPosition == null) await _getCurrentLocation(force: true);

    final startLat = _originLatLng?.latitude ?? _currentPosition!.latitude;
    final startLon = _originLatLng?.longitude ?? _currentPosition!.longitude;
    final double endLat = _selectedDestination!.latitude;
  final double endLon = _selectedDestination!.longitude;

  // لاگ کامل و خوانا برای دیباگ
  print("==========================================");
  print("مسیریابی شروع شد");
  print("مبدا (Origin):");
  print("   متن: ${_originController.text}");
  print("   مختصات: $startLat, $startLon");
  print("   منبع: ${_originLatLng != null ? "دستی انتخاب شده" : "موقعیت فعلی GPS"}");
  print("");
  print("مقصد (Destination):");
  print("   متن: ${_destinationController.text}");
  print("   مختصات: $endLat, $endLon");
  print("");
  print("وسیله نقلیه: $_selectedMode ($_selectedEngine)");
  print("آدرس درخواست به سرور:");
  print("$baseUrl/api/v1/osm/smart-route/?start_lat=$startLat&start_lon=$startLon"
      "&end_lat=$endLat&end_lon=$endLon&engine=$_selectedEngine&mode=$_selectedMode");
  print("==========================================");

    final url = Uri.parse(
      '$baseUrl/api/v1/osm/smart-route/?start_lat=$startLat&start_lon=$startLon'
      '&end_lat=${_selectedDestination!.latitude}&end_lon=${_selectedDestination!.longitude}'
      '&engine=$_selectedEngine&mode=$_selectedMode',
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 30));
      print("وضعیت پاسخ سرور: ${res.statusCode}");
      print("بدنه پاسخ: ${res.body}"); // این خط خیلی مهمه!
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          List<Polyline> lines = [];
          List routes = data['routes'] ?? [data];

          for (var r in routes) {
            var coords = r['route_coords'] as List;
            List<LatLng> pts = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

            lines.add(Polyline(
              points: pts,
              strokeWidth: 9,
              color: _selectedMode == "truck"
                  ? Colors.orange
                  : _selectedMode == "motorcycle"
                      ? Colors.purple
                      : _selectedMode == "bicycle"
                          ? Colors.green
                          : _selectedMode == "pedestrian"
                              ? Colors.teal
                              : Colors.blue,
            ));
          }

          setState(() {
            _routePolylines = lines;
            _isRoutingExpanded = false;
            _routingController.reverse();
          });
          _fitRouteToScreen();
          _showSnackBar("مسیر ${_getModeName()} رسم شد!", success: true);
        }
      } else {
        _showSnackBar("خطای سرور");
      }
    } catch (e) {
      _showSnackBar("اتصال ناموفق");
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  String _getModeName() {
    return transportModes.firstWhere((m) => m['mode'] == _selectedMode)['name'];
  }

  void _toggleRoutingCard() {
    setState(() {
      _isRoutingExpanded = !_isRoutingExpanded;
      _isRoutingExpanded ? _routingController.forward() : _routingController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TourAI Map"), centerTitle: true),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(35.6892, 51.3890),
              initialZoom: 12,
              onTap: (_, p) => _onMapTapped(p),
            ),
            children: [
              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.example.app'),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: [
                if (_currentLocationMarker != null) _currentLocationMarker!,
                if (_destinationMarker != null) _destinationMarker!,
              ]),
            ],
          ),

          if (_isLoadingLocation)
            const Positioned(top: 100, left: 0, right: 0, child: Center(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 12), Text("در حال گرفتن موقعیت...")]))))),

          // کارت مسیریابی
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _routingHeight,
              builder: (_, __) => GestureDetector(
                onTap: _toggleRoutingCard,
                child: Container(
                  height: _routingHeight.value,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.97), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black26)]),
                  child: _isRoutingExpanded ? _buildExpandedCard() : _buildCollapsedCard(),
                ),
              ),
            ),
          ),

          // دکمه‌های پایین
          Positioned(
            bottom: 130,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FloatingActionButton(heroTag: "north", backgroundColor: Colors.white, onPressed: _resetNorth, child: const Icon(Icons.explore)),
              const SizedBox(width: 16),
              FloatingActionButton(heroTag: "loc", backgroundColor: Colors.blue, onPressed: () => _getCurrentLocation(force: true), child: const Icon(Icons.my_location)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedCard() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(children: [Icon(Icons.directions, color: Colors.blue), SizedBox(width: 12), Text("مسیریابی هوشمند", style: TextStyle(fontWeight: FontWeight.bold)), Spacer(), Icon(Icons.keyboard_arrow_up)]),
    );
  }

  Widget _buildExpandedCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.directions, color: Colors.blue, size: 28), SizedBox(width: 10), Text("مسیریابی هوشمند", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 20),

        // مبدا
        TextField(
          controller: _originController,
          decoration: InputDecoration(
            hintText: "از کجا؟",
            prefixIcon: const Icon(Icons.my_location, color: Colors.green),
            suffixIcon: _isSearchingOrigin ? const CircularProgressIndicator(strokeWidth: 2) : (_originLatLng != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() { _originLatLng = null; _originController.text = "موقعیت فعلی"; }); }) : null),
            filled: true,
            fillColor: Colors.green[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
          onSubmitted: _searchOrigin,
        ),
        const SizedBox(height: 12),

        // مقصد
        TextField(
          controller: _destinationController,
          decoration: InputDecoration(
            hintText: "کجا می‌خوای بری؟",
            prefixIcon: const Icon(Icons.location_on, color: Colors.red),
            suffixIcon: _isSearchingDestination ? const CircularProgressIndicator(strokeWidth: 2) : (_selectedDestination != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() { _selectedDestination = null; _destinationMarker = null; _destinationController.clear(); }); }) : null),
            filled: true,
            fillColor: Colors.red[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
          onSubmitted: _searchDestination,
        ),

        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: GestureDetector(onTap: _swapOriginAndDestination, child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle), child: const Icon(Icons.swap_vert)))),

        const SizedBox(height: 20),

        // آیکون‌های وسیله
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: transportModes.map((m) {
          bool sel = _selectedMode == m['mode'];
          return GestureDetector(
            onTap: () => setState(() => {_selectedMode = m['mode'], _selectedEngine = m['engine']}),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: sel ? Colors.blue : Colors.grey[200], shape: BoxShape.circle, boxShadow: sel ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 12)] : null),
              child: Icon(m['icon'], color: sel ? Colors.white : Colors.black87, size: 28),
            ),
          );
        }).toList()),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton.icon(
            onPressed: _isLoadingRoute 
            ? null 
            : (_selectedDestination != null || _destinationController.text.trim().isNotEmpty)
                ? _startRouting
                : null,
            icon: _isLoadingRoute ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.navigation),
            label: Text(_isLoadingRoute ? "در حال رسم..." : "شروع مسیریابی با ${_getModeName()}"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 8),
          ),
        ),
      ]),
    );
  }
}