import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';


import 'navigation/widgets/routing_card.dart';
import 'navigation/widgets/advanced_search.dart';
import 'navigation/widgets/history_manager.dart';
import 'navigation/widgets/search_field.dart';


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
  bool _isSelectingFromMap = false;

  bool _isSearchMinimized = false;
  bool _isRoutingPanelMinimized = false;
  bool _isSelectingForRouting = false;

  List<TextEditingController> _destinationControllers = [];
  int _activeDestinationIndex = 0;

  static const String baseUrl = "http://192.168.0.145:8000";

  final List<Map<String, dynamic>> transportModes = [
    {"mode": "auto", "engine": "valhalla", "name": "ماشین", "icon": Icons.directions_car},
    {"mode": "motorcycle", "engine": "valhalla", "name": "موتور", "icon": Icons.motorcycle},
    {"mode": "truck", "engine": "valhalla", "name": "کامیون", "icon": Icons.local_shipping},
    {"mode": "bicycle", "engine": "valhalla", "name": "دوچرخه", "icon": Icons.directions_bike},
    {"mode": "pedestrian", "engine": "valhalla", "name": "پیاده", "icon": Icons.directions_walk},
  ];

  final SearchHistoryManager _historyManager = SearchHistoryManager();

  @override
  void initState() {
    super.initState();
    _originController.text = "موقعیت فعلی";
    _modeNotifier.value = _selectedMode;
    _setupAnimations();
    _getCurrentLocation();
    _historyManager.loadHistory().then((_) {
      if (mounted) setState(() {});
    });
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
          width: 40,
          height: 40,
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

void _onMapTapped(LatLng point) {
  if (_isSelectingFromMap) {
    final coordsText = "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";

    setState(() {
      _isSelectingFromMap = false;

      if (_activeDestinationIndex >= 0 && _activeDestinationIndex < _destinationControllers.length) {
      _destinationControllers[_activeDestinationIndex].text = coordsText.length > 35
          ? "${coordsText.substring(0, 35)}..."
          : coordsText;
      }

      if (_activeDestinationIndex == 0) {
        _selectedDestination = point;
        _destinationMarker = Marker(
          point: point,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.red, size: 50),
        );
      }

      _mapController.move(point, 16);
    });

    _showSnackBar("مختصات در فیلد نوشته شد", success: true);

    // 👈 تصمیم‌گیری بر اساس اینکه از کجا اومده
    if (_isSelectingForRouting) {
      // از پنل مسیریابی اومده → پنل مسیریابی رو باز کن
      _isRoutingPanelMinimized = false;
      _openRoutingPanel();
    } else {
      // از منوی جستجو اومده → منوی جستجو رو باز کن
      _searchController.text = coordsText.length > 40
          ? "${coordsText.substring(0, 37)}..."
          : coordsText;
      _openSearchFromFab();
      _isSearchMinimized = false;
    }
  } else {
    // تپ معمولی روی نقشه (بدون حالت انتخاب)
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
    if (_selectedDestination == null && _originLatLng == null) return;

    setState(() {
      final tempText = _originController.text;
      final tempLatLng = _originLatLng;
      final tempDestination = _selectedDestination;
      final tempDestinationText = _destinationController.text;

      _originController.text = tempDestinationText;
      _originLatLng = tempDestination;

      _destinationController.text = tempText;
      _selectedDestination = tempLatLng;

      if (_selectedDestination != null) {
        _destinationMarker = Marker(
          point: _selectedDestination!,
          width: 30,
          height: 50,
          alignment: Alignment.topCenter,
          child: Container(
            width: 6,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.brown.shade800,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 15,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: Icon(
                    Icons.flag,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
                SizedBox(height: 2),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        );
      } else {
        _destinationMarker = null;
      }

      if (_originLatLng != null) {
        _currentLocationMarker = Marker(
          point: _originLatLng!,
          width: 60,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: const Center(
              child: Text(
                "A",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      } else {
        _currentLocationMarker = _currentPosition != null
            ? Marker(
                point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
              )
            : null;
      }
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
      final destinationText = _destinationController.text.trim();
      if (destinationText == "موقعیت فعلی" || destinationText.isEmpty) {
        if (_currentPosition == null) {
          await _getCurrentLocation(force: true);
          if (_currentPosition == null) {
            _showSnackBar("موقعیت فعلی در دسترس نیست");
            return;
          }
        }
        _selectedDestination = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        _destinationMarker = Marker(
          point: _selectedDestination!,
          width: 30,
          height: 50,
          alignment: Alignment.topCenter,
          child: Container(
            width: 6,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.brown.shade800,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 15,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: Icon(
                    Icons.flag,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
                SizedBox(height: 2),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        );
        setState(() {});
      } else {
        _showSnackBar("مقصد را انتخاب کنید");
        return;
      }
    }
    setState(() => _isLoadingRoute = true);
    _routePolylines.clear();

    if (_currentPosition == null) await _getCurrentLocation(force: true);

    final startLat = _originLatLng?.latitude ?? _currentPosition!.latitude;
    final startLon = _originLatLng?.longitude ?? _currentPosition!.longitude;

    final url = Uri.parse(
        '$baseUrl/api/v1/osm/smart-route/?start_lat=$startLat&start_lon=$startLon&end_lat=${_selectedDestination!.latitude}&end_lon=${_selectedDestination!.longitude}&engine=$_selectedEngine&mode=$_selectedMode');

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          List<Polyline> lines = [];

          for (var r in (data['routes'] ?? [data])) {
            var coords = r['route_coords'] as List;

            final bool isBicycle = _selectedMode == "bicycle";
            final bool isMotorcycle = _selectedMode == "motorcycle";
            final bool isPedestrian = _selectedMode == "pedestrian";

            lines.add(Polyline(
              points: coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
              strokeWidth: (isBicycle || isMotorcycle || isPedestrian) ? 10.0 : 15.0,
              color: isMotorcycle
                  ? Colors.purple.shade600
                  : isBicycle
                      ? Colors.green.shade700
                      : isPedestrian
                          ? Colors.teal.shade700
                          : _selectedMode == "truck"
                              ? Colors.orange
                              : Colors.blue,
              pattern: isPedestrian
                  ? const StrokePattern.dotted(spacingFactor: 1.3)
                  : (isBicycle || isMotorcycle)
                      ? StrokePattern.dashed(segments: const [7.0, 15.0])
                      : StrokePattern.solid(),
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
  if (_currentPosition == null) {
    _showSnackBar("در حال دریافت موقعیت...");
    return;
  }

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "search_dialog",
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => SearchSheet(
      searchController: _searchController,
      isSearching: _isSearchingPoint,
      onClearSearch: () => _searchController.clear(),
      onPickFromMap: _enableMapSelectionMode,
      onUseCurrentLocation: _getCurrentLocation,
      onSearchPoint: _searchPoint,
      onOpenAdvancedSearch: _openAdvancedSearch,
      onOpenRoutingPanel: _openRoutingPanel,
      onMinimize: () {
        Navigator.pop(context);
        setState(() => _isSearchMinimized = true);
      },
      onClose: () {
        Navigator.pop(context);
        setState(() => _isSearchMinimized = false);
      },
      selectedDestination: _selectedDestination,
      selectedMode: _selectedMode,
      modeNotifier: _modeNotifier,
      destinationController: _destinationController,
      onShowSnackBar: () => _showSnackBar("مقصد انتخاب نشده است!", success: false),
      historyManager: _historyManager,
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

  void _enableMapSelectionMode() {
    setState(() {
      _isSelectingFromMap = true;
      _isSearchMinimized = true; // مینیمایز پنل جستجو
      _isSelectingForRouting = false;
    });
    Navigator.of(context).pop(); // بستن پنل کامل جستجو
    _showSnackBar("روی نقشه تپ کنید تا نقطه انتخاب شود", success: true);
  }
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
        initialControllers: _destinationControllers,
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
        onClose: () => Navigator.of(context).pop(),
        onMinimize: () {
          Navigator.pop(context);
          setState(() {
            _isRoutingPanelMinimized = true;
          });
        },
        onPickFromMap: (int index) {
          setState(() {
            _activeDestinationIndex = index;
            _isSelectingFromMap = true;
            _isSelectingForRouting = true;
            _isRoutingPanelMinimized = true;
          });
          _showSnackBar("روی نقشه تپ کنید تا نقطه انتخاب شود", success: true);
        },
        onProvideControllers: (List<TextEditingController> controllers) {
          setState(() {
            _destinationControllers = controllers;
          });
        },
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

  void _openAdvancedSearch({String? autoSearch}) {
    final LatLng? center = _selectedDestination ??
        (_currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : null);

    final LatLng finalCenter = center ?? const LatLng(35.6892, 51.3890);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.7,
        maxChildSize: 0.98,
        builder: (_, __) => AdvancedSearchSheet(
          centerLocation: finalCenter,
          onClose: () => Navigator.pop(context),
          onBackToSearch: () {
            Navigator.pop(context);
            _openSearchFromFab();
          },
          autoSearchCategory: autoSearch,
        ),
      ),
    );
  }

  Future<void> _searchPoint(String query) async {
    if (query.trim().isEmpty) return;

    await _historyManager.saveQuery(query);
    if (mounted) setState(() {});

    setState(() => _isSearchingPoint = true);

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&accept-language=fa');
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
              width: 50,
              height: 50,
              child: const Icon(Icons.location_searching, color: Colors.purple, size: 50),
            );
            _selectedDestination = point;
            _destinationController.text = name.length > 35 ? "${name.substring(0, 35)}..." : name;
            _destinationMarker = Marker(
              point: point,
              width: 50,
              height: 50,
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
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 12),
                        Text("در حال گرفتن موقعیت..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "search",
                  backgroundColor: _isSearchMinimized || _isRoutingPanelMinimized
                      ? (_isSearchMinimized ? Colors.blue : Colors.green)
                      : Colors.white,
                  onPressed: () {
                    if (_isRoutingPanelMinimized) {
                      _openRoutingPanel();
                      setState(() {
                        _isRoutingPanelMinimized = false;
                      });
                    } else {
                      _openSearchFromFab();
                      setState(() {
                        _isSearchMinimized = false;
                      });
                    }
                  },
                  child: Icon(
                    Icons.search,
                    color: _isSearchMinimized || _isRoutingPanelMinimized
                        ? Colors.white
                        : Colors.black87,
                  ),
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
}