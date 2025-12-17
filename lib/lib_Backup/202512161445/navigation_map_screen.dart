import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'navigation/widgets/routing_card.dart';
import 'navigation/widgets/share.dart';
import 'navigation/widgets/advanced_search.dart';
// 👇 ماژول جدید مدیریت تاریخچه
import 'navigation/widgets/history_manager.dart';

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

  // متغیر جدید برای ذخیره موقعیت‌های بین راهی
  List<LatLng> _waypoints = [];
  // متغیر جدید برای ذخیره نشانگرهای بین راهی
  List<Marker> _waypointMarkers = [];

  static const String baseUrl = "http://192.168.43.158:8000";//"http://192.168.100.176:8000";//"http://192.168.178.23:8000";//"http://192.168.0.145:8000";

  final List<Map<String, dynamic>> transportModes = [
    {"mode": "auto", "engine": "valhalla", "name": "ماشین", "icon": Icons.directions_car},
    {"mode": "motorcycle", "engine": "valhalla", "name": "موتور", "icon": Icons.motorcycle},
    {"mode": "truck", "engine": "valhalla", "name": "کامیون", "icon": Icons.local_shipping},
    {"mode": "bicycle", "engine": "valhalla", "name": "دوچرخه", "icon": Icons.directions_bike},
    {"mode": "pedestrian", "engine": "valhalla", "name": "پیاده", "icon": Icons.directions_walk},
  ];

  // 👇 ایجاد نمونه از کلاس مدیریت تاریخچه
  final SearchHistoryManager _historyManager = SearchHistoryManager();

  

  @override
  void initState() {
    super.initState();
    _originController.text = "موقعیت فعلی";
    _modeNotifier.value = _selectedMode;
    _setupAnimations();
    _getCurrentLocation();
    // 👇 بارگذاری تاریخچه هنگام شروع
    _historyManager.loadHistory().then((_) {
      if(mounted) setState(() {});
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
        _selectedDestination = point;
        _destinationController.text = coordsText.length > 35 ? "${coordsText.substring(0, 35)}..." : coordsText;
        _destinationMarker = Marker(
          point: point,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.red, size: 50),
        );
        _pendingSearchText = coordsText;
      });

      _mapController.move(point, 16);
      _showSnackBar("مختصات انتخاب شد: $coordsText", success: true);

      Future.delayed(const Duration(milliseconds: 300), () {
        _openSearchFromFab();
        setState(() {
          _isRoutingPanelMinimized = false;
        });
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
  if (_selectedDestination == null && _originLatLng == null) return;

  setState(() {
    // ذخیره موقت
    final tempText = _originController.text;
    final tempLatLng = _originLatLng;
    final tempDestination = _selectedDestination;
    final tempDestinationText = _destinationController.text;

    // جابجایی مبدأ و مقصد
    _originController.text = tempDestinationText;
    _originLatLng = tempDestination;

    _destinationController.text = tempText;
    _selectedDestination = tempLatLng;

    // بروزرسانی مارکر مقصد (پرچم گلف)
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

    // بروزرسانی مارکر مبدأ
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
      // اگر مبدأ موقعیت فعلی باشه
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

// در کلاس _NavigationMapScreenState

Future<void> _startRouting() async {
  // اگر مقصد انتخاب نشده، اما توی فیلد نوشته "موقعیت فعلی"، از موقعیت فعلی استفاده کن
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
      // مقصد = موقعیت فعلی
      _selectedDestination = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      
      // توجه: نیازی به تعریف مارکر در اینجا نیست، چون در بخش اصلی تعریف می‌شود.
      // اما برای اطمینان از بروزرسانی وضعیت:
      setState(() {
        _destinationController.text = "موقعیت فعلی"; // اطمینان از نمایش متن درست
      }); 
    } else {
      _showSnackBar("مقصد را انتخاب کنید");
      return;
    }
  }

  // 1. تنظیم وضعیت بارگذاری و پاکسازی مسیرهای قبلی
  setState(() => _isLoadingRoute = true);
  _routePolylines.clear();
  _waypointMarkers.clear(); // پاک کردن نشانگرهای بین راهی قبلی

  // 2. اطمینان از در دسترس بودن موقعیت شروع
  if (_currentPosition == null) await _getCurrentLocation(force: true);

  final startLat = _originLatLng?.latitude ?? _currentPosition!.latitude;
  final startLon = _originLatLng?.longitude ?? _currentPosition!.longitude;
  final startPoint = LatLng(startLat, startLon);

  // 3. 👇 تعریف نهایی نشانگرهای A و B با استفاده از RouteMarker
  setState(() {
    _tempSearchMarker = null; // پاک کردن نشانگر موقت جستجو

    // نشانگر مبدا (Start Point): دایره قرمز با A
    _currentLocationMarker = Marker(
      point: startPoint,
      width: 30,
      height: 30,
      // 👈 استفاده از RouteMarker
      child: const RouteMarker(letter: 'A', color: Colors.red),
    );

    // ساخت نشانگرهای مقاصد بین راهی (1, 2, 3...)
    for (int i = 0; i < _waypoints.length; i++) {
        _waypointMarkers.add(
          Marker(
            point: _waypoints[i],
            width: 30,
            height: 30,
            // 👈 استفاده از WaypointMarker جدید
            child: WaypointMarker(number: i + 1),
          ),
        );
    }

    // نشانگر مقصد (Destination Point): دایره سبز با B
    _destinationMarker = Marker(
      point: _selectedDestination!,
      width: 30,
      height: 30,
      // 👈 استفاده از RouteMarker
      child: const RouteMarker(letter: 'B', color: Colors.green),
    );
  });
  // 👆 پایان تعریف نشانگرها
  
// 4. ساخت رشته مختصات برای URL (شامل Waypoints)
  // Waypoints مختصات‌های بین راهی را با فرمت "lon1,lat1;lon2,lat2;..." در URL اضافه می‌کنند.
  String waypointsParam = '';
  if (_waypoints.isNotEmpty) {
      waypointsParam = 
          '&waypoints=${_waypoints.map((wp) => '${wp.longitude},${wp.latitude}').join(';')}' + 
          ';'; // اضافه کردن سمی‌کالن نهایی برای اطمینان از فرمت صحیح

      // توجه: برخی APIها ممکن است Waypoints را داخل پارامترهای start_lat/lon و end_lat/lon نخواهند.
      // اگر API شما Waypoints را قبول نمی‌کند، باید این بخش را اصلاح کنید.
      // فرض بر این است که API مختصات Waypoint را در پارامتر جداگانه می‌گیرد.
  }
  
  // 5. فراخوانی API با Waypoints جدید

  final url = Uri.parse(
      '$baseUrl/api/v1/osm/smart-route/?start_lat=$startLat&start_lon=$startLon$waypointsParam&end_lat=${_selectedDestination!.latitude}&end_lon=${_selectedDestination!.longitude}&engine=$_selectedEngine&mode=$_selectedMode');

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
            // خط‌چین و نقطه‌چین واقعی در نسخه 8.2.2
            pattern: isPedestrian
                ? const StrokePattern.dotted(spacingFactor: 1.3) // نقطه‌چین فاصله‌دار (۴ پیکسل نقطه، ۲۸ پیکسل فاصله)
                : (isBicycle || isMotorcycle)
                    ? StrokePattern.dashed(segments: const [7.0, 15.0]) // خط‌چین (۱۸ پیکسل خط، ۱۲ پیکسل فاصله)
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
    // مهم: اول وضعیت مینیمایز رو ریست کن
    setState(() {
      _isSearchMinimized = false;
      _isRoutingPanelMinimized = false; // اینم بهتره ریست بشه
    });

    if (_pendingSearchText != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _searchController.text = _pendingSearchText!;
        _pendingSearchText = null;
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
        transitionBuilder: (context, animation, _, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ).then((_) {
        // وقتی منو بسته شد، مطمئن شو رنگ دکمه درست باشه
        if (mounted) {
          setState(() {
            //_isSearchMinimized = false;
            _isRoutingPanelMinimized = false;
          });
        }
      });
    });
  }
  void _enableMapSelectionMode() {
    setState(() {
      _isSelectingFromMap = true;
      
      // 👈 اگر پنل مسیریابی باز است، آن را مینیمایز کن
      if (ModalRoute.of(context)?.settings.name == "routing_panel") {
        _isRoutingPanelMinimized = true;
      }
      
      // 👈 مطمئن شو که پنل جستجو بسته می‌شود
      Navigator.of(context).pop();
    });
    _showSnackBar("روی نقشه ضربه بزنید تا مقصد انتخاب شود", success: true);
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
        //modeName: _getModeName(),
        onClose: () => Navigator.of(context).pop(),
        onAddWaypoint: _addWaypoint,
        waypointsLength: _waypoints.length, // ← این خط رو اضافه کن
        onMinimize: () {
          Navigator.pop(context); // بستن Overlay
          setState(() {
            _isRoutingPanelMinimized = true; // تنظیم وضعیت مینیمایز
          });
        }

        
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

  // تابع اصلاح شده: باز کردن AdvancedSearch با رفع مشکل crash
  void _openAdvancedSearch({String? autoSearch}) {
    // اگر مقصدی انتخاب نشده بود، از موقعیت فعلی یا موقعیت پیش فرض (تهران) استفاده کن
    final LatLng? center = _selectedDestination ?? 
                            (_currentPosition != null 
                                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) 
                                : null); 
    
    final LatLng finalCenter = center ?? const LatLng(35.6892, 51.3890); // تهران

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.7,
        maxChildSize: 0.98,
        builder: (_, __) => AdvancedSearchSheet(
          centerLocation: finalCenter, // 👈 استفاده از مکان امن
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

  // 👇 به‌روزرسانی _searchPoint برای ذخیره تاریخچه
  Future<void> _searchPoint(String query) async {
    if (query.trim().isEmpty) return;

    // 👈 ذخیره جستجوی موفق با ماژول جدید
    await _historyManager.saveQuery(query);
    if(mounted) setState(() {}); // به‌روزرسانی UI تاریخچه
    
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
                ..._waypointMarkers,
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

  // در کلاس _NavigationMapScreenState، در کنار سایر توابع:

  /// افزودن مقصد فعلی به عنوان مقصد بین راهی
  void _addWaypoint() {
    if (_selectedDestination == null) {
      _showSnackBar("لطفا ابتدا یک مقصد نهایی را انتخاب کنید.");
      return;
    }

    // 1. موقعیت مقصد نهایی را به عنوان مقصد بین راهی ذخیره کن
    setState(() {
      _waypoints.add(_selectedDestination!);
      
      // 2. مقصد نهایی را پاک کن تا فیلد مقصد برای مقصد بعدی آزاد شود
      _selectedDestination = null;
      _destinationController.clear();
      _destinationMarker = null; // پاک کردن نشانگر مقصد قبلی

      // 3. نمایش پیام
      _showSnackBar("مقصد بین راهی شماره ${_waypoints.length} اضافه شد.");
    });
  }

}

/* --------------------------------------------------------------
   ویجت‌های کمکی
   -------------------------------------------------------------- */

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
              boxShadow: [BoxShadow(color: color.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Icon(icon, color: color, size: 36),
          ),
        ),
      ),
    );
  }
}

// 👇 ویجت جدید برای نمایش هر آیتم تاریخچه
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

/* --------------------------------------------------------------
   منوی جستجو + ردیف آیکون‌ها (با تاریخچه)
   -------------------------------------------------------------- */

// 1. کلاس _SearchTopSheet (فقط شامل متغیر و createSate)
class _SearchTopSheet extends StatefulWidget {
  final _NavigationMapScreenState state;

  // 👈 اصلاح: حذف خط خطا و افزودن super.key
  const _SearchTopSheet({required this.state, super.key}); 

  @override
  State<_SearchTopSheet> createState() => _SearchTopSheetState();
}

// 2. پیاده‌سازی State (اکنون می‌توان به widget.state دسترسی داشت)
class _SearchTopSheetState extends State<_SearchTopSheet> {
  
  Widget _buildIconButton(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      // _AdvancedIconButton باید در همین فایل تعریف شده باشد (قبلا در پایین فایل وجود داشت)
      child: _AdvancedIconButton(icon: icon, color: color, tooltip: tooltip, onTap: onTap), 
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👈 دسترسی به لیست تاریخچه از طریق ماژول جدید
    // 👈 دسترسی به state از طریق widget
    final _NavigationMapScreenState state = widget.state;
    final List<String> history = state._historyManager.history;
    
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // گوشه سمت چپ: دکمه‌های مینیمایز و بستن
                      Row(
                        children: [
                          // دکمه مینیمایز (-)
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.grey, size: 28),
                            tooltip: "مینیمایز",
                            onPressed: () {
                              Navigator.of(context).pop(true);
                              state._isSearchMinimized = true;
                              //(context.findAncestorStateOfType<_NavigationMapScreenState>())?.setState(() {});
                              
                            },
                          ),
                          const SizedBox(width: 8),
                          // دکمه بستن (X)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                            tooltip: "بستن",
                            onPressed: () {// دکمه بستن باید حالت مینیمایز رو غیرفعال کنه!
                              state.setState(() {
                                state._isSearchMinimized = false; 
                              });
                              // بعد منو رو ببند.
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      // گوشه سمت راست: (فعلاً خالی می‌ذاریم)
                      const SizedBox(width: 60), // فضای لازم برای تراز شدن
                    ],
                  ),

                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 5),
                  const Text("جستجو و مسیریابی", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),

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
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 25,
                              icon: const Icon(Icons.my_location, color: Colors.blue),
                              tooltip: "موقعیت فعلی من",
                              onPressed: () async {
                                await state._getCurrentLocation(force: true);
                                if (state._currentPosition != null) {
                                  final pos = state._currentPosition!;
                                  final coords = "${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}";
                                  //if (context.mounted) Navigator.of(context).pop();
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    state._searchController.text = coords;
                                    state._pendingSearchText = coords;
                                    state._selectedDestination = LatLng(pos.latitude, pos.longitude);
                                    state._showSnackBar("موقعیت فعلی شما انتخاب شد", success: true);
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 25,
                              icon: const Icon(Icons.location_on_outlined, color: Colors.red),
                              tooltip: "انتخاب از روی نقشه",
                              onPressed: state._enableMapSelectionMode,
                            ),
                          ),
                          state._isSearchingPoint
                              ? const Padding(
                                  padding: EdgeInsets.only(left: 4, right: 8),
                                  child: SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 25,
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => state._searchController.clear(),
                                  ),
                                ),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        state._searchPoint(query);
                        Navigator.of(context).pop();
                      }
                    },
                  ),

                  // 👇 بخش جدید: نمایش تاریخچه جستجو
                  if (history.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15, bottom: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("تاریخچه جستجو", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                              TextButton(
                                onPressed: () async {
                                  await state._historyManager.clearHistory(); // 👈 فراخوانی تابع از ماژول جدید
                                  state.setState(() {}); // به‌روزرسانی UI
                                },
                                child: const Text("پاک کردن همه", style: TextStyle(color: Colors.red, fontSize: 13)),
                              ),
                            ],
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          ...history.take(4).map((query) => _HistoryTile(
                                query: query,
                                onTap: () {
                                  state._searchController.text = query;
                                  state._searchPoint(query);
                                },
                                onRemove: () async {
                                  await state._historyManager.removeHistoryItem(query); // 👈 فراخوانی تابع از ماژول جدید
                                  state.setState(() {}); // به‌روزرسانی UI
                                },
                              )).toList(),
                        ],
                      ),
                    ),
                  // 👆 پایان بخش تاریخچه جستجو

                  const SizedBox(height: 10),

                  //if (state._selectedDestination != null) // این شرط قبلا حذف شده
                    SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          _buildIconButton(Icons.coffee, Colors.brown.shade700, "کافه", () {
                            state._openAdvancedSearch(autoSearch: "cafe");
                          }),
                          _buildIconButton(Icons.restaurant_menu, Colors.orange.shade700, "رستوران", () {
                            state._openAdvancedSearch(autoSearch: "restaurant");
                          }),
                          _buildIconButton(Icons.local_gas_station, Colors.red.shade600, "پمپ بنزین", () {
                            state._openAdvancedSearch(autoSearch: "fuel");
                          }),
                          _buildIconButton(Icons.medication, Colors.teal.shade700, "داروخانه", () {
                            state._openAdvancedSearch(autoSearch: "pharmacy");
                          }),
                          _buildIconButton(Icons.local_hospital, Colors.red.shade800, "بیمارستان", () {
                            state._openAdvancedSearch(autoSearch: "hospital");
                          }),
                          _buildIconButton(Icons.directions_bus, Colors.purple.shade700, "ایستگاه اتوبوس", () {
                            state._openAdvancedSearch(autoSearch: "bus_stop");
                          }),
                          _buildIconButton(Icons.store_mall_directory, Colors.blue.shade700, "سوپرمارکت", () {
                            state._openAdvancedSearch(autoSearch: "supermarket");
                          }),
                          _buildIconButton(Icons.park, Colors.green.shade700, "پارک", () {
                            state._openAdvancedSearch(autoSearch: "park");
                          }),
                          _buildIconButton(Icons.account_balance_outlined, Colors.indigo.shade700, "بانک", () {
                            state._openAdvancedSearch(autoSearch: "bank");
                          }),
                          _buildIconButton(FontAwesomeIcons.squareParking, Colors.green.shade800, "پارکینگ رایگان", () {
                            state._openAdvancedSearch(autoSearch: "free_parking");
                          }),
                          _buildIconButton(Icons.school, Colors.orange.shade800, "مدرسه و دانشگاه", () {
                            state._openAdvancedSearch(autoSearch: "school");
                          }),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      
                      _IconActionButton(icon: Icons.directions, color: Colors.blue.shade600, onTap: () async {
                        final q = state._searchController.text.trim();
                        if (q.isEmpty) return;
                        await state._searchPoint(q);
                        //if (state._selectedDestination != null) 
                        {
                          state._destinationController.text = q;
                          state._modeNotifier.value = state._selectedMode;
                          Navigator.of(context).pop();
                          state._openRoutingPanel();
                        }
                      }),
                      _IconActionButton(icon: Icons.search_rounded, color: Colors.green.shade600, onTap: () {
                        if (state._searchController.text.trim().isNotEmpty) {
                          state._searchPoint(state._searchController.text);
                          Navigator.of(context).pop();
                        }
                      }),
                      //if (state._selectedDestination != null)
                        _IconActionButton(icon: Icons.share, color: Colors.purple.shade600, onTap: () {
                          // 👇 اضافه کردن چک null
                          if (state._selectedDestination == null) {
                            state._showSnackBar("مقصد انتخاب نشده است!", success: false);
                            return;
                          }
                          ShareLocationButton.shareLocationStatic(
                              location: state._selectedDestination!,
                              placeName: state._searchController.text.trim().isNotEmpty
                                  ? state._searchController.text.trim()
                                  : null,
                              message: "اینجا را پیدا کردم!",
                            );
                        }),
                      //if (state._selectedDestination != null)
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
    );
  }
}