import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import './video_thumbnail_widget.dart';
import '../services/photo_editor_page.dart';


class AddAttractionSheet extends StatefulWidget {
  final int cityId;
  final VoidCallback onUploadSuccess;

  const AddAttractionSheet({
    super.key, 
    required this.cityId, 
    required this.onUploadSuccess
  });

  @override
  State<AddAttractionSheet> createState() => _AddAttractionSheetState();
}

// ۱. مدل برای نگهداری فایل و وضعیت انتخاب
class MediaItem {
  File file;
  bool isVideo;
  bool isSelected = false;
  MediaItem({required this.file, required this.isVideo});
}

class _AddAttractionSheetState extends State<AddAttractionSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<MediaItem> _allMedia = []; 
  bool _isSelectionMode = false; // برای مدیریت حالت انتخاب چندتایی
  bool _isReorderMode = false; // وضعیت جدید برای جابه‌جایی
  final bool _isUploading = false;

  // متد جادویی انتخاب ویدیو
  // متد عمومی برای انتخاب ویدیو
  Future<void>_pickMedia(bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    
    // نمایش انتخابگر منبع
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
              title: Text(isVideo ? 'ضبط ویدیو با دوربین' : 'گرفتن عکس با دوربین', style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
              title: Text(isVideo ? 'انتخاب ویدیو از گالری' : 'انتخاب عکس از گالری', style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      if (isVideo) {
        final XFile? file = await picker.pickVideo(source: source);
        if (file != null) {
          setState(() => _allMedia.add(MediaItem(file: File(file.path), isVideo: true)));
        }
      } else {
        final XFile? file = await picker.pickImage(source: source);
        if (file != null) {
          setState(() => _allMedia.add(MediaItem(file: File(file.path), isVideo: false)));
        }
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20, right: 20, top: 15,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121212), // تم دارک استارتاپی
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 10),
            const Text("ثبت جاذبه جدید", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // فیلد نام
            _buildInput(_nameController, "نام جاذبه/مکان", Icons.map),
            const SizedBox(height: 15),
            
            // فیلد توضیحات
            _buildInput(_descController, "چه تجربه‌ای داشتی؟", Icons.edit, maxLines: 3),
            const SizedBox(height: 20),

            // دکمه انتخاب ویدیو
            // این بخش را جایگزین GestureDetector قدیمی ویدیو کن
            Row(
              children: [
                Expanded(
                  child: _buildMediaBox(
                    title: "افزودن عکس",
                    // چک می‌کنیم آیا در لیست کل، حداقل یک آیتم هست که ویدیو نباشد (یعنی عکس باشد)
                    hasFiles: _allMedia.any((item) => !item.isVideo), 
                    icon: Icons.add_a_photo_rounded,
                    onTap: () => _pickMedia(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMediaBox(
                    title: "افزودن ویدیو",
                    // چک می‌کنیم آیا در لیست کل، حداقل یک آیتم هست که ویدیو باشد
                    hasFiles: _allMedia.any((item) => item.isVideo), 
                    icon: Icons.videocam_rounded,
                    onTap: () => _pickMedia(true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // این بخش را بعد از Row انتخاب رسانه اضافه کن
            // ۱. نمایش ابزار حذف در صورت انتخاب چندتایی
            
            if (_isSelectionMode || _isReorderMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isReorderMode ? "حالت جابه‌جایی فعال است" : "${_allMedia.where((e) => e.isSelected).length} مورد انتخاب شده",
                    style: const TextStyle(color: Colors.white)
                  ),
                  Row(
                    children: [
                      if (_isSelectionMode)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _allMedia.removeWhere((item) => item.isSelected);
                              _isSelectionMode = false;
                            });
                          },
                          child: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
                        ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _isReorderMode = false;
                            // همه را از انتخاب در می‌آوریم
                            for (var item in _allMedia) { item.isSelected = false; }
                          });
                        },
                        child: const Text("لغو", style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ],
              ),

              // ۲. لیست جابه‌جا شونده افقی
              if (_allMedia.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _allMedia.removeAt(oldIndex);
                        _allMedia.insert(newIndex, item);
                      });
                    },
                    // ایجاد آیتم‌ها
                    children: _allMedia.asMap().entries.map((entry) {
                      return _buildAdvancedThumbnail(entry.value, entry.key);
                    }).toList(),
                  ),
                ),

            // دکمه نهایی ثبت
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isUploading ? null : () => print("شلیک به سمت سرور!"),
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("انتشار در صفحه شهر", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => 
    Container(
      width: 40, 
      height: 5, 
      decoration: 
        BoxDecoration(
          color: Colors.white24, 
          borderRadius: 
            BorderRadius.circular(10)
        )
    );

  Widget _buildInput(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  // متد اصلاح شده
  Widget _buildMediaBox({
    required String title, 
    required bool hasFiles, // به جای فایل، وضعیت پر بودن لیست را می‌گیریم
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80, // ارتفاع را کمی کمتر کردیم چون قرار است زیرش لیست تامنیل بیاید
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            // اگر فایلی در لیست بود، رنگ حاشیه را آبی روشن بماند تا کاربر باز هم بتواند اضافه کند
            color: Colors.blueAccent.withOpacity(0.3) 
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (hasFiles) // اگر فایلی انتخاب شده بود، یک نقطه کوچک نشان بده
              Container(
                margin: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                width: 5, height: 5,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedThumbnail(MediaItem item, int index) {
  // اگر در حالت جابه‌جایی باشیم، Listener درگ فعال می‌شود
    return ReorderableDragStartListener(
      index: index,
      enabled: _isReorderMode, // فقط وقتی دکمه جابه‌جایی زده شده باشد فعال است
      key: ValueKey(item.file.path),
      child: GestureDetector(
        onTap: () {
          if (_isSelectionMode) {
            setState(() => item.isSelected = !item.isSelected);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode && !_isReorderMode) {
            _showSelectionDialog(item); // منوی انتخاب نوع عملیات
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80, height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isSelected ? Colors.blueAccent : (_isReorderMode ? Colors.orangeAccent : Colors.transparent),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Opacity(
                    opacity: item.isSelected ? 0.6 : 1.0,
                    child: item.isVideo 
                      ? VideoThumbnailWidget(videoFile: item.file) 
                      : Image.file(item.file, fit: BoxFit.cover),
                  ),
                ),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 5, left: 5,
                  child: Icon(
                    item.isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: item.isSelected ? Colors.blueAccent : Colors.white,
                    size: 20,
                  ),
                ),
              if (_isReorderMode)
                const Center(child: Icon(Icons.open_with, color: Colors.white70)), // آیکون جابه‌جایی روی کل عکس
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectionDialog(MediaItem selectedItem) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Wrap(
        children: [
          // گزینه ویرایش (جدید)
          ListTile(
            leading: Icon(selectedItem.isVideo ? Icons.video_settings : Icons.photo_filter, color: Colors.greenAccent),
            title: Text(selectedItem.isVideo ? "ویرایش ویدیو" : "ویرایش عکس", style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _navigateToEditor(selectedItem); // رفتن به صفحه ادیت
            },
          ),
          // گزینه جابه‌جایی
          ListTile(
            leading: const Icon(Icons.reorder, color: Colors.blueAccent),
            title: const Text("جابه‌جایی آیتم‌ها", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _isReorderMode = true);
            },
          ),
          // گزینه حذف
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            title: const Text("حذف چندتایی", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _isSelectionMode = true;
                selectedItem.isSelected = true;
              });
            },
          ),
        ],
      ),
    );
  }

  void _navigateToEditor(MediaItem item) async {
    File? editedFile;

    if (item.isVideo) {
      // رفتن به صفحه ادیت ویدیو (فعلاً اسکلت رو می‌سازیم)
      // editedFile = await Navigator.push(context, MaterialPageRoute(builder: (_) => VideoEditorPage(file: item.file)));
    } else {
      // رفتن به صفحه ادیت عکس و منتظر ماندن برای نتیجه (await)
      final File? editedFile = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoEditorPage(file: item.file),
        ),
      );
    }
  }

}
