import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  // İstatistik Değişkenleri
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalReports = 0;
  String _serverStatus = "Kontrol ediliyor...";
  Color _serverStatusColor = Colors.grey;

  // Son Aktiviteler Listesi
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // 📡 TÜM VERİLERİ TEK SEFERDE ÇEKEN FONKSİYON
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final client = Supabase.instance.client;

    try {
      // 1. Paralel olarak sayıları çek (Daha hızlı olması için Future.wait)
      final results = await Future.wait([
        client.from('profiles').count(CountOption.exact), // Toplam Kullanıcı
        client.from('posts').count(CountOption.exact),    // Toplam Post
        // Eğer 'reports' tablon varsa burayı aç, yoksa 0 döner
        // client.from('reports').count(CountOption.exact),
      ]);

      // 2. Son Aktiviteleri Çek (Örn: Son kayıt olan 5 kişi)
      final recentResponse = await client
          .from('profiles')
          .select('username, avatar_url, created_at')
          .order('created_at', ascending: false) // En yeniler
          .limit(5);

      if (mounted) {
        setState(() {
          _totalUsers = results[0];
          _totalPosts = results[1];
          _totalReports = 0; // results[2] (Eğer reports tablosu varsa)

          _recentActivities = List<Map<String, dynamic>>.from(recentResponse);

          _serverStatus = "TR-1 (Aktif)";
          _serverStatusColor = Colors.greenAccent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Dashboard veri hatası: $e");
      if (mounted) {
        setState(() {
          _serverStatus = "Bağlantı Hatası";
          _serverStatusColor = Colors.redAccent;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tema Renkleri
    const bgColor = Color(0xFF1E1E2C);
    const cardColor = Color(0xFF27293D);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BAŞLIK ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Dashboard Genel Bakış",
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _fetchDashboardData,
                  tooltip: "Verileri Yenile",
                )
              ],
            ),
            const SizedBox(height: 24),

            // --- İSTATİSTİK KARTLARI (GRID) ---
            LayoutBuilder(
              builder: (context, constraints) {
                // Ekran genişliğine göre 2'li veya 4'lü sıra
                final width = constraints.maxWidth;
                final isWide = width > 800;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard("Toplam Kullanıcı", "$_totalUsers", Icons.group, Colors.blueAccent, width, isWide),
                    _buildStatCard("Yeni Gönderiler", "$_totalPosts", Icons.post_add, Colors.purpleAccent, width, isWide),
                    _buildStatCard("Şikayetler", "$_totalReports", Icons.warning_amber_rounded, Colors.orangeAccent, width, isWide),
                    _buildStatCard("Sunucu Durumu", _serverStatus, Icons.dns, _serverStatusColor, width, isWide),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // --- ALT BÖLÜM: SON AKTİVİTELER ---
            Text(
              "Son Katılan Kullanıcılar",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: _recentActivities.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: Text("Henüz aktivite yok.", style: TextStyle(color: Colors.white54))),
              )
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentActivities.length,
                separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final user = _recentActivities[index];
                  final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(user['created_at']));

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                      child: user['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: Text(
                      user['username'] ?? "İsimsiz",
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      "Aramıza katıldı • $dateStr",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                      ),
                      child: const Text("Yeni Üye", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 KART WIDGET TASARIMI
  Widget _buildStatCard(String title, String value, IconData icon, Color color, double parentWidth, bool isWide) {
    // Geniş ekranda 4'e böl, dar ekranda 2'ye, çok darda tam boy
    double width = isWide ? (parentWidth - 48) / 4 : (parentWidth - 16) / 2;
    if (parentWidth < 500) width = parentWidth;

    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF27293D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}