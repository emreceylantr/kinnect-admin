import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_strategy/url_strategy.dart'; // URL'deki # işaretini kaldırır
import 'package:google_fonts/google_fonts.dart';

// 🔥 Oluşturduğumuz Login Ekranını Import Ediyoruz
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web tarayıcısında adres çubuğundaki gereksiz '#' işaretini kaldırır
  setPathUrlStrategy();

  // Admin paneli bağlantısı
  await Supabase.initialize(
    url: 'https://vxrvudcafkgqusjrawme.supabase.co',
    anonKey: 'sb_publishable_tSqnWtXnUhEog3MIx5ajRw_PZeTlwuG',
  );

  runApp(const KinnectAdminApp());
}

class KinnectAdminApp extends StatelessWidget {
  const KinnectAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinnect Admin',
      debugShowCheckedModeBanner: false,

      // Admin paneli için profesyonel "Dark Mode" teması
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF212332), // Şık bir koyu lacivert
        cardColor: const Color(0xFF2A2D3E), // Kartlar için biraz daha açık ton

        // Tüm yazılar için Poppins fontunu kullanıyoruz
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),

        // Input alanları için varsayılan stil
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2D3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
        ),
      ),

      // 🔥 ARTIK BAŞLANGIÇ SAYFAMIZ LOGIN EKRANI
      home: const LoginScreen(),
    );
  }
}