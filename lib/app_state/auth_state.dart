import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AuthState extends ChangeNotifier {
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox('auth');
  }

  bool get isReady => Hive.isBoxOpen('auth');
  bool get isLoggedIn => _box.get('isLoggedIn') == true;

  String? get username => _box.get('username') as String?;
  String? get password => _box.get('password') as String?;

  /// İlk girişte yazılan kullanıcı adı/şifreyi kalıcı yapar.
  /// Sonraki girişlerde eşleşme kontrolü yapar.
  Future<void> signIn(String user, String pass) async {
    final savedUser = _box.get('username');
    final savedPass = _box.get('password');

    if (savedUser == null || savedPass == null) {
      await _box.put('username', user);
      await _box.put('password', pass);
    } else {
      if (user != savedUser || pass != savedPass) {
        throw Exception('Kullanıcı adı veya şifre hatalı');
      }
    }
    await _box.put('isLoggedIn', true);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _box.put('isLoggedIn', false);
    notifyListeners();
  }

  Future<void> clearCredentials() async {
    await _box.delete('username');
    await _box.delete('password');
    await _box.put('isLoggedIn', false);
    notifyListeners();
  }
}