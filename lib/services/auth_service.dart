import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance!;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    _instance = this;
    _auth.authStateChanges().listen((user) async {
      _user = user;
      _parentId = null;
      _permissions = null;
      _role = null;
      
      if (user != null) {
        _isLoadingPermissions = true;
        notifyListeners();
        await _fetchSubAccountData(user.uid);
        _isLoadingPermissions = false;
      }
      _isInitialized = true;
      notifyListeners();
    });
  }

  bool _isInitialized = false;
  bool _isLoadingPermissions = false;
  bool get isLoadingPermissions => _isLoadingPermissions;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    final user = _auth.currentUser;
    if (user != null) {
      _isLoadingPermissions = true;
      await _fetchSubAccountData(user.uid);
      _isLoadingPermissions = false;
    }
    _isInitialized = true;
  }

  Future<void> _fetchSubAccountData(String uid) async {
    try {
      // 1. Look for pointer
      final pointerDoc = await FirebaseFirestore.instance.collection('sub_account_parents').doc(uid).get();
      
      if (pointerDoc.exists && pointerDoc.data() != null) {
        final parentId = pointerDoc.data()!['parentId'];
        
        // 2. Fetch actual permissions
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(parentId)
            .collection('sub_accounts')
            .doc(uid)
            .get();
            
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _parentId = data['parentId'] ?? parentId;
          _role = data['role'];
          if (data['permissions'] is Map) {
            _permissions = Map<String, dynamic>.from(data['permissions']);
          }
          return; // Success
        }
      }

      // Fallback for older accounts
      final doc = await FirebaseFirestore.instance.collection('sub_accounts').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _parentId = data['parentId'];
        _role = data['role'];
        if (data['permissions'] is Map) {
          _permissions = Map<String, dynamic>.from(data['permissions']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching sub-account permissions: $e');
    }
  }

  final FirebaseAuth _auth;
  User? _user;
  String? _parentId;
  String? _role;
  Map<String, dynamic>? _permissions;

  User? get currentUser => _user ?? _auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  // The actual database owner ID (either the current user, or their parent if they are a sub-account)
  String? get userId => _parentId ?? currentUser?.uid;
  
  // The real Firebase UID for this session
  String? get actualUid => currentUser?.uid;

  String get displayLabel {
    String baseLabel = currentUser?.email ?? currentUser?.displayName ?? 'مستخدم';
    if (_role != null) {
      return '$baseLabel ($_role)';
    }
    return baseLabel;
  }

  bool get isSubAccount => _parentId != null;
  String? get role => _role;

  // Permission Checks
  bool canAccessPage(String pageKey) {
    if (!isSubAccount) return true; // Master has full access
    return _permissions?[pageKey] ?? false; // Must be explicitly true
  }

  bool get canEdit {
    if (!isSubAccount) return true;
    return _permissions?['canEdit'] ?? false;
  }

  bool get canAdd {
    if (!isSubAccount) return true;
    return _permissions?['canAdd'] ?? false;
  }

  bool get canDelete {
    if (!isSubAccount) return true;
    return _permissions?['canDelete'] ?? false;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    notifyListeners();
    return credential;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
    }
    notifyListeners();
    return credential;
  }

  Future<void> signOut() async {
    _parentId = null;
    _permissions = null;
    _role = null;
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> setRememberMe(bool remember) async {
    try {
      await _auth.setPersistence(
          remember ? Persistence.LOCAL : Persistence.SESSION);
    } catch (e) {
      debugPrint('Persistence error: $e');
    }
  }
}
