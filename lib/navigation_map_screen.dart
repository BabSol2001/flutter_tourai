import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme.dart';
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
  final MapController _mapController = MapController();

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  Marker? _currentLocationMarker;

  double _currentMapRotation = 0.0;
  final TextEditingController _originController = TextEditingController();

  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  late AnimationController _routingController;
  late Animation<double> _routingHeight;
  bool _isRoutingExpanded = false;

  List<Polyline> _routePolylines = [];
  bool _isLoadingRoute = false;

  // حالت انتخابی کاربر
  String _selectedEngine = "valhalla"; // یا "osrm"
  String _selectedMode = "auto"; // auto, bicycle, pedestrian, motorcycle, truck, bus

  static const String baseUrl = "http://192.168.0.105:8000";

  // لیست وسایل نقلیه با آیکون و نام فارسی
  final List<Map<String, dynamic>> transportModes = [
    {"mode": "auto",       "engine": "valhalla", "name": "ماشین",         "icon": Icons.directions_car},
    {"mode": "motorcycle","engine": "valhalla", "name": "موتورسیکلت",   "icon": Icons.motorcycle},
    {"mode": "truck",      "engine": "valhalla", "name": "کامیون",        "icon": Icons.local_shipping},
    {"mode": "bicycle",    "engine": "valhalla", "name": "دوچرخه",        "icon": Icons.directions_bike},
    {"mode": "pedestrian", "engine": "valhalla", "name": "پیاده",         "icon": Icons.directions_walk},
    {"mode": "driving",    "engine": "osrm",     "name": "ماشین (OSRM)",  "icon": Icons.directions_car_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _getCurrentLocation();
  }

  void _setupAnimations() {
    _mapController.mapEventStream.listen((_) {
      _currentMapRotation = _mapController.camera.rotation;
    });

    _rotationController = AnimationController(duration: const Duration(milliseconds: 750), vsync: this);
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic));
    _rotationAnimation.addListener(() {
      _mapController.rotate(_rotationAnimation.value);
      _currentMapRotation = _rotationAnimation.value;
    });

    _routingController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _routingHeight = Tween<double>(begin: 70, end: 480).animate(CurvedAnimation(parent: _routingController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _originController.dispose();
    _rotationController.dispose();
    _routingController.dispose();
    super.dispose();
  }

  void _resetNorth() {
    _rotationAnimation = Tween<double>(begin: _currentMapRotation, end: 0.0)
        .animate(CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic));
    _rotationController.reset();
    _rotationController.forward();
  }

  Future<void> _getCurrentLocation({bool force = false}) async {
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('GPS خاموش است! لطفاً روشن کنید');
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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _currentLocationMarker = Marker(
          point: LatLng(position.latitude, position.longitude),
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
          width: 40, height: 40,
        );
      });

      if (force || _mapController.camera.zoom < 12) {
        _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
      }
    } catch (e) {
      debugPrint("خطا در موقعیت: $e");
      setState(() => _isLoadingLocation = false);
    }
  }

  void _fitRouteToScreen() {
    if (_routePolylines.isEmpty || _routePolylines.first.points.isEmpty) return;

    final points = _routePolylines.first.points;
    double minLat = points[0].latitude, maxLat = points[0].latitude;
    double minLng = points[0].longitude, maxLng = points[0].longitude;

    for (var p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)));
  }

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: success ? Colors.green : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _startRouting() async {
    setState(() => _isLoadingRoute = true);
    _routePolylines.clear();

    if (_currentPosition == null) {
      await _getCurrentLocation(force: true);
      if (_currentPosition == null) {
        _showSnackBar('موقعیت در دسترس نیست!');
        setState(() => _isLoadingRoute = false);
        return;
      }
    }

    final url = Uri.parse(
      '$baseUrl/api/v1/osm/smart-route/?'
      'start_lat=${_currentPosition!.latitude}'
      '&start_lon=${_currentPosition!.longitude}'
      '&end_lat=49.311389'
      '&end_lon=8.447222'
      '&engine=$_selectedEngine'
      '&mode=$_selectedMode',
    );

    debugPrint("درخواست: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          List<Polyline> polylines = [];

          // اگر OSRM باشه routes داره، اگر Valhalla باشه route_coords مستقیم
          List routes = data['routes'] ?? [data];

          for (var route in routes) {
            var coordsList = route['route_coords'] as List;

            List<LatLng> points = coordsList.map((coord) {
              double lng = coord[0].toDouble();
              double lat = coord[1].toDouble();
              return LatLng(lat, lng);
            }).toList();

            polylines.add(Polyline(
              points: points,
              strokeWidth: 9.0,
              color: _selectedMode == "truck" ? Colors.orange :
                     _selectedMode == "motorcycle" ? Colors.purple :
                     _selectedMode == "bicycle" ? Colors.green :
                     _selectedMode == "pedestrian" ? Colors.teal :
                     Colors.blue,
            ));
          }

          setState(() {
            _routePolylines = polylines;
            _isRoutingExpanded = false;
            _routingController.reverse();
          });

          _fitRouteToScreen();
          _showSnackBar('مسیر ${_getModeName()} رسم شد!', success: true);
        } else {
          _showSnackBar('خطا در دریافت مسیر');
        }
      } else {
        _showSnackBar('خطای سرور: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("خطا: $e");
      _showSnackBar('اتصال ناموفق');
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  String _getModeName() {
    return transportModes.firstWhere((m) => m['mode'] == _selectedMode, orElse: () => transportModes[0])['name'];
  }

  void _toggleRoutingCard() {
    setState(() {
      _isRoutingExpanded = !_isRoutingExpanded;
      _isRoutingExpanded ? _routingController.forward() : _routingController.reverse();
      if (_isRoutingExpanded) _originController.text = "موقعیت فعلی";
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TourAI Map', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(35.6892, 51.3890),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.tourai.app',
              ),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: _currentLocationMarker != null ? [_currentLocationMarker!] : []),
            ],
          ),

          if (_isLoadingLocation)
            Positioned(
              top: 100, left: 0, right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text("در حال گرفتن موقعیت شما..."),
                    ]),
                  ),
                ),
              ),
            ),

          // کارت مسیریابی با منوی جدید
          Positioned(
            bottom: 100, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _routingHeight,
              builder: (context, child) => GestureDetector(
                onTap: _toggleRoutingCard,
                child: Container(
                  height: _routingHeight.value,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: _isRoutingExpanded ? _buildExpandedCard(theme) : _buildCollapsedCard(),
                ),
              ),
            ),
          ),

          // دکمه‌های پایین
          Positioned(
            bottom: 130, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FloatingActionButton(heroTag: "north", backgroundColor: Colors.white, onPressed: _resetNorth, child: const Icon(Icons.explore, color: Colors.black87)),
              const SizedBox(width: 12),
              FloatingActionButton(heroTag: "loc", backgroundColor: AppTheme.primary, onPressed: () => _getCurrentLocation(force: true), child: const Icon(Icons.my_location)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.directions, color: AppTheme.primary, size: 26),
          const SizedBox(width: 12),
          Text("مسیریابی به موزه تکنیک اشپایر — ${_getModeName()}", style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.keyboard_arrow_up),
        ],
      ),
    );
  }

  Widget _buildExpandedCard(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTabHeader(Icons.directions, 'انتخاب نوع وسیله نقلیه', AppTheme.primary),
          const SizedBox(height: 16),

          // منوی انتخاب وسیله نقلیه
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: transportModes.map((item) {
              bool isSelected = _selectedMode == item['mode'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMode = item['mode'];
                    _selectedEngine = item['engine'];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppTheme.primary : Colors.transparent, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item['icon'], color: isSelected ? Colors.white : Colors.black87, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        item['name'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoadingRoute ? null : _startRouting,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: _isLoadingRoute
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Text("شروع مسیریابی با ${_getModeName()}", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}