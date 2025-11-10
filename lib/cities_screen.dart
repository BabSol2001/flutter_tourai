import 'package:flutter/material.dart';
import 'theme.dart';
import 'settings_screen.dart';

class CitiesScreen extends StatefulWidget {
  @override
  _CitiesScreenState createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _cities = [
    {
      'name': 'شیراز',
      'country': 'ایران',
      'image': 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?auto=format&fit=crop&w=500&q=80',
      'rating': 4.8,
      'price': '۲,۵۰۰,۰۰۰ تومان',
      'description': 'شهر شعر و گل',
    },
    {
      'name': 'اصفهان',
      'country': 'ایران',
      'image': 'https://images.unsplash.com/photo-1581093450021-4a7360e9a6b5?auto=format&fit=crop&w=500&q=80',
      'rating': 4.9,
      'price': '۳,۰۰۰,۰۰۰ تومان',
      'description': 'نصف جهان',
    },
    {
      'name': 'تهران',
      'country': 'ایران',
      'image': 'https://images.unsplash.com/photo-1585208798174-6cedd78e0198?auto=format&fit=crop&w=500&q=80',
      'rating': 4.2,
      'price': '۱,۸۰۰,۰۰۰ تومان',
      'description': 'پایتخت ایران',
    },
    {
      'name': 'مشهد',
      'country': 'ایران',
      'image': 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?auto=format&fit=crop&w=500&q=80',
      'rating': 4.7,
      'price': '۲,۲۰۰,۰۰۰ تومان',
      'description': 'مرکز زیارتی',
    },
    {
      'name': 'کیش',
      'country': 'ایران',
      'image': 'https://images.unsplash.com/photo-1581093450021-4a7360e9a6b5?auto=format&fit=crop&w=500&q=80',
      'rating': 4.6,
      'price': '۴,۵۰۰,۰۰۰ تومان',
      'description': 'جزیره تفریحی',
    },
  ];

  List<Map<String, dynamic>> get _filteredCities {
    return _cities.where((city) {
      if (_searchQuery.isEmpty && _selectedFilter == 'All') return true;
      bool matchesSearch = city['name'].toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesFilter = _selectedFilter == 'All' || city['country'] == _selectedFilter;
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
    final cardColor = theme.cardTheme.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'شهرها',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor),
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
          // جستجو و فیلتر
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'جستجو در شهرها...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _searchQuery.isEmpty ? null : () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
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
                      _buildFilterChip('All', 'همه', true),
                      _buildFilterChip('Iran', 'ایران', false),
                      _buildFilterChip('Europe', 'اروپا', false),
                      _buildFilterChip('Asia', 'آسیا', false),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredCities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('هیچ شهری پیدا نشد', style: TextStyle(color: Colors.grey, fontSize: 18)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _filteredCities.length,
                    itemBuilder: (context, index) {
                      final city = _filteredCities[index];
                      return _buildCityCard(city, theme);
                    },
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
        onSelected: (v) => setState(() => _selectedFilter = v ? value : 'All'),
        selectedColor: AppTheme.primary.withOpacity(0.1),
        checkmarkColor: AppTheme.primary,
        backgroundColor: Colors.grey.withOpacity(0.1),
      ),
    );
  }

  Widget _buildCityCard(Map<String, dynamic> city, ThemeData theme) {
    final textColor = theme.textTheme.bodyMedium?.color;
    final cardColor = theme.cardTheme.color;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('جزئیات ${city['name']}')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                city['image'],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey.withOpacity(0.2),
                    child: const Icon(Icons.location_city, size: 50, color: Colors.grey),
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
                    city['name'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                  Text(
                    city['country'],
                    style: TextStyle(fontSize: 14, color: textColor?.withOpacity(0.7)),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${city['rating']}'),
                      const Spacer(),
                      Text(
                        city['price'],
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  Text(
                    city['description'],
                    style: TextStyle(fontSize: 12, color: textColor?.withOpacity(0.8)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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