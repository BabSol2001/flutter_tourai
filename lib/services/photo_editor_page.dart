import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math; // برای دسترسی به pi
import 'dart:async'; // این را اضافه کن

import '../logic/editor/aspect_ratio_handler.dart';
import '../logic/view_manager.dart';

class PhotoEditorPage extends StatefulWidget {
  final File file;
  const PhotoEditorPage({super.key, required this.file});

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  bool _showHelp = false; // وضعیت نمایش دیالوگ راهنما از بالا
  bool _isHelpModeActive = false; // آیا حالت علامت سوال فعال است؟
  double _rotationAngle = 0.0; // مقدار چرخش به رادیان
  double _currentRotationDisplay = 0.0; // نگهدارنده زاویه برای نمایش در UI
  String _helpText = ""; // متن راهنما
  String _activeTool = ""; // ابزار انتخاب شده فعلی

  late ViewManager _viewManager;
  final TransformationController _transformationController = TransformationController();
  // در بخش تعریف متغیرها (State)
  List<EditStep> _historySteps = [
    EditStep("اصلی", {'rotation': 0.0, 'brightness': 1.0, 'tool': ""})
  ];

  int _lastSavedStepIndex = 0; // در ابتدا مرحله "اصلی" ذخیره شده محسوب می‌شود
  bool _isSaving = false; // برای مدیریت نمایش لودینگ روی دکمه ذخیره
  int _currentStepIndex = 0;
  double _brightnessValue = 1.0; // ۱.۰ یعنی نور طبیعی؛ کمتر تاریک و بیشتر روشن می‌کند


  double? _selectedRatio; // ذخیره نسبت انتخاب شده
  Size _cropAreaSize = const Size(200, 200); // اندازه پیش‌فرض کادر
  Offset _cropOffset = Offset.zero; // موقعیت کادر نسبت به مرکز
  late File _currentFile; // متغیری که عکس فعلی (بریده شده یا اصلی) را نگه می‌دارد

  bool _showZoomMenu = false; // برای باز و بسته شدن لیست درصدها

  bool _showPanMenu = false; // برای باز و بسته شدن منوی جابجا کردن عکس

  // ۱۵ درجه به رادیان (15 * pi / 180)
  bool _showrotateMenu = false; // برای باز و بسته شدن لیست درصدها


  final GlobalKey viewportKey = GlobalKey();

  /// مقداردهی اولیه وضعیت برنامه (State)
  /// در این مرحله:
  /// ۱. فایل ورودی از [widget.file] گرفته شده و به عنوان عکس جاری تعریف می‌شود.
  /// ۲. ابعاد واقعی عکس (عرض و ارتفاع) جهت محاسبات دقیق کادر برش استخراج می‌شود.
  /// ۳. اولین گام در لیست تاریخچه ([_historySteps]) با مقادیر پیش‌فرض (بدون چرخش و تغییر نور)
  ///    ثبت می‌شود تا کاربر بتواند در صورت نیاز به حالت کاملاً اصلی بازگردد.
  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleMatrixUpdate);
    // مقداردهی اولیه ViewManager
    _viewManager = ViewManager(
      controller: _transformationController,
      onUpdate: () => setState(() {}),
    );
    _currentFile = widget.file; // در ابتدا، فایل فعلی همان فایل ورودی است
  
    // گرفتن ابعاد عکس به محض شروع
    _viewManager.getImageDimensions(FileImage(widget.file));

    // اولین مرحله تاریخچه با فایل اصلی
    _historySteps = [
      EditStep("اصلی", {
        'rotation': 0.0, 
        'brightness': 1.0, 
        'tool': "", 
        'file': widget.file
      })
    ];
  }

void _handleMatrixUpdate() {
  // فقط همگام‌سازی عدد برای نمایش در منوها
  _viewManager.syncRotationAngle();
  
  setState(() {
    // تبدیل رادیان به درجه برای نمایش در متن منو
    double degrees = _viewManager.rotationAngle * 180 / math.pi;
    _currentRotationDisplay = (degrees % 360 + 360) % 360;
  });
}

  @override
  void dispose() {
    _viewManager.dispose(); // حتما تایمرها را آزاد کنیم
    _transformationController.removeListener(_handleMatrixUpdate);
    _transformationController.dispose();
    super.dispose();
  }

  /// متد اصلی ساخت رابط کاربری ویرایشگر تصویر
  /// ساختار این صفحه به صورت لایه‌بندی (Stack) طراحی شده است:
  /// ۱. لایه زیرین: شامل یک [AnimatedContainer] که بدنه اصلی (عکس و نوار ابزار عمودی) را در بر می‌گیرد.
  ///    - عکس داخل یک [InteractiveViewer] قرار دارد تا قابلیت زوم و جابه‌جایی داشته باشد.
  ///    - از [Transform.rotate] برای اعمال چرخش مستقل از زوم استفاده شده است.
  ///    - از [ColorFiltered] برای اعمال فیلترهای نوری (مانند Brightness) استفاده می‌شود.
  /// ۲. کادر برش (Crop Box): یک لایه تعاملی که فقط هنگام انتخاب ابزار "ابعاد و حجم" ظاهر می‌شود
  ///    و با استفاده از [GestureDetector] قابلیت جابه‌جایی روی عکس را دارد.
  /// ۳. لایه‌های کنترلی (Overlay):
  ///    - [_buildTopHelpBanner]: بنر راهنمای بالای صفحه.
  ///    - [_buildDynamicTopPanel]: پنل هوشمند دکمه‌های Undo/Redo و تنظیمات زوم.
  ///    - [_buildBottomActionBox]: باکس تنظیمات پایین صفحه که با انتخاب هر ابزار تغییر می‌کند.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack( // ۱. پشته اصلی برای مدیریت لایه‌های روی هم
          children: [ 
            // لایه ۱: بدنه اصلی (عکس و پنل ابزار عمودی)
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(top: _showHelp ? 120 : 0),
              child: Row(
                children: [
                  _buildSideToolbar(), // پنل ابزار عمودی سمت چپ
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container( // این کانتینر را اضافه یا اصلاح کن
                          key: viewportKey, // خط‌کش اینجا نصب شد
                          color: Colors.black, // محوطه سیاه
                          constraints: BoxConstraints.expand(),
                          child: Stack( // پشته داخلی برای عکس و کادر برش
                            alignment: Alignment.center,
                            children: [
                              // ۱. در بخش InteractiveViewer، رویداد را فقط برای گرفتن عدد بخواهید
                              InteractiveViewer(
                                transformationController: _transformationController,
                                boundaryMargin: const EdgeInsets.all(double.infinity),
                                minScale: 0.01,
                                maxScale: 5.0,
                                clipBehavior: Clip.none, // اجازه بده محتوا خارج از کادر هم وجود داشته باشد
                                onInteractionUpdate: (details) {
                                  // اگر کاربر در حال چرخاندن با دو انگشت است (rotation != 0)
                                  if (details.rotation != 0) {
                                    // مستقیماً مقدار تغییر زاویه را به ویو منیجر می‌فرستیم
                                    _viewManager.applyManualRotation(details.rotation);
                                  }
                                },
                                child: Stack( // یک استک جدید دور عکس می‌کشیم
                                children: [
                                  OverflowBox(
                                    alignment: Alignment.center,
                                    minWidth: 0.0, maxWidth: double.infinity,
                                    minHeight: 0.0, maxHeight: double.infinity,
                                    // ۲. حالا چرخش را اینجا اعمال می‌کنیم که مستقل از زومِ کنترلر باشد
                                    // child: Transform.rotate(
                                    //   angle: _rotationAngle,
                                      child: ColorFiltered(
                                        colorFilter: ColorFilter.matrix([
                                          _brightnessValue, 0, 0, 0, 0,
                                          0, _brightnessValue, 0, 0, 0,
                                          0, 0, _brightnessValue, 0, 0,
                                          0, 0, 0, 1, 0,
                                        ]),
                                        child: Image.file(
                                          _currentFile,
                                          fit: BoxFit.none,
                                        ),
                                      ),
                                    // ),
                                  ),
                                  // --- دایره قرمز را اینجا بگذار ---
                                  // حالا این دایره جزئی از "محتوا" است و با دست جابجا می‌شود
                                  _buildPhotoCenterPoint(),
                                ],
                              ),
                              ),

                              // لایه رویی پشته داخلی: کادر برش (فقط در حالت ابعاد)
                              if (_activeTool == "ابعاد و حجم")
                              GestureDetector(
                                // ۱. گوش دادن به حرکت انگشت روی کادر
                                onPanUpdate: (details) {
                                  setState(() {
                                    // اضافه کردن میزان حرکت انگشت به موقعیت فعلی کادر
                                    _cropOffset += details.delta;
                                  });
                                },
                                child: Transform.translate(
                                  // ۲. جابه‌جایی فیزیکی کادر بر اساس محاسبات
                                  offset: _cropOffset,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 100), // زمان کوتاه برای پاسخگویی سریع به انگشت
                                    width: _cropAreaSize.width,
                                    height: _cropAreaSize.height,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.7),
                                          spreadRadius: 2000, 
                                        )
                                      ],
                                    ),
                                    // اضافه کردن خطوط راهنما برای دقت بیشتر توریست
                                    child: Stack(
                                      children: [
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                                          children: [
                                            VerticalDivider(color: Colors.white.withOpacity(0.3), width: 1),
                                            VerticalDivider(color: Colors.white.withOpacity(0.3), width: 1),
                                          ]
                                        ),
                                        Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                                          children: [
                                            Divider(color: Colors.white.withOpacity(0.3), height: 1),
                                            Divider(color: Colors.white.withOpacity(0.3), height: 1),
                                          ]
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              _buildStaticDebugPoint(),
                            ]
                          )
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // لایه ۲: بنر راهنما (بالاترین لایه زمانی که باز است)
            _buildTopHelpBanner(),

            // لایه ۳: پنل هوشمند Undo/Redo (روی بدنه)
            _buildDynamicTopPanel(), 

            // لایه ۴: باکس تنظیمات پایین (روی بدنه)
            if (_activeTool.isNotEmpty) _buildBottomActionBox(),
          ],
        ),
      ),
    );
  }



  double _rawImageWidth = 0;
  double _rawImageHeight = 0;

  
  /// ساخت پنل داینامیک بالای صفحه (شامل ابزارهای مدیریت و تاریخچه)
  /// 
  /// این ویجت یک لایه شناور است که با استفاده از [AnimatedPositioned] جابه‌جا می‌شود:
  /// ۱. بخش تاریخچه (Undo/Redo): یک [ListView] افقی که تمام گام‌های ویرایش را نشان می‌دهد
  ///    و به کاربر اجازه می‌دهد به هر مرحله‌ای از ویرایش (Saved یا غیره) بپرد.
  /// ۲. مدیریت لایه‌ها: دکمه‌های Save، Help، Zoom و Rotate را در یک ستون کناری سازماندهی می‌کند.
  /// ۳. منوهای شناور (Floating Menus): 
  ///    - منوی زوم: نمایش درصد فعلی بزرگ‌نمایی و دکمه‌های کنترل پله‌ای.
  ///    - منوی چرخش: نمایش زاویه به درجه و دکمه‌های چرخش دقیق.
  /// ۴. پویایی: موقعیت این پنل با باز شدن بنر راهنما (تغییر مقدار [top]) به صورت انیمیشنی جابه‌جا می‌شود.
  Widget _buildDynamicTopPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      top: _showHelp ? 110 : 20,
      left: 80,
      right: 15,
      // تغییر ۱: ارتفاع ثابت می‌دهیم تا با باز شدن منو، کل پنل جابه‌جا نشود
      height: 450, 
      child: Stack( // تغییر ۲: استفاده از استک داخلی برای مدیریت لایه زوم
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ۱. دکمه ذخیره
              _buildActionButton(
                icon: Icons.save_rounded,
                color: Colors.greenAccent,
                onPressed: _saveFinalImage,
              ),

              const SizedBox(width: 5),

              // ۲. بخش Undo/Redo
              Expanded(
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.white, size: 20),
                        onPressed: _currentStepIndex > 0 ? () => _goToStep(_currentStepIndex - 1) : null,
                      ),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _historySteps.length,
                          itemBuilder: (context, index) {
                            bool isActive = index == _currentStepIndex;
                            bool isSaved = index <= _lastSavedStepIndex;
                            return GestureDetector(
                              onTap: () => _goToStep(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSaved
                                      ? Colors.greenAccent.withOpacity(isActive ? 0.8 : 0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isSaved ? Colors.greenAccent : Colors.white30,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _historySteps[index].label,
                                  style: TextStyle(
                                    color: isSaved ? Colors.white : Colors.white60,
                                    fontSize: 10,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.redo, color: Colors.white, size: 20),
                        onPressed: _currentStepIndex < _historySteps.length - 1 ? () => _goToStep(_currentStepIndex + 1) : null,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 0),

              			  // ۳. دکمه‌های سمت راست (Help و Zoom)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // دکمه راهنما
                  _buildActionButton(
                    icon: _isHelpModeActive ? Icons.help_rounded : Icons.help_outline_rounded,
                    color: _isHelpModeActive ? Colors.yellowAccent : Colors.white70,
                    onPressed: () => setState(() {
                      _isHelpModeActive = !_isHelpModeActive;
                      _showHelp = _isHelpModeActive;
                    }),
                  ),
                  
                  const SizedBox(height: 10),

                  // ۱. دکمه اصلی منوی زوم
                  _buildActionButton(
                    icon: Icons.center_focus_strong,
                    color: _showZoomMenu ? Colors.blueAccent : Colors.white70,
                    onPressed: () => setState(() {
                      _showZoomMenu = !_showZoomMenu;
                      _showrotateMenu = false; // بستن منوی دیگر برای جلوگیری از شلوغی
                    }),
                  ),

                  const SizedBox(height: 11),

                  // ۲. دکمه اصلی منوی چرخش
                  _buildActionButton(
                    icon: Icons.rotate_right_rounded,
                    color: _showrotateMenu ? Colors.orangeAccent : Colors.white70,
                    onPressed: () => setState(() {
                      _showrotateMenu = !_showrotateMenu;
                      _showZoomMenu = false; // بستن منوی دیگر
                    }),
                  ),

                  const SizedBox(height: 11),

                  // ۳. دکمه فیت کردن (Fit)
                  _buildActionButton(
                    icon: Icons.fit_screen_rounded,
                    color: Colors.greenAccent,
                    onPressed: () {
                      // مرحله ۱: زوم را اصلاح کن (عکس ممکن است به گوشه برود)
                      _viewManager.fitToScreen(viewportKey);
                      
                      setState(() {});
                    }
                  ),

// داخل آن ستون (Column) دکمه‌های سمت راست
const SizedBox(height: 11),
_buildActionButton(
  icon: Icons.open_with,
  // اگر ابزار فعال "pan" بود، رنگ دکمه بنفش شود
  color: _activeTool == "pan" ? Colors.purpleAccent : Colors.white70, 
  onPressed: () {
    setState(() {
        _showPanMenu = !_showPanMenu;
      
    });
  },
),
                ],
              ),
            ], // پایان Row اصلی
          ),


            // ۴. استفاده از متد آماده برای منوی زوم
            if (_showZoomMenu)
            _viewManager.buildFloatingMenu(
              top: 57,
              label: "${(_transformationController.value.getMaxScaleOnAxis() * 100).toInt()}%",
              onDecrease: () => _viewManager.changeZoomStep(false),
              onIncrease: () => _viewManager.changeZoomStep(true),
              onReset: () => _viewManager.resetZoom(),
              accentColor: Colors.blueAccent,
            ),

            // ۵. استفاده از متد آماده برای منوی چرخش
            if (_showrotateMenu)
            _viewManager.buildFloatingMenu(
              top: 114,
              label: "${(_viewManager.rotationAngle * 180 / math.pi).abs().toStringAsFixed(0)}°",
              resetText: "ZERO",
              onDecrease: () => _viewManager.changeRotation(false),
              onIncrease: () => _viewManager.changeRotation(true),
              onReset: () => _viewManager.resetRotation(),
              accentColor: Colors.orangeAccent,
            ),

            if (_showPanMenu)
            _viewManager.buildFloatingPanMenu(
                top: 230, // مقدار متناسب با دکمه پن
                onStartPan: (dx, dy) => _viewManager.startContinuousPan(dx, dy),
                onStop: () => _viewManager.stopContinuousPan(),
                onCenterTap: () {
                  _viewManager.resetToCenter(viewportKey);
                  setState(() {}); // برای بروزرسانی نقاط دیباگ اگر روشن هستند
                },
              ),
          ]
        ),
      );
  }

  Widget _buildArrowCircle(IconData icon, VoidCallback onPressed) {
  return InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    ),
  );
}

  // --- این بخش را دقیقاً قبل از پایانِ Stack (داخل لیست children) اضافه کن ---
  
 

Widget _buildToolButton({
  required IconData icon,
  required String label,
  required bool isActive,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // اگر ابزار فعال باشد، پس‌زمینه کمی روشن‌تر می‌شود
        color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.blueAccent : Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.blueAccent : Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

  // ۱. نقطه سبز: مرکز ثابت محوطه نمایش (Target)
  Widget _buildStaticDebugPoint() {
    if (_viewManager.debugViewportCenter == null) return const SizedBox.shrink();

    // print("-----------------------------------------");
    // print("📍 DEBUG COORDINATES:");
    // print("🟢 Viewport Center (Target): ${_viewManager.debugViewportCenter}");

  // ۱. گرفتن ماتریس فعلی از کنترلر InteractiveViewer
  final Matrix4 matrix = _transformationController.value;

  // ۲. تبدیل مختصات محلی عکس (نقطه قرمز) به مختصات نمایشی (Scene)
  // این کار اثر زوم (Scale) و جابجایی (Offset) را روی نقطه قرمز اعمال می‌کند
  final Offset localPoint = _viewManager.debugActualImageCenter!; 
  final Offset globalPointOfImage = MatrixUtils.transformPoint(matrix, localPoint);

  // ۳. حالا محاسبه بردار جابجایی واقعی
  final Offset displacementVector = _viewManager.debugViewportCenter! - globalPointOfImage;

  // print("-----------------------------------------");
  // print("📍 ACTUAL COORDINATES (Post-Transform):");
  // print("🟢 Viewport Center: ${_viewManager.debugViewportCenter}");
  // print("🔴 Image Center in Viewport Space: $globalPointOfImage"); // این عدد دیگر ۱۵۱ نخواهد بود
  // print("📐 REAL DISPLACEMENT VECTOR:");
  // print("   Vector DX: ${displacementVector.dx}");
  // print("   Vector DY: ${displacementVector.dy}");
  // print("   Required Move: ${displacementVector.distance.toStringAsFixed(2)} pixels");

    return Positioned(
      left: _viewManager.debugViewportCenter!.dx - 0,
      top: _viewManager.debugViewportCenter!.dy - 0,
      child: Container(
        width: 00, height: 00,
        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
      ),
    );
  }

  // ۲. نقطه قرمز: مرکز واقعی عکس که باید با عکس جابجا شود
  Widget _buildPhotoCenterPoint() {
    if (_viewManager.debugActualImageCenter == null) return const SizedBox.shrink();
    // print("🔴 Image Center (Current): ${_viewManager.debugActualImageCenter}");
    return Positioned(
      left: _viewManager.debugActualImageCenter!.dx - 0,
      top: _viewManager.debugActualImageCenter!.dy - 0,
      child: Container(
        width: 0, height: 0,
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }

  /// مدیریت فرآیند نهایی‌سازی و ذخیره تصویر
  /// 
  /// این متد وظایف زیر را به عهده دارد:
  /// ۱. فعال‌سازی حالت بارگذاری ([_isSaving]): نمایش نشانگر پیشرفت به کاربر.
  /// ۲. همگام‌سازی تاریخچه: مقدار [_lastSavedStepIndex] را با ایندکس فعلی برابر می‌کند. 
  ///    این کار باعث می‌شود در پنل تاریخچه، تمام گام‌های قبلی به رنگ سبز (ذخیره شده) درآیند.
  /// ۳. بازخورد به کاربر: نمایش یک [SnackBar] موفقیت‌آمیز پس از اتمام فرآیند.
  /// ۴. پایداری: استفاده از [mounted] برای جلوگیری از خطای حافظه در صورتی که کاربر قبل از اتمام ذخیره، صفحه را ببندد.
  void _saveFinalImage() async {
    setState(() => _isSaving = true);
    
    // شبیه‌سازی فرآیند ذخیره
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSaving = false;
        // مهم: ثبت ایندکس فعلی به عنوان آخرین وضعیت ذخیره شده
        _lastSavedStepIndex = _currentStepIndex; 
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تغییرات تا این مرحله ذخیره شدند"), backgroundColor: Colors.green),
      );
    }
  }

  /// مدیریت سیستم تاریخچه تعاملی (Undo/Redo Logic)
  /// 
  /// این متد قلب سیستم مدیریت وضعیت برنامه است که وظایف زیر را انجام می‌دهد:
  /// ۱. مدیریت انشعاب (Branching): اگر کاربر Undo کرده باشد و تغییر جدیدی ثبت کند، 
  ///    تمام مراحل "آینده" حذف می‌شوند تا تاریخچه خطی بماند (مشابه استاندارد فتوشاپ).
  /// ۲. ثبت وضعیت (Snapshot): یک کپی کامل از تمام متغیرهای کنترلی (زاویه، نور، ابزار فعال و فایل فعلی)
  ///    در لحظه تغییر ایجاد کرده و در قالب یک نقشه ([Map]) ذخیره می‌کند.
  /// ۳. به‌روزرسانی نشانگر: اشاره‌گر [_currentStepIndex] را به آخرین گام منتقل می‌کند تا 
  ///    رابط کاربری دقیقاً مرحله جدید را به عنوان مرحله فعال نشان دهد.
  void _addToHistory(String label) {
    setState(() {
      // ۱. اگر کاربر چند مرحله عقب رفته باشد و تغییر جدیدی ایجاد کند، 
      // مراحل جلوتر از لیست حذف می‌شوند (مثل فتوشاپ)
      if (_currentStepIndex < _historySteps.length - 1) {
        _historySteps = _historySteps.sublist(0, _currentStepIndex + 1);
      }

      // ۲. ثبت وضعیت فعلی متغیرها در یک نقشه (Map)
      Map<String, dynamic> currentState = {
        'rotation': _rotationAngle,
        'brightness': _brightnessValue,
        'tool': _activeTool,
        'file': _currentFile, // ذخیره فایل فعلی در این مرحله از تاریخچه
        // در آینده موارد دیگر مثل فیلتر و ابعاد را اینجا اضافه می‌کنیم
      };

      // ۳. اضافه کردن یک مرحله جدید به لیست تاریخچه
      _historySteps.add(EditStep(label, currentState));
      
      // ۴. بردن نشانگر وضعیت به آخرین مرحله اضافه شده
      _currentStepIndex = _historySteps.length - 1;
      
      // ۵. از آنجا که تغییری رخ داده، ایندکس آخرین ذخیره (فلاپی) با ایندکس فعلی متفاوت می‌شود
      // (این باعث می‌شود آیتم جدید در نوار بالا "Outline" بماند و سبز نشود)
    });
  }

  /// ساخت دکمه‌های کنترلی استاندارد و متحدالشکل
  /// 
  /// این متد کمکی (Helper) برای حفظ یکپارچگی طراحی در تمام بخش‌های برنامه استفاده می‌شود:
  /// ۱. هندسه ثابت: ایجاد دکمه‌های دایره‌ای با ابعاد دقیق ۴۵x۴۵ پیکسل.
  /// ۲. طراحی بصری: استفاده از پس‌زمینه نیمه‌شفاف ([withOpacity]) و لبه‌های ظریف ([Border]) 
  ///    برای ایجاد ظاهری مدرن و شیشه‌ای (Glassmorphism).
  /// ۳. تعامل: پارامتر [onPressed] اجازه می‌دهد تا عملکردهای مختلف به یک قالب بصری واحد تزریق شوند.
  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 26),
        onPressed: onPressed,
      ),
    );
  }

  /// انتقال وضعیت برنامه به یک گام مشخص از تاریخچه (Time Travel)
  /// 
  /// این متد با دریافت [index]، وضعیت کامل ویرایشگر را به آن لحظه بازمی‌گرداند:
  /// ۱. بازیابی متغیرها: تمام مقادیر ذخیره شده شامل زاویه چرخش، میزان نور و ابزار فعال 
  ///    از نقشه ([targetState]) استخراج و به متغیرهای اصلی اختصاص داده می‌شوند.
  /// ۲. مدیریت تصویر: فایل تصویر مربوط به آن مرحله (مثلاً عکسی که در مرحله قبل کراپ شده) 
  ///    مجدداً به عنوان تصویر جاری ([_currentFile]) بارگذاری می‌شود.
  /// ۳. پویایی راهنما: متن راهنمای بالای صفحه را متناسب با ابزاری که در آن مرحله فعال بوده، به‌روزرسانی می‌کند.
  /// ۴. ایمنی داده: با استفاده از عملگر [??]، از بروز خطا در صورت نبودن یکی از پارامترها در مراحل قدیمی جلوگیری می‌کند.
  void _goToStep(int index) {
    // بررسی اینکه ایندکس در محدوده لیست باشد
    if (index >= 0 && index < _historySteps.length) {
      setState(() {
        _currentStepIndex = index;
        final step = _historySteps[index];
        // استخراج اطلاعات مرحله
        var targetState = step.state;
        
        // بازگرداندن مقادیر ذخیره شده به متغیرهای صفحه
        // استفاده از ?? برای زمانی که شاید مقداری در آن مرحله ذخیره نشده باشد
        _rotationAngle = targetState['rotation'] ?? 0.0;
        _brightnessValue = targetState['brightness'] ?? 1.0;
        _activeTool = targetState['tool'] ?? "";
        
        // آپدیت متن راهنما بر اساس ابزار فعال در آن مرحله
        if (_activeTool.isNotEmpty) {
          _helpText = "تنظیمات مربوط به $_activeTool را تغییر دهید";
        }

        // بازیابی فایل تصویر مربوط به آن مرحله
        if (step.state.containsKey('file')) {
          _currentFile = step.state['file'];
        }

      });
    }
  }

  /// ساخت نوار ابزار عمودی کناری (Side Navigation Toolbar)
  /// 
  /// این ویجت ستون فقرات دسترسی کاربر به قابلیت‌های ویرایش است:
  /// ۱. دسته‌بندی هوشمند: ابزارها به دو بخش اصلی تقسیم شده‌اند:
  ///    الف) ابزارهای Frontend: پردازش‌های سریع و داخلی موبایل (رنگ صورتی).
  ///    ب) ابزارهای AI/Backend: پردازش‌های سنگین هوش مصنوعی در سمت سرور (رنگ زرد).
  /// ۲. طراحی ریسپانسیو: استفاده از [SingleChildScrollView] باعث می‌شود در گوشی‌هایی با 
  ///    صفحه نمایش کوچک، کاربر به راحتی با اسکرول کردن به تمام ابزارها دسترسی داشته باشد.
  /// ۳. تفکیک بصری: استفاده از یک خط عمودی ظریف ([Border]) و جداکننده‌های افقی ([Divider]) 
  ///    برای ایجاد نظم و تمایز بین بخش‌های مختلف ابزارها.
  Widget _buildSideToolbar() {
    return Container(
      width: 50, // کمی عریض‌تر برای راحتی لمس
      decoration: const BoxDecoration(
        color: Colors.transparent, // شفاف کردن کل پنل
        border: Border(
          right: BorderSide(color: Colors.white30, width: 0.5), // یک خط بسیار ظریف برای جدا سازی
        ),
      ),
      child: SingleChildScrollView( // برای اینکه در گوشی‌های کوچک‌تر اسکرول بخورد
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- بخش اول: ابزارهای Frontend (پردازش در موبایل) ---
            _toolIconButton(Icons.aspect_ratio, "ابعاد و حجم", "تغییر نسبت تصویر (استوری و...) و بهینه‌سازی حجم فایل", iconColor: Colors.pinkAccent), // <--- ابزار جدید
            _toolIconButton(Icons.crop, "کراپ", "بریدن عکس در ابعاد مختلف و نسبت‌های استاندارد", iconColor: Colors.pinkAccent),
            _toolIconButton(Icons.rotate_right, "چرخش", "چرخاندن آزادانه یا ۹۰ درجه‌ای عکس", iconColor: Colors.pinkAccent),
            _toolIconButton(Icons.brightness_6, "تنظیم نور", "تنظیم میزان روشنایی", iconColor: Colors.pinkAccent),
            _toolIconButton(Icons.text_fields, "متن", "اضافه کردن نوشته با فونت‌های توریستی زیبا", iconColor: Colors.pinkAccent),
            _toolIconButton(Icons.auto_fix_high, "فیلتر", "اعمال فیلترهای رنگی سریع و لایه‌ای", iconColor: Colors.pinkAccent),
            // اضافه کردن به بخش اول در _buildSideToolbar
            _toolIconButton(Icons.insert_emoticon, "ایموجی", "اضافه کردن استیکر و ایموجی برای بیان احساسات",iconColor: Colors.pinkAccent),
            _toolIconButton(Icons.category, "اشکال", "رسم دایره، مربع یا فلش برای راهنمایی روی عکس",iconColor: Colors.pinkAccent),
            _toolIconButton(Icons.edit, "قلم", "رسم آزاد (Freehand) یا خطوط مستقیم روی عکس",iconColor: Colors.pinkAccent),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Colors.white24, indent: 10, endIndent: 10),
            ),

            // --- بخش دوم: ابزارهای Backend AI (پردازش در Django) ---
            // از رنگ متفاوتی برای تمایز ابزارهای هوشمند استفاده می‌کنیم
            _toolIconButton(
              Icons.cleaning_services, 
              "حذف شیء", 
              "حذف هوشمند افراد و اشیاء اضافی از عکس توسط AI",
              iconColor: Colors.amberAccent
            ),
            _toolIconButton(
              Icons.face_retouching_natural, 
              "رتوش چهره", 
              "بهبود کیفیت چهره و اصلاح لبخند با هوش مصنوعی",
              iconColor: Colors.amberAccent
            ),
            _toolIconButton(
              Icons.wallpaper, 
              "تغییر پس‌زمینه", 
              "جداسازی هوشمند سوژه و تغییر یا تار کردن پس‌زمینه",
              iconColor: Colors.amberAccent
            ),
            _toolIconButton(
              Icons.shutter_speed, 
              "ارتقا کیفیت", 
              "افزایش رزولوشن و جزئیات عکس‌های تار (Upscale)",
              iconColor: Colors.amberAccent
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// ساخت دکمه‌های تکی نوار ابزار با قابلیت‌های تعاملی
  /// 
  /// این متد برای هر ابزار یک دکمه اختصاصی می‌سازد که شامل:
  /// ۱. سیستم بازخورد بصری: با استفاده از [AnimatedContainer]، ابزار فعال با تغییر رنگ پس‌زمینه و آیکون به رنگ آبی متمایز می‌شود.
  /// ۲. تول‌تیپ (Tooltip): هنگام نگه داشتن انگشت، نام ابزار در کنار نوار ابزار (سمت راست) نمایش داده می‌شود.
  /// ۳. مدیریت وضعیت: با ضربه زدن روی ابزار، متغیر [_activeTool] و متن راهنمای مربوط به آن ([_helpText]) به‌روزرسانی می‌شود.
  Widget _toolIconButton(IconData icon, String toolName, String helpDesc, {required MaterialAccentColor iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Tooltip(
        message: toolName, // متنی که هنگام نگه داشتن ظاهر می‌شود
        verticalOffset: 0,
        margin: const EdgeInsets.only(left: 75), // متن تول‌تیپ رو می‌ندازه سمت راست پنل که روی آیکون نباشه
        decoration: BoxDecoration(
          color: iconColor,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _activeTool = toolName;
              _helpText = helpDesc;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _activeTool == toolName ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _activeTool == toolName ? Colors.blueAccent : Colors.white70,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  /// ساخت دکمه‌های تکی نوار ابزار با قابلیت‌های تعاملی
  /// 
  /// این متد برای هر ابزار یک دکمه اختصاصی می‌سازد که شامل:
  /// ۱. سیستم بازخورد بصری: با استفاده از [AnimatedContainer]، ابزار فعال با تغییر رنگ پس‌زمینه و آیکون به رنگ آبی متمایز می‌شود.
  /// ۲. تول‌تیپ (Tooltip): هنگام نگه داشتن انگشت، نام ابزار در کنار نوار ابزار (سمت راست) نمایش داده می‌شود.
  /// ۳. مدیریت وضعیت: با ضربه زدن روی ابزار، متغیر [_activeTool] و متن راهنمای مربوط به آن ([_helpText]) به‌روزرسانی می‌شود.
  Widget _buildTopHelpBanner() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      // مقدار منفی باید دقیقاً برابر یا بیشتر از ارتفاع باشد تا کاملاً مخفی شود
      top: _showHelp ? 0 : -130, 
      left: 0, 
      right: 0,
      child: ClipRRect( // برای افکت بلور حتماً استفاده کن
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 120, // کمی بلندتر برای اطمینان از پوشش کامل آیکون و حاشیه امن بالا
            padding: const EdgeInsets.only(top: 20, left: 15, right: 15, bottom: 10),
            decoration: BoxDecoration(
              // لایه تیره شفاف برای کنتراست بهتر
              color: Colors.black.withOpacity(0.2), 
              // حذف مارجین برای اینکه بنر لبه به لبه باشد و آیکون پشتش لو نرود
              border: const Border(
                bottom: BorderSide(color: Colors.white10, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.yellowAccent, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    _helpText, 
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)
                  ),
                ),
                // دکمه بستن که هم بنر را می‌بندد و هم آیکون را دی‌اکتیو می‌کند
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _showHelp = false;
                      _isHelpModeActive = false;
                    });
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ساخت باکس عملیاتی پایین صفحه (Bottom Action Box)
  /// 
  /// این ویجت به عنوان کنسول کنترلی هر ابزار عمل می‌کند:
  /// ۱. مدیریت محتوای پویا: با توجه به ابزار انتخاب شده (مانند "ابعاد و حجم")، ویجت‌های کنترلی مخصوص آن ابزار را در بخش بالایی نمایش می‌دهد.
  /// ۲. دکمه‌های تایید و انصراف: 
  ///    - انصراف: ابزار فعال را غیرفعال کرده و تغییرات موقت را لغو می‌کند.
  ///    - اعمال: عملیات اصلی ابزار (مانند [AspectRatioHandler.cropImage]) را روی فایل واقعی اجرا می‌کند.
  /// ۳. پردازش تصویر: پس از کلیک بر روی "اعمال"، تصویر جدید جایگزین تصویر قبلی شده، مختصات کادر ریست می‌شود و یک گام جدید به تاریخچه افزوده می‌گردد.
  /// ۴. طراحی شناور: با استفاده از [Positioned]، این باکس به گونه‌ای قرار گرفته که با نوار ابزار کناری تداخلی نداشته باشد.عملیات
  Widget _buildBottomActionBox() {
    return Positioned(
      bottom: 10, left: 60, right: 10, // فاصله از چپ برای تداخل نداشتن با پنل ابزار
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.9), // کمی تیره‌تر برای خوانایی بهتر
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15)],
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // باکس به اندازه محتوا جمع می‌شود
          children: [
            // نمایش محتوای اختصاصی هر ابزار
            if (_activeTool == "ابعاد و حجم") _buildAspectRatioContent(),
            
            const SizedBox(height: 10),
            
            // ردیف دکمه‌های کنترلی (انصراف و اعمال)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => setState(() => _activeTool = ""),
                  child: const Text("انصراف", style: TextStyle(color: Colors.white54)),
                ),
                Text("تنظیمات $_activeTool", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    if (_activeTool == "ابعاد و حجم") {
                      // ۱. نمایش حالت انتظار (اختیاری ولی حرفه‌ای)
                      // اینجا می‌توانی یک متغیر isLoading را true کنی

                      // ۲. فراخوانی تابع برش که در AspectRatioHandler نوشتیم
                      final croppedFile = await AspectRatioHandler.cropImage(
                        imageFile: _currentFile, // استفاده از فایل فعلی
                            previewSize: const Size(300, 450), 
                            cropSize: _cropAreaSize,
                            cropOffset: _cropOffset,
                          );

                          setState(() {
                            _currentFile = croppedFile; // جایگزینی عکس بریده شده
                            _activeTool = ""; 
                            _cropOffset = Offset.zero; // ریست کردن مکان کادر برای استفاده بعدی
                          });
                          _addToHistory("-brush");
                    } else {
                      // برای بقیه ابزارها که هنوز نساختیم
                      setState(() => _activeTool = "");
                    }
                  },
                  child: const Text("اعمال"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ساخت لیست انتخاب نسبت تصویر (Aspect Ratio Selector)
  /// 
  /// این متد محتوای اختصاصی ابزار "ابعاد و حجم" را مدیریت می‌کند:
  /// ۱. دریافت گزینه‌ها: لیست نسبت‌های استاندارد (مثل ۱:۱ یا استوری) را از [AspectRatioHandler] فراخوانی می‌کند.
  /// ۲. محاسبه ابعاد کادر برش: با انتخاب هر گزینه، اندازه کادر سفید روی صفحه ([_cropAreaSize]) به صورت آنی محاسبه می‌شود تا پیش‌نمایش دقیقی به کاربر داده شود.
  /// ۳. تعامل کاربر: هر گزینه شامل یک آیکون و برچسب است که با کلیک روی آن، علاوه بر تغییر نسبت، یک ثبت موقت در تاریخچه انجام می‌شود تا کاربر بداند چه تغییری ایجاد کرده است.
  /// ۴. طراحی پیمایشی: گزینه‌ها در یک [ListView] افقی قرار گرفته‌اند تا فضای کمی اشغال کنند.
  Widget _buildAspectRatioContent() {
    var options = AspectRatioHandler.getOptions();
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        itemBuilder: (context, index) {
          var opt = options[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRatio = opt.ratio;
                _cropOffset = Offset.zero; // بازگشت به مرکز با تغییر نسبت
                
                // فرض می‌کنیم سایز نمایش عکس را داریم (مثلاً 300x400)
                // در دنیای واقعی بهتر است از LayoutBuilder استفاده شود
                _cropAreaSize = AspectRatioHandler.calculateCropSize(
                  ratio: opt.ratio,
                  imageAreaSize: const Size(300, 450), 
                );
              });
              _addToHistory("ابعاد: ${opt.label}");
            },
            child: Container(
              width: 65,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(opt.icon, color: Colors.pinkAccent, size: 20),
                  const SizedBox(height: 4),
                  Text(opt.label, style: const TextStyle(color: Colors.white, fontSize: 9)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void applyCorrection() {
  final Matrix4 currentMatrix = _transformationController.value;
  
  // ۱. محاسبه بردار جابجایی (همان کدی که در مرحله قبل نوشتیم)
  final Offset localPoint = _viewManager.debugActualImageCenter!; 
  final Offset globalPointOfImage = MatrixUtils.transformPoint(currentMatrix, localPoint);
  final Offset displacementVector = _viewManager.debugViewportCenter! - globalPointOfImage;

  // ۲. ایجاد یک ماتریس برای جابجایی (Translation)
  final Matrix4 translationMatrix = Matrix4.identity()
    ..translate(displacementVector.dx, displacementVector.dy);

  // ۳. ترکیب ماتریس جدید با ماتریس قبلی
  // نکته: جابجایی باید به "مجموع" ماتریس اضافه شود
  final Matrix4 newMatrix = translationMatrix * currentMatrix;

  // ۴. اعمال به کنترلر (به صورت انیمیشن یا مستقیم)
  setState(() {
    _transformationController.value = newMatrix;
  });
}

Widget _buildPanController() {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPanButton(Icons.arrow_upward, 0, -10), // بالا
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPanButton(Icons.arrow_back, -10, 0), // چپ
            const SizedBox(width: 20),
            _buildPanButton(Icons.arrow_forward, 10, 0), // راست
          ],
        ),
        _buildPanButton(Icons.arrow_downward, 0, 10), // پایین
      ],
    ),
  );
}

Widget _buildPanButton(IconData icon, double dx, double dy) {
  return GestureDetector(
    onLongPressStart: (_) => _viewManager.startContinuousPan(dx, dy),
    onLongPressEnd: (_) => _viewManager.stopContinuousPan(),
    onTap: () => _viewManager.manualPan(dx, dy), // برای جابجایی تکی با یک ضربه
    child: CircleAvatar(
      backgroundColor: Colors.white24,
      child: Icon(icon, color: Colors.white),
    ),
  );
}

}

/// مدل داده‌ای برای ذخیره "کپسول" وضعیت در هر مرحله
/// 
/// این کلاس [EditStep] وظیفه دارد یک اسنپ‌شات (Snapshot) کامل از تمام 
/// تنظیمات برنامه را در یک لحظه خاص ذخیره کند
class EditStep {
  final String label; // مثلاً "چرخش +۹۰"
  final Map<String, dynamic> state; // ذخیره مقادیر عددی در آن لحظه

  EditStep(this.label, this.state);
}

/// مدیریت مخزن تاریخچه و موقعیت فعلی کاربر
/// 
/// [_historySteps]: لیستی از تمام مراحلی که کاربر طی کرده است. 
/// اولین آیتم همیشه "اصلی" است تا راه بازگشت به عکس خام باز باشد.
/// 
/// [_currentStepIndex]: نشانگر یا "هد" سیستم تاریخچه است که مشخص می‌کند 
/// کاربر در حال حاضر در کدام مرحله از لیست قرار دارد (برای Undo/Redo).
List<EditStep> _historySteps = [EditStep("اصلی", {})]; // نقطه شروع
int _currentStepIndex = 0;