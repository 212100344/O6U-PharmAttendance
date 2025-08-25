import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'authentication/SignIn.dart';
import 'authentication/SignUp.dart';

class AdminStudent extends StatefulWidget {
  const AdminStudent({super.key});

  @override
  State<AdminStudent> createState() => _AdminStudentState();
}

class _AdminStudentState extends State<AdminStudent> {
  DateTime? _lastBackPressed;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
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
        body: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(74, 264, 63, 384),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: const LinearGradient(
                  begin: Alignment(-0.951, -1),
                  end: Alignment(1.508, 1.437),
                  colors: <Color>[
                    Color(0xff6617ff),
                    Color(0xff9d6bff),
                    Color(0xffffffff),
                    Color(0xff8048ec)
                  ],
                  stops: <double>[0, 1.792, 1, 1],
                ),
              ),
            ),
            Column(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100, bottom: 55),
                    child: Text(
                      ":تسجيل الدخول للمنصة عن طريق",
                      style: GoogleFonts.cairo(
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Admin Portal: SignIn only
                buildPortalButton(context, "الادارة", const SignIn(role: 'admin')),
                const SizedBox(height: 20),
                // Student Portal: SignUp for registration
                buildPortalButton(context, "الطالب", const EnhancedSignUp(role: 'student')),
                const SizedBox(height: 20),
                // Supervisor Portal: SignIn only
                buildPortalButton(context, "مركز التدريب", const SignIn(role: 'supervisor')),
                const SizedBox(height: 20),
                // Removed the test button.

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPortalButton(BuildContext context, String label, Widget targetPage) {
    return SizedBox(
      height: 150,
      width: 150,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetPage),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffc780ff),
          elevation: 5,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(65),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            textStyle: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xffdde6ed),
            ),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}