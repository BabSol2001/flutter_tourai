import 'package:flutter/material.dart';
import 'theme.dart';
import 'settings_screen.dart';

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  _CustomerAccountScreenState createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final isLarge = size.width >= 840;

    // پدینگ و اسپیسینگ دینامیک
    final padding = EdgeInsets.all(isLarge ? 32 : isTablet ? 24 : 16);
    final cardSpacing = isLarge ? 32.0 : isTablet ? 24.0 : 16.0;
    final fontScale = MediaQuery.of(context).textScaler;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'حساب کاربری',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: fontScale.scale(20),
            color: theme.appBarTheme.foregroundColor,
          ),
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
      body: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // پروفایل
            _buildProfileCard(theme, isTablet, fontScale),
            SizedBox(height: cardSpacing),

            // سفرهای اخیر
            Text(
              'سفرهای اخیر',
              style: TextStyle(
                fontSize: fontScale.scale(isTablet ? 22 : 18),
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: cardSpacing / 2),
            _buildRecentTrips(theme, size, isTablet, isLarge, fontScale),
            SizedBox(height: cardSpacing),

            // رزروهای جاری
            Text(
              'رزروهای جاری',
              style: TextStyle(
                fontSize: fontScale.scale(isTablet ? 22 : 18),
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: cardSpacing / 5),
            _buildCurrentBookings(theme, isTablet, fontScale),
            SizedBox(height: cardSpacing),

            // دکمه خروج
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context, theme),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'خروج از حساب',
                  style: TextStyle(
                    fontSize: fontScale.scale(16),
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(ThemeData theme, bool isTablet, TextScaler fontScale) {
    final cardColor = theme.cardTheme.color;
    final textColor = theme.textTheme.bodyMedium?.color;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: isTablet ? 36 : 30,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.person, color: Colors.white, size: isTablet ? 38 : 30),
            ),
            SizedBox(width: isTablet ? 24 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بابک عسل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontScale.scale(isTablet ? 20 : 18),
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'babak@example.com',
                    style: TextStyle(
                      fontSize: fontScale.scale(14),
                      color: textColor?.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    '+98 912 345 6789',
                    style: TextStyle(
                      fontSize: fontScale.scale(14),
                      color: textColor?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: AppTheme.primary, size: isTablet ? 28 : 24),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ویرایش پروفایل')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTrips(
    ThemeData theme,
    Size size,
    bool isTablet,
    bool isLarge,
    TextScaler fontScale,
  ) {
    final cardWidth = isLarge ? size.width * 0.25 : isTablet ? size.width * 0.35 : 160.0;
    final cardHeight = isLarge ? 180.0 : isTablet ? 160.0 : 140.0;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            margin: EdgeInsets.only(right: isLarge ? 20 : 12),
            child: _buildTripCard(index, theme, cardHeight * 0.50, fontScale),
          );
        },
      ),
    );
  }

  Widget _buildTripCard(int index, ThemeData theme, double imageHeight, TextScaler fontScale) {
    final cardColor = theme.cardTheme.color;
    final textColor = theme.textTheme.bodyMedium?.color;
    final cities = ['شیراز', 'اصفهان', 'تهران', 'مشهد', 'کیش'];

    return Card(
      elevation: 5,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: imageHeight,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1), // کاهش پدینگ عمودی
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cities[index % cities.length],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontScale.scale(12), color: textColor),
                ),
                SizedBox(height: 1),
                Text(
                  '3 روز',
                  style: TextStyle(fontSize: fontScale.scale(12), color: textColor?.withOpacity(0.7)),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: TextStyle(fontSize: fontScale.scale(12), color: textColor?.withOpacity(0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBookings(ThemeData theme, bool isTablet, TextScaler fontScale) {
    final bookings = [
      {'city': 'شیراز', 'date': '۱۴۰۴/۰۸/۱۵', 'status': 'در انتظار تایید'},
      {'city': 'اصفهان', 'date': '۱۴۰۴/۰۹/۰۱', 'status': 'تایید شده'},
      {'city': 'تهران', 'date': '۱۴۰۴/۰۹/۱۰', 'status': 'لغو شده'},
    ];

    if (isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 12,
        ),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(bookings[index], theme, fontScale);
        },
      );
    } else {
      return Column(
        children: bookings
            .map((booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildBookingCard(booking, theme, fontScale),
                ))
            .toList(),
      );
    }
  }

  Widget _buildBookingCard(Map<String, String> booking, ThemeData theme, TextScaler fontScale) {
    final cardColor = theme.cardTheme.color;
    final textColor = theme.textTheme.bodyMedium?.color;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.primary.withOpacity(0.2),
          child: Icon(Icons.flight, color: AppTheme.primary, size: 20),
        ),
        title: Text(
          'سفر به ${booking['city']}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontScale.scale(15), color: textColor),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تاریخ: ${booking['date']}',
              style: TextStyle(fontSize: fontScale.scale(13), color: textColor?.withOpacity(0.7)),
            ),
            Text(
              'وضعیت: ${booking['status']}',
              style: TextStyle(
                fontSize: fontScale.scale(13),
                color: booking['status'] == 'تایید شده'
                    ? Colors.green
                    : booking['status'] == 'لغو شده'
                        ? Colors.red
                        : Colors.orange,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: textColor?.withOpacity(0.5)),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('جزئیات رزرو ${booking['city']}')),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        title: Text('خروج از حساب', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
        content: Text('آیا مطمئن هستید؟', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('خروج موفقیت‌آمیز!'), backgroundColor: Colors.red),
              );
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}