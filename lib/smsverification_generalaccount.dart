import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tourai/help_screen.dart';
import 'package:flutter_tourai/settings_screen.dart';
import 'theme.dart';

class SMSVerificationGeneralAccount extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const SMSVerificationGeneralAccount({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SMSVerificationGeneralAccount> createState() => _SMSVerificationGeneralAccountState();
}

class _SMSVerificationGeneralAccountState extends State<SMSVerificationGeneralAccount> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final TextEditingController _phoneController = TextEditingController();
  bool _isVerifyEnabled = false;
  int _resendSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    for (var controller in _otpControllers) {
      controller.addListener(_checkOtpComplete);
    }
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
        _startResendTimer();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  void _checkOtpComplete() {
    final filled = _otpControllers.every((c) => c.text.isNotEmpty);
    setState(() => _isVerifyEnabled = filled);
  }

  void _sendCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Verification code sent!'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _resendCode() {
    setState(() {
      _resendSeconds = 60;
      _canResend = false;
    });
    _startResendTimer();
    _sendCode();
  }

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.removeListener(_checkOtpComplete);
      c.dispose();
    }
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    final cardColor = theme.cardTheme.color;
    final borderColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.foregroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Your Account',
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: Icon(Icons.menu, color: theme.appBarTheme.foregroundColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            offset: const Offset(0, 56),
            onSelected: (String value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        isDarkMode: widget.isDarkMode,
                        onThemeChanged: widget.onThemeChanged,
                      ),
                    ),
                  );
                  break;
                case 'help':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20, color: theme.appBarTheme.foregroundColor),
                      const SizedBox(width: 12),
                      const Text('Settings'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help, size: 20, color: theme.appBarTheme.foregroundColor),
                      const SizedBox(width: 12),
                      const Text('Help'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Indicators
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Indicator(active: true),
                SizedBox(width: 12),
                _Indicator(active: false),
              ],
            ),
            const SizedBox(height: 24),

            // Headline
            Text(
              "Let's get started",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 12),

            // Body Text
            Text(
              "Please enter your mobile number to receive a verification code.",
              style: TextStyle(fontSize: 16, color: hintColor),
            ),
            const SizedBox(height: 32),

            // Phone Number Input
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixText: "+1 ",
                    prefixStyle: TextStyle(fontWeight: FontWeight.w500, color: textColor),
                    suffixIcon: Icon(Icons.expand_more, color: hintColor),
                    hintText: "(555) 000-0000",
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 72, vertical: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Send Code Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  "Send Verification Code",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Verification Code Section
            Text("Verification Code", style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
            const SizedBox(height: 8),
            Text(
              "We've sent a code to your number. Please enter it below.",
              style: TextStyle(fontSize: 14, color: hintColor),
            ),
            const SizedBox(height: 16),

            // OTP Inputs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 52,
                  height: 56,
                  child: TextField(
                    controller: _otpControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    decoration: InputDecoration(
                      counterText: "",
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (v) {
                      if (v.length == 1 && i < 5) {
                        FocusScope.of(context).nextFocus();
                      } else if (v.isEmpty && i > 0) {
                        FocusScope.of(context).previousFocus();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Resend Link
            Center(
              child: _canResend
                  ? TextButton(
                      onPressed: _resendCode,
                      child: Text(
                        "Didn't receive a code? Resend",
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500),
                      ),
                    )
                  : Text(
                      "Resend in ${_resendSeconds}s",
                      style: TextStyle(color: hintColor, fontSize: 14),
                    ),
            ),

            const SizedBox(height: 32),

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isVerifyEnabled
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Account created successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isVerifyEnabled ? AppTheme.primary : AppTheme.primary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  "Verify & Continue",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Disclaimer
            Center(
              child: Text.rich(
                TextSpan(
                  text: "By continuing, you agree to our ",
                  style: TextStyle(fontSize: 12, color: hintColor),
                  children: const [
                    TextSpan(text: "Terms of Service", style: TextStyle(decoration: TextDecoration.underline)),
                    TextSpan(text: " and "),
                    TextSpan(text: "Privacy Policy", style: TextStyle(decoration: TextDecoration.underline)),
                    TextSpan(text: "."),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Indicator Widget
class _Indicator extends StatelessWidget {
  final bool active;
  const _Indicator({required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : theme.dividerColor,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}