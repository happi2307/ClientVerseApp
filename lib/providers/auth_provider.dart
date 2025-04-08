import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  User? _user;
  bool _loading = false;

  bool get isAuthenticated => _user != null;
  User? get user => _user;
  bool get loading => _loading;

  AuthProvider() {
    _initialize();
  }

  void _initialize() async {
    _loading = true;
    notifyListeners();
    
    _user = _supabase.auth.currentUser;
    
    _loading = false;
    notifyListeners();
    
    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      
      if (event == AuthChangeEvent.signedIn) {
        _user = data.session?.user;
      } else if (event == AuthChangeEvent.signedOut) {
        _user = null;
      }
      
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      _loading = true;
      notifyListeners();
      
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _loading = true;
      notifyListeners();
      
      await _supabase.auth.signOut();
      
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }
}