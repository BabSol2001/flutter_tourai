import 'package:flutter/material.dart';

import 'dart:io';
import 'package:image/image.dart' as img; // پکیج اصلی پردازش تصویر
import 'package:path_provider/path_provider.dart';

// مدلی برای هر گزینه نسبت تصویر
class AspectRatioOption {
  final String label;
  final double? ratio; // مقدار عددی نسبت (مثلاً 16/9)
  final IconData icon;

  AspectRatioOption({required this.label, this.ratio, required this.icon});
}

class AspectRatioHandler {
  // لیست نسبت‌های استاندارد برای توریست‌ها
  static List<AspectRatioOption> getOptions() {
    return [
      AspectRatioOption(label: "اصلی", ratio: null, icon: Icons.image),
      AspectRatioOption(label: "1:1", ratio: 1.0, icon: Icons.crop_square),
      AspectRatioOption(label: "استوری", ratio: 9 / 16, icon: Icons.stay_current_portrait),
      AspectRatioOption(label: "پست", ratio: 4 / 5, icon: Icons.ad_units),
      AspectRatioOption(label: "سینمایی", ratio: 16 / 9, icon: Icons.movie_creation_outlined),
      AspectRatioOption(label: "3:2", ratio: 3 / 2, icon: Icons.crop_original),
    ];
  }

  // متد محاسباتی برای پیدا کردن اندازه کادر برش روی صفحه
// این تابع ابعاد بهینه کادر برش را محاسبه می‌کند
  static Size calculateCropSize({
    required double? ratio,
    required Size imageAreaSize, // ابعادی که عکس در حال حاضر در آن نمایش داده می‌شود
  }) {
    if (ratio == null) return imageAreaSize;

    double width, height;

    // اگر نسبت تصویر انتخابی پهن‌تر از کادر نمایش باشد
    if (ratio > (imageAreaSize.width / imageAreaSize.height)) {
      width = imageAreaSize.width;
      height = width / ratio;
    } else {
      // اگر نسبت تصویر انتخابی عمودی‌تر باشد (مثل استوری)
      height = imageAreaSize.height;
      width = height * ratio;
    }

    return Size(width * 0.9, height * 0.9); // ضرب در 0.9 برای اینکه کمی فاصله از لبه‌ها داشته باشد
  }

  // اضافه کردن کلمه static قبل از تابع برای دسترسی مستقیم
  static Future<File> cropImage({
    required File imageFile,
    required Size previewSize,
    required Size cropSize,
    required Offset cropOffset,
  }) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return imageFile;

    // محاسبات نسبت مقیاس
    double scaleX = originalImage.width / previewSize.width;
    double scaleY = originalImage.height / previewSize.height;

    double centerX = previewSize.width / 2 + cropOffset.dx;
    double centerY = previewSize.height / 2 + cropOffset.dy;
    
    int x = ((centerX - cropSize.width / 2) * scaleX).toInt();
    int y = ((centerY - cropSize.height / 2) * scaleY).toInt();
    int width = (cropSize.width * scaleX).toInt();
    int height = (cropSize.height * scaleY).toInt();

    // عملیات برش
    img.Image cropped = img.copyCrop(
      originalImage, 
      x: x, 
      y: y, 
      width: width, 
      height: height
    );

    final tempDir = await getTemporaryDirectory();
    final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    return await croppedFile.writeAsBytes(img.encodeJpg(cropped));
  }
}



extension PhotoCropper on AspectRatioHandler {
  
  static Future<File> cropImage({
    required File imageFile,
    required Size previewSize,    // سایزی که عکس در موبایل نمایش داده می‌شد
    required Size cropSize,       // سایز کادر سفید ما
    required Offset cropOffset,   // جابه‌جایی کادر از مرکز
  }) async {
    // ۱. خواندن فایل عکس
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return imageFile;

    // ۲. محاسبه نسبت بین عکس واقعی و پیش‌نمایش در موبایل
    // چون عکسی که کاربر می‌بینه با سایز واقعی عکس فرق داره
    double scaleX = originalImage.width / previewSize.width;
    double scaleY = originalImage.height / previewSize.height;

    // ۳. پیدا کردن نقطه شروع برش (Top-Left) بر اساس آفست مرکز
    double centerX = previewSize.width / 2 + cropOffset.dx;
    double centerY = previewSize.height / 2 + cropOffset.dy;
    
    int x = ((centerX - cropSize.width / 2) * scaleX).toInt();
    int y = ((centerY - cropSize.height / 2) * scaleY).toInt();
    int width = (cropSize.width * scaleX).toInt();
    int height = (cropSize.height * scaleY).toInt();

    // ۴. انجام عملیات برش واقعی
    img.Image cropped = img.copyCrop(
      originalImage, 
      x: x, 
      y: y, 
      width: width, 
      height: height
    );

    // ۵. ذخیره در یک فایل موقت برای نمایش در اپلیکیشن
    final tempDir = await getTemporaryDirectory();
    final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    return await croppedFile.writeAsBytes(img.encodeJpg(cropped));
  }
}