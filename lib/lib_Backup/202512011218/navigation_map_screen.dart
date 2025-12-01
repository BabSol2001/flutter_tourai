import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

// ویجت منوی مسیریابی از بالا (با ValueNotifier)
import 'navigation/widgets/routing_card.dart';

class NavigationMapScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const NavigationMapScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  Marker? _currentLocationMarker;

  LatLng? _selectedDestination;
  Marker? _destinationMarker;
  final TextEditingController _destinationController = TextEditingController();

  final TextEditingController _originController = TextEditingController();
  LatLng? _originLatLng;

  double _currentMapRotation = 0.0;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  List<Polyline> _routePolylines = [];
  bool _isLoadingRoute = false;

  String _selectedEngine = "valhalla";
  String _selectedMode = "auto";

  final ValueNotifier<String> _modeNotifier = ValueNotifier<String>("auto");

  final TextEditingController _searchController = TextEditingController();
  bool _isSearchingPoint = false;
  Marker? _tempSearchMarker;

  String? _pendingSearchText;

  // فقط برای قابلیت جدید: انتخاب مقصد از روی نقشه
  bool _isSelectingFromMap = false;

  static const String baseUrl = "http://192.168.0.105:8000";

  final List<Map<String, dynamic>> transportModes = [
    {"mode": "auto", "engine": "valhalla", "name": "ماشین", "icon": Icons.directions_car},
    {"mode": "motorcycle", "engine": "valhalla", "name": "موتور", "icon": Icons.motorcycle},
    {"mode": "truck", "engine": "valhalla", "name": "کامیون", "icon": Icons.local_shipping},
    {"mode": "bicycle", "engine": "valhalla", "name": "دوچرخه", "icon": Icons.directions_bike},
    {"mode": "pedestrian", "engine": "valhalla", "name": "پیاده", "icon": Icons.directions_walk},
  ];

  @override
  void initState() {
    super.initState();
    _originController.text = "موقعیت فعلی";
    _modeNotifier.value = _selectedMode;
    _setupAnimations();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _searchController.dispose();
    _rotationController.dispose();
    _modeNotifier.dispose();
    super.dispose();
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
        _showSnackBar("اجازه دسترسی به مکان داده نشد");
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
          width: 40, height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
        );
      });

      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
      _showSnackBar("موقعیت شما بروز شد", success: true);
    } catch (e) {
      _showSnackBar("خطا در گرفتن موقعیت");
      setState(() => _isLoadingLocation = false);
    }
  }

  // تغییر مهم: حالا تشخیص میده حالت انتخاب از نقشه فعاله یا نه
  void _onMapTapped(LatLng point) {
    if (_isSelectingFromMap) {
      final coordsText = "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";

      setState(() {
        _isSelectingFromMap = false;
        _selectedDestination = point;
        _destinationController.text = coordsText.length > 35 
            ? "${coordsText.substring(0, 35)}..." 
            : coordsText;

        _destinationMarker = Marker(
          point: point,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.red, size: 50),
        );

        // مهم: مختصات رو موقت نگه می‌داریم
        _pendingSearchText = coordsText;
      });

      _mapController.move(point, 16);
      _showSnackBar("مختصات انتخاب شد: $coordsText", success: true);

      // منو رو دوباره باز کن — و داخلش مختصات میاد
      Future.delayed(const Duration(milliseconds: 300), () {
        _openSearchFromFab();
      });
    } else {
      setState(() {
        _selectedDestination = point;
        _destinationMarker = Marker(
          point: point,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.red, size: 50),
        );
      });
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

      _destinationMarker = Marker(
        point: _selectedDestination ?? _originLatLng!,
        width: 50, height: 50,
        child: const Icon(Icons.location_on, color: Colors.red, size: 50),
      );
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
      backgroundColor: success ? Colors.green : Colors.red,
      duration: const Duration(seconds: 2),
    ));
  }

  String _getModeName() {
    return transportModes.firstWhere((m) => m['mode'] == _selectedMode)['name'];
  }

  Future<void> _startRouting() async {
    if (_selectedDestination == null) {
      _showSnackBar("مقصد را انتخاب کنید");
      return;
    }

    setState(() => _isLoadingRoute = true);
    _routePolylines.clear();

    if (_currentPosition == null) await _getCurrentLocation(force: true);

    final startLat = _originLatLng?.latitude ?? _currentPosition!.latitude;
    final startLon = _originLatLng?.longitude ?? _currentPosition!.longitude;

    final url = Uri.parse('$baseUrl/api/v1/osm/smart-route/?start_lat=$startLat&start_lon=$startLon&end_lat=${_selectedDestination!.latitude}&end_lon=${_selectedDestination!.longitude}&engine=$_selectedEngine&mode=$_selectedMode');

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          List<Polyline> lines = [];
          for (var r in (data['routes'] ?? [data])) {
            var coords = r['route_coords'] as List;
            lines.add(Polyline(
              points: coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
              strokeWidth: 9,
              color: _selectedMode == "truck" ? Colors.orange : _selectedMode == "motorcycle" ? Colors.purple : _selectedMode == "bicycle" ? Colors.green : _selectedMode == "pedestrian" ? Colors.teal : Colors.blue,
            ));
          }
          setState(() => _routePolylines = lines);
          _fitRouteToScreen();
          _showSnackBar("مسیر ${_getModeName()} رسم شد!", success: true);
        }
      }
    } catch (e) {
      _showSnackBar("اتصال ناموفق");
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  void _openSearchFromFab() {
    _searchController.clear();

    // اگر مختصات منتظر بود، بعد از باز شدن منو بذار توی فیلد
    if (_pendingSearchText != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _searchController.text = _pendingSearchText!;
        _pendingSearchText = null; // پاک کن که دوباره نیاد
      });
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "search_dialog",
        barrierColor: Colors.black.withOpacity(0.5),
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, _, __) => _SearchTopSheet(state: this),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ).then((_) {
        _searchController.clear();
        _pendingSearchText = null; // در صورت بسته شدن دستی
      });
    });
  }
  // تابع جدید: فعال کردن حالت انتخاب از نقشه
  void _enableMapSelectionMode() {
    setState(() => _isSelectingFromMap = true);
    Navigator.of(context).pop(); // بستن منوی جستجو
    _showSnackBar("روی نقشه ضربه بزنید تا مقصد انتخاب شود", success: true);
  }

  // تابع جدید: باز کردن منوی مسیریابی (برای استفاده بعد از انتخاب از نقشه)
  void _openRoutingPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "routing_panel",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => RoutingTopPanel(
        originController: _originController,
        destinationController: _destinationController,
        selectedDestination: _selectedDestination,
        originLatLng: _originLatLng,
        isLoadingRoute: _isLoadingRoute,
        modeNotifier: _modeNotifier,
        onModeChanged: (mode) {
          _selectedMode = mode;
          _modeNotifier.value = mode;
        },
        onSwap: _swapOriginAndDestination,
        onClearDestination: () => setState(() {
          _selectedDestination = null;
          _destinationMarker = null;
          _destinationController.clear();
        }),
        onClearOrigin: () => setState(() {
          _originLatLng = null;
          _originController.text = "موقعیت فعلی";
        }),
        onStartRouting: _startRouting,
        modeName: _getModeName(),
        onClose: () => Navigator.of(context).pop(),
      ),
      transitionBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b'],
                userAgentPackageName: 'com.tourai.app',
              ),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: [
                if (_currentLocationMarker != null) _currentLocationMarker!,
                if (_destinationMarker != null) _destinationMarker!,
                if (_tempSearchMarker != null) _tempSearchMarker!,
              ]),
            ],
          ),

          if (_isLoadingLocation)
            const Positioned(
              top: 100, left: 0, right: 0,
              child: Center(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 12), Text("در حال گرفتن موقعیت...")])))),
            ),

          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "search",
                  backgroundColor: Colors.white,
                  onPressed: _openSearchFromFab,
                  child: const Icon(Icons.search, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: "north",
                  backgroundColor: Colors.white,
                  onPressed: _resetNorth,
                  child: const Icon(Icons.explore, size: 20),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: "locate",
                  backgroundColor: Colors.blue,
                  onPressed: () => _getCurrentLocation(force: true),
                  child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchPoint(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearchingPoint = true);

    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&accept-language=fa');
    try {
      final res = await http.get(url, headers: {'User-Agent': 'TourAI/1.0'});
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final point = LatLng(lat, lon);
          final name = (data[0]['display_name'] as String).split(',').first.trim();

          setState(() {
            _tempSearchMarker = Marker(
              point: point,
              width: 50, height: 50,
              child: const Icon(Icons.location_searching, color: Colors.purple, size: 50),
            );
            _selectedDestination = point;
            _destinationController.text = name.length > 35 ? "${name.substring(0, 35)}..." : name;
            _destinationMarker = Marker(
              point: point,
              width: 50, height: 50,
              child: const Icon(Icons.location_on, color: Colors.red, size: 50),
            );
          });

          _mapController.move(point, 16);
          _showSnackBar("پیدا شد: $name", success: true);

          Future.delayed(const Duration(seconds: 8), () {
            if (mounted) setState(() => _tempSearchMarker = null);
          });
        }
      }
    } catch (e) {
      _showSnackBar("خطا در جستجو");
    } finally {
      if (mounted) setState(() => _isSearchingPoint = false);
    }
  }
}

// منوی جستجو از بالا — فقط با اضافه شدن دکمه انتخاب از نقشه
class _SearchTopSheet extends StatelessWidget {
  final _NavigationMapScreenState state;
  const _SearchTopSheet({required this.state});

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
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  const Text("جستجو و مسیریابی", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // فقط این قسمت تغییر کرد: اضافه شدن دکمه نقشه
                  TextField(
                    controller: state._searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "نام مکان، آدرس یا نقطه معروف...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // دکمه انتخاب از روی نقشه
                          IconButton(
                            icon: const Icon(Icons.location_on_outlined, color: Colors.red),
                            tooltip: "انتخاب از روی نقشه",
                            onPressed: state._enableMapSelectionMode,
                          ),
                          // لودینگ یا پاک کردن
                          state._isSearchingPoint
                              ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => state._searchController.clear(),
                                ),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        state._searchPoint(query);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.directions, color: Colors.white),
                          label: const Text("مسیریابی"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 15)),
                          onPressed: () async {
                            final query = state._searchController.text.trim();
                            if (query.isEmpty) return;

                            await state._searchPoint(query);

                            if (state._selectedDestination != null) {
                              state._destinationController.text = query;
                              state._modeNotifier.value = state._selectedMode;
                              Navigator.of(context).pop();

                              state._openRoutingPanel();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.location_on, color: Colors.white),
                          label: const Text("جستجو"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                          onPressed: () {
                            if (state._searchController.text.trim().isNotEmpty) {
                              state._searchPoint(state._searchController.text);
                              Navigator.of(context).pop();
                            }
                          },
                        ),
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
    );
  }
}