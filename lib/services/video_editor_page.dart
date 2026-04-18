import 'dart:io';
import 'package:flutter/material.dart';


class VideoEditorPage extends StatelessWidget {
  final File file;
  const VideoEditorPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("ویرایش ویدیو"), backgroundColor: Colors.black),
      body: const Center(child: Text("پلیر ویدیو و ابزار برش اینجا قرار می‌گیرد", style: TextStyle(color: Colors.white))),
    );
  }
}