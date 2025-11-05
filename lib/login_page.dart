import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// HomePage, main.dart içinde tanımlı. Doğrudan ona gideceğiz.
import 'main.dart' show HomePage;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController(); // oluşturma modunda tekrar

  bool _obscure = true;
  bool _loading = false;
  bool _isCreating = false; // hesap oluşturma modu

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await Hive.openBox('auth');
    await _prefillAndDecideMode();
  }

  Future<void> _prefillAndDecideMode() async {
    try {
      final box = Hive.box('auth');
      final savedUser = box.get('username') as String?;
      final savedPin = box.get('pin') as String?;
      if (savedUser != null && savedUser.isNotEmpty) {
        _userCtrl.text = savedUser;
      }
      // Kayıt var mı yok mu? Yoksa oluşturma moduna gir.
      setState(() {
        _isCreating = (savedUser == null || savedPin == null);
      });
    } catch (_) {
      setState(() {
        _isCreating = true;
      });
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final username = _userCtrl.text.trim();
      final pin = _passCtrl.text.trim();
      final box = Hive.box('auth');

      if (_isCreating) {
        // Hesap oluştur / sıfırla
        await box.put('username', username);
        await box.put('pin', pin);
        await box.put('isLoggedIn', true);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        // Giriş
        final savedUser = box.get('username') as String?;
        final savedPin = box.get('pin') as String?;
        if (username != savedUser || pin != savedPin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı adı veya şifre hatalı')),
          );
          return;
        }
        await box.put('isLoggedIn', true);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchToCreate() {
    setState(() {
      _isCreating = true;
      _passCtrl.clear();
      _pass2Ctrl.clear();
    });
  }

  void _switchToLogin() {
    setState(() {
      _isCreating = false;
      _passCtrl.clear();
      _pass2Ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreating ? 'Hesap oluştur' : 'Giriş yap';
    final primaryLabel = _isCreating ? 'Hesap Oluştur' : 'Giriş Yap';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      const Text(
                        'Finix',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      // Kullanıcı adı
                      TextFormField(
                        controller: _userCtrl,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı adı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Kullanıcı adı zorunlu';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Şifre
                      TextFormField(
                        controller: _passCtrl,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Şifre zorunlu';
                          if (v.length < 4) return 'En az 4 karakter';
                          return null;
                        },
                      ),

                      // Şifre tekrar (sadece oluşturma modunda)
                      if (_isCreating) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass2Ctrl,
                          obscureText: _obscure,
                          decoration: const InputDecoration(
                            labelText: 'Şifre (tekrar)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Şifre tekrarı zorunlu';
                            if (v != _passCtrl.text.trim()) return 'Şifreler eşleşmiyor';
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Icon(_isCreating ? Icons.person_add_alt_1 : Icons.login),
                          label: Text(_loading ? 'Lütfen bekleyin...' : primaryLabel),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Alt aksiyon: modlar arası geçiş
                      if (_isCreating)
                        TextButton(
                          onPressed: _loading ? null : _switchToLogin,
                          child: const Text('Zaten hesabım var, girişe dön'),
                        )
                      else
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () async {
                            // Basit uyarı
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Hesabı sıfırla'),
                                content: const Text(
                                    'Mevcut kullanıcı adı ve şifreyi yeni bilgilerle değiştireceksiniz. Devam edilsin mi?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Devam')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              _switchToCreate();
                            }
                          },
                          child: const Text('Şifremi unuttum / Hesabı sıfırla'),
                        ),

                      const SizedBox(height: 6),
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
}