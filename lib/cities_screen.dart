import 'package:flutter/material.dart';
import 'package:flutter_tourai/city_detail_screen.dart';
import 'theme.dart';
import 'settings_screen.dart';

// ── جدید ────────────────────────────────────────────────
import 'services/api_service.dart';           // ApiService
import 'models/city.dart';                   // مدل City

class CitiesScreen extends StatefulWidget {
  const CitiesScreen({super.key});

  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  late Future<List<City>> _citiesFuture;

  final ApiService _apiService = ApiService();

  // ثابت کردن دامنه سرور (برای توسعه محلی - بعداً می‌تونی از Provider یا env بگیری)
  static const String serverBaseUrl = 'http://192.168.0.145:8000';

  @override
  void initState() {
    super.initState();
    _loadCities();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  void _loadCities() {
    _citiesFuture = _apiService.getCities();
  }

  List<City> _filterCities(List<City> cities) {
    if (_searchQuery.isEmpty && _selectedFilter == 'All') {
      return cities;
    }

    final query = _searchQuery.toLowerCase();
    return cities.where((city) {
      final matchesSearch = city.name.toLowerCase().contains(query);
      final matchesFilter =
          _selectedFilter == 'All' ||
          (city.countryName?.toLowerCase() == _selectedFilter.toLowerCase());
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text(
          'شهرها',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.appBarTheme.foregroundColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      isDarkMode: theme.brightness == Brightness.dark,
                      onThemeChanged: (v) {},
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [Icon(Icons.settings), SizedBox(width: 12), Text('تنظیمات')]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // جستجو و فیلتر (تقریباً بدون تغییر)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'جستجو در شهرها...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All', 'همه', _selectedFilter == 'All'),
                      _buildFilterChip('Iran', 'ایران', _selectedFilter == 'Iran'),
                      _buildFilterChip('Europe', 'اروپا', _selectedFilter == 'Europe'),
                      _buildFilterChip('Asia', 'آسیا', _selectedFilter == 'Asia'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // بخش اصلی - FutureBuilder
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _loadCities());
                await _citiesFuture; // منتظر می‌ماند تا درخواست جدید تمام شود
              },
              child: FutureBuilder<List<City>>(
                future: _citiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('خطا: ${snapshot.error.toString().split('\n').first}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() => _loadCities()),
                            child: const Text('تلاش مجدد'),
                          ),
                        ],
                      ),
                    );
                  }

                  final allCities = snapshot.data ?? [];
                  final filtered = _filterCities(allCities);

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'هیچ شهری پیدا نشد',
                            style: TextStyle(color: Colors.grey, fontSize: 18),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final city = filtered[index];
                      return _buildCityCard(city);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'All';
          });
        },
        selectedColor: AppTheme.primary.withOpacity(0.1),
        checkmarkColor: AppTheme.primary,
        backgroundColor: Colors.grey.withOpacity(0.1),
      ),
    );
  }

  Widget _buildCityCard(City city) {
    // پیدا کردن آخرین عکس معتبر (جدیدترین آپلود شده)
    CityMedia? imageMedia;
    for (final m in city.mediaItems.reversed) {
      if (m.mediaType == 'image' && m.url != null && m.url!.isNotEmpty) {
        imageMedia = m;
        break;
      }
    }

    final rawUrl = imageMedia?.url;
    final displayImageUrl = rawUrl != null && rawUrl.isNotEmpty
        ? '$serverBaseUrl$rawUrl'
        : 'assets/images/default_city.jpg';

    print("DEBUG CitiesScreen - شهر ${city.name} - URL عکس کارت: $displayImageUrl");

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CityDetailScreen(city: city),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image(
                image: displayImageUrl.startsWith('assets/')
                    ? const AssetImage('assets/images/default_city.jpg')
                    : NetworkImage(displayImageUrl),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  print("ERROR - لود عکس کارت شهر ${city.name} شکست خورد: $error");
                  return Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 50),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    city.countryName ?? 'نامشخص',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(city.rating?.toStringAsFixed(1) ?? "—"),
                      const Spacer(),
                      Text(
                        city.priceText ?? 'قیمت نامشخص',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                  if (city.description != null && city.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        city.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}