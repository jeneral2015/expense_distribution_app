import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.setRememberMe(_rememberMe);
      await widget.auth.signIn(
        email: _email.text,
        password: _password.text,
      );
      if (mounted) context.go('/main');
    } on Exception catch (e) {
      setState(() => _error = _mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(Object e) {
    final msg = e.toString();
    if (msg.contains('invalid-credential') ||
        msg.contains('wrong-password') ||
        msg.contains('user-not-found')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (msg.contains('network')) {
      return 'تحقق من الاتصال بالإنترنت';
    }
    return 'تعذر تسجيل الدخول. حاول مرة أخرى';
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
              colors: [Color(0xFFCCFBF1), Color(0xFFE0E7FF), AppTheme.surface],
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
                          const Icon(Icons.account_balance_wallet_rounded,
                              size: 48, color: AppTheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            'توزيع المصاريف',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'سجّل الدخول لمزامنة بياناتك على Firebase',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'أدخل البريد';
                              }
                              if (!v.contains('@')) return 'بريد غير صالح';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return '6 أحرف على الأقل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            title: const Text('تذكرني'),
                            value: _rememberMe,
                            onChanged: (val) {
                              setState(() => _rememberMe = val ?? true);
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
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
                                : const Text('تسجيل الدخول'),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => context.go('/register'),
                            child: const Text('إنشاء حساب جديد'),
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
