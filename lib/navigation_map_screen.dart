import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme.dart';
import 'settings_screen.dart';
import 'help_screen.dart';

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

class _NavigationMapScreenState extends State<NavigationMapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  late AnimationController _searchController;
  late Animation<double> _searchAnimation;
  bool _isSearchExpanded = false;

  late AnimationController _exploreController;
  late Animation<double> _exploreHeight;
  bool _isExploreExpanded = false;

  late AnimationController _aiController;
  late Animation<double> _aiHeight;
  bool _isAIExpanded = false;

  int _selectedIndex = 1;

  List<Polyline> _routePolylines = [];
  bool _isLoadingRoute = false;

  final LatLng _startPoint = LatLng(35.6892, 51.3890); // انقلاب
  final LatLng _endPoint = LatLng(35.8116, 51.4272);   // تجریش

  Future<void> _fetchRoute() async {
    if (_isLoadingRoute) return;
    setState(() => _isLoadingRoute = true);

    final url = Uri.parse(
      'http://10.0.2.2:8000/osm/smart-route/?start_lat=${_startPoint.latitude}&start_lon=${_startPoint.longitude}&end_lat=${_endPoint.latitude}&end_lon=${_endPoint.longitude}'
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
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${data['routes'].length} مسیر دریافت شد!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطا در دریافت مسیر')));
    } finally {
      setState(() => _isLoadingRoute = false);
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

  final List<Marker> _markers = [
    Marker(point: LatLng(35.6892, 51.3890), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
    Marker(point: LatLng(48.8566, 2.3522), width: 40, height: 40, child: const Icon(Icons.location_on, color: AppTheme.primary, size: 40)),
    Marker(point: LatLng(35.6762, 139.6503), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.orange, size: 40)),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _searchAnimation = Tween<double>(begin: 56, end: 0).animate(CurvedAnimation(parent: _searchController, curve: Curves.easeInOut));

    _exploreController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _exploreHeight = Tween<double>(begin: 60, end: 280).animate(CurvedAnimation(parent: _exploreController, curve: Curves.easeInOut));

    _aiController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _aiHeight = Tween<double>(begin: 60, end: 280).animate(CurvedAnimation(parent: _aiController, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchAnimation = Tween<double>(begin: 56, end: MediaQuery.of(context).size.width - 32)
        .animate(CurvedAnimation(parent: _searchController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _exploreController.dispose();  // درست شد!
    _aiController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
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
          // نقشه — همیشه زیر همه چیز
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: LatLng(35.6892, 51.3890), initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.tourai.app',
              ),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Explore + AI Cards
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Explore Card
                AnimatedBuilder(
                  animation: _exploreHeight,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExploreExpanded = !_isExploreExpanded;
                          if (_isExploreExpanded) {
                            _exploreController.forward();
                            if (_isAIExpanded) {
                              _isAIExpanded = false;
                              _aiController.reverse();
                            }
                          } else {
                            _exploreController.reverse();
                          }
                        });
                      },
                      child: Container(
                        height: _exploreHeight.value,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.cardColor.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
                        ),
                        child: _isExploreExpanded
                            ? _buildExploreExpanded(theme)
                            : _buildTabHeader(Icons.explore, 'Explore Nearby', AppTheme.primary),
                      ),
                    );
                  },
                ),

                // AI Card
                AnimatedBuilder(
                  animation: _aiHeight,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAIExpanded = !_isAIExpanded;
                          if (_isAIExpanded) {
                            _aiController.forward();
                            if (_isExploreExpanded) {
                              _isExploreExpanded = false;
                              _exploreController.reverse();
                            }
                          } else {
                            _aiController.reverse();
                          }
                        });
                      },
                      child: Container(
                        height: _aiHeight.value,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.cardColor.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
                        ),
                        child: _isAIExpanded
                            ? _buildAIExpanded(theme)
                            : _buildTabHeader(Icons.auto_awesome, 'AI Suggested', Colors.purple),
                      ),
                    );
                  },
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
                builder: (context, child) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                        _isSearchExpanded ? _searchController.forward() : _searchController.reverse();
                      });
                    },
                    child: Container(
                      width: _searchAnimation.value == 0 ? 56 : _searchAnimation.value,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: _isSearchExpanded
                          ? Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(Icons.search),
                                const SizedBox(width: 8),
                                const Expanded(child: TextField(decoration: InputDecoration(hintText: 'جستجو...', border: InputBorder.none))),
                                IconButton(icon: const Icon(Icons.tune), onPressed: () {}),
                                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isSearchExpanded = false)),
                              ],
                            )
                          : const Center(child: Icon(Icons.search)),
                    ),
                  );
                },
              ),
            ),
          ),

          // دکمه مسیریابی
          Positioned(
            bottom: 180,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: AppTheme.primary,
              heroTag: "route_fab",
              onPressed: _isLoadingRoute ? null : _fetchRoute,
              child: _isLoadingRoute
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Icon(Icons.directions, size: 32),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _mapController.move(LatLng(35.6892, 51.3890), 15),
        child: const Icon(Icons.my_location),
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