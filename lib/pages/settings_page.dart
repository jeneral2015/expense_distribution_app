import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';
import '../services/auth_service.dart';
import '../utils/background_scaffold.dart';

class SettingsPage extends StatefulWidget {
  final AuthService auth;

  const SettingsPage({super.key, required this.auth});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _showAddOrEditDialog({String? uid, Map<String, dynamic>? currentData}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddOrEditSubAccountDialog(
        auth: widget.auth,
        uid: uid,
        currentData: currentData,
      ),
    );
  }

  void _deleteSubAccount(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من رغبتك في حذف هذا الحساب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        batch.delete(FirebaseFirestore.instance
            .collection('users')
            .doc(widget.auth.userId)
            .collection('sub_accounts')
            .doc(uid));

        batch.delete(FirebaseFirestore.instance
            .collection('sub_account_parents')
            .doc(uid));

        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الحساب بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isSubAccount) {
      return const BackgroundScaffold(
        title: 'الإعدادات',
        child: Center(
          child: Text('عذراً، لا تملك الصلاحية لإدارة الحسابات الفرعية.'),
        ),
      );
    }

    return BackgroundScaffold(
      title: 'إدارة الحسابات والصلاحيات',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الحسابات الفرعية',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddOrEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة حساب جديد'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.auth.userId)
                        .collection('sub_accounts')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('خطأ: ${snapshot.error}'));
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('لا توجد حسابات فرعية مضافة.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final uid = docs[index].id;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(data['email'] ?? 'بدون بريد'),
                              subtitle: Text('الدور: ${data['role']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _showAddOrEditDialog(
                                        uid: uid, currentData: data),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteSubAccount(uid),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
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

class _AddOrEditSubAccountDialog extends StatefulWidget {
  final AuthService auth;
  final String? uid;
  final Map<String, dynamic>? currentData;

  const _AddOrEditSubAccountDialog({
    required this.auth,
    this.uid,
    this.currentData,
  });

  @override
  State<_AddOrEditSubAccountDialog> createState() =>
      _AddOrEditSubAccountDialogState();
}

class _AddOrEditSubAccountDialogState
    extends State<_AddOrEditSubAccountDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'مساعد';

  bool _canAdd = true;
  bool _canEdit = true;
  bool _canDelete = false;

  final Map<String, bool> _pageAccess = {
    'page_input': true,
    'page_view': true,
    'page_distribute': true,
    'page_reports': true,
    'page_end_month': true,
    'page_database': true,
  };

  final Map<String, String> _pageNames = {
    'page_input': 'إدخال البيانات',
    'page_view': 'عرض وبحث',
    'page_distribute': 'توزيع المصروفات',
    'page_reports': 'التقارير',
    'page_end_month': 'تقفيل الشهر',
    'page_database': 'قاعدة البيانات',
  };

  bool get _isEditMode => widget.uid != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.currentData != null) {
      _emailController.text = widget.currentData!['email'] ?? '';
      _selectedRole = widget.currentData!['role'] ?? 'مساعد';

      final perms = widget.currentData!['permissions'] as Map<String, dynamic>?;
      if (perms != null) {
        _canAdd = perms['canAdd'] ?? false;
        _canEdit = perms['canEdit'] ?? false;
        _canDelete = perms['canDelete'] ?? false;

        for (var key in _pageAccess.keys) {
          _pageAccess[key] = perms[key] ?? false;
        }
      }
    }
  }

  Future<void> _saveAccount() async {
    if (!_isEditMode &&
        (_emailController.text.isEmpty ||
            _passwordController.text.length < 6)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('يرجى إدخال بريد صحيح وكلمة مرور من 6 أحرف')),
      );
      return;
    }

    setState(() {});

    try {
      String subUid = widget.uid ?? '';

      if (!_isEditMode) {
        FirebaseApp tempApp = await Firebase.initializeApp(
          name: 'temp_app_${DateTime.now().millisecondsSinceEpoch}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final credential = await tempAuth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        subUid = credential.user!.uid;
        await tempApp.delete();
      }

      Map<String, dynamic> permissions = {
        'canAdd': _selectedRole == 'مراقب' ? false : _canAdd,
        'canEdit': _selectedRole == 'مراقب' ? false : _canEdit,
        'canDelete': _selectedRole == 'مراقب' ? false : _canDelete,
      };

      permissions.addAll(_pageAccess);

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.auth.userId)
          .collection('sub_accounts')
          .doc(subUid);

      if (_isEditMode) {
        await docRef.update({
          'role': _selectedRole,
          'permissions': permissions,
        });
      } else {
        final batch = FirebaseFirestore.instance.batch();

        batch.set(docRef, {
          'uid': subUid,
          'parentId': widget.auth.userId,
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'permissions': permissions,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Pointer for login
        final pointerRef = FirebaseFirestore.instance
            .collection('sub_account_parents')
            .doc(subUid);
        batch.set(pointerRef, {
          'parentId': widget.auth.userId,
        });

        await batch.commit();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditMode
                  ? 'تم تحديث الصلاحيات بنجاح!'
                  : 'تم إضافة الحساب بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(_isEditMode ? 'تعديل الصلاحيات' : 'إضافة حساب جديد'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isEditMode) ...[
                  TextField(
                    controller: _emailController,
                    decoration:
                        const InputDecoration(labelText: 'البريد الإلكتروني'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                        labelText: 'كلمة المرور (6 أحرف كحد أدنى)'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isEditMode) ...[
                  Text('البريد الإلكتروني: ${_emailController.text}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: _emailController.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'تم إرسال رابط تعديل كلمة المرور إلى البريد الإلكتروني')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('حدث خطأ: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('إرسال رابط لتعديل كلمة المرور'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: ['مساعد', 'مراقب'].map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRole = val;
                        if (_selectedRole == 'مراقب') {
                          _canAdd = false;
                          _canEdit = false;
                          _canDelete = false;
                        }
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'نوع الحساب'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'الصلاحيات العامة:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                CheckboxListTile(
                  title: const Text('السماح بالإضافة'),
                  value: _canAdd,
                  onChanged: _selectedRole == 'مراقب'
                      ? null
                      : (val) => setState(() => _canAdd = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text('السماح بالتعديل'),
                  value: _canEdit,
                  onChanged: _selectedRole == 'مراقب'
                      ? null
                      : (val) => setState(() => _canEdit = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text('السماح بالحذف'),
                  value: _canDelete,
                  onChanged: _selectedRole == 'مراقب'
                      ? null
                      : (val) => setState(() => _canDelete = val ?? false),
                ),
                const SizedBox(height: 24),
                const Text(
                  'صلاحيات الوصول للصفحات:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _pageAccess.keys.map((key) {
                    return SizedBox(
                      width: 200,
                      child: CheckboxListTile(
                        title: Text(_pageNames[key]!),
                        value: _pageAccess[key],
                        onChanged: (val) {
                          setState(() {
                            _pageAccess[key] = val ?? false;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _saveAccount,
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
