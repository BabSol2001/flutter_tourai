// lib/navigation/widgets/guidance_button.dart
import 'package:flutter/material.dart';

class GuidanceFloatingButton extends StatelessWidget {
  final bool isRouteDrawn; // آیا مسیر رسم شده؟
  final VoidCallback onPressed; // وقتی دکمه زده شد

  const GuidanceFloatingButton({
    Key? key,
    required this.isRouteDrawn,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isRouteDrawn ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !isRouteDrawn,
        child: FloatingActionButton(
          heroTag: "fab_guidance",
          backgroundColor: isRouteDrawn ? Colors.orange.shade600 : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: isRouteDrawn ? 6 : 0,
          onPressed: isRouteDrawn ? onPressed : null,
          child: const Icon(
            Icons.navigation,
            size: 32,
          ),
          tooltip: "شروع راهنمایی پیمایش",
        ),
      ),
    );
  }
}