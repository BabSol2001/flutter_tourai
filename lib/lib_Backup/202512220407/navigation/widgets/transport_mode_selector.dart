import 'package:flutter/material.dart';

class TransportModeSelector extends StatefulWidget {
  final String selectedMode;
  final Function(String mode) onModeSelected;
  final Function(String profile) onProfileSelected; // ← callback جدید برای پروفایل

  const TransportModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
    required this.onProfileSelected,
  });

  @override
  State<TransportModeSelector> createState() => _TransportModeSelectorState();
}

class _TransportModeSelectorState extends State<TransportModeSelector> {
  String _selectedProfile = "fastest"; // پیش‌فرض: سریع‌ترین

  final List<Map<String, dynamic>> _modes = const [
    {"mode": "auto", "name": "ماشین", "icon": Icons.directions_car},
    {"mode": "motorcycle", "name": "موتور", "icon": Icons.motorcycle},
    {"mode": "truck", "name": "کامیون", "icon": Icons.local_shipping},
    {"mode": "bicycle", "name": "دوچرخه", "icon": Icons.directions_bike},
    {"mode": "pedestrian", "name": "پیاده", "icon": Icons.directions_walk},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سلکتور حالت حمل‌ونقل (قبلی)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _modes.map((m) {
            final bool isSelected = widget.selectedMode == m['mode'];
            return GestureDetector(
              onTap: () {
                widget.onModeSelected(m['mode'] as String);
                setState(() {
                  // وقتی mode عوض می‌شه، پروفایل پیش‌فرض رو ریست کن
                  _selectedProfile = "fastest";
                  widget.onProfileSelected(_selectedProfile);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey[200],
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Icon(
                  m['icon'] as IconData,
                  color: isSelected ? Colors.white : Colors.black87,
                  size: 30,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // UI جدید: سلکتور پروفایل مسیریابی
        _buildProfileSelector(widget.selectedMode),
      ],
    );
  }

  Widget _buildProfileSelector(String currentMode) {
    // لیست پروفایل‌ها بر اساس حالت حمل‌ونقل
    List<Map<String, dynamic>> profiles = [];

    if (currentMode == "auto" || currentMode == "motorcycle" || currentMode == "truck") {
      profiles = [
        {"value": "fastest", "label": "سریع‌ترین", "icon": Icons.speed},
        {"value": "shortest", "label": "کوتاه‌ترین", "icon": Icons.swap_horiz},
        {"value": "eco", "label": "کم‌مصرف", "icon": Icons.eco},
        {"value": "scenic", "label": "خوش‌منظره", "icon": Icons.landscape},
      ];
    } else if (currentMode == "bicycle" || currentMode == "pedestrian") {
      profiles = [
        {"value": "shortest", "label": "کوتاه‌ترین", "icon": Icons.swap_horiz},
        {"value": "scenic", "label": "خوش‌منظره", "icon": Icons.landscape},
      ];
    }

    if (profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "نوع مسیریابی:",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: profiles.map((profile) {
            bool isSelected = _selectedProfile == profile["value"];
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(profile["icon"], size: 18, color: isSelected ? Colors.white : Colors.blue),
                  const SizedBox(width: 6),
                  Text(profile["label"]),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedProfile = profile["value"];
                  });
                  widget.onProfileSelected(_selectedProfile); // منتقل به پنل اصلی
                }
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}