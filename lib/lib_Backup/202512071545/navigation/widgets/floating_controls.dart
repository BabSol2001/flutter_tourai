import 'package:flutter/material.dart';

class FloatingControls extends StatelessWidget {
  final VoidCallback onNorth;
  final VoidCallback onLocate;

  const FloatingControls({
    super.key,
    required this.onNorth,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 130,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: "north",
            backgroundColor: Colors.white,
            onPressed: onNorth,
            child: const Icon(Icons.explore, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: "locate",
            backgroundColor: Colors.blue,
            onPressed: onLocate,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }
}