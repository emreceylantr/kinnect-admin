import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_theme.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'reports_screen.dart';
import 'ai_matching_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final _screens = const [
    DashboardScreen(),
    UsersScreen(),
    ReportsScreen(),
    AiMatchingScreen(),
  ];

  final _navItems = const [
    _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.people_outline_rounded, label: 'Kullanıcılar'),
    _NavItem(icon: Icons.flag_outlined, label: 'Şikayetler'),
    _NavItem(icon: Icons.auto_awesome_rounded, label: 'AI Eşleşme'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: AC.surface,
            child: Column(
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AC.indigoDark, AC.purple]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kinnect', style: GoogleFonts.inter(color: AC.text, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('Admin', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: AC.border),
                const SizedBox(height: 12),

                // Nav items
                ...List.generate(_navItems.length, (i) => _buildNavItem(i)),

                const Spacer(),

                // Divider
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: AC.border),
                const SizedBox(height: 8),

                // Logout
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: AC.danger.withValues(alpha: 0.08),
                      onTap: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.logout_rounded, color: AC.danger, size: 16),
                            const SizedBox(width: 10),
                            Text('Çıkış Yap', style: GoogleFonts.inter(color: AC.danger, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: AC.indigo.withValues(alpha: 0.06),
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AC.indigo.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: isSelected ? AC.indigo : AC.textMuted),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    color: isSelected ? AC.text : AC.textSub,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
