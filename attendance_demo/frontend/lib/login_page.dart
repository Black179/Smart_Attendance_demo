import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _selectedRole = 'student';
  final _rollController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _rollController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;

    // Validation
    if (_selectedRole == 'student' && _rollController.text.trim().isEmpty) {
      _showError('Please enter your roll number');
      return;
    }

    if (_selectedRole != 'student') {
      if (_usernameController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
        _showError('Please enter username and password');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('LoginPage: Starting login process for role: $_selectedRole');
      
      final result = await AuthService.login(
        role: _selectedRole,
        roll: _selectedRole == 'student' ? _rollController.text.trim() : null,
        username: _selectedRole != 'student' ? _usernameController.text.trim() : null,
        password: _selectedRole != 'student' ? _passwordController.text.trim() : null,
      );

      print('LoginPage: Login result: $result');

      if (result['success']) {
        // Navigate to main app
        if (mounted) {
          print('LoginPage: Navigating to main app');
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } else {
        _showError(result['error'] ?? 'Login failed');
      }
    } catch (e) {
      print('LoginPage: Exception during login: $e');
      _showError('Network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo/Title
                      const Icon(
                        Icons.school,
                        size: 64,
                        color: Color(0xFF1976D2),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Smart Attendance',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please login to continue',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role Selection
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            _buildRoleOption('student', 'Student', Icons.person),
                            const Divider(height: 1),
                            _buildRoleOption('teacher', 'Teacher', Icons.person_outline),
                            const Divider(height: 1),
                            _buildRoleOption('driver', 'Driver', Icons.directions_bus),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Input Fields
                      if (_selectedRole == 'student') ...[
                        TextField(
                          controller: _rollController,
                          decoration: InputDecoration(
                            labelText: 'Roll Number',
                            prefixIcon: const Icon(Icons.badge),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.text,
                        ),
                      ] else ...[
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: true,
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      // Demo Credentials
                      if (_selectedRole != 'student') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Demo Credentials:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedRole == 'teacher'
                                    ? 'Username: teacher, Password: teacher123'
                                    : 'Username: driver, Password: driver123',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption(String role, String title, IconData icon) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          // Clear form fields when switching roles
          _rollController.clear();
          _usernameController.clear();
          _passwordController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1976D2) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF1976D2) : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF1976D2),
              ),
          ],
        ),
      ),
    );
  }
}
