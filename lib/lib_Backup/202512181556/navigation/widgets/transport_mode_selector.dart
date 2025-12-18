import 'package:flutter/material.dart';

class TransportModeSelector extends StatelessWidget {
  final String selectedMode;
  final Function(String mode) onModeSelected;

  const TransportModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
  });

  final List<Map<String, dynamic>> _modes = const [
    {"mode": "auto",       "name": "ماشین",     "icon": Icons.directions_car},
    {"mode": "motorcycle", "name": "موتور",     "icon": Icons.motorcycle},
    {"mode": "truck",      "name": "کامیون",    "icon": Icons.local_shipping},
    {"mode": "bicycle",    "name": "دوچرخه",   "icon": Icons.directions_bike},
    {"mode": "pedestrian", "name": "پیاده",     "icon": Icons.directions_walk},
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _modes.map((m) {
        final bool isSelected = selectedMode == m['mode'];
        return GestureDetector(
          onTap: () => onModeSelected(m['mode'] as String),
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
    );
  }
}