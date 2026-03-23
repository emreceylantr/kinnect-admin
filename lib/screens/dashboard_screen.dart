import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../admin_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalReports = 0;
  int _aiProfiles = 0;
  int _pendingReports = 0;
  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _recentReports = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client.from('profiles').count(CountOption.exact),
        client.from('posts').count(CountOption.exact),
        client.from('user_profiles').count(CountOption.exact),
      ]);

      int pendingCount = 0;
      List<Map<String, dynamic>> reportsData = [];
      try {
        final reportsResp = await client
            .from('reports')
            .select('*, reporter:profiles!reporter_id(username, avatar_url)')
            .order('created_at', ascending: false)
            .limit(5);
        reportsData = List<Map<String, dynamic>>.from(reportsResp);

        final pendingResp = await client
            .from('reports')
            .count(CountOption.exact)
            .eq('status', 'pending');
        pendingCount = pendingResp;
      } catch (_) {}

      final recentResp = await client
          .from('profiles')
          .select('username, full_name, avatar_url, created_at')
          .order('created_at', ascending: false)
          .limit(6);

      if (mounted) {
        setState(() {
          _totalUsers = results[0];
          _totalPosts = results[1];
          _aiProfiles = results[2];
          _totalReports = reportsData.length;
          _pendingReports = pendingCount;
          _recentUsers = List<Map<String, dynamic>>.from(recentResp);
          _recentReports = reportsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AC.indigo))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dashboard', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AC.text)),
                          const SizedBox(height: 2),
                          Text(
                            'Son güncelleme: ${DateFormat('dd MMM, HH:mm').format(DateTime.now())}',
                            style: GoogleFonts.inter(fontSize: 12, color: AC.textMuted),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _IconBtn(icon: Icons.refresh_rounded, onTap: _fetchData),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats grid
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
                      final w = (c.maxWidth - (cols - 1) * 12) / cols;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(title: 'Toplam Kullanıcı', value: '$_totalUsers', icon: Icons.people_outline_rounded, color: AC.indigo, width: w),
                          _StatCard(title: 'Toplam Gönderi', value: '$_totalPosts', icon: Icons.photo_library_outlined, color: AC.purple, width: w),
                          _StatCard(title: 'AI Profil', value: '$_aiProfiles', icon: Icons.auto_awesome_rounded, color: AC.success, width: w,
                            subtitle: '${_totalUsers > 0 ? ((_aiProfiles / _totalUsers) * 100).toInt() : 0}% kapsama'),
                          _StatCard(title: 'Bekleyen Şikayet', value: '$_pendingReports', icon: Icons.flag_outlined, color: _pendingReports > 0 ? AC.warning : AC.textMuted, width: w),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Bottom section: 2 columns
                  LayoutBuilder(
                    builder: (context, c) {
                      if (c.maxWidth > 800) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _recentUsersCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _recentReportsCard()),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _recentUsersCard(),
                          const SizedBox(height: 16),
                          _recentReportsCard(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _recentUsersCard() {
    return Container(
      decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Son Katılan Kullanıcılar', style: GoogleFonts.inter(color: AC.text, fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                StatusBadge(text: '$_totalUsers toplam', color: AC.indigo),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AC.border, height: 1),
          ..._recentUsers.map((u) {
            final date = DateFormat('dd MMM').format(DateTime.parse(u['created_at']));
            final name = u['full_name'] ?? u['username'] ?? 'Bilinmiyor';
            final avatarUrl = u['avatar_url']?.toString();
            return _UserRow(name: name.toString(), sub: '@${u['username'] ?? ''} · $date', avatarUrl: avatarUrl);
          }),
        ],
      ),
    );
  }

  Widget _recentReportsCard() {
    return Container(
      decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Son Şikayetler', style: GoogleFonts.inter(color: AC.text, fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                if (_pendingReports > 0)
                  StatusBadge(text: '$_pendingReports bekliyor', color: AC.warning),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AC.border, height: 1),
          if (_recentReports.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Şikayet yok', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 13))),
            )
          else
            ..._recentReports.map((r) {
              final reporter = r['reporter'] as Map<String, dynamic>? ?? {};
              final status = r['status'] ?? 'pending';
              final statusColor = status == 'pending' ? AC.warning : status == 'resolved' ? AC.success : AC.textMuted;
              final statusLabel = status == 'pending' ? 'Bekliyor' : status == 'resolved' ? 'Çözüldü' : 'Arşiv';
              return _ReportRow(
                username: reporter['username']?.toString() ?? 'Anonim',
                reason: r['reason']?.toString() ?? '',
                statusLabel: statusLabel,
                statusColor: statusColor,
              );
            }),
        ],
      ),
    );
  }
}

// ── Components ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;
  final String? subtitle;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color, required this.width, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(subtitle!, style: GoogleFonts.inter(color: AC.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: GoogleFonts.inter(color: AC.text, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(color: AC.textSub, fontSize: 12)),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final String name;
  final String sub;
  final String? avatarUrl;
  const _UserRow({required this.name, required this.sub, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AC.surface,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null ? const Icon(Icons.person, size: 14, color: AC.textMuted) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(color: AC.text, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(sub, style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
              ],
            ),
          ),
          StatusBadge(text: 'Yeni', color: AC.success),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String username;
  final String reason;
  final String statusLabel;
  final Color statusColor;
  const _ReportRow({required this.username, required this.reason, required this.statusLabel, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: AC.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.flag_outlined, color: AC.warning, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username', style: GoogleFonts.inter(color: AC.text, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(reason, style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          StatusBadge(text: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.border)),
        child: Icon(icon, color: AC.textSub, size: 17),
      ),
    );
  }
}
