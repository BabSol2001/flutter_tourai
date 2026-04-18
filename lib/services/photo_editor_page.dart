import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../logic/editor/aspect_ratio_handler.dart';

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
  String _helpText = ""; // متن راهنما
  String _activeTool = ""; // ابزار انتخاب شده فعلی

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

  final TransformationController _transformationController = TransformationController();

  bool _showZoomMenu = false; // برای باز و بسته شدن لیست درصدها

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file; // در ابتدا، فایل فعلی همان فایل ورودی است
  
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
                        child: Stack( // پشته داخلی برای عکس و کادر برش
                          alignment: Alignment.center,
                          children: [
                            InteractiveViewer(
                              transformationController: _transformationController, // اتصال کنترلر
                              panEnabled: true, // اجازه جابه‌جایی عکس با انگشت                              
                              scaleEnabled: true,
                              // این گزینه اجازه می‌دهد با دو انگشت عکس را بچرخانیم
                              onInteractionUpdate: (ScaleUpdateDetails details) {
                                // اگر کاربر در حال چرخاندن دو انگشت است (Rotation != 0)
                                if (details.rotation != 0) {
                                  setState(() {
                                    // تغییر زاویه بر اساس حرکت انگشتان
                                    double sensitivity = 0.005;
                                    _rotationAngle += details.rotation* sensitivity;
                                  });
                                }
                              },

                              boundaryMargin: const EdgeInsets.all(100), // حاشیه برای بیرون نرفتن کامل عکس
                              minScale: 0.5, // حداقل مقدار کوچک‌نمایی
                              maxScale: 4.0, // حداکثر مقدار بزرگ‌نمایی
                              // لایه زیرین پشته داخلی: عکس
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix([
                                  _brightnessValue, 0, 0, 0, 0,
                                  0, _brightnessValue, 0, 0, 0,
                                  0, 0, _brightnessValue, 0, 0,
                                  0, 0, 0, 1, 0,
                                ]),
                                child: Transform.rotate(
                                  angle: _rotationAngle,
                                  child: Image.file(_currentFile),
                                ),
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
                            ]
                        
                        )
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

  void _setZoomLevel(double scale) {
    setState(() {
      // ایجاد یک ماتریس که فقط مقیاس (Scale) را تغییر می‌دهد
      _transformationController.value = Matrix4.identity()..scale(scale);
      _showZoomMenu = false; // بستن منو بعد از انتخاب
    });
  }

  Widget _buildDynamicTopPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      top: _showHelp ? 110 : 20,
      left: 80, // برای ایجاد فاصله از پنل ابزار عمودی
      right: 15,
      child: Row(
        children: [
          // ۱. دکمه ذخیره (سمت چپ - قرینه هلپ)
          _buildActionButton(
            icon: Icons.save_rounded, // آیکون معروف فلاپی‌دیسک
            color: Colors.greenAccent, // همون رنگ سبزِ تایید
            onPressed: _saveFinalImage, // متدی که در ادامه تعریف می‌کنیم
          ),

          const SizedBox(width: 10),

          // ۲. بخش Undo/Redo (مرکز)
          Expanded(
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        // بررسی اینکه آیا این مرحله قبل یا مساوی آخرین مرحله ذخیره شده است
                        bool isSaved = index <= _lastSavedStepIndex; 

                        return GestureDetector(
                          onTap: () => _goToStep(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            decoration: BoxDecoration(
                              // اگر ذخیره شده باشد -> پس‌زمینه سبز کدر یا روشن
                              // اگر ذخیره نشده باشد -> فقط خط دور (Outline)
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

          const SizedBox(width: 10),

          // ۳. پنل عمودی سمت راست (هلپ و ریست زوم)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // دکمه هلپ
              _buildActionButton(
                icon: _isHelpModeActive ? Icons.help_rounded : Icons.help_outline_rounded,
                color: _isHelpModeActive ? Colors.yellowAccent : Colors.white70,
                onPressed: () {
                  setState(() {
                    _isHelpModeActive = !_isHelpModeActive;
                    _showHelp = _isHelpModeActive;
                  });
                },
              ),
              
              const SizedBox(height: 8), // فاصله عمودی بین دو دکمه

              // بخش کنترل زوم
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الف) لیست افقی درصدها (فقط وقتی منو باز است)
                  if (_showZoomMenu)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 4.0].map((level) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => _setZoomLevel(level),
                              child: Text(
                                "${(level * 100).toInt()}%",
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // ب) دکمه اصلی زوم
                  _buildActionButton(
                    icon: Icons.center_focus_strong,
                    color: _showZoomMenu ? Colors.blueAccent : Colors.white70,
                    onPressed: () {
                      setState(() {
                        _showZoomMenu = !_showZoomMenu; // باز و بسته کردن منو
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  // متد کمکی برای ساخت دکمه‌های گرد و هم‌اندازه
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

  // پنل ابزارهای کناری
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

  // ویجت دکمه ابزار با قابلیت تول‌تیپ و علامت سوال
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

  // بنر راهنما که از بالا باز می‌شود
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

  // دیالوگ باکس پایین برای انجام عملیات
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
                      imageFile: _currentFile!, // استفاده از فایل فعلی
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

}

// مدلی برای ذخیره هر مرحله از ویرایش
class EditStep {
  final String label; // مثلاً "چرخش +۹۰"
  final Map<String, dynamic> state; // ذخیره مقادیر عددی در آن لحظه

  EditStep(this.label, this.state);
}

List<EditStep> _historySteps = [EditStep("اصلی", {})]; // نقطه شروع
int _currentStepIndex = 0;