import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'theme.dart';
import 'settings_screen.dart';

class TravelPlanScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const TravelPlanScreen({super.key, this.onThemeChanged});

  @override
  _TravelPlanScreenState createState() => _TravelPlanScreenState();
}

class _TravelPlanScreenState extends State<TravelPlanScreen> {
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.0.105:8000/api/v1/'));
  final _formKey = GlobalKey<FormState>();

  String cities = '';
  String attractionType = 'historical';
  String duration = 'one_day';
  bool hasVehicle = false;
  bool hasDisabled = false;
  String disabledDetails = '';
  String additionalNotes = '';

  bool isLoading = false;

  // لیست پاسخ‌های Groq
  List<Map<String, String>> groqResponses = [];
  // لیست پاسخ‌های Fireworks
  List<Map<String, String>> fireworksResponses = [];

  final attractionChoices = {
    'historical': 'تاریخی',
    'religious': 'مذهبی',
    'restaurants_cafes': 'رستوران و کافه',
    'sports': 'امکان ورزشی',
    'recreational': 'تفریحی',
    'romantic': 'عاشقانه (دونفره)',
    'family': 'خانوادگی (با بچه)',
    'friends': 'با دوستان',
  };

  final durationChoices = {
    'one_day': 'یک روز',
    'one_week': 'یک هفته',
    'two_weeks': 'دو هفته',
    'one_month': 'یک ماه',
    'custom': 'مدت دلخواه',
  };

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      isLoading = true;
      groqResponses = [];
      fireworksResponses = [];
    });

    try {
      // ۱. ذخیره ورودی‌ها (اختیاری)
      await dio.post('chatgpt_travel/travelplans/', data: {
        'destination_cities': cities,
        'attraction_types': attractionType,
        'duration_of_visit': duration,
        'has_vehicle': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'disabled_details': disabledDetails,
        'additional_notes': additionalNotes,
      });

      // ۲. ساخت پرامپت
      final promptResponse = await dio.post('chatgpt_travel/generate-prompt/', data: {
        'cities': cities,
        'attraction_type': attractionType,
        'duration': duration,
        'vehicle_available': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'disabled_details': disabledDetails,
        'additional_notes': additionalNotes,
      });

      final prompt = promptResponse.data['prompt'] as String?;
      if (prompt == null || prompt.trim().isEmpty) {
        throw Exception('پرامپت ساخته نشد');
      }

      print('پرامپت: $prompt');

      // ۳. درخواست به Groq
      final groqRaw = await dio.post(
        'groqchat/sessions/1/send-message/',
        data: {'message': prompt},
        options: Options(contentType: Headers.jsonContentType),
      );

      // استخراج Groq
      final groqList = groqRaw.data['assistant_replies'] as List<dynamic>? ?? [];
      List<Map<String, String>> tempGroq = [];
      for (var item in groqList) {
        final model = item['model'] as String? ?? 'Groq';
        final content = item['reply']['content'] as String? ?? '';
        if (content.isNotEmpty) {
          tempGroq.add({'model': model, 'response': content});
        }
      }

      // ۴. درخواست به Fireworks
      final fwRaw = await dio.post(
        'fireworkschat/sessions/1/send-message/',
        data: {'message': prompt},
        options: Options(contentType: Headers.jsonContentType),
      );

      // استخراج Fireworks
      final fwList = fwRaw.data['assistant_replies'] as List<dynamic>? ?? [];
      List<Map<String, String>> tempFw = [];
      for (var item in fwList) {
        final model = item['model'] as String? ?? 'Fireworks';
        final content = item['reply']['content'] as String? ?? '';
        if (content.isNotEmpty) {
          tempFw.add({'model': model, 'response': content});
        }
      }

      setState(() {
        groqResponses = tempGroq;
        fireworksResponses = tempFw;
      });
    } on DioException catch (e) {
      String msg = 'خطا در ارتباط با سرور';
      if (e.response != null) {
        msg = 'خطا ${e.response?.statusCode}: ${e.response?.data['error'] ?? 'نامشخص'}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ساخت برنامه سفر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                    onThemeChanged: widget.onThemeChanged ?? (bool isDark) {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // فیلدهای فرم (بدون تغییر)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'شهرها (مثال: تهران، اصفهان)',
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => cities = value ?? '',
                validator: (value) => value!.isEmpty ? 'لطفاً شهرها را وارد کنید' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: attractionType,
                decoration: const InputDecoration(
                  labelText: 'نوع جاذبه مورد علاقه',
                  border: OutlineInputBorder(),
                ),
                items: attractionChoices.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (value) => setState(() => attractionType = value!),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: duration,
                decoration: const InputDecoration(
                  labelText: 'مدت زمان سفر',
                  border: OutlineInputBorder(),
                ),
                items: durationChoices.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (value) => setState(() => duration = value!),
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('وسیله نقلیه شخصی دارم'),
                value: hasVehicle,
                onChanged: (value) => setState(() => hasVehicle = value),
              ),

              SwitchListTile(
                title: const Text('مسافر دارای معلولیت همراه دارم'),
                value: hasDisabled,
                onChanged: (value) => setState(() => hasDisabled = value),
              ),

              if (hasDisabled) ...[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'جزئیات معلولیت',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onSaved: (value) => disabledDetails = value ?? '',
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'یادداشت یا درخواست ویژه',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                onSaved: (value) => additionalNotes = value ?? '',
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: isLoading ? null : _submitForm,
                icon: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.smart_toy, size: 20),
                label: const Text('ساخت برنامه سفر', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),

              // نمایش Groq
              if (groqResponses.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  'نتایج Groq (${groqResponses.length} مدل)',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...groqResponses.map((res) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.smart_toy, color: Colors.purple),
                                const SizedBox(width: 8),
                                Text(
                                  res['model']!,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText(res['response']!, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    )),
              ],

              // نمایش Fireworks
              if (fireworksResponses.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  'نتایج Fireworks (${fireworksResponses.length} مدل)',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...fireworksResponses.map((res) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.smart_toy, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  res['model']!,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText(res['response']!, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}