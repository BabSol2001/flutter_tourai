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
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (controller.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
                : null),
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