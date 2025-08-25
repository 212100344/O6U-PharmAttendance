import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils.dart';
import '../utils/supabase.dart'; // Use the helper
import 'SignIn.dart';


class EnhancedSignUp extends StatefulWidget {
  const EnhancedSignUp({super.key, required String role});

  @override
  State<EnhancedSignUp> createState() => _EnhancedSignUpState();
}

class _EnhancedSignUpState extends State<EnhancedSignUp> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final studentIdController = TextEditingController();
  final nationalIdController = TextEditingController();

  // Password visibility states
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // Animated step indicator
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == _currentStep ? 24 : 16,
          height: 4,
          decoration: BoxDecoration(
            color: index == _currentStep
                ? Colors.deepPurple
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // Enhanced validation for password complexity
  String? _validatePasswordStrength(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'At least one uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'At least one lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'At least one number';
    return null;
  }

  // Original signup method enhanced with better error handling
  Future<void> _performSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (passwordController.text != confirmPasswordController.text) {
      Utils().toastMessage("Passwords do not match");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await SupabaseConfig.client.from('profiles').insert({
        'email': emailController.text.trim(),
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'student_id': studentIdController.text.trim(),
        'national_id': nationalIdController.text.trim(),
        'role': 'student',
        'status': 'inactive', // Always create as 'inactive' initially.
        'password': passwordController.text.trim(),
      });

      // Immediately navigate to StudentHome after signup.
      if(mounted) {
        Navigator.pushReplacementNamed(context, '/studenthome', arguments: {'email': emailController.text.trim()});
      }


    } catch (e) {
      Utils().toastMessage("Error: ${e.toString()}");

    } finally {
      setState(() => _isSubmitting = false);

    }
  }

  // Reusable input field builder
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
              'Create Student Account',
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
                    // Step 1: Personal Information
                    ListView(
                      children: [
                        _buildInputField(
                          controller: firstNameController,
                          hintText: 'First Name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) => value!.isEmpty
                              ? 'Please enter your first name'
                              : null,
                        ),
                        _buildInputField(
                          controller: lastNameController,
                          hintText: 'Last Name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) => value!.isEmpty
                              ? 'Please enter your last name'
                              : null,
                        ),
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
                            if (value?.length != 14) {
                              return 'Must be 14 digits';
                            }
                            return null;
                          },
                        ),
                        _NavigationButtons(
                          currentStep: _currentStep,
                          totalSteps: 3,
                          onNext: () {
                            if (_formKey.currentState!.validate()) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              setState(() => _currentStep++);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignIn(),
                            ),
                          ),
                          child: Text.rich(
                            TextSpan(
                              text: 'Already have an account? ',
                              style: const TextStyle(color: Colors.deepPurple),
                              children: [
                                TextSpan(
                                  text: 'Sign In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Step 2: Account Credentials
                    ListView(
                      children: [
                        _buildInputField(
                          controller: emailController,
                          hintText: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value!)) {
                              return 'Enter valid email';
                            }
                            return null;
                          },
                        ),
                        _buildInputField(
                          controller: passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          isPasswordVisible: _passwordVisible,
                          onToggleVisibility: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                          ),
                          validator: _validatePasswordStrength,
                        ),
                        _buildInputField(
                          controller: confirmPasswordController,
                          hintText: 'Confirm Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          isPasswordVisible: _confirmPasswordVisible,
                          onToggleVisibility: () => setState(
                                () => _confirmPasswordVisible = !_confirmPasswordVisible,
                          ),
                          validator: (value) {
                            if (value != passwordController.text) {
                              return 'Passwords must match';
                            }
                            return null;
                          },
                        ),
                        _NavigationButtons(
                          currentStep: _currentStep,
                          totalSteps: 3,
                          onNext: () {
                            if (_formKey.currentState!.validate()) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              setState(() => _currentStep++);
                            }
                          },
                          onPrevious: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                            setState(() => _currentStep--);
                          },
                        ),
                      ],
                    ),

                    // Step 3: Academic Information
                    ListView(
                      children: [
                        _buildInputField(
                          controller: studentIdController,
                          hintText: 'Student ID',
                          prefixIcon: Icons.school_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) => value!.isEmpty
                              ? 'Student ID required'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _performSignUp,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator()
                                : const Text('Complete Registration'),
                          ),
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
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    studentIdController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }
}

class _NavigationButtons extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const _NavigationButtons({
    required this.currentStep,
    required this.totalSteps,
    this.onNext,
    this.onPrevious,
  });

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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back'),
            ),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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