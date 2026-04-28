import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_colors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = 'volunteer';
  bool _obscurePass = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      role: _selectedRole,
    );
    if (success && mounted) {
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
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name field
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 16),
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
                        ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(
                        () => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) => v!.length < 6
                    ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 20),
                // Role selector — THE key UI feature
                const Text('I am joining as:',
                  style: TextStyle(fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  _RoleCard(
                    title: 'Volunteer',
                    subtitle: 'Accept & complete tasks',
                    icon: Icons.volunteer_activism,
                    isSelected: _selectedRole == 'volunteer',
                    onTap: () => setState(
                      () => _selectedRole = 'volunteer'),
                  ),
                  const SizedBox(width: 12),
                  _RoleCard(
                    title: 'Admin',
                    subtitle: 'Manage needs & teams',
                    icon: Icons.admin_panel_settings,
                    isSelected: _selectedRole == 'admin',
                    onTap: () => setState(
                      () => _selectedRole = 'admin'),
                  ),
                ]),
                const SizedBox(height: 24),
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(auth.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.urgencyHigh)),
                  ),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    child: auth.isLoading
                      ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                      : const Text('Create Account',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reusable role selection card widget
class _RoleCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleCard({required this.title,
    required this.subtitle, required this.icon,
    required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
            border: Border.all(
              color: isSelected
                ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, size: 36,
              color: isSelected
                ? AppColors.primary : Colors.grey),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11,
                color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}