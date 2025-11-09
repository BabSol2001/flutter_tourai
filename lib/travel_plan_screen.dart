import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'theme.dart';

class TravelPlanScreen extends StatefulWidget {
  @override
  _TravelPlanScreenState createState() => _TravelPlanScreenState();
}

class _TravelPlanScreenState extends State<TravelPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000/api/travel/')); // برای اندروید امولاتور

  // فرم فیلدها
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
      // 1. ذخیره برنامه
      final saveResponse = await dio.post('travelplans/', data: {
        'cities': cities,
        'attraction_type': attractionType,
        'duration': duration,
        'vehicle_available': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'disabled_details': disabledDetails,
        'additional_notes': additionalNotes,
      });

      // 2. ساخت پرامپت
      final promptResponse = await dio.post('generate-prompt/', data: {
        'cities': cities,
        'attraction_type': attractionType,
        'duration': duration,
        'vehicle_available': hasVehicle,
        'has_disabled_travelers': hasDisabled,
        'additional_notes': additionalNotes,
      });

      setState(() => prompt = promptResponse.data['prompt']);

      // 3. گرفتن جواب AI
      final aiResponse = await dio.post('ai-travelplan/', data: {
        'prompt': prompt,
      });

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
      appBar: AppBar(title: const Text('برنامه‌ریزی سفر با AI')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // شهرها
              TextFormField(
                decoration: const InputDecoration(labelText: 'شهر مقصد', hintText: 'مثلاً: شیراز، اصفهان'),
                validator: (v) => v!.isEmpty ? 'لطفاً شهر را وارد کنید' : null,
                onChanged: (v) => cities = v,
              ),
              const SizedBox(height: 16),

              // نوع جاذبه
              DropdownButtonFormField<String>(
                value: attractionType,
                decoration: const InputDecoration(labelText: 'نوع جاذبه مورد علاقه'),
                items: attractionChoices.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => attractionType = v!),
              ),
              const SizedBox(height: 16),

              // مدت زمان
              DropdownButtonFormField<String>(
                value: duration,
                decoration: const InputDecoration(labelText: 'مدت سفر'),
                items: durationChoices.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => duration = v!),
              ),
              const SizedBox(height: 16),

              // وسیله نقلیه
              SwitchListTile(
                title: const Text('وسیله نقلیه دارم'),
                value: hasVehicle,
                onChanged: (v) => setState(() => hasVehicle = v),
              ),

              // معلول همراه
              SwitchListTile(
                title: const Text('مسافر معلول همراه است'),
                value: hasDisabled,
                onChanged: (v) => setState(() => hasDisabled = v),
              ),

              if (hasDisabled) ...[
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'جزئیات معلولیت'),
                  maxLines: 3,
                  onChanged: (v) => disabledDetails = v,
                ),
              ],

              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'یادداشت اضافی'),
                maxLines: 3,
                onChanged: (v) => additionalNotes = v,
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : _submitForm,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('بساز برنامه سفر!'),
              ),

              if (prompt != null) ...[
                const Divider(height: 32),
                Text('پرامپت:', style: theme.textTheme.titleMedium),
                SelectableText(prompt!, style: const TextStyle(fontSize: 12)),
              ],

              if (chatGptResponse != null) ...[
                const Divider(height: 32),
                _buildAIResponse('ChatGPT', chatGptResponse!, Colors.blue),
              ],

              if (deepSeekResponse != null) ...[
                const Divider(height: 32),
                _buildAIResponse('DeepSeek', deepSeekResponse!, Colors.green),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIResponse(String title, String response, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            SelectableText(response),
          ],
        ),
      ),
    );
  }
}