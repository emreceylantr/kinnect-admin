import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Diğer sayfaları import ediyoruz
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'reports_screen.dart'; // 🔥 EKSİK OLAN BUYDU! Bunu ekledik.

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0; // Hangi sayfanın seçili olduğunu tutar

  // Sayfaların Listesi (Menü sırasına göre)
  final List<Widget> _screens = [
    const DashboardScreen(), // 0. Dashboard
    const UsersScreen(),     // 1. Kullanıcılar
    const ReportsScreen(),   // 2. 🔥 ARTIK GERÇEK ŞİKAYET EKRANI BAĞLI!
    const Center(child: Text("Sistem Ayarları (Yakında)")),  // 3. Placeholder
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- SOL SIDEBAR (MENÜ) ---
          Container(
            width: 260,
            color: const Color(0xFF2A2D3E), // Sidebar Rengi
            child: Column(
              children: [
                // Logo Alanı
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: Colors.blueAccent, size: 32),
                      const SizedBox(width: 12),
                      Text(
                          "Kinnect",
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                    ],
                  ),
                ),

                // Menü Linkleri
                _buildMenuItem(0, "Dashboard", Icons.dashboard_outlined),
                _buildMenuItem(1, "Kullanıcılar", Icons.people_outline),
                _buildMenuItem(2, "Şikayetler", Icons.report_gmailerrorred_outlined),
                _buildMenuItem(3, "Ayarlar", Icons.settings_outlined),

                const Spacer(), // Çıkış butonunu en alta iter

                // Çıkış Butonu
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text("Çıkış Yap"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- SAĞ İÇERİK ALANI ---
          Expanded(
            child: Container(
              color: const Color(0xFF212332), // Ana içerik arkaplanı
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  // Menü Elemanı Tasarımı
  Widget _buildMenuItem(int index, String title, IconData icon) {
    final bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        hoverColor: Colors.white.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(left: BorderSide(color: Colors.blueAccent, width: 4))
                : null,
            color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}