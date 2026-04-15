import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailWidget extends StatelessWidget {
  final File videoFile;
  final double size;

  const VideoThumbnailWidget({
    super.key, 
    required this.videoFile, 
    this.size = 80.0
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<Uint8List?>(
          // چرا از thumbnailData استفاده کردیم؟ چون بایت‌های تصویر را سریع به ما می‌دهد
          future: VideoThumbnail.thumbnailData(
            video: videoFile.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 150, // اندازه کوچک برای بهینه بودن سرعت
            quality: 50,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(snapshot.data!, fit: BoxFit.cover),
                  // اضافه کردن یک آیکون پلی کوچک روی تامنیل برای تشخیص ویدیو
                  Center(
                    child: Icon(
                      Icons.play_circle_fill, 
                      color: Colors.white.withOpacity(0.7), 
                      size: 30
                    ),
                  ),
                ],
              );
            }
            // تا زمانی که در حال پردازش است، یک لودینگ ظریف نشان می‌دهیم
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
              ),
            );
          },
        ),
      ),
    );
  }
}