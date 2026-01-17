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
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.178.23:8000/api/v1/chatgpt_travel/ai-travelplan/'));
  final _formKey = GlobalKey<FormState>();

  String cities = '';
  String attractionType = 'historical';
  String duration = 'one_day';
  bool hasVehicle = false;
  bool hasDisabled = false;
  String disabledDetails = '';
  String additionalNotes = '';

  bool isLoading = false;
  String? prompt;
  String? chatGptResponse;
  String? deepSeekResponse;

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
      chatGptResponse = null;
      deepSeekResponse = null;
    });

    try {
      // ۱. ذخیره اطلاعات ورودی
      await dio.post('travelplans/', data: {
        'cities': cities,
        'attraction_type': attractionType,
        'duration': duration,
        'vehicle_available': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'disabled_details': disabledDetails,
        'additional_notes': additionalNotes,
      });

      // ۲. ساخت پرامپت
      final promptResponse = await dio.post('generate-prompt/', data: {
        'cities': cities,
        'attraction_type': attractionType,
        'duration': duration,
        'vehicle_available': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'disabled_details': disabledDetails,
        'additional_notes': additionalNotes,
      });
      prompt = promptResponse.data['prompt'];

      // ۳. گرفتن پاسخ‌های هوش مصنوعی
      final aiResponse = await dio.post('ai-travelplan/', data: {
        'prompt': prompt,
      });

      setState(() {
        chatGptResponse = aiResponse.data['chatgpt_response'];
        deepSeekResponse = aiResponse.data['deepseek_response'];
      });
    } on DioException catch (e) {
      String errorMessage = 'خطا در ارتباط با سرور';
      if (e.response != null) {
        errorMessage = 'خطا ${e.response?.statusCode}: ${e.response?.data['error'] ?? 'نامشخص'}';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'اتصال به سرور زمان‌بر شد';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطای غیرمنتظره: $e'), backgroundColor: Colors.red),
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
                    onThemeChanged: widget.onThemeChanged ?? (bool isDark) {}, // جلوگیری از null
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
              // فیلد شهرها
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'شهرها (مثال: تهران، اصفهان)',
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => cities = value ?? '',
                validator: (value) => value!.isEmpty ? 'لطفاً شهرها را وارد کنید' : null,
              ),
              const SizedBox(height: 16),

              // نوع جاذبه
              DropdownButtonFormField<String>(
                value: attractionType,
                decoration: const InputDecoration(
                  labelText: 'نوع جاذبه مورد علاقه',
                  border: OutlineInputBorder(),
                ),
                items: attractionChoices.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (value) => setState(() => attractionType = value!),
              ),
              const SizedBox(height: 16),

              // مدت زمان
              DropdownButtonFormField<String>(
                value: duration,
                decoration: const InputDecoration(
                  labelText: 'مدت زمان سفر',
                  border: OutlineInputBorder(),
                ),
                items: durationChoices.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (value) => setState(() => duration = value!),
              ),
              const SizedBox(height: 16),

              // وسیله نقلیه
              SwitchListTile(
                title: const Text('وسیله نقلیه شخصی دارم'),
                value: hasVehicle,
                onChanged: (value) => setState(() => hasVehicle = value),
              ),

              // مسافر معلول
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

              // یادداشت اضافی
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'یادداشت یا درخواست ویژه',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                onSaved: (value) => additionalNotes = value ?? '',
              ),
              const SizedBox(height: 24),

              // دکمه ارسال
              ElevatedButton.icon(
                onPressed: isLoading ? null : _submitForm,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
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

              // نمایش نتایج هوش مصنوعی
              if (chatGptResponse != null || deepSeekResponse != null) ...[
                const SizedBox(height: 32),
                Text(
                  'نتایج هوش مصنوعی',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (chatGptResponse != null)
                  _buildAIResponse('ChatGPT', chatGptResponse!, Colors.blue),

                const SizedBox(height: 16),

                if (deepSeekResponse != null)
                  _buildAIResponse('DeepSeek', deepSeekResponse!, Colors.green),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIResponse(String title, String response, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(response, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}