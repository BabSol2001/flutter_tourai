// lib/widgets/search_field.dart  (یا هر مسیری که داری)
import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isLoading;
  final VoidCallback? onClear;
  final Color fillColor;
  final IconData prefixIcon;
  final Color prefixIconColor;
  final Function(String) onSubmitted;
  final VoidCallback? onMapTap; // جدید: دکمه انتخاب از نقشه

  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.isLoading,
    this.onClear,
    required this.fillColor,
    required this.prefixIcon,
    required this.prefixIconColor,
    required this.onSubmitted,
    this.onMapTap, // جدید
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: prefixIconColor),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // دکمه انتخاب از روی نقشه
            if (onMapTap != null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                child: IconButton(
                  icon: const Icon(Icons.location_on_outlined, color: Colors.red),
                  tooltip: "انتخاب از روی نقشه",
                  onPressed: onMapTap,
                ),
              ),
            // دکمه پاک کردن
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (controller.text.isNotEmpty && onClear != null)
              IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
          ],
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}