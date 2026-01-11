import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

import 'navigation/widgets/routing_card.dart';
import 'navigation/widgets/advanced_search.dart';
import 'navigation/widgets/history_manager.dart';
import 'navigation/widgets/search_sheet.dart';
import 'navigation/widgets/guidance_button.dart';
import 'navigation/widgets/guidance_manager.dart';
import 'navigation/widgets/guidance_simulator.dart';
import 'navigation/widgets/traffic_sign_indicator.dart';

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

  List<Marker> _waypointMarkers = [];

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  LatLng? _selectedDestination;
  LatLng? _originLatLng;

  double _currentMapRotation = 0.0;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  List<Polyline> _routePolylines = [];
  bool _isLoadingRoute = false;

  String _selectedEngine = "valhalla";
  String _selectedMode = "auto";

  String? _currentSignType;
  String? _currentSignValue;

  final ValueNotifier<String> _modeNotifier = ValueNotifier<String>("auto");
  final ValueNotifier<String> _profileNotifier = ValueNotifier<String>("fastest");

  final TextEditingController _searchController = TextEditingController();
  bool _isSearchingPoint = false;
  Marker? _tempSearchMarker;
  Marker? _searchResultMarker;

  bool _isSelectingFromMap = false;
  bool _isSearchMinimized = false;
  bool _isRoutingPanelMinimized = false;
  bool _isSelectingForRouting = false;
  bool _isGuidanceMode = false;

  StreamSubscription<Position>? _positionStream;
  Marker? _userPositionMarker;
  double _currentBearing = 0.0;
  StreamSubscription<CompassEvent>? _compassStream;

  List<TextEditingController> _destinationControllers = [];
  int _activeDestinationIndex = 0;

  List<LatLng?> _destinationLatLngs = [];

  OverlayEntry? _routingPanelOverlay;

  GuidanceManager? _guidanceManager;
  bool _isSimulationMode = false;
  GuidanceSimulator? _guidanceSimulator;
  String _currentInstruction = "";
  IconData _currentTurnIcon = Icons.arrow_upward;
  double _currentDistance = 0.0;
  double _distanceToNext = 0.0;

  List<Map<String, dynamic>> _maneuvers = [];
  List<LatLng> _routePoints = [];

  String? _selectedWeatherLayer;  // null یعنی خاموش

  List<String> _views = [
    "https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
  ];
  int _currentViewIndex = 0;

  String? _searchResultPlaceName;

  String _tileUrl = "https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png";

  List<TileLayer> _overlayLayers = [];

  bool _showCrowdLayer = false;
  bool _showTrafficSignsLayer = false;
  bool _showRailwayLayer = false;
  bool _showPublicTransportLayer = false;
  bool _showWeatherLayer = false;
  bool _showBikePathsLayer = false;
  bool _showPedestrianPathsLayer = false;

  static const String baseUrl = "http://192.168.0.145:8000";

  final List<Map<String, dynamic>> transportModes = [
    {"mode": "auto", "engine": "valhalla", "name": "ماشین", "icon": Icons.directions_car},
    {"mode": "motorcycle", "engine": "valhalla", "name": "موتور", "icon": Icons.motorcycle},
    {"mode": "truck", "engine": "valhalla", "name": "کامیون", "icon": Icons.local_shipping},
    {"mode": "bicycle", "engine": "valhalla", "name": "دوچرخه", "icon": Icons.directions_bike},
    {"mode": "pedestrian", "engine": "valhalla", "name": "پیاده", "icon": Icons.directions_walk},
  ];

  static const List<Map<String, String>> weatherOptions = [
    {"value": "", "label": "خاموش"},
    {"value": "precipitation_new", "label": "بارش (باران/برف)"},
    {"value": "temp_new", "label": "دما"},
    {"value": "wind_new", "label": "باد"},
    {"value": "clouds_new", "label": "ابرها"},
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

    _destinationControllers.add(_destinationController);
    _destinationLatLngs = <LatLng?>[null];
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

  Future<LatLng?> _geocodeAddress(String query) async {
    if (query.trim().isEmpty) return null;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'TourAI/1.0'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      print("خطا در geocode خودکار: $e");
    }
    return null;
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
    final coordsText = "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";

    if (_isSelectingFromMap) {
      setState(() {
        _isSelectingFromMap = false;

        if (_activeDestinationIndex == -1) {
          _originLatLng = point;
          _originController.text = coordsText;
        } else if (_activeDestinationIndex >= 0 && _activeDestinationIndex < _destinationControllers.length) {
          _destinationControllers[_activeDestinationIndex].text = coordsText;

          if (_destinationLatLngs.length <= _activeDestinationIndex) {
            _destinationLatLngs.length = _activeDestinationIndex + 1;
          }
          _destinationLatLngs[_activeDestinationIndex] = point;

          if (_activeDestinationIndex == 0) {
            _selectedDestination = point;
          }
        }

        _mapController.move(point, 16);
      });

      _showSnackBar(
        _activeDestinationIndex == -1 ? "مبدا انتخاب شد" : "مقصد انتخاب شد",
        success: true,
      );

      if (_isSelectingForRouting) {
        _isRoutingPanelMinimized = false;
        _openRoutingPanel();
      }
    } else {
      setState(() {
        if (_destinationControllers.isNotEmpty) {
          _destinationControllers[0].text = coordsText;
          _selectedDestination = point;
          if (_destinationLatLngs.isNotEmpty) {
            _destinationLatLngs[0] = point;
          }
        }
        _mapController.move(point, 16);
      });
      _showSnackBar("مقصد انتخاب شد", success: true);
    }
  }

  void _swapOriginAndDestination() {
    if (_originLatLng == null && _destinationControllers.isEmpty) return;

    setState(() {
      final tempText = _originController.text;
      final tempLatLng = _originLatLng;

      if (_destinationControllers.isNotEmpty) {
        final destinationText = _destinationControllers[0].text;
        _originController.text = destinationText;
        _destinationControllers[0].text = tempText;
        
        _originLatLng = _selectedDestination;
        _selectedDestination = tempLatLng;
      }
      _waypointMarkers.clear();
      _routePolylines.clear();
    });

    _showSnackBar("مبدا و مقصد سوییچ شدند", success: true);
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

  Future<void> _startRouting() async {
    List<LatLng> waypoints = [];

    // مبدا
    LatLng? origin;
    if (_originLatLng != null) {
      origin = _originLatLng!;
    } else if (_originController.text != "موقعیت فعلی" && _originController.text.isNotEmpty) {
      origin = await _geocodeAddress(_originController.text);
      if (origin == null) {
        _showSnackBar("مبدا پیدا نشد");
        return;
      }
    } else if (_currentPosition != null) {
      origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      await _getCurrentLocation(force: true);
      if (_currentPosition == null) return;
      origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    waypoints.add(origin);

    print("=== شروع مسیریابی ===");
    print("مبدا: ${origin.latitude}, ${origin.longitude}");

    // مقصدها
    bool hasValidDestination = false;
    for (int i = 0; i < _destinationControllers.length; i++) {
      final text = _destinationControllers[i].text.trim();
      print("مقصد $i - متن: '$text'");

      if (text.isNotEmpty) {
        LatLng? location;

        if (_destinationLatLngs.length > i && _destinationLatLngs[i] != null) {
          location = _destinationLatLngs[i];
        } else {
          location = await _geocodeAddress(text);
          if (location == null) {
            _showSnackBar("نتوانستیم مکان '$text' را پیدا کنیم");
            setState(() => _isLoadingRoute = false);
            return;
          }
          setState(() {
            if (_destinationLatLngs.length <= i) {
              _destinationLatLngs.length = i + 1;
            }
            _destinationLatLngs[i] = location;
            if (i == 0) _selectedDestination = location;
          });
        }

        waypoints.add(location!);
        hasValidDestination = true;
      }
    }

    if (waypoints.length < 2 || !hasValidDestination) {
      _showSnackBar("حداقل یک مقصد معتبر انتخاب کنید");
      setState(() => _isLoadingRoute = false);
      return;
    }

    setState(() => _isLoadingRoute = true);

    final coordsList = waypoints.map((p) => "${p.longitude},${p.latitude}").join('|');
    final url = Uri.parse('$baseUrl/api/v1/osm/smart-route/?coords=$coordsList&engine=$_selectedEngine&mode=$_selectedMode');

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print("پاسخ سرور: $data");
        
        if (data['success'] == true) {
          List<Polyline> lines = [];
          final routes = data['routes'] as List;
          var route = routes[0];
          var coords = route['route_coords'] as List;

          final List<LatLng> points = coords.map((c) => LatLng(c[0].toDouble(), c[1].toDouble())).toList();

          for (int i = 0; i < routes.length; i++) {
            Color routeColor = i == 0 ? Colors.blue.shade700 : Colors.green.shade600;
            double width = i == 0 ? 10.0 : 8.0;

            lines.add(Polyline(
              points: points,
              strokeWidth: width,
              color: routeColor.withOpacity(0.8),
            ));
          }

          List<Marker> markers = waypoints.asMap().entries.map((entry) {
            int idx = entry.key;
            LatLng p = entry.value;

            if (idx == 0) {
              IconData icon;
              switch (_selectedMode) {
                case "auto": icon = Icons.directions_car; break;
                case "motorcycle": icon = Icons.motorcycle; break;
                case "truck": icon = Icons.local_shipping; break;
                case "bicycle": icon = Icons.directions_bike; break;
                default: icon = Icons.directions_walk; break;
              }

              return Marker(
                point: p,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
              );
            }

            return Marker(
              point: p,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                ),
                child: Center(
                  child: Text(
                    idx.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          }).toList();

          setState(() {
            _routePolylines = lines;
            _waypointMarkers = markers;

            _maneuvers = (route['maneuvers'] as List?)
              ?.map((m) => m as Map<String, dynamic>)
              .toList() ?? [];

            _routePoints = points;

            if (_maneuvers.isNotEmpty) {
              _currentInstruction = _maneuvers[0]['instruction'] ?? "مستقیم بروید";
              _currentTurnIcon = Icons.arrow_upward;
            } else {
              _currentInstruction = "در حال حرکت";
              _currentTurnIcon = Icons.arrow_upward;
            }
          });

          _fitRouteToScreen();
        } else {
          _showSnackBar("مسیر پیدا نشد");
        }
      } else {
        _showSnackBar("خطای سرور: ${res.statusCode}");
      }
    } catch (e) {
      print("خطا در درخواست: $e");
      _showSnackBar("خطا در ارتباط با سرور");
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  void _startGuidance() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _userPositionMarker = Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade800, width: 3),
              color: Colors.transparent,
            ),
            child: const Icon(
              Icons.circle_outlined,
              color: const Color(0xFF1B5E20),
              size: 40,
            ),
          ),
        );

        _mapController.move(
          LatLng(position.latitude, position.longitude),
          19,
        );
      });
    });

    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        setState(() {
          _currentBearing = event.heading!;
          _mapController.rotate(-event.heading!);
        });
      }
    });
  }

  void _stopGuidance() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    setState(() {
      _isGuidanceMode = false;
      _userPositionMarker = null;
    });
    _resetNorth();
    _showSnackBar("راهنمایی پیمایش متوقف شد", success: true);
  }

  void _startSimulation() {
    if (_routePolylines.isEmpty || _routePoints.isEmpty) {
      _showSnackBar("ابتدا یک مسیر رسم کنید!", success: false);
      return;
    }

    setState(() {
      _isSimulationMode = true;
      _isGuidanceMode = true;
    });

    _guidanceManager = GuidanceManager(
      mapController: _mapController,
      onUserMarkerUpdate: (marker) => setState(() => _userPositionMarker = marker),
      onInstructionUpdate: (instruction, icon, distance) {
        setState(() {
          _currentInstruction = instruction;
          _currentTurnIcon = icon;
          _distanceToNext = distance;
        });
      },
      maneuvers: _maneuvers,
      routePoints: _routePoints,
      vehicleMode: _selectedMode,
    );

    _guidanceSimulator = GuidanceSimulator(
      mapController: _mapController,
      onUserMarkerUpdate: (marker) => setState(() => _userPositionMarker = marker),
      routePoints: _routePoints,
      onPositionUpdate: (position) {
        _guidanceManager?.updateUserPosition(position);
      },
    );

    _guidanceSimulator!.startSimulation(
      stepDuration: const Duration(milliseconds: 1000),
    );

    _showSnackBar("شبیه‌سازی مسیر شروع شد! ▶️", success: true);
  }

  void _stopSimulation() {
    _guidanceSimulator?.stopSimulation();
    _guidanceManager?.stopGuidance();

    setState(() {
      _isSimulationMode = false;
      _isGuidanceMode = false;
      _currentInstruction = "";
    });

    _resetNorth();
    _showSnackBar("شبیه‌سازی متوقف شد", success: true);
  }


  void _showLayersMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => ListView(
          children: [
            SwitchListTile(
              title: const Text("ازدحام جمعیت"),
              value: _showCrowdLayer,
              onChanged: (val) {
                setStateModal(() => _showCrowdLayer = val);
                setState(() => _updateOverlayLayers());
              },
            ),
            SwitchListTile(
              title: const Text("تابلوهای راهنمایی"),
              value: _showTrafficSignsLayer,
              onChanged: (val) {
                setStateModal(() => _showTrafficSignsLayer = val);
                setState(() => _updateOverlayLayers());
              },
            ),
            SwitchListTile(
              title: const Text("راه آهن"),
              value: _showRailwayLayer,
              onChanged: (val) {
                setStateModal(() => _showRailwayLayer = val);
                setState(() => _updateOverlayLayers());
              },
            ),
            SwitchListTile(
              title: const Text("حمل و نقل عمومی"),
              value: _showPublicTransportLayer,
              onChanged: (val) {
                setStateModal(() => _showPublicTransportLayer = val);
                setState(() => _updateOverlayLayers());
              },
            ),
            SwitchListTile(
              title: const Text("آب و هوا"),
              value: _showWeatherLayer,
              onChanged: (val) {
                setStateModal(() => _showWeatherLayer = val);
                setState(() => _updateOverlayLayers());
              },
            ),
            
            // ... بقیه سوئیچ‌ها (راه‌آهن، حمل و نقل و ...)

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("لایه آب و هوا:", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      DropdownButton<String?>(
        value: _selectedWeatherLayer,
        isExpanded: true,
        hint: const Text("انتخاب نوع لایه"),
        items: weatherOptions.map((option) {
          return DropdownMenuItem<String?>(
            value: option["value"],
            child: Text(option["label"]!),
          );
        }).toList(),
        onChanged: (newValue) {
          setStateModal(() {
            _selectedWeatherLayer = newValue;
          });
          setState(() {
            _updateOverlayLayers();
          });
        },
      ),
    ],
  ),
),
            
            SwitchListTile(
              title: const Text("مسیر دوچرخه"),
              value: _showBikePathsLayer,
              onChanged: (val) {
                setStateModal(() => _showBikePathsLayer = val);
                setState(() => _updateOverlayLayers());
              },
            ),
            SwitchListTile(
              title: const Text("مسیر پیاده"),
              value: _showPedestrianPathsLayer,
              onChanged: (val) {
                setStateModal(() => _showPedestrianPathsLayer = val);
                setState(() => _updateOverlayLayers());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateOverlayLayers() {
    _overlayLayers.clear();

    print("به‌روزرسانی لایه‌ها شروع شد...");

    if (_showRailwayLayer) {
      _overlayLayers.add(TileLayer(
        urlTemplate: "https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png",
      ));
      print("لایه راه‌آهن اضافه شد");
    }

    if (_showPublicTransportLayer) {
      _overlayLayers.add(TileLayer(
        urlTemplate: "https://tile.memomaps.de/tilegen/{z}/{x}/{y}.png",
      ));
      print("لایه حمل و نقل عمومی اضافه شد");
    }

    if (_showWeatherLayer) {
    const String apiKey = "b30cea8dbe88001d89eca6d08f10a0cf";

    // اگر هنوز چیزی انتخاب نشده (بعید هست چون از بالا تنظیم کردیم)، باز هم پیش‌فرض بگذار
    final String layerType = _selectedWeatherLayer != null && _selectedWeatherLayer!.isNotEmpty
        ? _selectedWeatherLayer!
        : "precipitation";  // پیش‌فرض نهایی

    final String weatherUrl = 
        "https://tile.openweathermap.org/map/$layerType/{z}/{x}/{y}.png?appid=$apiKey";

    print("لایه آب و هوا فعال شد:");
    print("   نوع لایه: $layerType");
    print("   URL کامل: $weatherUrl");
    print("--------------------------------------------------");

    _overlayLayers.add(TileLayer(
      urlTemplate: weatherUrl,
    ));
  }

  setState(() {}); // اگر لازم بود UI رو بروز کن
}

  void _openSearchFromFab() {
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
        onShowSnackBar: () => _showSnackBar("مقصد انتخاب نشده است!"),
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
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isSelectingFromMap = true;
          _isSelectingForRouting = false;
        });
        _showSnackBar("روی نقشه تپ کنید", success: true);
      }
    });
  }

  void _openRoutingPanel() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "routing_panel",
        barrierColor: Colors.black.withOpacity(0.3),
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) {
          return Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: RoutingTopPanel(
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
                          _destinationController.clear();
                          _selectedDestination = null;
                          _waypointMarkers.clear();
                          if (_destinationLatLngs.isNotEmpty) _destinationLatLngs[0] = null;
                        }),
                        onClearOrigin: () => setState(() {
                          _originLatLng = null;
                          _originController.text = "موقعیت فعلی";
                        }),
                        onStartRouting: _startRouting,
                        onClose: () => Navigator.pop(context),
                        onMinimize: () {
                          Navigator.pop(context);
                          setState(() => _isRoutingPanelMinimized = true);
                        },
                        onProfileChanged: (newProfile) {
                          _profileNotifier.value = newProfile;
                        },
                        onPickFromMap: (int index) {
                          setState(() {
                            _activeDestinationIndex = index;
                            _isSelectingFromMap = true;
                            _isSelectingForRouting = true;
                            _isRoutingPanelMinimized = true;

                            if (index == -1) {
                              _showSnackBar("مبدا را روی نقشه انتخاب کنید", success: true);
                            } else {
                              _showSnackBar("مقصد را روی نقشه انتخاب کنید", success: true);
                            }
                          });
                          Navigator.pop(context);
                        },
                        onProvideControllers: (controllers) {
                          setState(() {
                            _destinationControllers = controllers;
                            if (_destinationLatLngs.length < controllers.length) {
                              _destinationLatLngs.addAll(List.filled(controllers.length - _destinationLatLngs.length, null));
                            } else if (_destinationLatLngs.length > controllers.length) {
                              _destinationLatLngs = _destinationLatLngs.sublist(0, controllers.length);
                            }
                          });
                        },
                        onDestinationGeocoded: (int index, LatLng location) {
                          setState(() {
                            if (_destinationLatLngs.length <= index) {
                              _destinationLatLngs.length = index + 1;
                            }
                            _destinationLatLngs[index] = location;
                            if (index == 0) _selectedDestination = location;
                          });
                        },
                        onOriginGeocoded: (LatLng location) {
                          setState(() {
                            _originLatLng = location;
                          });
                          _showSnackBar("مبدا از نقشه انتخاب شد", success: true);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      );
    });
  }

  void _openAdvancedSearch({String? autoSearch}) {
    LatLng finalCenter = _selectedDestination ?? 
        (_currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : const LatLng(35.6892, 51.3890));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        builder: (_, __) => AdvancedSearchSheet(
          centerLocation: finalCenter,
          onClose: () => Navigator.pop(context),
          onBackToSearch: () {
            Navigator.pop(context);
            _openSearchFromFab();
          },
          autoSearchCategory: autoSearch,
          onSelectPlace: _handlePlaceSelected,
        ),
      ),
    );
  }

  Future<void> _searchPoint(String query) async {
    if (query.trim().isEmpty) return;
    await _historyManager.saveQuery(query);
    setState(() => _isSearchingPoint = true);

    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
    try {
      final res = await http.get(url, headers: {'User-Agent': 'TourAI/1.0'});
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final point = LatLng(lat, lon);
          
          setState(() {
            _selectedDestination = point;
            _destinationController.text = data[0]['display_name'];
            _tempSearchMarker = Marker(
              point: point,
              width: 50, height: 50,
              child: const Icon(Icons.location_pin, color: Colors.purple, size: 30),
            );
          });
          _mapController.move(point, 16);
        }
      }
    } catch (_) {
      _showSnackBar("خطا در جستجو");
    } finally {
      setState(() => _isSearchingPoint = false);
    }
  }

  void _handlePlaceSelected(LatLng point, String? name) async {
    final String fullAddress = await _getReverseGeocode(point);

    final String displayText = name?.trim().isNotEmpty == true 
        ? "$name - $fullAddress" 
        : fullAddress;

    setState(() {
      _selectedDestination = point;
      _destinationController.text = displayText;

      if (_destinationLatLngs.isEmpty) {
        _destinationLatLngs = [point];
      } else {
        _destinationLatLngs[0] = point;
      }

      _searchResultPlaceName = displayText;

      _searchResultMarker = Marker(
        point: point,
        width: 90,
        height: 90,
        child: _buildPlaceMarker(displayText),
      );
    });

    _mapController.move(point, 17.5);
    _showSnackBar("مقصد تنظیم شد: $displayText", success: true);

    _searchController.text = displayText;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_isRoutingPanelMinimized || _isSearchMinimized || !Navigator.canPop(context)) {
        _openRoutingPanel();
        setState(() {
          _isRoutingPanelMinimized = false;
          _isSearchMinimized = false;
        });
      } else {
        _openSearchFromFab();
      }
    });
  }

  Widget _buildPlaceMarker(String name) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const Icon(
          Icons.location_pin,
          color: Colors.deepPurple,
          size: 64,
          shadows: [
            Shadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),

        Positioned(
          top: -12,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Future<String> _getReverseGeocode(LatLng point) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&limit=1',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'TourAI/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          return data['display_name'];
        }
      }
    } catch (e) {
      print("خطا در reverse geocode: $e");
    }
    return "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";
  }

  Future<void> _getOvercrowd(LatLng center, String activity) async {
    final url = Uri.parse('$baseUrl/api/v1/osm/overcrowd/?lat=${center.latitude}&lon=${center.longitude}&radius=500&activity=$activity');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _showSnackBar("ازدحام تقریبی برای $activity: ${data['estimation']} نفر");
      }
    } catch (e) {
      _showSnackBar("خطا در گرفتن ازدحام");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(35.6892, 51.3890),
              initialZoom: 12,
              onTap: (_, p) => _onMapTapped(p),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'tourai.com',
              ),
              ..._overlayLayers,
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: [
                if (_currentLocationMarker != null) _currentLocationMarker!,
                ..._waypointMarkers,
                if (_tempSearchMarker != null) _tempSearchMarker!,
                if (_userPositionMarker != null) _userPositionMarker!,
                if (_searchResultMarker != null) _searchResultMarker!,
              ]),
            ],
          ),

          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(24),
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Row(
                  children: [
                    Icon(_currentTurnIcon, color: Colors.white, size: 68),
                    const SizedBox(width: 16),
                    if (_currentSignType != null)
                      TrafficSignIndicator(
                        signType: _currentSignType,
                        signValue: _currentSignValue,
                      ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        _currentInstruction,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
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
                if (_routePolylines.isNotEmpty)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: "fab_guidance",
                        backgroundColor: _isGuidanceMode ? Colors.orange.shade700 : Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          if (_isGuidanceMode) {
                            _guidanceManager?.stopGuidance();
                            setState(() {
                              _isGuidanceMode = false;
                              _currentInstruction = "";
                            });
                            _resetNorth();
                          } else {
                            if (_routePolylines.isEmpty) {
                              _showSnackBar("ابتدا یک مسیر رسم کنید!", success: false);
                              return;
                            }

                            setState(() => _isGuidanceMode = true);

                            _guidanceManager = GuidanceManager(
                              mapController: _mapController,
                              onUserMarkerUpdate: (marker) => setState(() => _userPositionMarker = marker),
                              onInstructionUpdate: (instruction, icon, distance) {
                                setState(() {
                                  _currentInstruction = instruction;
                                  _currentTurnIcon = icon;
                                  _currentDistance = distance;
                                });
                              },
                              maneuvers: _maneuvers,
                              routePoints: _routePoints,
                              vehicleMode: _selectedMode,
                            );

                            _guidanceManager!.startGuidance();

                            if (_routePoints.isNotEmpty) {
                              _mapController.move(_routePoints.first, 19);
                            }

                            _showSnackBar("راهبری شروع شد! 🚗", success: true);
                          }
                        },
                        child: Icon(
                          _isGuidanceMode ? Icons.stop : Icons.navigation,
                          size: 32,
                        ),
                        tooltip: _isGuidanceMode ? "توقف راهبری" : "شروع راهبری",
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton.small(
                        heroTag: "fab_simulate",
                        backgroundColor: Colors.blue.shade700,
                        onPressed: _routePolylines.isEmpty
                            ? null
                            : () {
                                if (_isSimulationMode) {
                                  _stopSimulation();
                                } else {
                                  _startSimulation();
                                }
                              },
                        child: Icon(
                          _isSimulationMode ? Icons.stop : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: _isSimulationMode ? "توقف شبیه‌سازی" : "شروع شبیه‌سازی مسیر",
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),

                FloatingActionButton.small(
                  heroTag: "fab_layers_menu",
                  onPressed: _showLayersMenu,
                  child: const Icon(Icons.layers),
                  tooltip: "لایه‌های نقشه",
                ),
                const SizedBox(height: 10),

                FloatingActionButton.small(
                  heroTag: "fab_view",
                  onPressed: () {
                    setState(() {
                      _currentViewIndex = (_currentViewIndex + 1) % _views.length;
                      _tileUrl = _views[_currentViewIndex];
                    });
                    _showSnackBar("ویو نقشه تغییر کرد!");
                  },
                  child: const Icon(Icons.map),
                  tooltip: "تغییر ویو نقشه",
                ),
                const SizedBox(height: 10),

                FloatingActionButton.small(
                  heroTag: "fab_google_maps",
                  backgroundColor: Colors.yellowAccent,
                  onPressed: () {
                    if (_routePoints.isEmpty || _routePoints.length < 2) {
                      _showSnackBar("ابتدا یک مسیر رسم کنید!", success: false);
                      return;
                    }

                    final origin = _routePoints.first;
                    final destination = _routePoints.last;

                    final googleMapsUrl = "https://www.google.com/maps/dir/?api=1"
                        "&origin=${origin.latitude},${origin.longitude}"
                        "&destination=${destination.latitude},${destination.longitude}"
                        "&travelmode=driving";

                    launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                  },
                  child: Image.asset(
                    'assets/images/google_maps_icon.png',
                    width: 30,
                    height: 30,
                  ),
                  tooltip: "باز کردن در گوگل مپس",
                ),
                const SizedBox(height: 10),

                FloatingActionButton.small(
                  heroTag: "fab_search",
                  backgroundColor: (_isSearchMinimized || _isRoutingPanelMinimized)
                      ? (_isSearchMinimized ? Colors.blue : Colors.green)
                      : Colors.white,
                  onPressed: () {
                    if (_isRoutingPanelMinimized) _openRoutingPanel();
                    else _openSearchFromFab();
                    setState(() {
                      _isSearchMinimized = false;
                      _isRoutingPanelMinimized = false;
                    });
                  },
                  child: Icon(Icons.search,
                      color: (_isSearchMinimized || _isRoutingPanelMinimized) ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 10),

                FloatingActionButton.small(
                  heroTag: "fab_north",
                  onPressed: _resetNorth,
                  child: const Icon(Icons.explore),
                ),
                const SizedBox(height: 10),

                FloatingActionButton.small(
                  heroTag: "fab_locate",
                  backgroundColor: Colors.blue,
                  onPressed: () => _getCurrentLocation(force: true),
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}