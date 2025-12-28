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
  final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000/api/travel/'));
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

    setState(() => isLoading = true);

    try {
      await dio.post('travelplans/', data: {
        'cities': cities,
        'attraction_type': attractionType,
        'duration': duration,
        'vehicle_available': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'disabled_details': disabledDetails,
        'additional_notes': additionalNotes,
      });

      final promptResponse = await dio.post('generate-prompt/', data: {
        'cities': cities,
        'attraction_type': attractionType,
        'duration': duration,
        'vehicle_available': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'additional_notes': additionalNotes,
      });

      setState(() => prompt = promptResponse.data['prompt']);

      final aiResponse = await dio.post('ai-travelplan/', data: {'prompt': prompt});

      setState(() {
        chatGptResponse = aiResponse.data['chatgpt_response'];
        deepSeekResponse = aiResponse.data['deepseek_response'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
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
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'برنامه‌ریزی سفر با AI',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.appBarTheme.foregroundColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      isDarkMode: Theme.of(context).brightness == Brightness.dark,
                      onThemeChanged: widget.onThemeChanged ?? (v) {},
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [Icon(Icons.settings), SizedBox(width: 12), Text('تنظیمات')]),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView( // خطا رفع شد
            children: [
              // شهرها
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'شهر مقصد',
                  hintText: 'مثلاً: شیراز، اصفهان',
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.location_city, size: 20),
                ),
                validator: (v) => v!.isEmpty ? 'شهر را وارد کنید' : null,
                onChanged: (v) => cities = v,
              ),
              const SizedBox(height: 16),

              // نوع جاذبه
              DropdownButtonFormField<String>(
                value: attractionType,
                decoration: InputDecoration(
                  labelText: 'نوع جاذبه',
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.category, size: 20),
                ),
                items: attractionChoices.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => attractionType = v!),
              ),
              const SizedBox(height: 16),

              // مدت زمان
              DropdownButtonFormField<String>(
                value: duration,
                decoration: InputDecoration(
                  labelText: 'مدت سفر',
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.access_time, size: 20),
                ),
                items: durationChoices.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => duration = v!),
              ),
              const SizedBox(height: 16),

              // وسیله نقلیه
              SwitchListTile(
                title: Row(
                  children: [
                    Icon(Icons.directions_car, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text('وسیله نقلیه دارم'),
                  ],
                ),
                value: hasVehicle,
                onChanged: (v) => setState(() => hasVehicle = v),
                activeColor: AppTheme.primary,
              ),

              // معلول همراه
              SwitchListTile(
                title: Row(
                  children: [
                    Icon(Icons.accessible, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text('مسافر معلول همراه است'),
                  ],
                ),
                value: hasDisabled,
                onChanged: (v) => setState(() => hasDisabled = v),
                activeColor: AppTheme.primary,
              ),

              if (hasDisabled) ...[
                const SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'جزئیات معلولیت',
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.info, size: 20),
                  ),
                  maxLines: 3,
                  onChanged: (v) => disabledDetails = v,
                ),
              ],

              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'یادداشت اضافی',
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.note, size: 20),
                ),
                maxLines: 3,
                onChanged: (v) => additionalNotes = v,
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _submitForm,
                icon: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.smart_toy, size: 20),
                label: const Text('بساز برنامه سفر!', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),

              // نتیجه AI
              if (chatGptResponse != null) ...[
                const SizedBox(height: 32),
                Text(
                  'نتیجه هوش مصنوعی',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildAIResponse('ChatGPT', chatGptResponse!, Colors.blue),
                const SizedBox(height: 16),
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