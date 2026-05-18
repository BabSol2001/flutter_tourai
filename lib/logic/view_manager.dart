import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

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
  double currentFitScale = 1.0;    // تراز فعلی برای تراز کردن عکس با صفحه
  // --- ثابت‌های تنظیمات ---
  static const double _rotateStep = math.pi / 180; // گام ۱۰ درجه‌ای برای چرخش
  static const double _zoomFactor = 0.005;          // مقدار تغییر زوم در هر پله زدن

  Offset? debugViewportCenter; // نقطه قرمز (مرکز محوطه سیاه)
  Offset? debugActualImageCenter; // نقطه زرد (مرکز واقعی عکس بعد از تحولات)

  final AnimationController animationController; 

  Animation<Matrix4>? _animationMatrix;


  // ۲. اضافه کردن animationController به ورودی‌های سازنده
  ViewManager({
    required this.controller,
    required this.onUpdate,
    required this.animationController, // این خط اضافه شد
  });

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

  void setRotation(double angle) {
    // ساخت یک ماتریس جدید که فقط زاویه مشخص شده را دارد
    // ما مقیاس (Scale) را ۱ نگه می‌داریم تا تصویر زوم نشود
    final Matrix4 newMatrix = Matrix4.identity()
      ..rotateZ(angle);
      
    controller.value = newMatrix;
    onUpdate(); // اطلاع به UI برای بازسازی (Rebuild)
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

  // ۱. محاسبه اسکیل بر اساس چرخش (این بخش درست بود)
  bool isRotatedSide = (rotationAngle / (math.pi / 2)).round() % 2 != 0;
  double effectiveWidth = isRotatedSide ? rawImageHeight : rawImageWidth;
  double effectiveHeight = isRotatedSide ? rawImageWidth : rawImageHeight;

  double scaleX = renderBox.size.width / effectiveWidth;
  double scaleY = renderBox.size.height / effectiveHeight;
  double targetScale = (scaleX < scaleY) ? scaleX : scaleY;
  currentFitScale = targetScale; // 👈 این خط را اضافه کنید
  // ۲. اعمال زوم و چرخش به کنترلر (بدون تغییر دادن آفست فعلی)
  final Matrix4 newMatrix = Matrix4.identity();
  newMatrix.scale(targetScale);
  
  final double centerX = rawImageWidth / 2;
  final double centerY = rawImageHeight / 2;
  
  controller.value = newMatrix
    ..translate(centerX, centerY)
    ..rotateZ(rotationAngle)
    ..translate(-centerX, -centerY);

  // ۳. حالا که ماتریس زوم ست شد، بلافاصله متد ریست خودت رو صدا می‌زنیم
  // این همون خطیه که نباید حذف می‌شد
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

 /// تمرکز هوشمند بر اساس خروجی هوش مصنوعی (مختصات و زاویه)
void smartFocus({
    required Rect objectRect,
    required double rotationAngle,
    required GlobalKey viewportKey,
    double padding = 40.0,
  }) {
    print("--- 🎯 شروع عملیات Smart Focus ---");
    
    final renderBox = viewportKey.currentContext?.findRenderObject() as RenderBox?;
    
    // بررسی وجود رندر باکس و ابعاد تصویر اصلی
    if (renderBox == null) {
      print("❌ خطا: Viewport یافت نشد (GlobalKey اشتباه است یا ویجت هنوز رندر نشده)");
      return;
    }
    if (rawImageWidth == 0 || rawImageHeight == 0) {
      print("❌ خطا: ابعاد واقعی عکس صفر است! (rawImageWidth: $rawImageWidth)");
      return;
    }

    // ۱. اطلاعات ورودی
    print("📥 22222222222222222222222222ورودی سرور:");
    print("   - مستطیل سوژه (Object Rect): $objectRect");
    print("   - مرکز سوژه: ${objectRect.center}");
    print("   - زاویه پیشنهادی (رادیان): $rotationAngle");

    // ۲. محاسبه ابعاد فضای نمایش تصویر در موبایل (با کسر پدینگ)
    double viewW = renderBox.size.width - (padding * 2);
    double viewH = renderBox.size.height - (padding * 2);
    print("📱 ابعاد نمایشگر (Viewport): ${renderBox.size.width}x${renderBox.size.height}");

    // ۳. محاسبه مقیاس زوم (Scale)
    double scaleX = viewW / objectRect.width;
    double scaleY = viewH / objectRect.height;
    
    // انتخاب کمترین مقیاس برای اینکه کل شیء دیده شود
    double targetScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.5, 10.0);
    print("🔍 محاسبات زوم:");
    print("   - مقیاس پیشنهادی عرض: ${scaleX.toStringAsFixed(2)}");
    print("   - مقیاس پیشنهادی ارتفاع: ${scaleY.toStringAsFixed(2)}");
    print("   - زوم نهایی اعمال شده: ${targetScale.toStringAsFixed(2)}");

    // ۴. پیدا کردن مرکز ویوپورت (نقطه وسط کادر سیاه)
    Offset viewCenter = Offset(renderBox.size.width / 2, renderBox.size.height / 2);
    print("📍 مرکز هدف در صفحه گوشی: $viewCenter");

    // ۵. ساخت ماتریس تغییر وضعیت
    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(viewCenter.dx, viewCenter.dy)
      ..scale(targetScale)
      ..rotateZ(rotationAngle)
      ..translate(-objectRect.center.dx, -objectRect.center.dy);

    print("🚀 ماتریس نهایی تولید شد. در حال اعمال...");

    // ۶. اعمال ماتریس به صورت انیمیشن (یا مستقیم)
    animateToMatrix(targetMatrix);
    
    onUpdate();
    print("--- ✅ پایان عملیات Smart Focus ---");
  }

  void animateToMatrix(Matrix4 targetMatrix) {
    print("--- 🎬 شروع انیمیشن ماتریس ---");

    // ۱. استخراج مقادیر نهایی برای لاگ (بسیار مفید برای دیباگ)
    final Float64List storage = targetMatrix.storage;
    double finalScale = targetMatrix.getMaxScaleOnAxis();
    double finalTranslationX = storage[12];
    double finalTranslationY = storage[13];

    print("📊 وضعیت نهایی هدف:");
    print("   - میزان زوم نهایی: ${finalScale.toStringAsFixed(2)}");
    print("   - جابه‌جایی نهایی: X=${finalTranslationX.toStringAsFixed(1)}, Y=${finalTranslationY.toStringAsFixed(1)}");

    // ۲. تعریف Tween برای حرکت نرم از وضعیت فعلی به وضعیت هدف
    final Matrix4Tween matrixTween = Matrix4Tween(
      begin: controller.value,
      end: targetMatrix,
    );

    _animationMatrix = matrixTween.animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    // ۳. مدیریت لیسنرها (پاکسازی لیسنر قبلی برای جلوگیری از نشت حافظه)
    animationController.removeListener(_updateTransformation);
    animationController.addListener(_updateTransformation);

    // ۴. شروع انیمیشن
    print("🚀 استارت موتور انیمیشن...");
    animationController.reset();
    animationController.forward().then((_) {
      print("✅ انیمیشن با موفقیت به پایان رسید.");
    });
  }

  // این متد در هر فریم انیمیشن اجرا می‌شود
  void _updateTransformation() {
    if (_animationMatrix != null) {
      controller.value = _animationMatrix!.value;
      
      // لاگ کردن لحظه‌ای (اختیاری - اگر کنسول خیلی شلوغ شد این خط را کامنت کنید)
      // print("🎞 در حال حرکت... زوم لحظه‌ای: ${controller.value.getMaxScaleOnAxis().toStringAsFixed(2)}");
      
      onUpdate(); // اطلاع به UI برای رندر فریم جدید
    }
  }

void focusOnObject({
  required Rect objectRect,
  required double rotationAngle,
  required GlobalKey viewportKey,
  double padding = 40.0,
}) {
  final renderBox = viewportKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  double viewW = renderBox.size.width;
  double viewH = renderBox.size.height;

  if (rawImageWidth == 0 || rawImageHeight == 0) {
    print("⚠️ ابعاد عکس ناقص است! W:$rawImageWidth, H:$rawImageHeight");
    return;
  }

  // ۱. محاسبه Scale اولیه (چقدر عکس بزرگ شده تا در صفحه جا شود)
  // ما باید بفهمیم عکس چطور در صفحه فیت شده است (مانند BoxFit.contain)
  double scaleToFit = (viewW / rawImageWidth < viewH / rawImageHeight) 
      ? viewW / rawImageWidth 
      : viewH / rawImageHeight;

  // ۲. پیدا کردن مختصات مرکز عکس در صفحه (چون عکس وسط‌چین است)
  double displayedImageWidth = rawImageWidth * scaleToFit;
  double displayedImageHeight = rawImageHeight * scaleToFit;
  
  double offsetX = (viewW - displayedImageWidth) / 2;
  double offsetY = (viewH - displayedImageHeight) / 2;

  // ۳. تبدیل مختصات سوژه از پیکسل خام به پیکسل نمایشگر
  // ابتدا تبدیل به مقیاس گوشی، سپس اضافه کردن آفستِ ناشی از وسط‌چین بودن عکس
  double centerX = (objectRect.center.dx * scaleToFit) + offsetX;
  double centerY = (objectRect.center.dy * scaleToFit) + offsetY;

  // ۴. محاسبه زوم (Scale) هدف
  // عرض سوژه در نمایشگر
  double objectViewWidth = objectRect.width * scaleToFit;
  
  // هدف: سوژه ۷۰٪ عرض یا ارتفاع نمایشگر را پر کند (هر کدام که کوچکتر بود)
  double targetScale = (viewW * 0.7) / objectViewWidth;

  // ۵. محدود کردن زوم (بین ۱.۵ تا ۵ برابر)
  targetScale = targetScale.clamp(1.5, 5.0);

  print("📏 سوژه در عکس: ${objectRect.width.toInt()}x${objectRect.height.toInt()}");
  print("🔍 زوم نهایی: ${targetScale.toStringAsFixed(2)}");

  // ۶. ساخت ماتریس نهایی
  // ترتیب عملیات در ماتریس از پایین به بالا خوانده می‌شود:
  // اول انتقال به مرکز، بعد زوم، بعد چرخش، و در نهایت جابه‌جایی به مرکز گوشی
  final Matrix4 targetMatrix = Matrix4.identity();
  
  targetMatrix.translate(viewW / 2, viewH / 2); // ۳. بردن به وسط صفحه گوشی
  targetMatrix.rotateZ(rotationAngle);           // ۴. اعمال چرخش (اگر نیاز بود)
  targetMatrix.scale(targetScale);               // ۲. اعمال زوم
  targetMatrix.translate(-centerX, -centerY);    // ۱. بردن سوژه به نقطه صفر

  animateToMatrix(targetMatrix);
}

 /// متد برای زوم دوبرابری روی یک نقطه خاص بدون درگیری با هوش مصنوعی
void zoomToPoint({
  required Offset tapPoint, // مختصاتی که از details.localPosition می‌آید
  required GlobalKey viewportKey,
}) {
  final renderBox = viewportKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null || rawImageWidth == 0) return;

  double viewW = renderBox.size.width;
  double viewH = renderBox.size.height;

  // ۱. تبدیل نقطه تپ شده از اسکرین به مختصات واقعی عکس
  // این مرحله حیاتی است؛ چون تپ شما روی عکسی خورده که الان کوچک (Scale: 0.16) است.
  final Matrix4 inverseCurrent = Matrix4.inverted(controller.value);
  final Offset localPoint = MatrixUtils.transformPoint(inverseCurrent, tapPoint);

  // ۲. زوم هدف (۲ برابرِ حالت فیت)
  double targetScale = currentFitScale * 2.0;

  // ۳. محاسبه جابه‌جایی برای مرکزیت
  // فرمول: (مرکز نمایشگر) - (مختصات واقعی نقطه در زومِ جدید)
  double targetX = (viewW / 2) - (localPoint.dx * targetScale);
  double targetY = (viewH / 2) - (localPoint.dy * targetScale);

  // ۴. ساخت ماتریس نهایی
  final Matrix4 targetMatrix = Matrix4.identity()
    ..translate(targetX, targetY)
    ..scale(targetScale);

  print("🎯 نقطه محلی محاسبه شده (Local): $localPoint");
  print("🔍 زوم هدف: $targetScale");
  print("↕️ جابه‌جایی نهایی: X=${targetX.toInt()}, Y=${targetY.toInt()}");

  animateToMatrix(targetMatrix);
}

}

class LocalAiProcessor {
  // --- موشکافی برای یافتن تمام اشیاء (برای تپ سه‌گانه) ---
  static Future<List<Rect>> detectAllObjects(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single, // برای پردازش دقیق یک تصویر ایستا
      classifyObjects: true,
      multipleObjects: true, // یافتن بیش از یک شیء
    );

    final objectDetector = ObjectDetector(options: options);
    
    try {
      final List<DetectedObject> objects = await objectDetector.processImage(inputImage);
      
      // استخراج مرزهای (Bounding Boxes) تمام اشیاء یافت شده
      return objects.map((obj) => obj.boundingBox).toList();
    } catch (e) {
      print("در روند موشکافی هوش دست‌ساخته خطایی رخ داد: $e");
      return [];
    } finally {
      objectDetector.close();
    }
  }

  // ۲. متد هوشمند برای پیدا کردن نزدیک‌ترین شیء به نقطه تپ شده
  static Future<Rect?> detectObjectAtPoint(File imageFile, Offset touchPoint) async {
    final inputImage = InputImage.fromFile(imageFile);
    
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );

    final objectDetector = ObjectDetector(options: options);
    
    try {
      final List<DetectedObject> objects = await objectDetector.processImage(inputImage);
      
      if (objects.isEmpty) return null;

      DetectedObject? bestMatch;
      double minDistance = double.infinity;

      for (var obj in objects) {
        // اگر نقطه دقیقاً داخل یک مستطیل باشد
        if (obj.boundingBox.contains(touchPoint)) {
          return obj.boundingBox;
        }
        
        // محاسبه فاصله مرکز مستطیل تا نقطه تپ برای پیدا کردن نزدیک‌ترین مورد
        double dist = (obj.boundingBox.center - touchPoint).distance;
        if (dist < minDistance) {
          minDistance = dist;
          bestMatch = obj;
        }
      }

      return bestMatch?.boundingBox;
    } catch (e) {
      print("❌ خطا در موشکافی نقطه‌ای: $e");
      return null;
    } finally {
      objectDetector.close();
    }
  }

}

class ObjectBoundsPainter extends CustomPainter {
  final List<Rect> rects;
  final Size imageRawSize;
  final Size layerLocalSize; // ابعاد کانتینر لایه روی نمایشگر
  final Matrix4 transform; 

  ObjectBoundsPainter({
    required this.rects,
    required this.imageRawSize,
    required this.layerLocalSize,
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageRawSize.width == 0 || layerLocalSize.width == 0 || rects.isEmpty) return;

    // ۱. محاسبه ابعاد دقیق عکس رندر شده در حالت BoxFit.contain داخل کانتینر لایه
    double srcAspect = imageRawSize.width / imageRawSize.height;
    double dstAspect = layerLocalSize.width / layerLocalSize.height;

    double drawWidth, drawHeight;
    if (srcAspect > dstAspect) {
      drawWidth = layerLocalSize.width;
      drawHeight = layerLocalSize.width / srcAspect;
    } else {
      drawHeight = layerLocalSize.height;
      drawWidth = layerLocalSize.height * srcAspect;
    }

    final double initialScale = transform.getMaxScaleOnAxis();

    // ۲. پیدا کردن آفست یا همان نقطه شروع (Top-Left) واقعی عکس رندر شده (حذف فضاهای سیاه دور عکس)
    double offsetX = ((layerLocalSize.width*initialScale) - drawWidth) / 2;
    double offsetY = ((layerLocalSize.height*initialScale) - drawHeight) / 2;

    // ۳. محاسبه ضریب تبدیل دقیق از پیکسل خام به ابعاد فیزیکی عکس روی صفحه
    double scaleX = drawWidth / (initialScale*imageRawSize.width);
    double scaleY = drawHeight / (initialScale*imageRawSize.height);

    final paint = Paint()
      ..color = const Color(0xFF00FF00) // سبز هوش مصنوعی
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // ۴. اعمال ماتریکس زوم، چرخش و پن دقیقاً بر اساس دستگاه مختصات تصویر مبنا
    canvas.save();
    canvas.transform(transform.storage);

    for (var rect in rects) {
      // نگاشت مستطیل خام هوش مصنوعی به مختصات فیزیکی عکس رندر شده
      final Rect localRect = Rect.fromLTRB(
        offsetX + (rect.left * scaleX*1),
        offsetY + (rect.top * scaleY*1),
        offsetX + (rect.right * scaleX*1),
        offsetY + (rect.bottom * scaleY*1),
      );
      
      canvas.drawRect(localRect, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ObjectBoundsPainter oldDelegate) => true;
}