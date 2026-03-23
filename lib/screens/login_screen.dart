import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../admin_theme.dart';
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _adminLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack('Lütfen tüm alanları doldurun', AC.warning);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (response.user == null) throw 'Giriş yapılamadı.';

      final userProfile = await supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', response.user!.id)
          .maybeSingle();

      final isAdmin = userProfile?['is_admin'] as bool? ?? false;
      if (!isAdmin) {
        await supabase.auth.signOut();
        if (mounted) _showSnack('⛔ Yetkisiz giriş! Sadece yöneticiler girebilir.', AC.danger);
      } else {
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
      }
    } on AuthException catch (e) {
      if (mounted) _showSnack('Giriş hatası: ${e.message}', AC.danger);
    } catch (e) {
      if (mounted) _showSnack('Hata: $e', AC.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.inter()), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AC.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AC.indigoDark, AC.purple]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kinnect', style: GoogleFonts.inter(color: AC.text, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Admin Paneli', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Giriş Yap', style: GoogleFonts.inter(color: AC.text, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Devam etmek için yönetici hesabınla giriş yap', style: GoogleFonts.inter(color: AC.textSub, fontSize: 13)),
              const SizedBox(height: 28),

              // Email
              Text('E-posta', style: GoogleFonts.inter(color: AC.textSub, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: AC.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'admin@kinnect.app',
                  prefixIcon: const Icon(Icons.email_outlined, size: 16),
                ),
                onSubmitted: (_) => _adminLogin(),
              ),
              const SizedBox(height: 16),

              // Password
              Text('Şifre', style: GoogleFonts.inter(color: AC.textSub, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                style: GoogleFonts.inter(color: AC.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 16),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16, color: AC.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _adminLogin(),
              ),
              const SizedBox(height: 24),

              // Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _adminLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AC.indigoDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Giriş Yap', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
