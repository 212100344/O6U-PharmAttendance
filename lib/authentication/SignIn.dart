import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/supabase.dart';
import 'SignUp.dart';
import 'ResetPassword.dart';

class SignIn extends StatefulWidget {
  final String role; // Role parameter for the SignIn screen

  const SignIn({Key? key, this.role = 'student'}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  bool _isPasswordVisible = false;
  bool _rememberMe = false; // Remember only email, not password.
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _loadCredentials(); // Load saved email if exists.
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email') ?? '';
    if (savedEmail.isNotEmpty) {
      setState(() {
        emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final data = await SupabaseConfig.client.rpc(
        'authenticate_user',
        params: {
          'user_email': email,
          'user_password': password,
        },
      );
      print("Supabase Response: $data");

      if (data == null || (data is List && data.isEmpty)) {
        throw Exception('Invalid credentials.');
      }

      final user = (data as List).first;
      final role = user['role'];
      final status = user['status'];
      print("User Role: $role, Status: $status");

      if (status == 'inactive') {
        Fluttertoast.showToast(
          msg: "Account is inactive. Please wait for approval.",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // Store login state and role only for students.
      final prefs = await SharedPreferences.getInstance();
      if (role == 'student') {
        await prefs.setBool('isLoggedIn', true);
        print("Setting isLoggedIn to true");
      } else {
        await prefs.setBool('isLoggedIn', false);
        print("Setting isLoggedIn to false (non-student)");
      }
      await prefs.setString('userRole', role);
      print("Setting userRole to $role");
      await prefs.setString('email', email);
      print("Setting email to $email");

      // Save login time so background tasks can use it.
      final now = DateTime.now().toIso8601String();
      await prefs.setString('loginTime', now);

      if (_rememberMe) {
        await _saveCredentials(email);
      } else {
        await _clearCredentials();
      }

      // Navigate directly to the appropriate portal.
      String routeName;
      switch (role) {
        case 'student':
          routeName = '/studenthome';
          break;
        case 'admin':
          routeName = '/adminhome';
          break;
        case 'supervisor':
          routeName = '/supervisorhome';
          break;
        default:
          routeName = '/adminStudent';
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, routeName, arguments: {'email': email});
      }
    } catch (e) {
      print("Caught exception: $e");
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          DateTime now = DateTime.now();
          if (_lastBackPressed == null ||
              now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
            _lastBackPressed = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
              ),
            );
            return false;
          }
          return true;
        },
        child: Scaffold(
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
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      buildInputField(
                        controller: emailController,
                        hintText: 'Email',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      buildInputField(
                        controller: passwordController,
                        hintText: 'Password',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        onToggleVisibility: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (bool? value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            activeColor: Colors.deepPurple,
                          ),
                          Text(
                            "Remember Me",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text(
                      "Log In",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _login();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.role == 'student')
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Don't have an account?",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EnhancedSignUp(role: 'student'),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ResetPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Forget Password?',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, color: Colors.deepPurple),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility_off : Icons.visibility,
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
        validator: (value) {
          if (value!.isEmpty) {
            return 'Please enter ${isPassword ? 'a password' : 'a valid email'}';
          }
          if (isPassword && value.length < 6) {
            return 'Password should be at least 6 characters long';
          }
          return null;
        },
      ),
    );
  }
}
