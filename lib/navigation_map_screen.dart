import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  int _selectedIndex = 1;

  final List<Marker> _markers = [
    Marker(
      point: LatLng(35.6892, 51.3890),
      width: 40,
      height: 40,
      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
    ),
    Marker(
      point: LatLng(48.8566, 2.3522),
      width: 40,
      height: 40,
      child: const Icon(Icons.location_on, color: AppTheme.primary, size: 40),
    ),
    Marker(
      point: LatLng(35.6762, 139.6503),
      width: 40,
      height: 40,
      child: const Icon(Icons.location_on, color: Colors.orange, size: 40),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = Tween<double>(begin: 56, end: 0).animate(
      CurvedAnimation(parent: _searchController, curve: Curves.easeInOut),
    );
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
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to screen $index')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Map & Navigation',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.appBarTheme.foregroundColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        isDarkMode: widget.isDarkMode,
                        onThemeChanged: widget.onThemeChanged,
                      ),
                    ),
                  );
                  break;
                case 'help':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                  break;
                case 'logout':
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings), SizedBox(width: 12), Text('Settings')])),
              const PopupMenuItem(value: 'help', child: Row(children: [Icon(Icons.help), SizedBox(width: 12), Text('Help')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 12), Text('Logout', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // نقشه
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(35.6892, 51.3890),
              initialZoom: 12,
              onTap: (_, latLng) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tapped: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}')),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tourai.app',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Explore Nearby + AI Suggested
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 320,
              child: PageView(
                controller: PageController(viewportFraction: 0.85),
                children: [
                  _buildExploreSection(theme),
                  _buildAISuggestedSection(theme),
                ],
              ),
            ),
          ),

          // Search Icon → Expandable
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
                        if (_isSearchExpanded) {
                          _searchController.forward();
                        } else {
                          _searchController.reverse();
                        }
                      });
                    },
                    child: Container(
                      width: _searchAnimation.value,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isSearchExpanded
                          ? Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(Icons.search, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Search destinations...',
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.tune, size: 20),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Filters opened')),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _isSearchExpanded = false;
                                      _searchController.reverse();
                                    });
                                  },
                                ),
                              ],
                            )
                          : const Center(
                              child: Icon(Icons.search, size: 24),
                            ),
                    ),
                  );
                },
              ),
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
        backgroundColor: theme.colorScheme.surface,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () {
          _mapController.move(LatLng(35.6892, 51.3890), 15);
        },
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  // Explore Nearby
  Widget _buildExploreSection(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.cardColor.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.explore, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Explore Nearby', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildNearbyCard(
                  'Milad Tower',
                  '2.1 km',
                  'https://images.unsplash.com/photo-1578662996442-48f60103fc96?auto=format&fit=crop&w=800',
                  theme,
                ),
                _buildNearbyCard(
                  'Azadi Tower',
                  '5.3 km',
                  'https://images.unsplash.com/photo-1581093450021-4a7360e9a6b5?auto=format&fit=crop&w=800',
                  theme,
                ),
                _buildNearbyCard(
                  'Golestan Palace',
                  '8.7 km',
                  'https://images.unsplash.com/photo-1585208798174-6cedd78e0198?auto=format&fit=crop&w=800',
                  theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // AI Suggested
  Widget _buildAISuggestedSection(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.cardColor.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple),
                const SizedBox(width: 8),
                Text('AI Suggested Spot', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildAICard('Darband Mountain Trail', 'Hiking • 4.8', 'Perfect for sunset', theme),
                _buildAICard('Tajrish Bazaar', 'Local Food • 4.6', 'Try Gheymeh!', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // کارت نزدیک
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
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(distance, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // کارت AI
  Widget _buildAICard(String title, String rating, String tip, ThemeData theme) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primary.withOpacity(0.2),
        child: const Icon(Icons.auto_awesome, color: AppTheme.primary),
      ),
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rating),
          Text(tip, style: TextStyle(color: Colors.purple[300], fontStyle: FontStyle.italic)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.navigation),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigating...')));
        },
      ),
    );
  }

  @override
  void didUpdateWidget(covariant NavigationMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDarkMode != oldWidget.isDarkMode) {
      setState(() {});
    }
  }
}