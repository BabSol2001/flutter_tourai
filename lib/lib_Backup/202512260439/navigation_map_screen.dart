import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';  // ←←← این خط جدید

import 'navigation/widgets/routing_card.dart';
import 'navigation/widgets/advanced_search.dart';
import 'navigation/widgets/history_manager.dart';
import 'navigation/widgets/search_sheet.dart';
import 'navigation/widgets/guidance_button.dart';

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

  final ValueNotifier<String> _modeNotifier = ValueNotifier<String>("auto");
  final ValueNotifier<String> _profileNotifier = ValueNotifier<String>("fastest");

  final TextEditingController _searchController = TextEditingController();
  bool _isSearchingPoint = false;
  Marker? _tempSearchMarker;

  bool _isSelectingFromMap = false;
  bool _isSearchMinimized = false;
  bool _isRoutingPanelMinimized = false;
  bool _isSelectingForRouting = false;
  bool _isGuidanceMode = false; // آیا در حالت راهنمایی هستیم؟

  StreamSubscription<Position>? _positionStream;  // برای دنبال کردن موقعیت لایو
  Marker? _userPositionMarker;  // مارکر outline برای موقعیت کاربر
  double _currentBearing = 0.0;  // جهت فعلی (برای چرخش نقشه)
  StreamSubscription<CompassEvent>? _compassStream;  // برای جهت دستگاه

  List<TextEditingController> _destinationControllers = [];
  int _activeDestinationIndex = 0;

  List<LatLng?> _destinationLatLngs = [];

  OverlayEntry? _routingPanelOverlay;

  static const String baseUrl = "http://192.168.0.105:8000";

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

  // ←←← تابع geocode خودکار (خارج از _startRouting)
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

      // اگر کاربر در حال انتخاب مبدا بود (index == -1)
      if (_activeDestinationIndex == -1) {
        _originLatLng = point;
        _originController.text = coordsText;
      }
      // اگر در حال انتخاب یکی از مقصدها بود
      else if (_activeDestinationIndex >= 0 && _activeDestinationIndex < _destinationControllers.length) {
        _destinationControllers[_activeDestinationIndex].text = coordsText;

        // آپدیت مختصات مقصد
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

    // اگر از پنل مسیریابی اومده بود، دوباره بازش کن
    if (_isSelectingForRouting) {
      _isRoutingPanelMinimized = false;
      _openRoutingPanel();
    }
  } 
  // اگر مستقیم روی نقشه تپ کرده (نه در حالت انتخاب)
  else {
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
      origin = await _geocodeAddress(_originController.text);  // اگر آدرس تایپ کرده
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

    // مقصدها — با geocode خودکار اگر مختصات نداشت
    bool hasValidDestination = false;
    for (int i = 0; i < _destinationControllers.length; i++) {
      final text = _destinationControllers[i].text.trim();
      print("مقصد $i - متن: '$text'");

      if (text.isNotEmpty) {
        LatLng? location;

        if (_destinationLatLngs.length > i && _destinationLatLngs[i] != null) {
          location = _destinationLatLngs[i];
          print("مقصد $i - مختصات موجود: ${location!.latitude}, ${location.longitude}");
        } else {
          print("مقصد $i - در حال جستجوی خودکار مختصات...");
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
          print("مقصد $i - مختصات پیدا شد: ${location.latitude}, ${location.longitude}");
        }

        waypoints.add(location!);
        hasValidDestination = true;
      }
    }

    print("لیست نهایی waypoints: $waypoints");
    print("تعداد نقاط: ${waypoints.length}");

    if (waypoints.length < 2 || !hasValidDestination) {
      print("خطا: مقصد معتبر نیست");
      _showSnackBar("حداقل یک مقصد معتبر انتخاب کنید");
      setState(() => _isLoadingRoute = false);
      return;
    }

    print("در حال ارسال به بک‌اند...");
    setState(() => _isLoadingRoute = true);

    final coordsList = waypoints.map((p) => "${p.longitude},${p.latitude}").join('|');
    print("coords string: $coordsList");

    final url = Uri.parse('$baseUrl/api/v1/osm/smart-route/?coords=$coordsList&engine=$_selectedEngine&mode=$_selectedMode');

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 40));
      print("پاسخ سرور: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print("داده دریافتی: $data");

        if (data['success'] == true) {
          List<Polyline> lines = [];
          final routes = data['routes'] as List;

          for (int i = 0; i < routes.length; i++) {
            var r = routes[i];
            var coords = r['route_coords'] as List;
            final points = coords.map((c) => LatLng(c[0].toDouble(), c[1].toDouble())).toList();

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
          });

          print("مسیر و مارکرها رسم شدند");
          _fitRouteToScreen();
        } else {
          _showSnackBar("سرور مسیر پیدا نکرد");
        }
      } else {
        _showSnackBar("خطای سرور: ${res.statusCode}");
      }
    } catch (e) {
      print("خطا در درخواست: $e");
      _showSnackBar("خطا در ارتباط با سرور");
    } finally {
      setState(() => _isLoadingRoute = false);
      print("=== پایان مسیریابی ===");
    }
  }

void _startGuidance() {
  // دنبال کردن موقعیت کاربر
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

  // دنبال کردن جهت دستگاه (نسخه جدید)
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
    _resetNorth();  // نقشه رو به شمال برگردون
    _showSnackBar("راهنمایی پیمایش متوقف شد", success: true);
  }

  // بقیه متدها (openSearchFromFab، enableMapSelectionMode، openRoutingPanel، openAdvancedSearch، searchPoint، build) دقیقاً مثل قبل

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
  
  // اول هر دیالوگ یا شیت قبلی رو ببند
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  }

  Future.delayed(const Duration(milliseconds: 200), () {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "routing_panel",
      barrierColor: Colors.black.withOpacity(0.3), // ← تاریکی ملایم، نقشه دیده می‌شه
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
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20, // ← این خط کیبورد رو درست می‌کنه
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
                urlTemplate: "https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: [
                if (_currentLocationMarker != null) _currentLocationMarker!,
                ..._waypointMarkers,
                if (_tempSearchMarker != null) _tempSearchMarker!,
                if (_userPositionMarker != null) _userPositionMarker!,  // ← جدید: مارکر outline کاربر
              ]),
            ],
          ),
          
          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                              // دکمه شروع راهنمایی (فقط وقتی مسیر رسم شده دیده می‌شه)
              GuidanceFloatingButton(
                isRouteDrawn: _routePolylines.isNotEmpty,
                onPressed: () {
                  if (_isGuidanceMode) {
                    _stopGuidance();
                  } else {
                    setState(() => _isGuidanceMode = true);
                    if (_routePolylines.isNotEmpty) {
                      final firstPoint = _routePolylines.first.points.first;
                      _mapController.move(firstPoint, 19);
                    }
                    _startGuidance();
                    _showSnackBar("راهنمایی پیمایش شروع شد! 🚗", success: true);
                  }
                },
              ),
              const SizedBox(height: 12), // فاصله بین دکمه‌ها
                FloatingActionButton(
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
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: "fab_north",
                  onPressed: _resetNorth,
                  child: const Icon(Icons.explore),
                ),
                const SizedBox(height: 12),
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