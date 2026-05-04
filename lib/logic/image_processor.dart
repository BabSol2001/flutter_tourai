import 'dart:io';
import 'package:image/image.dart' as img; // حتما پکیج image را در pubspec داشته باش
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ImageProcessor {
  /// اعمال تغییرات واقعی بر روی پیکسل‌های تصویر
  static Future<File> applyAndSave({
    required File sourceFile,
    required double brightness,
    required double rotationRadians,
  }) async {
    try {
      // ۱. خواندن فایل اصلی به صورت بایت
      final bytes = await sourceFile.readAsBytes();
      
      // ۲. رمزگشایی (Decode) بایت‌ها به شیء Image
      img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) throw Exception("عدم توانایی در خواندن تصویر");

      // ۳. اعمال تغییرات نور (Brightness)
      // کتابخانه image مقداری بین 0 تا 2 (یا بیشتر) می‌گیرد (1.0 خنثی است)
      if (brightness != 1.0) {
        decodedImage = img.adjustColor(decodedImage, brightness: brightness);
      }

      // ۴. اعمال چرخش (Rotation)
      // تبدیل رادیان به درجه: (radians * 180 / pi)
      double degrees = rotationRadians * (180 / 3.141592653589793);
      
      if (degrees != 0) {
        // استفاده از copyRotate برای چرخش با کیفیت بالا
        decodedImage = img.copyRotate(decodedImage, angle: degrees);
      }

      // ۵. آماده‌سازی مسیر ذخیره در پوشه موقت
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final directory = await getTemporaryDirectory();
      final String targetPath = '${directory.path}/edited_$timestamp.jpg';

      // ۶. تبدیل تصویر پردازش شده به فرمت JPG و ذخیره
      final encodedJpg = img.encodeJpg(decodedImage, quality: 90);
      final File resultFile = File(targetPath);
      await resultFile.writeAsBytes(encodedJpg);

      return resultFile;
    } catch (e) {
      debugPrint("خطا در پردازش واقعی تصویر: $e");
      rethrow;
    }
  }

  /// متد برای ذخیره نهایی (در آینده به پکیج‌های گالری وصل می‌شود)
  static Future<bool> saveToGallery(File file) async {
    // فعلاً شبیه‌سازی موفقیت
    await Future.delayed(const Duration(seconds: 1));
    return true; 
  }

  // اضافه کردن این متدها به کلاس ImageProcessor
  static Future<File> saveAsCopy(File currentFile, String name) async {
    final directory = await getApplicationDocumentsDirectory();

    // پاکسازی نام فایل از کاراکترهای غیرمجاز سیستم‌عامل
    String sanitizedName = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    // اضافه کردن پسوند در صورتی که کاربر وارد نکرده باشد
    final String fileName = name.endsWith('.jpg') ? name : '$name.jpg';
    final String path = '${directory.path}/$fileName';
    return await currentFile.copy(path);
  }

  static Future<File> exportToPdf(File imageFile, String fileName) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageFile.readAsBytesSync());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4, // می‌تونی سایز رو دلخواه بذاری
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.pdf');
    return await file.writeAsBytes(await pdf.save());
  }

  static Future<File> exportImage({
    required File sourceFile,
    required String format,
    required String fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final String formatUpper = format.toUpperCase();
    final String ext = format.toLowerCase();
    final String targetPath = '${directory.path}/$fileName.$ext';

    // ۱. کیس اختصاصی PDF (استفاده از متدی که قبلاً نوشتیم)
    if (formatUpper == 'PDF') {
      return await exportToPdf(sourceFile, fileName);
    }

    // ۲. کیس‌های BMP و GIF (خروجی مستقیم از پکیج image)
    if (formatUpper == 'BMP' || formatUpper == 'GIF') {
      final rawImage = img.decodeImage(await sourceFile.readAsBytes());
      if (rawImage != null) {
        final bytes = (formatUpper == 'BMP') 
            ? img.encodeBmp(rawImage) 
            : img.encodeGif(rawImage);
        return await File(targetPath).writeAsBytes(bytes);
      }
    }

    // ۳. کیس‌های فشرده‌سازی (JPG, PNG, WebP, HEIC)
    CompressFormat compressFormat;
    switch (formatUpper) {
      case 'PNG':
        compressFormat = CompressFormat.png;
        break;
      case 'WEBP':
        compressFormat = CompressFormat.webp;
        break;
      case 'HEIC':
        compressFormat = CompressFormat.heic;
        break;
      case 'JPG':
      case 'JPEG':
      default:
        compressFormat = CompressFormat.jpeg;
        break;
    }

    var result = await FlutterImageCompress.compressAndGetFile(
      sourceFile.absolute.path,
      targetPath,
      format: compressFormat,
      quality: 90,
    );

    return File(result!.path);
  }

}