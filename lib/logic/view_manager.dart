import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../services/photo_editor_page.dart';
/// کلاس مدیریت نمایش و تحولات تصویر (View & Transformation Manager)
/// 
/// این کلاس وظایف زیر را بر عهده دارد:
/// ۱. مدیریت بزرگ‌نمایی (Zoom) و جابه‌جایی (Pan) از طریق [TransformationController]
/// ۲. محاسبات مربوط به چرخش (Rotation) حول مرکز تصویر
/// ۳. استخراج ابعاد واقعی عکس و تراز کردن آن با ابعاد صفحه (Fit to Screen)
/// ۴. ارائه ویجت‌های آماده و قابل بازاستفاده برای کنترل تصویر
class ViewManager {
  // --- وابستگی‌های خارجی ---
  final TransformationController controller;
  final VoidCallback onUpdate; // تابعی که جایگزین setState شده تا تغییرات را به UI خبر دهد
  final double rotationSensitivity = 0.005; // ضریب حساسیت: بین ۰.۱ تا ۱.۰ تنظیمش کن 
  // --- متغیرهای وضعیت داخلی ---
  double rotationAngle = 0.0;     // زاویه فعلی چرخش به رادیان
  double rawImageWidth = 0;       // عرض واقعی پیکسل‌های عکس
  double rawImageHeight = 0;      // ارتفاع واقعی پیکسل‌های عکس
  Timer? _zoomTimer;              // تایمر برای مدیریت زوم/چرخش پیوسته

  // --- ثابت‌های تنظیمات ---
  static const double _rotateStep = math.pi / 180; // گام ۱۰ درجه‌ای برای چرخش
  static const double _zoomFactor = 0.005;          // مقدار تغییر زوم در هر پله زدن

  Offset? debugViewportCenter; // نقطه قرمز (مرکز محوطه سیاه)
  Offset? debugActualImageCenter; // نقطه زرد (مرکز واقعی عکس بعد از تحولات)


  ViewManager({required this.controller, required this.onUpdate});


  /// آزادسازی منابع برای جلوگیری از Memory Leak
  void dispose() {
    _zoomTimer?.cancel();
  }

  /// استخراج ابعاد واقعی (پیکسلی) تصویر به محض بارگذاری
  /// 
  /// این متد با استفاده از [ImageStream] ابعاد دقیق فایل را می‌گیرد.
  /// داشتن این ابعاد برای انجام عملیات "چرخش حول مرکز" و "کراپ" ضروری است.
  void getImageDimensions(ImageProvider provider) {
    late ImageStreamListener listener;
    final ImageStream stream = provider.resolve(const ImageConfiguration());
    
    listener = ImageStreamListener((ImageInfo info, bool _) {
      rawImageWidth = info.image.width.toDouble();
      rawImageHeight = info.image.height.toDouble();
      onUpdate();
      // حذف شنونده بلافاصله پس از دریافت اطلاعات برای بهینه‌سازی حافظه
      stream.removeListener(listener);
    });
    
    stream.addListener(listener);
  }

  // --- بخش منطق چرخش (Rotation Logic) ---

  /// چرخش مرحله‌ای تصویر حول نقطه مرکزی آن
  /// 
  /// به دلیل اینکه ماتریس‌ها به صورت پیش‌فرض حول نقطه (0,0) می‌چرخند،
  /// ما از تکنیک "انتقال-چرخش-بازگشت" استفاده می‌کنیم:
  /// ۱. ابتدا مرکز عکس را به نقطه صفر مختصات می‌بریم ([translate]).
  /// ۲. زاویه را در محور Z تغییر می‌دهیم ([rotateZ]).
  /// ۳. عکس را به جای اصلی خود برمی‌گردانیم ([translate] معکوس).
// در فایل view_manager.dart

/// ۱. همگام‌سازی عدد داخلی با واقعیت ماتریس (برای نمایش در UI)
void syncRotationAngle() {
  final matrix = controller.value;
  // استخراج دقیق زاویه از درایه‌های ماتریس
  rotationAngle = math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));
}

/// ۲. متد مخصوص چرخش دستی (Gesture) که از فایل اصلی صدا زده می‌شود
void applyManualRotation(double deltaRadians) {
  if (rawImageWidth == 0 || rawImageHeight == 0) return;

  // اعمال ضریب حساسیت روی مقدار جابجایی انگشت
  double adjustedDelta = deltaRadians * rotationSensitivity;
  // ساخت ماتریس چرخش حول مرکز به اندازه تفاوت (Delta)
  final rotationMatrix = 
    Matrix4.translationValues(rawImageWidth / 2, rawImageHeight / 2, 0) *
    Matrix4.rotationZ(adjustedDelta) *
    Matrix4.translationValues(-rawImageWidth / 2, -rawImageHeight / 2, 0);

  // اعمال تغییر روی ماتریس فعلی
  controller.value = controller.value * rotationMatrix;

  // به‌روزرسانی عدد داخلی
  syncRotationAngle();
  
  // خبر دادن به UI برای بازطراحی
  onUpdate();
}

/// ۳. متد چرخش با منو (که قبلاً داشتی، فقط مطمئن شو sync را صدا می‌زند)
void changeRotation(bool clockwise) {
  if (rawImageWidth == 0 || rawImageHeight == 0) return;
  double step = clockwise ? _rotateStep : -_rotateStep;
  
  final rotationMatrix = 
    Matrix4.translationValues(rawImageWidth / 2, rawImageHeight / 2, 0) *
    Matrix4.rotationZ(step) *
    Matrix4.translationValues(-rawImageWidth / 2, -rawImageHeight / 2, 0);

  controller.value = controller.value * rotationMatrix;
  
  syncRotationAngle();
  onUpdate();
}
  /// بازگرداندن زاویه چرخش به حالت اولیه (صفر درجه)
  void resetRotation() {
    if (rawImageWidth == 0 || rawImageHeight == 0) return;

    // دقیقاً مثل متد بالا، اما با زاویه معکوس کلِ زاویه فعلی
    final double undoAngle = -rotationAngle;
    
    final rotationMatrix = 
      Matrix4.translationValues(rawImageWidth / 2, rawImageHeight / 2, 0) *
      Matrix4.rotationZ(undoAngle) *
      Matrix4.translationValues(-rawImageWidth / 2, -rawImageHeight / 2, 0);

    controller.value = controller.value * rotationMatrix;
    
    rotationAngle = 0.0; // صفر کردن متغیر عددی
    onUpdate();
  }

  // --- بخش منطق زوم (Zoom Logic) ---

  /// تغییر مقیاس (Scale) تصویر به صورت پله‌ای
  /// 
  /// مقیاس فعلی را از قطر اصلی ماتریس استخراج کرده و آن را در 
  /// محدوده ۱۰٪ تا ۴۰۰٪ محدود ([clamp]) می‌کند.
  void changeZoomStep(bool increase) {
    final double currentScale = controller.value.getMaxScaleOnAxis();
    double newScale = (increase ? currentScale + _zoomFactor : currentScale - _zoomFactor).clamp(0.01, 4.0);
    
    // ضریب تغییر اسکیل نسبت به حالت فعلی
    final double ratio = newScale / currentScale;
    controller.value = Matrix4.copy(controller.value)..scale(ratio);
    onUpdate();
  }

  /// ریست کردن تمام جابه‌جایی‌ها و زوم‌ها به حالت هویت (Identity)
  void resetZoom() {
    controller.value = Matrix4.identity();
    onUpdate();
  }

  // --- مدیریت تعامل پیوسته (Continuous Action) ---

  /// شروع عملیات تکرار شونده (مثل زوم یا چرخش مداوم هنگام نگه داشتن دکمه)
  void startContinuousAction(VoidCallback action) {
    _zoomTimer?.cancel();
    action(); // اجرای اولین مرحله بلافاصله
    _zoomTimer = Timer.periodic(const Duration(milliseconds: 100), (t) => action());
  }

  /// متوقف کردن تایمر عملیات تکرار شونده
  void stopContinuousAction() => _zoomTimer?.cancel();

  // --- بخش فیت کردن (Fit to Screen) ---

  /// تراز کردن هوشمند تصویر در فضای موجود صفحه
  /// 
  /// این متد با محاسبات مثلثاتی، مستطیل دربرگیرنده عکس چرخیده (Bounding Box) را پیدا کرده
  /// و اسکیل عکس را طوری تنظیم می‌کند که در فضای خالی بین پنل‌ها به بهترین شکل جای گیرد.
void fitToScreen(GlobalKey key) {
  if (rawImageWidth == 0 || rawImageHeight == 0) return;

  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  // ۱. محاسبه اسکیل هدف (متناسب با فضای صفحه)
  double scaleX = renderBox.size.width / rawImageWidth;
  double scaleY = renderBox.size.height / rawImageHeight;
  double targetScale = (scaleX < scaleY) ? scaleX : scaleY;

  // ۲. حفظ زاویه چرخش فعلی
  // ما از متغیر rotationAngle که همیشه همگام است استفاده می‌کنیم
  final double currentAngle = rotationAngle;

  // ۳. ساخت ماتریس جدید: 
  // ابتدا هویت، سپس اعمال چرخش فعلی حول مرکز، و در نهایت اعمال اسکیل جدید
  controller.value = Matrix4.identity()
    ..translate(rawImageWidth / 2, rawImageHeight / 2)
    ..rotateZ(currentAngle)
    ..translate(-rawImageWidth / 2, -rawImageHeight / 2)
    ..scale(targetScale);

  // ۴. مرکز کردن تصویر در صفحه
  resetToCenter(key); 

  onUpdate();
}

/// مدیریت جابه‌جایی دستی دقیقاً مشابه رفتار انگشت (Gesture)
  void handleGestureManualPan(Offset delta) {
    // ۱. ماتریس فعلی را بگیر
  final Matrix4 mat = controller.value;

  // ۲. جابه‌جایی را بدون هیچ ضرب پیچیده‌ای، دقیقاً به مختصات فعلی اضافه کن
  // [0,3] مختصات X و [1,3] مختصات Y در صفحه هستند
  mat.setEntry(0, 3, mat.entry(0, 3) + delta.dx);
  mat.setEntry(1, 3, mat.entry(1, 3) + delta.dy);

  // ۳. جایگزین کن
  controller.value = mat;
  
  onUpdate();
  }

  void manualPan(double dx, double dy) {
    // ۱. ماتریس فعلی رو بگیر
    final Matrix4 currentMatrix = controller.value;

    // ۲. یک ماتریس جابه‌جایی بساز
    // این ماتریس دقیقا به همون اندازه پیکسلی که می‌گی (مثلاً ۱ واحد) جابه‌جا می‌کنه
    final Matrix4 translation = Matrix4.translationValues(dx, dy, 0);
    double scale = currentMatrix.getMaxScaleOnAxis();
    // ۳. جابه‌جایی رو به ماتریس فعلی "اضافه" کن (ضرب از چپ برای جابه‌جایی در فضای Viewport)
    controller.value = currentMatrix * translation ;

    // // ۴. بروزرسانی نقاط دیباگ (برای اینکه ببینی قرمز چطور حرکت می‌کنه)
    // debugImageCenter = MatrixUtils.transformPoint(
    //   controller.value, 
    //   Offset(rawImageWidth / 2, rawImageHeight / 2)
    // );

    onUpdate();
  }

  // مقادیر ذخیره شده برای جابه‌جایی دستی
  double manualX = 0;
  double manualY = 0;

  void updateManualPan(double dx, double dy) {
    // ۱. محاسبه تفاوت نسبت به مقدار قبلی برای اعمال روی ماتریس
    double deltaX = dx - manualX;
    double deltaY = dy - manualY;

    // ۲. آپدیت مقادیر اصلی
    manualX = dx;
    manualY = dy;

    // ۳. اعمال جابه‌جایی روی ماتریس فعلی کنترلر
    // از ضرب ماتریسی استفاده می‌کنیم تا به موقعیت فعلی اضافه شود
    controller.value = Matrix4.translationValues(deltaX, deltaY, 0) * controller.value;

    // // ۴. آپدیت دایره قرمز برای عیب‌یابی
    // debugImageCenter = MatrixUtils.transformPoint(
    //   controller.value,
    //   Offset(rawImageWidth / 2, rawImageHeight / 2),
    // );

    onUpdate();
  }

void startContinuousPan(double dx, double dy) {
    stopContinuousPan();
    _zoomTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // ارسال تغییر به متد جدید
      handleGestureManualPan(Offset(dx, dy));
    });
  }

void stopContinuousPan() {
  _zoomTimer?.cancel();
  _zoomTimer = null;
}

  // --- بخش ویجت‌های آماده (Reusable UI Components) ---
  
  /// ساخت دکمه اکشن با قابلیت Long Press (تکرار خودکار)
  Widget buildActionStepButton({required IconData icon, required VoidCallback action}) {
    return GestureDetector(
      // ۱. به محض لمس (بدون کوچکترین تاخیر)
      onTapDown: (_) {
        action(); // اجرای اولین گام (۱۰ درصد)
        startContinuousAction(action); // شروع تایمر برای تکرار
      },
      
      // ۲. به محض برداشتن انگشت (در هر شرایطی)
      onTapUp: (_) => stopContinuousAction(),
      onTapCancel: () => stopContinuousAction(),
      
      child: Container(
        // اضافه کردن پس‌زمینه شفاف برای اینکه تمام فضای دکمه حساس به لمس باشد
        color: Colors.transparent, 
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  /// ساخت منوی شناور کامل (شامل دکمه‌های مثبت، منفی و ریست)
  Widget buildFloatingMenu({
    required double top,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    required VoidCallback onReset,
    required String label,
    String resetText = "RESET",
    Color accentColor = Colors.blueAccent,
  }) {
    return Positioned(
      right: 55,
      top: top,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white24),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildActionStepButton(icon: Icons.remove, action: onDecrease),
            _buildCenterLabel(label, resetText, accentColor, onReset),
            buildActionStepButton(icon: Icons.add, action: onIncrease),
          ],
        ),
      ),
    );
  }

  /// ویجت کمکی برای بخش مرکزی منوی شناور
  Widget _buildCenterLabel(String label, String resetText, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 50),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(resetText, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // در فایل view_manager.dart

// در فایل view_manager.dart

Widget buildFloatingPanMenu({
  required double top,
  required VoidCallback onStop,
  required Function(double dx, double dy) onStartPan,
  required VoidCallback onCenterTap, // پارامتر جدید برای مرکز کردن
}) {
  return Positioned(
    right: 65,
    top: top,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDirectionalButton(Icons.keyboard_arrow_up, () => onStartPan(0, -10), onStop),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDirectionalButton(Icons.keyboard_arrow_left, () => onStartPan(-10, 0), onStop),
              
              // --- دکمه مرکز (نقطه) ---
              GestureDetector(
                onTap: onCenterTap,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.greenAccent, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 14),
                  ),
                ),
              ),
              
              _buildDirectionalButton(Icons.keyboard_arrow_right, () => onStartPan(10, 0), onStop),
            ],
          ),
          _buildDirectionalButton(Icons.keyboard_arrow_down, () => onStartPan(0, 10), onStop),
        ],
      ),
    ),
  );
}

// ویجت کمکی برای دکمه‌های جهت‌دار داخل منو
Widget _buildDirectionalButton(IconData icon, VoidCallback onStart, VoidCallback onStop) {
  return GestureDetector(
    // ۱. برای ضربه کوتاه (Short Tap): فقط یکبار متد حرکت را اجرا می‌کند و بلافاصله متوقف می‌شود
    onTap: () {
      onStart();
      // یک تاخیر بسیار کوتاه برای اینکه فقط یک پله جابجا شود و بعد تایمر متوقف شود
      Future.delayed(const Duration(milliseconds: 50), () => onStop());
    },

    // ۲. برای نگه داشتن انگشت (Long Press): حرکت پیوسته تا زمان رها کردن
    onLongPressStart: (_) => onStart(),
    onLongPressEnd: (_) => onStop(),
    
    // ۳. احتیاط برای زمانی که انگشت از روی دکمه سُر می‌خورد
    onLongPressMoveUpdate: (details) {
      // اگر انگشت خیلی از دکمه دور شد، متوقف کن
      if (details.localOffsetFromOrigin.distance > 50) onStop();
    },
    child: Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

// در فایل view_manager.dart

void resetToCenter(GlobalKey key) {
  // ۱. گرفتن RenderBox کانتینر سیاه
  final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null || rawImageWidth == 0) return;

  // ۲. مرکز محدوده نمایش (Target) - در دستگاه مختصات محلی
  final Offset viewportCenter = Offset(renderBox.size.width / 2, renderBox.size.height / 2);

  // ۳. مرکز عکس را ابتدا با ماتریس تبدیل می‌کنیم (این نقطه معمولاً نسبت به والد است)
  // final Offset globalImageCenter = MatrixUtils.transformPoint(
  //   controller.value, 
  //   Offset(rawImageWidth / 2, rawImageHeight / 2)
  // );

  // // ۴. حیاتی‌ترین بخش: تبدیل نقطه به دستگاه مختصات محلی کانتینر سیاه
  // // این خط تضمین می‌کند که هر دو نقطه در یک دستگاه مختصات سنجیده شوند
  // final Offset localImageCenter = renderBox.globalToLocal(globalImageCenter);

  // // ۵. محاسبه اختلاف در همان دستگاه مختصات مشترک
  // final Offset displacement = viewportCenter - localImageCenter;

  // // ۶. استفاده از متد سالم برای جابه‌جایی
  // handleGestureManualPan(displacement);

  // برای تست چشمی:
  debugViewportCenter = viewportCenter;
  debugActualImageCenter = MatrixUtils.transformPoint(
    controller.value, 
    Offset(rawImageWidth / 2, rawImageHeight / 2)
  );
  final Offset localPoint = debugActualImageCenter!; 
  final Offset globalPointOfImage = MatrixUtils.transformPoint(controller.value, localPoint);
  final Offset displacementVector = debugViewportCenter! - globalPointOfImage;

  handleGestureManualPan(displacementVector);  
  onUpdate();
}

}