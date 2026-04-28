import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    if (success && mounted) {
      // Route based on role
      final route = auth.isAdmin
        ? AppRoutes.adminDashboard
        : AppRoutes.volunteerDashboard;
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                // Logo + title
                const Icon(Icons.crisis_alert,
                  size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text('CrisisConnect',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
                const SizedBox(height: 8),
                const Text('Sign in to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 40),
                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter email' : null,
                ),
                const SizedBox(height: 16),
                // Password field
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                        ? Icons.visibility_off
                        : Icons.visibility),
                      onPressed: () => setState(
                        () => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) => v!.length < 6
                    ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 12),
                // Error message
                if (auth.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.urgencyHigh.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(auth.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.urgencyHigh)),
                  ),
                const SizedBox(height: 24),
                // Login button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    child: auth.isLoading
                      ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                      : const Text('Sign In',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                // Go to signup
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context, AppRoutes.signup),
                  child: const Text(
                    "Don't have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}