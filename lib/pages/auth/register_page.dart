import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.register(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
      );
      if (mounted) context.go('/main');
    } on Exception catch (e) {
      setState(() {
        final msg = e.toString();
        if (msg.contains('email-already-in-use')) {
          _error = 'هذا البريد مسجّل مسبقاً';
        } else if (msg.contains('operation-not-allowed')) {
          _error = 'يرجى تفعيل الدخول بالبريد من لوحة تحكم Firebase (Authentication)';
        } else if (msg.contains('weak-password')) {
          _error = 'كلمة المرور ضعيفة جداً';
        } else {
          _error = 'تعذر إنشاء الحساب. راجع إعدادات Firebase';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width > 600 ? 420.0 : width * 0.92;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFE0E7FF), Color(0xFFCCFBF1), AppTheme.surface],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardWidth),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'حساب جديد',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'الاسم (اختياري)',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || !v.contains('@')) {
                                return 'بريد غير صالح';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return '6 أحرف على الأقل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirm,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) {
                              if (v != _password.text) {
                                return 'كلمتا المرور غير متطابقتين';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('إنشاء الحساب'),
                          ),
                          TextButton(
                            onPressed:
                                _loading ? null : () => context.go('/login'),
                            child: const Text('لديك حساب؟ تسجيل الدخول'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
