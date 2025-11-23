import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
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
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _originPoint;

  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  late AnimationController _searchController;
  late Animation<double> _searchAnimation;
  bool _isSearchExpanded = false;

  late AnimationController _exploreController;
  late Animation<double> _exploreHeight;
  bool _isExploreExpanded = false;

  late AnimationController _aiController;
  late Animation<double> _aiHeight;
  bool _isAIExpanded = false;

  // جدید: انیمیشن برای کارت مسیریابی شناور
  late AnimationController _routingController;
  late Animation<double> _routingHeight;
  bool _isRoutingExpanded = false;

  int _selectedIndex = 1;
  List<Polyline> _routePolylines = [];
  bool _isLoadingRoute = false;

  final List<Marker> _markers = [
    Marker(point: LatLng(35.6892, 51.3890), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
    Marker(point: LatLng(48.8566, 2.3522), width: 40, height: 40, child: const Icon(Icons.location_on, color: AppTheme.primary, size: 40)),
    Marker(point: LatLng(35.6762, 139.6503), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.orange, size: 40)),
  ];

  @override
  void initState() {
    super.initState();

    _mapController.mapEventStream.listen((_) {
      _currentMapRotation = _mapController.camera.rotation;
    });

    _rotationController = AnimationController(duration: const Duration(milliseconds: 750), vsync: this);
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic));
    _rotationAnimation.addListener(() {
      _mapController.rotate(_rotationAnimation.value);
      _currentMapRotation = _rotationAnimation.value;
    });

    _searchController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _exploreController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _aiController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    // جدید: کنترلر برای کارت مسیریابی
    _routingController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _routingHeight = Tween<double>(begin: 70, end: 420).animate(CurvedAnimation(parent: _routingController, curve: Curves.easeOutCubic));

    _searchAnimation = Tween<double>(begin: 56, end: 0).animate(CurvedAnimation(parent: _searchController, curve: Curves.easeInOut));
    _exploreHeight = Tween<double>(begin: 60, end: 280).animate(CurvedAnimation(parent: _exploreController, curve: Curves.easeInOut));
    _aiHeight = Tween<double>(begin: 60, end: 280).animate(CurvedAnimation(parent: _aiController, curve: Curves.easeInOut));

    _getCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchAnimation = Tween<double>(
      begin: 56,
      end: MediaQuery.of(context).size.width - 32,
    ).animate(CurvedAnimation(parent: _searchController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _rotationController.dispose();
    _searchController.dispose();
    _exploreController.dispose();
    _aiController.dispose();
    _routingController.dispose(); // جدید
    super.dispose();
  }

  void _resetNorth() {
    _rotationAnimation = Tween<double>(begin: _currentMapRotation, end: 0.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic),
    );
    _rotationController.reset();
    _rotationController.forward();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً GPS را روشن کنید')));
      setState(() => _isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اجازه دسترسی به موقعیت داده نشد')));
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اجازه موقعیت برای همیشه رد شده!')));
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _currentLocationMarker = Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 50,
          height: 50,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40, shadows: [Shadow(color: Colors.black54, blurRadius: 10)]),
        );
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در گرفتن موقعیت: $e')));
      setState(() => _isLoadingLocation = false);
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    double south = points[0].latitude, north = points[0].latitude;
    double west = points[0].longitude, east = points[0].longitude;

    for (var p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }

    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
      padding: const EdgeInsets.all(100),
    ));
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  // جدید: باز کردن کارت مسیریابی شناور (مثل AI Suggested)
  void _toggleRoutingCard() {
    setState(() {
      _isRoutingExpanded = !_isRoutingExpanded;
      _isRoutingExpanded ? _routingController.forward() : _routingController.reverse();

      // وقتی مسیریابی باز شد، بقیه رو ببند
      if (_isRoutingExpanded) {
        if (_isExploreExpanded) {
          _isExploreExpanded = false;
          _exploreController.reverse();
        }
        if (_isAIExpanded) {
          _isAIExpanded = false;
          _aiController.reverse();
        }
      }
    });

    if (_isRoutingExpanded) {
      _originController.text = "موقعیت فعلی";
      _destinationController.clear();
      _originPoint = _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : null;
    }
  }

  Future<void> _startRouting() async {
    if (_originPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('موقعیت فعلی در دسترس نیست')));
      return;
    }
    if (_destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً مقصد را وارد کنید')));
      return;
    }

    setState(() => _isLoadingRoute = true);

    final LatLng destination = LatLng(35.7446, 51.3753); // برج میلاد

    final url = Uri.parse(
      'http://10.0.2.2:8000/osm/smart-route/?start_lat=${_originPoint!.latitude}&start_lon=${_originPoint!.longitude}&end_lat=${destination.latitude}&end_lon=${destination.longitude}'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Polyline> polylines = [];

        for (var route in data['routes']) {
          List<LatLng> points = (route['route_coords'] as List)
              .map((coord) => LatLng(coord[0] as double, coord[1] as double))
              .toList();

          polylines.add(Polyline(
            points: points,
            strokeWidth: 7,
            color: route['is_fastest'] == true ? Colors.blue : Colors.green.withOpacity(0.8),
          ));
        }

        setState(() {
          _routePolylines = polylines;
          if (polylines.isNotEmpty) _fitBounds(polylines.first.points);
          _isRoutingExpanded = false;
          _routingController.reverse();
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("مسیر با موفقیت رسم شد!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطا در دریافت مسیر')));
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text('Map & Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(isDarkMode: widget.isDarkMode, onThemeChanged: widget.onThemeChanged)));
              } else if (value == 'help') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings), SizedBox(width: 12), Text('Settings')])),
              const PopupMenuItem(value: 'help', child: Row(children: [Icon(Icons.help), SizedBox(width: 12), Text('Help')])),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : LatLng(35.6892, 51.3890),
              initialZoom: 15,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.tourai.app'),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: [if (_currentLocationMarker != null) _currentLocationMarker!, ..._markers]),
            ],
          ),

          // وقتی کارت مسیریابی بازه، نقشه کمی تیره بشه
          if (_isRoutingExpanded || _isExploreExpanded || _isAIExpanded)
            Container(color: Colors.black.withOpacity(0.5)),

          if (_isLoadingLocation)
            Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text("در حال گرفتن موقعیت شما..."),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // کارت مسیریابی شناور — دقیقاً مثل AI Suggested
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Explore Nearby
                AnimatedBuilder(
                  animation: _exploreHeight,
                  builder: (context, child) => GestureDetector(
                    onTap: () => setState(() {
                      _isExploreExpanded = !_isExploreExpanded;
                      _isExploreExpanded ? _exploreController.forward() : _exploreController.reverse();
                      if (_isExploreExpanded) {
                        _isAIExpanded = false;
                        _aiController.reverse();
                        _isRoutingExpanded = false;
                        _routingController.reverse();
                      }
                    }),
                    child: Container(
                      height: _exploreHeight.value,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
                      ),
                      child: _isExploreExpanded ? _buildExploreExpanded(theme) : _buildTabHeader(Icons.explore, 'Explore Nearby', AppTheme.primary),
                    ),
                  ),
                ),

                // AI Suggested
                AnimatedBuilder(
                  animation: _aiHeight,
                  builder: (context, child) => GestureDetector(
                    onTap: () => setState(() {
                      _isAIExpanded = !_isAIExpanded;
                      _isAIExpanded ? _aiController.forward() : _aiController.reverse();
                      if (_isAIExpanded) {
                        _isExploreExpanded = false;
                        _exploreController.reverse();
                        _isRoutingExpanded = false;
                        _routingController.reverse();
                      }
                    }),
                    child: Container(
                      height: _aiHeight.value,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
                      ),
                      child: _isAIExpanded ? _buildAIExpanded(theme) : _buildTabHeader(Icons.auto_awesome, 'AI Suggested', Colors.purple),
                    ),
                  ),
                ),

                // کارت جدید: کارت مسیریابی شناور
                AnimatedBuilder(
                  animation: _routingHeight,
                  builder: (context, child) => GestureDetector(
                    onTap: _toggleRoutingCard,
                    child: Container(
                      height: _routingHeight.value,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: _isRoutingExpanded ? _buildRoutingCard(theme) : _buildTabHeader(Icons.directions, 'مسیریابی سریع', AppTheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _searchAnimation,
                builder: (context, child) => GestureDetector(
                  onTap: () {
                    setState(() => _isSearchExpanded = !_isSearchExpanded);
                    _isSearchExpanded ? _searchController.forward() : _searchController.reverse();
                  },
                  child: Container(
                    width: _searchAnimation.value == 0 ? 56 : _searchAnimation.value,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.70),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: _isSearchExpanded
                        ? Row(children: [
                            const SizedBox(width: 16),
                            const Icon(Icons.search),
                            const SizedBox(width: 8),
                            const Expanded(child: TextField(decoration: InputDecoration(hintText: 'جستجو...', border: InputBorder.none))),
                            IconButton(icon: const Icon(Icons.tune), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isSearchExpanded = false)),
                          ])
                        : const Center(child: Icon(Icons.search)),
                  ),
                ),
              ),
            ),
          ),

          // دکمه موقعیت فعلی + دکمه قطب‌نما — هر جا بخوای می‌تونی بذاریشون!
          Positioned(
            bottom: 10, // بهتره یه کم بالاتر باشه که با کارت‌ها تداخل نکنه
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // دکمه قطب‌نما
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 6,
                  heroTag: "north_fab",
                  onPressed: _resetNorth,
                  child: const Icon(Icons.explore, size: 30),
                ),

                // فاصله فقط ۵ واحد بین دو دکمه
                const SizedBox(width: 5),

                // دکمه موقعیت فعلی
                FloatingActionButton(
                  backgroundColor: const Color.fromARGB(221, 0, 0, 0),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  heroTag: "location_fab",
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.my_location, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // جدید: کارت مسیریابی شناور
  Widget _buildRoutingCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTabHeader(Icons.directions, 'مسیریابی سریع', AppTheme.primary),
          const SizedBox(height: 16),
          TextField(
            controller: _originController,
            readOnly: true,
            decoration: InputDecoration(
              hintText: "مبدا",
              prefixIcon: const Icon(Icons.my_location, color: AppTheme.primary),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              suffixIcon : const Icon(Icons.location_on, color: AppTheme.primary),
              suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              hintText: "مقصد را وارد کنید...",
              prefixIcon: const Icon(Icons.location_on, color: Colors.red),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoadingRoute ? null : _startRouting,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isLoadingRoute
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text("شروع مسیریابی", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Icon(Icons.keyboard_arrow_up, size: 20, color: color.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _buildExploreExpanded(ThemeData theme) {
    return Column(
      children: [
        _buildTabHeader(Icons.explore, 'Explore Nearby', AppTheme.primary),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _buildNearbyCard('برج میلاد', '۲.۱ کیلومتر', 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800', theme),
              _buildNearbyCard('برج آزادی', '۵.۳ کیلومتر', 'https://images.unsplash.com/photo-1581093450021-4a7360e9a6b5?w=800', theme),
              _buildNearbyCard('کاخ گلستان', '۸.۷ کیلومتر', 'https://images.unsplash.com/photo-1585208798174-6cedd78e0198?w=800', theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIExpanded(ThemeData theme) {
    return Column(
      children: [
        _buildTabHeader(Icons.auto_awesome, 'AI Suggested', Colors.purple),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _buildAICard('دربند', 'کوهنوردی • ۴.۸', 'عصر عالیه!', theme),
              _buildAICard('بازار تجریش', 'غذا • ۴.۶', 'قیمه نثار بخور!', theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyCard(String title, String distance, String imageUrl, ThemeData theme) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(height: 100, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(distance, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAICard(String title, String rating, String tip, ThemeData theme) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.2), child: const Icon(Icons.auto_awesome, color: AppTheme.primary)),
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rating),
        Text(tip, style: TextStyle(color: Colors.purple[300], fontStyle: FontStyle.italic)),
      ]),
      trailing: IconButton(icon: const Icon(Icons.navigation), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('در حال مسیریابی...')))),
    );
  }
}