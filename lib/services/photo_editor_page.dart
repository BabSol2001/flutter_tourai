import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math; // برای دسترسی به pi
import 'package:gal/gal.dart'; 
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import '../logic/editor/aspect_ratio_handler.dart';
import '../logic/view_manager.dart';
import '../logic/edit_history_manager.dart';
import '../logic/image_processor.dart';
import '../logic/editor/image_layer_manager.dart';


//PhotoEditorPage: کلاس اصلی که به عنوان یک StatefulWidget تعریف شده و نقطه ورود این صفحه است.
// این کلاس فایل تصویر انتخاب شده را به عنوان ورودی دریافت می‌کند.
class PhotoEditorPage extends StatefulWidget {
  final File file;
  const PhotoEditorPage({super.key, required this.file});

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

//_PhotoEditorPageState: کلاسِ وضعیت (State) که تمام منطق‌های عملیاتی، مدیریت حافظه، انیمیشن‌ها و ساختار رابط کاربری (UI) در آن قرار دارد.
//این کلاس از TickerProviderStateMixin برای مدیریت انیمیشن‌ها استفاده می‌کند.
class _PhotoEditorPageState extends State<PhotoEditorPage> with TickerProviderStateMixin {
  bool _showHelp = false; // وضعیت نمایش دیالوگ راهنما از بالا
  bool _isHelpModeActive = false; // آیا حالت علامت سوال فعال است؟
  double _rotationAngle = 0.0; // مقدار چرخش به رادیان
  double _currentRotationDisplay = 0.0; // نگهدارنده زاویه برای نمایش در UI
  String _helpText = ""; // متن راهنما
  String _activeTool = ""; // ابزار انتخاب شده فعلی
  bool _isSaveMenuOpen = false; // در بخش State تعریف شود
  late ViewManager _viewManager;
  final TransformationController _transformationController = TransformationController();
  late EditHistoryManager<Map<String, dynamic>> _historyManager;
  bool _isSaving = false; // برای مدیریت نمایش لودینگ روی دکمه ذخیره
  double _brightnessValue = 1.0; // ۱.۰ یعنی نور طبیعی؛ کمتر تاریک و بیشتر روشن می‌کند
  final TextEditingController _fileNameController = TextEditingController();
  double? _selectedRatio; // ذخیره نسبت انتخاب شده
  Size _cropAreaSize = const Size(200, 200); // اندازه پیش‌فرض کادر
  Offset _cropOffset = Offset.zero; // موقعیت کادر نسبت به مرکز
  late File _currentFile; // متغیری که عکس فعلی (بریده شده یا اصلی) را نگه می‌دارد
  bool _showZoomMenu = false; // برای باز و بسته شدن لیست درصدها
  bool _showPanMenu = false; // برای باز و بسته شدن منوی جابجا کردن عکس
  bool _showrotateMenu = false; // برای باز و بسته شدن لیست درصدها
  bool _isLoading = false;
  final GlobalKey viewportKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey(); // تعریف کلید برای شناسایی فضای نمایش
  Map<String, dynamic>? serverResultData; // دیتای دریافتی از جنگو اینجا ذخیره می‌شود
  bool _isProcessing = false; // برای نمایش لودینگ
  late AnimationController _animationController;

  int _pointerCount = 0; // تعداد انگشت‌های روی صفحه
  int _twoFingerTapCount = 0; // شمارنده دابل‌تپ دوانگشتی
  Timer? _twoFingerTimer; // تایمر برای ریست کردن شمارنده
  Timer? _tapTimer; // تایمر برای تپ دو انگشت
  
  bool _isOverlayVisible = false; 
  List<Rect> _detectedObjectRects = [];

  final ImageLayerController _layerController = ImageLayerController();  
  bool _showLayersMenu = false; // کنترل باز و بسته بودن منوی لایه‌ها

//////////////////متدهای چرخه حیات (Lifecycle) و اولیه//////////////////////////
  //initState(): متدی که هنگام ساخته شدن صفحه اجرا می‌شود.
  //تنظیمات اولیه ViewManager (برای کنترل دوربین روی عکس)، EditHistoryManager (برای سیستم Undo) و کنترلرهای انیمیشن در اینجا انجام می‌شود.
  @override
  void initState() {
    super.initState();
    // ساخت کنترلر انیمیشن
    _animationController = AnimationController(
      vsync: this, // نیاز به with SingleTickerProviderStateMixin دارد
      duration: const Duration(milliseconds: 600),
    );

    _transformationController.value = Matrix4.identity();
    // مقداردهی اولیه ViewManager
    _viewManager = ViewManager(
      controller: _transformationController,
      onUpdate: () => setState(() {}),
      animationController: _animationController, // پاس دادن کنترلر
    );
    _getImageDimensions();
    _currentFile = widget.file; // در ابتدا، فایل فعلی همان فایل ورودی است
  
    // گرفتن ابعاد عکس به محض شروع
    _viewManager.getImageDimensions(FileImage(widget.file));

    // ۳. مقداردهی اولیه منیجر تاریخچه
    _historyManager = EditHistoryManager<Map<String, dynamic>>();
    _historyManager.initialize("اصلی", {
      'rotation': 0.0,
      'brightness': 1.0,
      'tool': "",
      'file': widget.file,
    });

    _animationController = AnimationController(
    duration: const Duration(milliseconds: 600), // زمان انیمیشن
    vsync: this,
    );
  }

  //_getImageDimensions(): به صورت ناهمگام (Async) ابعاد واقعی تصویر (عرض و ارتفاع) را استخراج کرده و در ViewManager ذخیره می‌کند تا محاسبات زوم و چرخش دقیق باشد.
  void _getImageDimensions() async {
    final bytes = await widget.file.readAsBytes();
    ui.decodeImageFromList(bytes, (ui.Image image) {
      setState(() {
        _viewManager.rawImageWidth = image.width.toDouble();
        _viewManager.rawImageHeight = image.height.toDouble();
      });
      print("📏 ابعاد تصویر لود شد: ${_viewManager.rawImageWidth}x${_viewManager.rawImageHeight}");
    });
  }

  //dispose(): متدی که هنگام بستن صفحه اجرا می‌شود.
  //این متد برای آزاد کردن منابع انیمیشن، ویرایشگر تصویر، و منیجر تاریخچه استفاده می‌شود.
  @override
  void dispose() {
    _viewManager.dispose(); // حتما تایمرها را آزاد کنیم
    _transformationController.removeListener(_handleMatrixUpdate);
    _transformationController.dispose();
    _fileNameController.dispose();
    _animationController.dispose(); // آزاد کردن منابع انیمیشن
    super.dispose();
  }
//XXXXXXXXXXXXXXXXمتدهای چرخه حیات (Lifecycle) و اولیهXXXXXXXXXXXXXXXXXXXXXXXXXX

//////////////////متدهای مربوط به هوش مصنوعی (AI) و شبکه/////////////////////

  //applyServerResponse(): داده‌های دریافتی از سرور (مثل مختصات یک شیء) را پردازش کرده و متد smartFocus را برای تمرکز روی آن شیء صدا می‌زند.
  void applyServerResponse(Map<String, dynamic> data) {
    print("📩 شروع پردازش پاسخ سرور...");
    
    // ۱. نفوذ به لایه result_data
    final resultData = data['result_data'];
    if (resultData == null) {
      print("❌ خطا: result_data یافت نشد");
      return;
    }

    // ۲. استخراج مختصات مستطیل
    final rect = resultData['object_rect'];
    if (rect == null) {
      print("❌ خطا: object_rect یافت نشد");
      return;
    }

    // ۳. تبدیل مقادیر به Double
    final double left = (rect['left'] as num).toDouble();
    final double top = (rect['top'] as num).toDouble();
    final double width = (rect['width'] as num).toDouble();
    final double height = (rect['height'] as num).toDouble();
    final double angle = (resultData['suggested_rotation'] as num? ?? 0.0).toDouble();

    print("✅ اعداد استخراج شدند: L:$left, T:$top, W:$width, H:$height, A:$angle");

    // ۴. فراخوانی متد هوشمند (با کلید ویوپورت)
    _viewManager.focusOnObject(
      objectRect: Rect.fromLTWH(left, top, width, height),
      rotationAngle: -angle,
      viewportKey: _viewportKey, // این کلید را در قدم بعدی تعریف می‌کنیم
      padding: 60.0,
    );

    setState(() {
      _isLoading = false;
    });
  }

  //_handleDoubleTapAi(): فرآیند ارسال عکس به سرور و تحلیل هوشمند را آغاز می‌کند.
  /// مدیریت سوییچ لایه شناسایی اشیاء (AI Discovery Layer Toggle)
  /// 
  /// این متد وظیفه دارد:
  /// ۱. وضعیت نمایانی لایه سبز (Overlay) را تغییر دهد.
  /// ۲. در صورت نیاز به تحلیل جدید، تصویر را به موتور Google ML Kit بفرستد.
  /// ۳. وضعیت بارگذاری (Loading) را در حین پردازش مدیریت کند.
  /// ۴. نتایج شناسایی (مستطیل‌ها) را در متغیرهای State ذخیره کند تا توسط Painter رسم شوند.
  Future<void> _toggleObjectDiscovery() async {
  // الف) اگر لایه هوش مصنوعی از قبل وجود دارد، آن را حذف کن (حالت Toggle Off)
  final bool hasAiLayer = _layerController.layers.any((l) => l.id == 'ai_layer');
  
  if (hasAiLayer) {
    // انتخاب لایه بک‌گراند به عنوان لایه اکتیو قبل از حذف
    _layerController.selectLayer('bg_layer');
    // حذف لایه هوش مصنوعی از کنترلر مرکزی
    _layerController.layers.removeWhere((l) => l.id == 'ai_layer');
    // به روز رسانی لایه‌ها
    _layerController.addNewLayer(customId: 'bg_layer', customName: 'لایه پس‌زمینه (عکس)', customData: null);
    return;
  }

  // ب) اگر لایه خاموش است، فرآیند شناسایی را آغاز کن (حالت Toggle On)
  setState(() => _isLoading = true);

  try {
    // ۱. ارسال فایل فعلی به کلاس پردازشگر برای استخراج تمام مستطیل‌های اشیاء
    final List<Rect> results = await LocalAiProcessor.detectAllObjects(_currentFile);

    // ۲. تزریق مستقیم به کنترلر لایه‌ها (این همان حلقه‌ی مفقوده بود!)
    if (results.isNotEmpty) {
      _layerController.addNewLayer(
        customId: 'ai_layer',
        customName: 'تشخیص هوش مصنوعی 🤖',
        customData: results, // مستطیل‌های سبز رنگ را به دیتای لایه پاس می‌دهیم
      );
      
      print("✅ تعداد مستطیل‌های یافت شده: ${results.length}");
      print("📍 ابعاد اولین مستطیل: ${results.first}");
    } else {
      // اگر شیئی پیدا نشد، یک پاپ‌آپ کوچک یا لاگ بده
      debugPrint("🤖 هوش مصنوعی شیئی در تصویر پیدا نکرد.");
    }
    
  } catch (e) {
    debugPrint("❌ Error in AI Object Discovery: $e");
  } finally {
    setState(() => _isLoading = false);
  }
}
  
  //startAIProcessing(): فایل تصویر را به بک‌اِند (جنگو) ارسال می‌کند تا تحلیل‌های هوشمند روی آن انجام شود و نتیجه را در serverResultData ذخیره می‌کند.

  Future<void> startAIProcessing() async {
    setState(() => _isProcessing = true);
    
    try {
      // ۱. ارسال فایل به بک‌اِند جنگو
      // نکته: آدرس IP سیستم خودت را جایگزین کن
      final response = await ImageProcessor.sendToBackend(widget.file); 
      
      if (response != null) {
        setState(() {
          serverResultData = response; // حالا این متغیر پر می‌شود!
          _isProcessing = false;
        });
        _showSnackBar("هوش مصنوعی با موفقیت تصویر را تحلیل کرد ✅");
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar("خطا در ارتباط با سرور: $e");
    }
  }

  void _showDebugPreview(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ورودی نهایی گوگل"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(file),
            const SizedBox(height: 10),
            Text("مسیر: ${file.path.split('/').last}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("فهمیدم"),
          ),
        ],
      ),
    );
  }

//XXXXXXXXXXXXXXXXمتدهای مربوط به هوش مصنوعی (AI) و شبکهXXXXXXXXXXXXXXXXXXXXX

//////////////////متدهای ویرایشی و مدیریت فایل//////////////////////////////////
  ///_saveFinalImage(): تغییرات فعلی (نور، چرخش و...) را روی فایل اصلی اعمال کرده و تاریخچه را به عنوان "ذخیره شده" علامت می‌زند.
  void _saveAsCopyAction() {
    // ۱. بستن منوی کوچک ذخیره (تا روی دیالوگ باز نماند)
    setState(() => _isSaveMenuOpen = false);
    
    // ۲. باز کردن پنل پایین برای گرفتن نام فایل
    _showSaveAsDialog();
  }

  ///_executeSaveAs(): یک کپی از تصویر ویرایش شده را با نام جدید در گالری گوشی ذخیره می‌کند.
  void _executeSaveAs(String name) async {
    if (name.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // ۱. پردازش تصویر
      final File tempFile = await ImageProcessor.applyAndSave(
        sourceFile: widget.file,
        brightness: _brightnessValue,
        rotationRadians: _rotationAngle,
      );

      // ۲. کپی در پوشه اسناد (همان کد قبلی خودت)
      final File finalFile = await ImageProcessor.saveAsCopy(tempFile, name);

      // ۳. اضافه کردن به گالری گوشی (بخش اصلی برای نمایش در Photos)
      await Gal.putImage(finalFile.path); 

      if (mounted) {
        _showSnackBar("عکس با نام $name در گالری ذخیره شد ✅");
      }
      
    } catch (e) {
      print("خطا در ذخیره گالری: $e");
      if (mounted) _showSnackBar("خطا در دسترسی به گالری");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ///_executeExportLogic(): تصویر را با فرمت‌های مختلف (مثل PNG یا PDF) خروجی می‌گیرد.
  void _executeExportLogic(String name, String format) async {
    setState(() => _isSaving = true);
    try {
      // ۱. ساخت فایل در پوشه موقت (مثل قبل)
      File tempFile = await ImageProcessor.exportImage(
        sourceFile: _currentFile,
        format: format,
        fileName: name,
      );

      if (format.toUpperCase() == 'PDF') {
        // ۲. خواندن بایت‌های فایل (این همان چیزی است که پکیج می‌خواهد)
        Uint8List fileBytes = await tempFile.readAsBytes();

        // ۳. فراخوانی متد ذخیره با پارامتر bytes
        // نکته: روی موبایل پارامتر bytes اجباری است
        String? outputFile = await FilePicker.saveFile(
          dialogTitle: 'محل ذخیره فایل PDF را انتخاب کنید',
          fileName: '$name.pdf',
          bytes: fileBytes, // اضافه شدن بایت‌ها
        );

        if (outputFile != null) {
          _showSnackBar("فایل PDF با موفقیت ذخیره شد 📄");
        } else {
          _showSnackBar("ذخیره لغو شد");
        }
        
      } else {
        // برای بقیه فرمت‌ها در گالری
        await Gal.putImage(tempFile.path);
        _showSnackBar("فایل در گالری ذخیره شد ✅");
      }

    } catch (e) {
      print("Export Error: $e");
      _showSnackBar("خطا در ذخیره‌سازی رخ داد");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  ///_addToHistory(): وضعیت فعلی برنامه را در لیست تاریخچه ذخیره می‌کند تا کاربر بتواند به این مرحله برگردد.
  void _addToHistory(String label) {
    setState(() {
      // استفاده از متد addStep که خودش مدیریت انشعاب (Branching) را انجام می‌دهد
      _historyManager.addStep(label, {
        'rotation': _viewManager.rotationAngle, // از ویو منیجر می‌گیریم
        'brightness': _brightnessValue,
        'tool': _activeTool,
        'file': _currentFile,
      });
    });
  }

  ///_goToStep(): برای جابجایی بین مراحل قبلی و بعدی (Undo/Redo) استفاده می‌شود و متغیرهای UI را به حالت آن مرحله برمی‌گرداند.
  void _goToStep(int index) {
    // یک چک ساده برای اطمینان از اینکه ایندکس معتبر است
    if (index < 0 || index >= _historyManager.allSteps.length) return;

    setState(() {
      // ۱. جابجایی در تاریخچه
      _historyManager.goToStep(index);
      
      // ۲. دریافت اطلاعات آن مرحله
      final step = _historyManager.currentStep; 
      final Map<String, dynamic> targetState = step.state;

      // ۳. بازیابی متغیرهای لایه UI
      _brightnessValue = targetState['brightness'] ?? 1.0;
      _activeTool = targetState['tool'] ?? "";
      _currentFile = targetState['file'] ?? widget.file;
      
      // ۴. بازگرداندن زاویه چرخش (بسیار مهم برای نمایش درست)
      if (targetState.containsKey('rotation')) {
        _rotationAngle = targetState['rotation'];
        // آپدیت کردن ماتریس نمایش در ویو منیجر
        _viewManager.setRotation(_rotationAngle);
      }

      // ۵. به‌روزرسانی متن راهنما
      if (_activeTool.isNotEmpty) {
        _helpText = "تنظیمات مربوط به $_activeTool را تغییر دهید";
      } else {
        _helpText = "یک ابزار انتخاب کنید";
      }
    });
  }
//XXXXXXXXXXXXXXXXمتدهای ویرایشی و مدیریت فایلXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  
//////////////////متدهای ساخت رابط کاربری (UI Builders)////////////////////////
  ///build(): متد اصلی ترسیم صفحه که لایه‌های مختلف (عکس، پنل ابزار، بنر راهنما) را روی هم می‌چیند.
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
                        child: Container(
                          key: viewportKey,
                          color: Colors.black,
                          constraints: const BoxConstraints.expand(),
                          child: Listener(
                            onPointerDown: _handleMultiFingerGesture,
                            onPointerUp: _handleMultiFingerGesture,
                            onPointerCancel: _handleMultiFingerGesture,
                            // ۱. GestureDetector دابل‌تپ را به بالاترین لایه محوطه وسط آوردیم
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque, // حساس کردن کل فضای سیاه
                              onDoubleTapDown: (details) {
                                _viewManager.zoomToPoint(
                                  tapPoint: details.localPosition, 
                                  viewportKey: viewportKey,
                                );
                              },
                              //_handleDoubleTapAi,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  InteractiveViewer(
                                    key: _viewportKey, // 👈 اینجا وصلش کن
                                    transformationController: _transformationController,
                                    boundaryMargin: const EdgeInsets.all(double.infinity),
                                    minScale: 0.01,
                                    maxScale: 10.0,
                                    clipBehavior: Clip.none,
                                    onInteractionUpdate: (details) {
                                      if (details.rotation != 0) {
                                        _viewManager.applyManualRotation(details.rotation);
                                      }
                                    },
                                    // دتکتور دابل‌تپ از اینجا حذف شد تا با لایه بالا تداخل نکند
                                    child: Stack(
                                      children: [
                                        OverflowBox(
                                          alignment: Alignment.center,
                                          minWidth: 0.0, maxWidth: double.infinity,
                                          minHeight: 0.0, maxHeight: double.infinity,
                                          
                                          // 🎯 کدهای طلایی خودت رو بدون دستکاری، می‌ذاریم داخل ImageLayerRenderWidget
                                          child: ImageLayerRenderWidget(
                                            imageFile: _currentFile,
                                            imageRawSize: Size(
                                              _viewManager.rawImageWidth.toDouble(),
                                              _viewManager.rawImageHeight.toDouble(),
                                            ),
                                            controller: _layerController,
                                            transformMatrix: _transformationController.value,
                                            // این دقیقا همان کالبد و ساختاری است که خودت فیکس کردی:
                                            baseImageWidget: Stack(
                                              children: [
                                                ColorFiltered(
                                                  colorFilter: ColorFilter.matrix([
                                                    _brightnessValue, 0, 0, 0, 0,
                                                    0, _brightnessValue, 0, 0, 0,
                                                    0, 0, _brightnessValue, 0, 0,
                                                    0, 0, 0, 1, 0,
                                                  ]),
                                                  child: Image.file(
                                                    _currentFile,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                                
                                                // === لایه هوش مصنوعی تو که دقیقاً سر جایش حفظ شد ===
                                                if (_isOverlayVisible)
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: LayoutBuilder(
                                                      builder: (context, constraints) {
                                                        // محاسبه سایز محلی کانتینر برای ساکت کردن خطای کامپایلر
                                                        final Size localSize = Size(constraints.maxWidth, constraints.maxHeight);
                                                        
                                                        return CustomPaint(
                                                          painter: ObjectBoundsPainter(
                                                            rects: _detectedObjectRects,
                                                            imageRawSize: Size(
                                                              _viewManager.rawImageWidth.toDouble(),
                                                              _viewManager.rawImageHeight.toDouble(),
                                                            ),
                                                            layerLocalSize: localSize, // 🎯 حل خطای کامپایل این بخش قدیمی
                                                            transform: _transformationController.value,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),                                                  
                                                _buildPhotoCenterPoint(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ========================================================
                                  // ۲. این دقیقاً منطق کادر برش شماست که بدون تغییر برگردانده شد
                                  // ========================================================
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
                                  // ========================================================
                                  _buildStaticDebugPoint(),
                                ],
                              ),
                            ),
                          ),
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

            if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7), // تاریک کردن کل صفحه
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.cyanAccent,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "در حال تحلیل هوشمند شیء...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //_buildSideToolbar(): نوار ابزار عمودی سمت چپ را می‌سازد که شامل دکمه‌های ابزارهای مختلف است.
  /// ساخت نوار ابزار عمودی کناری (Side Navigation Toolbar)
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

  //_buildDynamicTopPanel(): پنل بالای صفحه شامل دکمه‌های Undo/Redo، ذخیره و راهنما را مدیریت می‌کند.
  Widget _buildDynamicTopPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      top: _showHelp ? 110 : 20,
      left: 80,
      right: 15,
      // تغییر ۱: ارتفاع ثابت می‌دهیم تا با باز شدن منو، کل پنل جابه‌جا نشود
      height: 850, 
      child: Stack( // تغییر ۲: استفاده از استک داخلی برای مدیریت لایه زوم
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ۱. دکمه ذخیره
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ۱. دکمه اصلی ذخیره (حالا در بالا قرار دارد تا ثابت بماند)
                  _buildActionButton(
                    icon: Icons.save_rounded, 
                    color: Colors.greenAccent, 
                    onPressed: () {
                      setState(() {
                        // بستن سایر منوها برای جلوگیری از تداخل
                        //_isRotationPanelOpen = false;
                        //_isPanPanelOpen = false;
                        
                        _isSaveMenuOpen = !_isSaveMenuOpen; 
                      });
                    },
                  ),

                  // ۲. منوی گزینه‌های ذخیره (حالا زیر دکمه باز می‌شود)
                  // با استفاده از یک سایز کوچک (مثل SizedBox) یا Margin، منو را از دکمه فاصله می‌دهیم
                  if (_isSaveMenuOpen) const SizedBox(height: 8), 
                  
                  _buildSaveMenu(),
                ],
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
                        // چک کردن قابلیت Undo از طریق منیجر
                        onPressed: _historyManager.canUndo 
                            ? () => _goToStep(_historyManager.currentIndex - 1)
                            : null,
                      ),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _historyManager.allSteps.length,
                          itemBuilder: (context, index) {
                            // ۱. بررسی وضعیت فعلی و وضعیت ذخیره از طریق منیجر
                            bool isActive = index == _historyManager.currentIndex;
                            // هر مرحله‌ای که ایندکسش کوچک‌تر یا مساوی آخرین مرحله ذخیره شده باشد، "ذخیره شده" است
                            bool isSaved = index <= _historyManager.lastSavedIndex;

                            return GestureDetector(
                              onTap: () => _goToStep(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                decoration: BoxDecoration(
                                  // رنگ پس‌زمینه کپسول: اگر ذخیره شده باشد سبز کمرنگ، در غیر این صورت شفاف
                                  color: isSaved
                                      ? Colors.greenAccent.withOpacity(isActive ? 0.8 : 0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    // رنگ حاشیه: اگر ذخیره شده سبز، در غیر این صورت سفید محو
                                    color: isSaved ? Colors.greenAccent : Colors.white30,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _historyManager.allSteps[index].label,
                                  style: TextStyle(
                                    // رنگ متن: سفید برای ذخیره شده‌ها، سفید مایل به خاکستری برای بقیه
                                    color: isSaved ? Colors.white : Colors.white60,
                                    fontSize: 10,
                                    // ضخامت متن: برای مرحله‌ای که کاربر در حال مشاهده آن است (Active) بولد می‌شود
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
                        // استفاده از Getter هوشمند منیجر
                        onPressed: _historyManager.canRedo 
                            ? () => _goToStep(_historyManager.currentIndex + 1) 
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 5),

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

                  const SizedBox(height: 11), // فاصله بین پن و دکمه جدید

                  // ۵. دکمه تمرکز هوشمند (Smart Focus) 🚀
                  // دکمه شروع تحلیل (بک‌اِند)
                  _buildActionButton(
                    icon: _isProcessing ? Icons.sync : Icons.cloud_upload_rounded,
                    color: Colors.orangeAccent,
                    onPressed: () {
                      if (!_isProcessing) {
                        startAIProcessing();
                      } // فراخوانی به این صورت مشکل تایپ را حل می‌کند
                      },
                  ),

                  const SizedBox(height: 11),

                  // دکمه تمرکز هوشمند
                  _buildActionButton(
                    icon: Icons.auto_awesome_motion,
                    color: serverResultData != null ? Colors.cyanAccent : Colors.white24, 
                    onPressed: () {
                      if (serverResultData != null) {
                        applyServerResponse(serverResultData!);
                      }
                    },
                  ),

                  const SizedBox(height: 11),

                  // ۳. دکمه اصلی منوی مدیریت لایه‌ها
                  _buildActionButton(
                    icon: Icons.layers_outlined, // یا Icons.layers_rounded
                    color: _showLayersMenu ? Colors.blueAccent : Colors.white70,
                    onPressed: () => setState(() {
                      _showLayersMenu = !_showLayersMenu;
                      _showrotateMenu = false; // بستن منوی چرخش
                      _showZoomMenu = false;   // بستن منوی زوم
                    }),
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

          // 🎯 اضافه شدن منوی لایه‌ها به صورت هوشمند و شرطی
          if (_showLayersMenu)
            LayerManagementMenuWidget(controller: _layerController),
            
          _buildStaticDebugPoint(),

        ]
      ),
    );
  }

  //_buildBottomActionBox(): با انتخاب هر ابزار، تنظیمات اختصاصی آن (مثل لیست نسبت‌های تصویر) را در پایین صفحه نمایش می‌دهد.
  /// ساخت باکس عملیاتی پایین صفحه (Bottom Action Box)
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

  //_buildTopHelpBanner(): یک بنر شیشه‌ای (Blur) در بالای صفحه نمایش می‌دهد که توضیحات هر ابزار را برای کاربر می‌نویسد.
  /// ساخت دکمه‌های تکی نوار ابزار با قابلیت‌های تعاملی
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

  //_buildAspectRatioContent(): گزینه‌های مختلف برای تغییر ابعاد عکس (مثل ۱۶:۹ یا ۴:۳) را به صورت لیست افقی می‌سازد.
  /// ساخت لیست انتخاب نسبت تصویر (Aspect Ratio Selector)
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

  void _handleMultiFingerGesture(PointerEvent event) {
    if (event is PointerDownEvent) {
      _pointerCount++;
      
      // اگر دقیقاً دو انگشت روی صفحه قرار گرفت
      if (_pointerCount == 2) {
// ۱. پاکسازی فوری تمام رکوردهای تک‌انگشتی 
      // تا دابل‌تپِ زوم (تک‌انگشتی) تحریک نشود
      _pointerCount = 0; 
      _tapTimer?.cancel(); 

      // ۲. مدیریت دابل‌تپِ دوانگشتی خودمان
      _twoFingerTimer?.cancel();
      _twoFingerTapCount++;

        if (_twoFingerTapCount == 1) {
          // واقعه نهایی: دوبار تپ با دو انگشت انجام شد
          _twoFingerTapCount = 0;
          _pointerCount=0;
          _toggleObjectDiscovery(); // اجرای هوش مصنوعی
        } else {
          // استارت تایمر برای ریست کردن؛ اگر تپ دوم دیر برسد، شمارش صفر می‌شود
          _twoFingerTimer = Timer(const Duration(milliseconds: 400), () {
            _twoFingerTapCount = 0;
            _pointerCount=0;
          });
        }
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerCount--;
      if (_pointerCount < 0) _pointerCount = 0;
    }
  }

//XXXXXXXXXXXXXXXXمتدهای ساخت رابط کاربری (UI Builders)XXXXXXXXXXXXXXXXXXXXXXXX

//////////////////متدهای محاسباتی و کمکی/////////////////////////////////////
  //_handleMatrixUpdate(): هر زمان که کاربر عکس را جابجا کند یا زوم کند، این متد زاویه چرخش را همگام‌سازی کرده و UI را بروزرسانی می‌کند.
  void _handleMatrixUpdate() {
    // فقط همگام‌سازی عدد برای نمایش در منوها
    _viewManager.syncRotationAngle();
    
    setState(() {
      // تبدیل رادیان به درجه برای نمایش در متن منو
      double degrees = _viewManager.rotationAngle * 180 / math.pi;
      _currentRotationDisplay = (degrees % 360 + 360) % 360;
    });
  }

  //applyCorrection(): یک متد محاسباتی برای اصلاح موقعیت عکس و قرار دادن مرکز تصویر دقیقاً در مرکز محوطه نمایش (Viewport) است.
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

  //_showSnackBar(): برای نمایش پیام‌های کوتاه به کاربر (مثل "ذخیره شد") در پایین صفحه استفاده می‌شود.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }


  // ۱. نقطه سبز: مرکز ثابت محوطه نمایش (Target)
  Widget _buildStaticDebugPoint() {
    if (_viewManager.debugViewportCenter == null) return const SizedBox.shrink();
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
  void _saveFinalImage() async {
    // اگر در مرحله‌ای هستیم که قبلاً ذخیره شده، پردازش مجدد نکن
   setState(() => _isSaving = true);
    try {
      // ۱. پردازش و جایگزینی روی فایل اصلی
      final File processedFile = await ImageProcessor.applyAndSave(
        sourceFile: widget.file,
        brightness: _brightnessValue,
        rotationRadians: _rotationAngle,
      );

      if (mounted) {
        setState(() {
          _currentFile = processedFile; // نمایش فایل جدید
          _historyManager.markAsSaved(); // تثبیت تاریخچه
          _isSaving = false;
        });
        _showSnackBar("تغییرات با موفقیت روی فایل اصلی ذخیره شد ✅");
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar("خطا در ذخیره‌سازی: $e");
    }
  }

  void _showSaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("ذخیره تغییرات", 
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("آیا می‌خواهید تغییرات بر روی فایل اصلی ذخیره شود؟ این عمل فایل قدیمی را جایگزین می‌کند.",
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("انصراف", style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportAction(); // رفتن به منوی Save As
            },
            child: const Text("Save As...", style: TextStyle(color: Colors.blueAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
            onPressed: () {
              Navigator.pop(context); // بستن دیالوگ
              _saveFinalImage(); // اینجا اتصال برقرار شد!
            },
            child: const Text("ذخیره"),
          ),
        ],
      ),
    );
  }

  void _shareAction() async {
    setState(() => _isSaving = true); // نمایش لودینگ مختصر
    try {
      // ایجاد یک نام موقت برای فایلی که قرار است به اشتراک گذاشته شود
      //String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      // اشتراک‌گذاری نسخه فعلی تصویر
      await Share.shareXFiles(
        [XFile(_currentFile.path)],
        text: 'تصویر ویرایش شده با اپلیکیشن Tourai AI',
        subject: 'اشتراک‌گذاری عکس',
      );
    } catch (e) {
      _showSnackBar("خطا در اشتراک‌گذاری ❌");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildSaveMenu() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isSaveMenuOpen ? 200 : 0, 
      width: 50,
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      // استفاده از ClipRRect برای اینکه آیکون‌ها در لحظه باز شدن از کادر گرد بیرون نزنند
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: SingleChildScrollView(
          // جلوگیری از اسکرول خوردن توسط کاربر
          physics: const NeverScrollableScrollPhysics(), 
          child: SizedBox(
            // ارتفاع ثابت اینجا باعث می‌شود Column فضای لازم برای چیدمان را داشته باشد
            height: 184, // کمی کمتر از ۲۰۰ (بخاطر padding)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSaveOption(Icons.save, "ذخیره روی نسخه فعلی", _showSaveConfirmationDialog),
                _buildSaveOption(Icons.save_as, "ذخیره به عنوان کپی", _saveAsCopyAction),
                _buildSaveOption(Icons.save_alt_rounded, "خروجی با فرمت PNG", _exportAction),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSaveAsDialog() {
    // ۱. ساخت فرمت زمان به صورت ساده و خوانا
    // خروجی چیزی شبیه این می‌شود: copy_20260503_194530
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    
    // ۲. قرار دادن فقط واژه copy و زمان در فیلد متن
    _fileNameController.text = "copy_$timestamp";    
    // ۲. باز کردن پنل از پایین (Bottom Sheet)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // مهم: برای اینکه وقتی کیبورد باز می‌شود، منو بالا برود
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, // ایجاد فاصله برای کیبورد
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ذخیره نسخه جدید",
              style: TextStyle(
                color: Colors.white, 
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazir', // اگر فونت داری
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _fileNameController,
              autofocus: true, // به محض باز شدن کیبورد را بالا می‌آورد
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "نام فایل را اینجا بنویسید...",
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.greenAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // دکمه انصراف
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("انصراف", style: TextStyle(color: Colors.white60)),
                  ),
                ),
                const SizedBox(width: 10),
                // دکمه ذخیره اصلی
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      String newName = _fileNameController.text;
                      Navigator.pop(context); // بستن پنل
                      _executeSaveAs(newName); // اجرای عملیات اصلی ذخیره
                    },
                    child: const Text("ذخیره", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),

                Expanded(
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.blueAccent),
                    onPressed: _shareAction,
                    tooltip: 'اشتراک‌گذاری مستقیم',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _exportAction() async {
    // ۱. تنظیمات اولیه نام (شبیه Save As)
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    _fileNameController.text = "export_$timestamp";
    String localSelectedFormat = 'JPG'; // فرمت پیش‌فرض داخلی برای دیالوگ

    // ۲. نمایش دیالوگ ترکیبی (نام + فرمت)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder( // برای اینکه تغییر فرمت در لحظه دیده شود
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20, left: 20, right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("خروجی گرفتن (Export)",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // فیلد نام فایل
              TextField(
                controller: _fileNameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "نام فایل",
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),

              // منوی انتخاب فرمت
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButton<String>(
                  value: localSelectedFormat,
                  dropdownColor: Colors.grey[900],
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  items: ['JPG', 'PNG', 'WebP', 'GIF', 'BMP', 'HEIC', 'PDF']
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (val) {
                    setModalState(() => localSelectedFormat = val!);
                  },
                ),
              ),
              const SizedBox(height: 20),
              // دکمه تایید نهایی
              Row(
                children: [
                  // دکمه انصراف
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("انصراف", style: TextStyle(color: Colors.white60)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      String finalName = _fileNameController.text.trim();
                      Navigator.pop(context); // بستن دیالوگ
                      _executeExportLogic(finalName, localSelectedFormat); // اجرای منطق اکسپورت
                    },
                    child: const Text(" ذخیره ", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ),

                  Expanded(
                  child: IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.blueAccent),
                      onPressed: _shareAction,
                      tooltip: 'اشتراک‌گذاری مستقیم',
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSaveOption(IconData icon, String title, VoidCallback onTap) {
    return Tooltip(
      message: title, // متنی که با نگه داشتن دست ظاهر می‌شود
      preferBelow: false, // تول‌تیپ را بالای آیکون نشان دهد (یا کنار)
      child: InkWell(
        onTap: () {
          setState(() => _isSaveMenuOpen = false); // بستن منو بعد از انتخاب
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(
            icon, 
            color: Colors.greenAccent, 
            size: 22
          ),
        ),
      ),
    );
  }
    
  /// ساخت دکمه‌های کنترلی استاندارد و متحدالشکل
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

  /// ساخت دکمه‌های تکی نوار ابزار با قابلیت‌های تعاملی
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

}