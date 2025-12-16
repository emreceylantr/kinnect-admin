import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Dashboard Genel Bakış",
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),

          // İstatistik Kartları (Responsive Grid)
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildStatCard(context, "Toplam Kullanıcı", "1,240", Icons.people, Colors.blue),
              _buildStatCard(context, "Yeni Gönderiler", "345", Icons.post_add, Colors.purple),
              _buildStatCard(context, "Şikayetler", "12", Icons.report_problem, Colors.orange),
              _buildStatCard(context, "Aktif Sunucular", "TR-1", Icons.dns, Colors.green),
            ],
          ),

          const SizedBox(height: 40),
          Text(
            "Son Aktiviteler",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 10),

          // Grafik Gelecek Alan (Boş Kutu)
          Container(
            height: 400,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                "Grafikler ve Tablolar buraya gelecek... 📈",
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}