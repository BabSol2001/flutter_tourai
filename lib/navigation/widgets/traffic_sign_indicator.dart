// lib/navigation/widgets/traffic_sign_indicator.dart
import 'package:flutter/material.dart';

class TrafficSignIndicator extends StatelessWidget {
  final String? signType;     // نوع تابلو (مثل "speed_limit", "stop", "no_entry")
  final String? signValue;    // مقدار (مثل "50" برای سرعت)

  const TrafficSignIndicator({
    super.key,
    this.signType,
    this.signValue,
  });

  @override
  Widget build(BuildContext context) {
    if (signType == null) return const SizedBox.shrink();

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.red.shade700, width: 3),
      ),
      child: Center(
        child: _buildSignContent(),
      ),
    );
  }

  Widget _buildSignContent() {
    switch (signType) {
      case "speed_limit":
        return Text(
          signValue ?? "؟",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        );
      case "stop":
        return const Text(
          "STOP",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        );
      case "no_entry":
        return const Icon(Icons.block, color: Colors.red, size: 30);
      case "yield":
        return const RotatedBox(
          quarterTurns: 2,
          child: Icon(Icons.arrow_downward, color: Colors.red, size: 30),
        );
      case "right_turn":
        return const Icon(Icons.turn_right, color: Colors.blue, size: 30);
      case "left_turn":
        return const Icon(Icons.turn_left, color: Colors.blue, size: 30);
      case "no_overtaking":
        return const Icon(Icons.do_not_touch, color: Colors.red, size: 30);
      default:
        return const Icon(Icons.warning, color: Colors.orange, size: 30);
    }
  }
}