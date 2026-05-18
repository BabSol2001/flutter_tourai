import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../view_manager.dart';

/// ۱. دیتامدل کاملاً عمومی برای هر لایه
class AppLayer {
  final String id;
  final String name;
  final bool isVisible;
  final dynamic data; // فیلد برای نگهداری دیتای خام لایه‌ها (مانند List<Rect>)

  AppLayer({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.data,
  });

  AppLayer copyWith({String? name, bool? isVisible, dynamic data}) {
    return AppLayer(
      id: this.id,
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      data: data ?? this.data,
    );
  }
}

/// ۲. مغز متفکر لایه‌ها (کنترلر عمومی وضعیت‌ها)
class ImageLayerController extends ChangeNotifier {
  final List<AppLayer> _layers = [
    AppLayer(id: 'bg_layer', name: 'لایه پس‌زمینه (عکس)')
  ];
  String? _activeLayerId = 'bg_layer';
  int _layerCounter = 1;

  List<AppLayer> get layers => _layers;
  String? get activeLayerId => _activeLayerId;

  /// متد عمومی برای افزودن یا به‌روزرسانی هر نوع لایه از بیرون (توسط هوش مصنوعی یا منو)
  void addNewLayer({String? customId, String? customName, dynamic customData}) {
    print("🤖 متد addNewLayer صدا زده شد! تعداد لایه‌های فعلی: ${_layers.length}");
    final String newId = customId ?? 'layer_${DateTime.now().millisecondsSinceEpoch}';
    final String newName = customName ?? 'لایه $_layerCounter';
    
    if (customId == null) _layerCounter++;

    // اگر لایه‌ای با این ID از قبل وجود داشت، حذف می‌شود تا با دیتای جدید آپدیت شود
    _layers.removeWhere((l) => l.id == newId);

    final newLayer = AppLayer(id: newId, name: newName, data: customData);

    // درج هوشمند لایه جدید بالای لایه اکتیو فعلی
    int activeIndex = _layers.indexWhere((l) => l.id == _activeLayerId);
    if (activeIndex != -1) {
      _layers.insert(activeIndex + 1, newLayer);
    } else {
      _layers.add(newLayer);
    }
    
    _activeLayerId = newId;
    notifyListeners();
  }

  /// متد حذف لایه اکتیو
  void removeActiveLayer() {
    if (_activeLayerId == 'bg_layer') return; 
    
    int currentIndex = _layers.indexWhere((l) => l.id == _activeLayerId);
    _layers.removeWhere((l) => l.id == _activeLayerId);
    
    if (_layers.isNotEmpty) {
      _activeLayerId = _layers[math.max(0, currentIndex - 1)].id;
    } else {
      _activeLayerId = null;
    }
    notifyListeners();
  }

  /// متد جابه‌جایی لایه اکتیو به بالا یا پایین در لیست رندرینگ
  void moveActiveLayer({required bool moveUp}) {
    int currentIndex = _layers.indexWhere((l) => l.id == _activeLayerId);
    if (currentIndex == -1 || _layers[currentIndex].id == 'bg_layer') return;

    int targetIndex = moveUp ? currentIndex + 1 : currentIndex - 1;
    if (targetIndex < 1 || targetIndex >= _layers.length) return;

    final layer = _layers.removeAt(currentIndex);
    _layers.insert(targetIndex, layer);
    notifyListeners();
  }

  /// متد انتخاب و اکتیو کردن یک لایه با تپ روی آن
  void selectLayer(String id) {
    _activeLayerId = id;
    notifyListeners();
  }
}

/// ۳. ویجت رندرکننده بسته لایه‌ها روی عکس
class ImageLayerRenderWidget extends StatelessWidget {
  final File imageFile;
  final Size imageRawSize;
  final ImageLayerController controller;
  final Widget baseImageWidget; 
  final Matrix4 transformMatrix; // ماتریس دریافتی زوم و پن از تصویر اصلی

  const ImageLayerRenderWidget({
    Key? key,
    required this.imageFile,
    required this.imageRawSize,
    required this.controller,
    required this.baseImageWidget,
    required this.transformMatrix,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SizedBox(
          width: imageRawSize.width,
          height: imageRawSize.height,
          child: AspectRatio(
            aspectRatio: imageRawSize.width / imageRawSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // لایه صفر: کل پکیج کدهای فیکس‌شده و طلایی خودت (عکس + نقطه مرکز)
                baseImageWidget,

                // رندر کردن سایر لایه‌های ایجاد شده به صورت کاملاً پویا
                ...controller.layers.map((layer) {
                  if (layer.id == 'bg_layer' || !layer.isVisible) {
                    return const SizedBox.shrink();
                  }
                  
                  final bool isActive = layer.id == controller.activeLayerId;
                  
                  return IgnorePointer(
                    ignoring: !isActive, 
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent, 
                        border: isActive 
                          ? Border.all(
                              color: Colors.yellow,
                              width: 3.0, // قاب دور لایه اکتیو
                            )
                          : null,
                      ),
                      child: (layer.data != null && layer.data is List)
                        ? LayoutBuilder(
                          builder: (context, constraints) {
                            // ۱. گرفتن ابعاد واقعی کانتینر لایه در محیط نمایش
                            final Size localSize = Size(constraints.maxWidth, constraints.maxHeight);
                            
                            return CustomPaint(
                              size: Size.infinite,
                              painter: ObjectBoundsPainter(
                                rects: (layer.data as List).cast<Rect>(),
                                imageRawSize: imageRawSize,
                                layerLocalSize: localSize, // 🎯 حل خطای کامپایل: آرگومان مورد نیاز پاس داده شد
                                transform: transformMatrix, 
                              ),
                            );
                          },
                        )
                      : null,
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ۵. ویجت منوی مستقل مدیریت لایه‌ها (سمت راست صفحه)
class LayerManagementMenuWidget extends StatelessWidget {
  final ImageLayerController controller;

  const LayerManagementMenuWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Positioned(
          right: 55,
          top: 388, 
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(3.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_box, color: Colors.green, size: 30),
                      tooltip: 'افزودن لایه عمومی',
                      onPressed: () => controller.addNewLayer(), 
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 30),
                      tooltip: 'حذف لایه اکتیو',
                      onPressed: controller.activeLayerId != 'bg_layer' 
                          ? controller.removeActiveLayer 
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.blue, size: 30),
                      tooltip: 'انتقال به بالا',
                      onPressed: () => controller.moveActiveLayer(moveUp: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, color: Colors.blue, size: 30),
                      tooltip: 'انتقال به پایین',
                      onPressed: () => controller.moveActiveLayer(moveUp: false),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 5),
                
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.layers.length,
                    itemBuilder: (context, index) {
                      final layer = controller.layers[controller.layers.length - 1 - index];
                      final isSelected = layer.id == controller.activeLayerId;
                      
                      return GestureDetector(
                        onTap: () => controller.selectLayer(layer.id),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.withOpacity(0.35) : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected ? Border.all(color: Colors.blue) : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                layer.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Colors.blue, size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}