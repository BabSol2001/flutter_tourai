import 'package:flutter/material.dart';
import 'package:flutter_tourai/help_screen.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
  
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _pushNotifications;
  late bool _emailNotifications;
  late bool _darkMode;

  @override
  void initState() {
    super.initState();
    _pushNotifications = true;
    _emailNotifications = false;
    _darkMode = widget.isDarkMode;
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.foregroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'تنظیمات',
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search, color: theme.appBarTheme.foregroundColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جستجو در تنظیمات...')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Card(
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primary,
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بابک عسل',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                          ),
                          Text(
                            'babak@example.com',
                            style: TextStyle(fontSize: 14, color: textColor?.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: AppTheme.primary),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ویرایش پروفایل')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Appearance Section
            Text(
              'ظاهر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildThemeOption(
                    title: 'حالت روشن',
                    icon: Icons.light_mode,
                    isSelected: !_darkMode,
                    onTap: () {
                      setState(() => _darkMode = false);
                      widget.onThemeChanged(false);
                    },
                  ),
                  const Divider(height: 1),
                  _buildThemeOption(
                    title: 'حالت تاریک',
                    icon: Icons.dark_mode,
                    isSelected: _darkMode,
                    onTap: () {
                      setState(() => _darkMode = true);
                      widget.onThemeChanged(true);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notifications Section
            Text(
              'اعلان‌ها',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.notifications,
              title: 'اعلان‌های پوش',
              trailing: Switch(
                value: _pushNotifications,
                onChanged: (value) => setState(() => _pushNotifications = value),
                activeThumbColor: AppTheme.primary,
              ),
            ),
            _buildSettingTile(
              icon: Icons.email,
              title: 'اعلان‌های ایمیل',
              trailing: Switch(
                value: _emailNotifications,
                onChanged: (value) => setState(() => _emailNotifications = value),
                activeThumbColor: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Privacy & Security
            Text(
              'حریم خصوصی و امنیت',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.privacy_tip,
              title: 'تنظیمات حریم خصوصی',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تنظیمات حریم خصوصی')),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.security,
              title: 'امنیت حساب',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16), // خطا رفع شد
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تنظیمات امنیت')),
                );
              },
            ),
            const SizedBox(height: 24),

            // Help
            Text(
              'کمک',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.help_outline,
              title: 'مرکز کمک',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.feedback,
              title: 'ارسال بازخورد',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('بازخورد ارسال شد')),
                );
              },
            ),
            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: cardColor,
                      title: Text('خروج', style: TextStyle(color: textColor)),
                      content: Text('آیا مطمئن هستید که می‌خواهید خارج شوید؟', style: TextStyle(color: textColor)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('لغو'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('با موفقیت خارج شدید!'), backgroundColor: Colors.red),
                            );
                          },
                          child: const Text('خروج', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'خروج از حساب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? Border.all(color: AppTheme.primary) : null,
              ),
              child: Icon(icon, color: isSelected ? AppTheme.primary : theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color;
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
