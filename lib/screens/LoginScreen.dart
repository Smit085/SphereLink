import 'package:flutter/material.dart';
import 'package:spherelink/core/session.dart';
import 'package:spherelink/core/GoogleAuthService.dart';
import 'package:spherelink/utils/appColors.dart';
import '../core/AppConfig.dart';
import '../utils/CustomPageRoute.dart';
import '../widget/customSnackbar.dart';
import 'MainScreen.dart';
import 'RegistrationScreen.dart';
import 'package:spherelink/core/apiService.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String _emailError = '';
  String _passwordError = '';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final response = await GoogleAuthService().signInWithGoogle();
    final user = response?['user'];
    final token = response?['token'];
    await Session().saveUserToken(token);

    if (user != null) {
      String baseUrl = AppConfig.apiBaseUrl;
      baseUrl = baseUrl.substring(0, baseUrl.lastIndexOf('/'));
      await Session().saveFirstName("${user['firstName']}");
      await Session().saveLastName("${user['lastName']}");
      await Session().saveEmail("${user['email']}");
      await Session().savePhone(
          user['phoneNumber'] != null ? "${user['phoneNumber']}" : "");

      String? profileImagePath = user['profileImagePath'];

      await Session().saveProfileImagePath(profileImagePath!);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomSnackBar(context, AppColors.textColorPrimary,
            "Login successful", Colors.white, "", () => {});
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Sign-In failed. Try again!")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          errorText: _emailError.isEmpty ? null : _emailError,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          } else if (!RegExp(
                                  r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        autocorrect: false,
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          errorText:
                              _passwordError.isEmpty ? null : _passwordError,
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          } else if (!RegExp(
                                  r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                              .hasMatch(value)) {
                            return 'Password must be in proper format';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _isLoading = true;
                              _emailError = '';
                              _passwordError = '';
                            });

                            final response = await ApiService().validateUser(
                              _emailController.text,
                              _passwordController.text,
                            );

                            setState(() {
                              _isLoading = false;
                            });

                            if (response == 'Login successful') {
                              final response = await ApiService()
                                  .getUser(_emailController.text);

                              await Session()
                                  .saveFirstName("${response?['firstName']}");
                              await Session()
                                  .saveLastName("${response?['lastName']}");
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCustomSnackBar(
                                    context,
                                    AppColors.textColorPrimary,
                                    "Login successful",
                                    Colors.white,
                                    "",
                                    () => {});
                              });
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MainScreen(),
                                  ));
                            } else if (response == "Invalid password.") {
                              _passwordError = 'Invalid password.';
                            } else if (response == "Login unsuccessful") {
                              setState(() {
                                _emailError = 'Invalid email.';
                              });
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCustomSnackBar(
                                    context,
                                    Colors.redAccent,
                                    "Something went wrong.",
                                    Colors.white,
                                    "",
                                    () => {});
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(115, 12),
                    backgroundColor: Colors.lightBlueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            color: Colors.blue,
                            strokeWidth:
                                3, // Adjust the thickness of the indicator
                            backgroundColor: Colors.blue,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                        context,
                        CustomPageRoute(
                          builder: (_) => const RegistrationScreen(),
                          direction: TransitionDirection.fromRight,
                        ));
                  },
                  child: const Text('Don\'t have an account? Register',
                      style: TextStyle(color: Colors.blue)),
                ),
                GestureDetector(
                  onTap: () {
                    print("Google");
                    _isLoading ? null : _handleGoogleSignIn();
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: _isLoading
                        ? null
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Image.asset(
                                "assets/img_google.png",
                                width: 45,
                                height: 45,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(
                                width: 5.0,
                              ),
                              const Text(
                                'Sign-in with Google',
                                style: TextStyle(fontSize: 14),
                              )
                            ],
                          ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
