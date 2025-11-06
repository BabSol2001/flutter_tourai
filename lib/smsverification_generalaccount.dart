import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SMSVerificationGeneralAccount extends StatefulWidget {
  const SMSVerificationGeneralAccount({super.key});

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
      const SnackBar(
        content: Text('Verification code sent!'),
        backgroundColor: Color(0xFF13a4ec),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111618)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Your Account',
          style: TextStyle(color: Color(0xFF111618), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
            const Text(
              "Let's get started",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF111618)),
            ),
            const SizedBox(height: 12),

            // Body Text
            const Text(
              "Please enter your mobile number to receive a verification code.",
              style: TextStyle(fontSize: 16, color: Color(0xFF617c89)),
            ),
            const SizedBox(height: 32),

            // Phone Number Input
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF111618))),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixText: "+1 ",
                    prefixStyle: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF111618)),
                    suffixIcon: const Icon(Icons.expand_more, color: Color(0xFF617c89)),
                    hintText: "(555) 000-0000",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFDbe2e6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF13a4ec), width: 2),
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
                  backgroundColor: const Color(0xFF13a4ec),
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
            const Text("Verification Code", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF111618))),
            const SizedBox(height: 8),
            const Text(
              "We've sent a code to your number. Please enter it below.",
              style: TextStyle(fontSize: 14, color: Color(0xFF617c89)),
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF101c22)),
                    decoration: InputDecoration(
                      counterText: "",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFDbe2e6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF13a4ec), width: 2),
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
                      child: const Text(
                        "Didn't receive a code? Resend",
                        style: TextStyle(color: Color(0xFF13a4ec), fontWeight: FontWeight.w500),
                      ),
                    )
                  : Text(
                      "Resend in ${_resendSeconds}s",
                      style: const TextStyle(color: Color(0xFF617c89), fontSize: 14),
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
                  backgroundColor: _isVerifyEnabled ? const Color(0xFF13a4ec) : const Color(0xFF13a4ec).withOpacity(0.3),
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
            const Center(
              child: Text.rich(
                TextSpan(
                  text: "By continuing, you agree to our ",
                  style: TextStyle(fontSize: 12, color: Color(0xFF617c89)),
                  children: [
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
    return Container(
      width: 48,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF13a4ec) : const Color(0xFFDbe2e66),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}