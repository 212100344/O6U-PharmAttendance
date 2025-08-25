import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils.dart';
import '../utils/supabase.dart';
import 'SignIn.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1 controllers (verification)
  final nationalIdController = TextEditingController();
  final studentIdController = TextEditingController();
  final emailController = TextEditingController();

  // Step 2 controllers (reset password)
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Password visibility states for step 2
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // Password strength validator (similar to SignUp.dart)
  String? _validatePasswordStrength(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'At least one uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'At least one lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'At least one number';
    return null;
  }

  // Step indicator widget
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == _currentStep ? 24 : 16,
          height: 4,
          decoration: BoxDecoration(
            color: index == _currentStep ? Colors.deepPurple : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // Reusable input field builder (similar to SignUp.dart)
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !(isPasswordVisible ?? false),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, color: Colors.deepPurple),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isPasswordVisible ?? false
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: onToggleVisibility,
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        validator: validator,
      ),
    );
  }

  // Function to verify identity in step 1
  Future<bool> _verifyIdentity() async {
    final nationalId = nationalIdController.text.trim();
    final studentId = studentIdController.text.trim();
    final email = emailController.text.trim();

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('national_id', nationalId)
          .eq('student_id', studentId)
          .eq('email', email);
      if (response is List && response.isNotEmpty) {
        return true;
      } else {
        Utils().toastMessage("No matching account found");
        return false;
      }
    } catch (e) {
      Utils().toastMessage("Error: ${e.toString()}");
      return false;
    }
  }

  // Function to update the password in step 2
  Future<void> _resetPassword() async {
    final nationalId = nationalIdController.text.trim();
    final studentId = studentIdController.text.trim();
    final email = emailController.text.trim();
    final newPassword = newPasswordController.text.trim();

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .update({'password': newPassword})
          .eq('national_id', nationalId)
          .eq('student_id', studentId)
          .eq('email', email)
          .eq('role', 'student')
          .select();
      if (response != null && (response as List).isNotEmpty) {
        Utils().toastMessage("Password reset successful");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignIn()),
        );
      } else {
        Utils().toastMessage("Password reset failed");
      }
    } catch (e) {
      Utils().toastMessage("Error: ${e.toString()}");
    }
  }

  // Handler for the "Next" button
  Future<void> _handleNext() async {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) {
        final verified = await _verifyIdentity();
        if (verified) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          setState(() {
            _currentStep++;
          });
        }
      }
    }
  }

  // Handler for the "Submit" button in step 2
  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      if (newPasswordController.text != confirmPasswordController.text) {
        Utils().toastMessage("Passwords do not match");
        return;
      }
      await _resetPassword();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "O6U Pharmacy Attendance",
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _currentStep == 0 ? 'Verify Your Identity' : 'Reset Password',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 20),
            _buildStepIndicator(),
            const SizedBox(height: 20),
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Step 1: Identity Verification
                    ListView(
                      children: [
                        _buildInputField(
                          controller: nationalIdController,
                          hintText: 'National ID',
                          prefixIcon: Icons.credit_card,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(14),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty || value.length != 14) {
                              return 'Enter a valid 14-digit National ID';
                            }
                            return null;
                          },
                        ),
                        _buildInputField(
                          controller: studentIdController,
                          hintText: 'Student ID',
                          prefixIcon: Icons.school_outlined,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Student ID required';
                            }
                            return null;
                          },
                        ),
                        _buildInputField(
                          controller: emailController,
                          hintText: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null ||
                                !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        _NavigationButtons(
                          currentStep: _currentStep,
                          totalSteps: 2,
                          onNext: _handleNext,
                        ),
                      ],
                    ),
                    // Step 2: Reset Password
                    ListView(
                      children: [
                        _buildInputField(
                          controller: newPasswordController,
                          hintText: 'New Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          isPasswordVisible: _passwordVisible,
                          onToggleVisibility: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                          validator: _validatePasswordStrength,
                        ),
                        _buildInputField(
                          controller: confirmPasswordController,
                          hintText: 'Confirm New Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          isPasswordVisible: _confirmPasswordVisible,
                          onToggleVisibility: () {
                            setState(() {
                              _confirmPasswordVisible = !_confirmPasswordVisible;
                            });
                          },
                          validator: (value) {
                            if (value != newPasswordController.text) {
                              return 'Passwords must match';
                            }
                            return null;
                          },
                        ),
                        _NavigationButtons(
                          currentStep: _currentStep,
                          totalSteps: 2,
                          onNext: _handleSubmit,
                          onPrevious: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                            setState(() {
                              _currentStep--;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    nationalIdController.dispose();
    studentIdController.dispose();
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}

class _NavigationButtons extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const _NavigationButtons({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    this.onNext,
    this.onPrevious,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (currentStep > 0)
            OutlinedButton(
              onPressed: onPrevious,
              style: OutlinedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back'),
            ),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(currentStep == totalSteps - 1 ? 'Submit' : 'Next'),
          ),
        ],
      ),
    );
  }
}