import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'homepage.dart';
import 'welcomepage.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style here
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Call this after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0xFFFEFBFA),
          systemNavigationBarIconBrightness: Brightness.dark,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Registration',
      theme: ThemeData(
        fontFamily: 'Lateef',
        scaffoldBackgroundColor: const Color(0xFFFEFBFA),
        canvasColor: Colors.white,
        bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFEFBFA),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFEFBFA),
        ),
      ),
      home: const WelcomePage(),
    );
  }
}

/// Bullet line widget that renders RTL bullets and wraps text nicely
class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: Colors.red,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterWidget extends StatefulWidget {
  const RegisterWidget({super.key});

  @override
  State<RegisterWidget> createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _passwordsMatch = true;
  String _errorMessage = ''; // fixed inline error like login page

  // Strong password: 8–64 chars, requires upper, lower, number, special
  final RegExp _passwordPolicy =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,64}$');

  bool get _isPasswordStrong =>
      _passwordPolicy.hasMatch(_passwordController.text);

  // Enable only when all conditions are met
  bool get _canSubmit =>
      !_isLoading &&
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty &&
      _confirmPasswordController.text.trim().isNotEmpty &&
      _isPasswordStrong &&
      _passwordsMatch;

  // Compare passwords live
  void _comparePasswords() {
    setState(() {
      _passwordsMatch =
          _passwordController.text == _confirmPasswordController.text;
    });
  }

  /// Handle registration with FirebaseAuth and save user data to Firestore
  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    // show inline fixed error instead of Snackbar
    setState(() {
      _errorMessage = '';
    });

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        _errorMessage = ' يرجى ملء جميع الحقول';
      });
      return;
    }

    if (!_isPasswordStrong) {
      setState(() {
        _errorMessage =
            ' المتطلبات: 8–64 حرفًا وتتضمن حرفًا كبيرًا/صغيرًا، رقمًا، ورمزًا خاصًا.';
      });
      return;
    }

    if (!_passwordsMatch) {
      setState(() {
        _errorMessage = ' كلمتا المرور غير متطابقتين';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({'name': name, 'email': email, 'createdAt': Timestamp.now()});

      // success: navigate only (no Snackbar)
      _navigateToHome();
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = ' هذا البريد الإلكتروني مسجل بالفعل';
            break;
          case 'invalid-email':
            _errorMessage = ' صيغة البريد الإلكتروني غير صحيحة';
            break;
          case 'weak-password':
            _errorMessage =
                ' كلمة المرور ضعيفة. التزم بالمتطلبات (8–64، حرف كبير/صغير، رقم، ورمز خاص).';
            break;
          default:
            _errorMessage = 'فشل التسجيل. حاول مرة أخرى';
        }
      });
    } catch (_) {
      setState(() {
        _errorMessage = ' حدث خطأ غير متوقع';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Navigate to Home Page
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  /// Navigate to Login Page
  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.topRight,
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '!سجّل الآن',
                    style: TextStyle(
                      color: Color.fromRGBO(0, 0, 0, 1.0),
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM Plex Sans Arabic',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '.ادخل البيانات التالية لإنشاء حساب جديد',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color.fromRGBO(122, 122, 122, 1),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'IBM Plex Sans Arabic',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildInputField(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  hintText: 'Ahmed Al-Azaiza',
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _emailController,
                  label: 'البريد الالكتروني',
                  hintText: 'example@gmail.com',
                ),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildConfirmPasswordField(),

                // fixed inline error (single red line), like login page
                if (!_passwordsMatch)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'كلمتا المرور غير متطابقتين. يرجى التأكد من التطابق',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        fontFamily: 'IBM Plex Sans Arabic',
                      ),
                    ),
                  ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'IBM Plex Sans Arabic',
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : _buildRegisterButton(),
                const SizedBox(height: 24),
                _buildLoginOption(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable Input Field Widget
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF989898),
            fontSize: 14,
            fontFamily: 'IBM Plex Sans Arabic',
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textAlign: TextAlign.end,
          onChanged: (_) => setState(() {}), // keep as your original
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(32),
              borderSide: const BorderSide(color: Color(0xFFECECEC)),
            ),
          ),
        ),
      ],
    );
  }

  /// Password Field Widget
  Widget _buildPasswordField() {
    final showPolicyError =
        _passwordController.text.isNotEmpty && !_isPasswordStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'كلمة المرور',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF989898),
            fontFamily: 'IBM Plex Sans Arabic',
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          textAlign: TextAlign.end,
          onChanged: (_) {
            setState(() {}); // keep as your original
            _comparePasswords();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: '***********',
            hintStyle: const TextStyle(color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(32),
              borderSide: BorderSide(
                color: showPolicyError ? Colors.red : const Color(0xFFECECEC)),
            ),
            prefixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),
        if (showPolicyError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                _BulletLine('كلمة المرور بين 8 و64 حرفًا'),
                _BulletLine('تتضمن حرفًا كبيرًا (A–Z)'),
                _BulletLine('تتضمن حرفًا صغيرًا (a–z)'),
                _BulletLine('تتضمن رقمًا (0–9)'),
                _BulletLine('تتضمن رمزًا خاصًا (!@#\$%...)'),
              ],
            ),
          ),
      ],
    );
  }

  /// Confirm Password Field Widget
  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'تأكيد كلمة المرور',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF989898),
            fontFamily: 'IBM Plex Sans Arabic',
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          textAlign: TextAlign.end,
          onChanged: (_) => _comparePasswords(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: '***********',
            hintStyle: const TextStyle(color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(32),
              borderSide: BorderSide(
                color: _passwordsMatch ? const Color(0xFFECECEC) : Colors.red,
              ),
            ),
            prefixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Register Button
  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canSubmit ? _handleRegister : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFE399),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'تسجيل مستخدم جديد',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'IBM Plex Sans Arabic',
          ),
        ),
      ),
    );
  }

  /// Login Redirect Option
  Widget _buildLoginOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _navigateToLogin,
          child: const Text(
            '!سجّل دخول الآن',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'IBM Plex Sans Arabic',
            ),
          ),
        ),
        const Text(
          'لديك حساب بالفعل؟',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontFamily: 'IBM Plex Sans Arabic',
          ),
        ),
      ],
    );
  }
}
