import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_theme.dart';

class AiMatchingScreen extends StatefulWidget {
  const AiMatchingScreen({super.key});

  @override
  State<AiMatchingScreen> createState() => _AiMatchingScreenState();
}

class _AiMatchingScreenState extends State<AiMatchingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _filtered = [];
  final _search = TextEditingController();
  Map<String, bool> _analyzing = {};

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _profiles
            : _profiles.where((p) {
                final name = (p['full_name'] ?? p['username'] ?? '').toString().toLowerCase();
                return name.contains(q);
              }).toList();
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    try {
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .order('username');

      final userProfiles = await Supabase.instance.client
          .from('user_profiles')
          .select('user_id, interests, social_style, analyzed_post_count, profile_summary, updated_at');

      final profileMap = {for (final p in (userProfiles as List)) p['user_id'] as String: p};

      final combined = (profiles as List).map((p) {
        final ai = profileMap[p['id']];
        return {...p as Map<String, dynamic>, 'ai': ai};
      }).toList();

      setState(() {
        _profiles = combined.cast<Map<String, dynamic>>();
        _filtered = _profiles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('AI profiles fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerAnalysis(String userId, String name) async {
    setState(() => _analyzing[userId] = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'analyze-user-profile',
        body: {'user_id': userId},
      );
      await _fetchProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name analiz edildi ✓'), backgroundColor: AC.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AC.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _analyzing.remove(userId));
    }
  }

  Future<void> _showMatchesDialog(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    showDialog(
      context: context,
      builder: (_) => _MatchesDialog(userId: userId, userName: user['full_name'] ?? user['username'] ?? ''),
    );
  }

  int _profileStrength(Map<String, dynamic>? ai) {
    if (ai == null) return 0;
    int s = 0;
    final postCount = (ai['analyzed_post_count'] as int?) ?? 0;
    final interests = (ai['interests'] as List?)?.length ?? 0;
    if (postCount >= 5) s++;
    if (postCount >= 15) s++;
    if (interests >= 3) s++;
    if ((ai['social_style'] as String?)?.isNotEmpty == true) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final analyzed = _profiles.where((p) => p['ai'] != null).length;
    final notAnalyzed = _profiles.length - analyzed;

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
                          Text('AI Eşleşme', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AC.text)),
                          const SizedBox(height: 2),
                          Text('Kullanıcı profillerini gör, analiz tetikle', style: GoogleFonts.inter(fontSize: 13, color: AC.textSub)),
                        ],
                      ),
                      const Spacer(),
                      _ActionButton(
                        icon: Icons.refresh_rounded,
                        label: 'Yenile',
                        color: AC.indigo,
                        onTap: _fetchProfiles,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats row
                  Row(
                    children: [
                      _MiniStat(label: 'Toplam Kullanıcı', value: '${_profiles.length}', color: AC.indigo),
                      const SizedBox(width: 12),
                      _MiniStat(label: 'Analiz Edilmiş', value: '$analyzed', color: AC.success),
                      const SizedBox(width: 12),
                      _MiniStat(label: 'Analiz Bekliyor', value: '$notAnalyzed', color: AC.warning),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AC.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AC.border),
                    ),
                    child: TextField(
                      controller: _search,
                      style: GoogleFonts.inter(color: AC.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Kullanıcı ara...',
                        hintStyle: GoogleFonts.inter(color: AC.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AC.textMuted, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        filled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AC.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border.all(color: AC.border),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(flex: 3, child: Text('Kullanıcı', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AC.textMuted, letterSpacing: 0.5))),
                        Expanded(flex: 2, child: Text('Sosyal Stil', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AC.textMuted, letterSpacing: 0.5))),
                        Expanded(flex: 3, child: Text('İlgi Alanları', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AC.textMuted, letterSpacing: 0.5))),
                        const SizedBox(width: 60, child: Text('Post', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AC.textMuted))),
                        const SizedBox(width: 100, child: Text('Güç', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AC.textMuted))),
                        const SizedBox(width: 160, child: Text('İşlemler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AC.textMuted))),
                      ],
                    ),
                  ),

                  // Rows
                  Container(
                    decoration: BoxDecoration(
                      color: AC.card,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(
                        left: BorderSide(color: AC.border),
                        right: BorderSide(color: AC.border),
                        bottom: BorderSide(color: AC.border),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(color: AC.border, height: 1),
                      itemBuilder: (context, i) {
                        final user = _filtered[i];
                        final ai = user['ai'] as Map<String, dynamic>?;
                        final userId = user['id'] as String;
                        final name = (user['full_name'] ?? user['username'] ?? 'Bilinmiyor').toString();
                        final username = (user['username'] ?? '').toString();
                        final avatarUrl = user['avatar_url']?.toString();
                        final interests = (ai?['interests'] as List?)?.cast<String>() ?? [];
                        final socialStyle = (ai?['social_style'] as String?) ?? '';
                        final postCount = (ai?['analyzed_post_count'] as int?) ?? 0;
                        final strength = _profileStrength(ai);
                        final isAnalyzing = _analyzing[userId] == true;
                        final hasProfile = ai != null;

                        final styleColor = {
                          'yalnız': AC.purple,
                          'ikili': AC.info,
                          'sosyal': AC.success,
                          'karma': AC.indigo,
                        }[socialStyle] ?? AC.textMuted;

                        final styleLabel = {
                          'yalnız': 'Bağımsız',
                          'ikili': 'İkili',
                          'sosyal': 'Sosyal',
                          'karma': 'Karma',
                        }[socialStyle] ?? '—';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AC.surface,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? const Icon(Icons.person, size: 16, color: AC.textMuted) : null,
                              ),
                              const SizedBox(width: 12),

                              // Name
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.inter(color: AC.text, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                                    Text('@$username', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),

                              // Social style
                              Expanded(
                                flex: 2,
                                child: hasProfile
                                    ? StatusBadge(text: styleLabel, color: styleColor)
                                    : Text('—', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 12)),
                              ),

                              // Interests
                              Expanded(
                                flex: 3,
                                child: interests.isEmpty
                                    ? Text('—', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 12))
                                    : Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: interests.take(3).map((t) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AC.indigo.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(t, style: GoogleFonts.inter(color: AC.indigo, fontSize: 10)),
                                        )).toList(),
                                      ),
                              ),

                              // Post count
                              SizedBox(
                                width: 60,
                                child: Text(
                                  hasProfile ? '$postCount' : '—',
                                  style: GoogleFonts.inter(color: hasProfile ? AC.text : AC.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),

                              // Strength bars
                              SizedBox(
                                width: 100,
                                child: hasProfile
                                    ? Row(
                                        children: List.generate(4, (i) => Container(
                                          width: 14,
                                          height: 6,
                                          margin: const EdgeInsets.only(right: 3),
                                          decoration: BoxDecoration(
                                            color: i < strength
                                                ? (strength <= 1 ? AC.danger : strength <= 2 ? AC.warning : AC.success)
                                                : AC.border,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        )),
                                      )
                                    : Text('Analiz yok', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
                              ),

                              // Actions
                              SizedBox(
                                width: 160,
                                child: Row(
                                  children: [
                                    // Analyze button
                                    GestureDetector(
                                      onTap: isAnalyzing ? null : () => _triggerAnalysis(userId, name),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AC.indigo.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AC.indigo.withValues(alpha: 0.25)),
                                        ),
                                        child: isAnalyzing
                                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AC.indigo))
                                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                                const Icon(Icons.auto_fix_high_rounded, size: 12, color: AC.indigo),
                                                const SizedBox(width: 4),
                                                Text('Analiz', style: GoogleFonts.inter(color: AC.indigo, fontSize: 11, fontWeight: FontWeight.w600)),
                                              ]),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Matches button
                                    if (hasProfile)
                                      GestureDetector(
                                        onTap: () => _showMatchesDialog(user),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AC.success.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AC.success.withValues(alpha: 0.25)),
                                          ),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.favorite_border_rounded, size: 12, color: AC.success),
                                            const SizedBox(width: 4),
                                            Text('Eşleş', style: GoogleFonts.inter(color: AC.success, fontSize: 11, fontWeight: FontWeight.w600)),
                                          ]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
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
}

// ── Matches Dialog ──────────────────────────────────────────────────────────
class _MatchesDialog extends StatefulWidget {
  final String userId;
  final String userName;
  const _MatchesDialog({required this.userId, required this.userName});

  @override
  State<_MatchesDialog> createState() => _MatchesDialogState();
}

class _MatchesDialogState extends State<_MatchesDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'match-users',
        body: {'user_id': widget.userId},
      );
      if (res.status != 200 || res.data == null) {
        setState(() => _loading = false);
        return;
      }
      final List<dynamic> matches = res.data is List
          ? res.data as List
          : ((res.data as Map)['matches'] as List? ?? []);
      setState(() {
        _matches = matches.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Matches fetch error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AC.indigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: AC.indigo, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.userName} Eşleşmeleri', style: GoogleFonts.inter(color: AC.text, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('AI algoritması tarafından hesaplandı', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AC.textMuted, size: 18)),
                ],
              ),
            ),
            const Divider(color: AC.border, height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AC.indigo))
                  : _matches.isEmpty
                      ? Center(child: Text('Eşleşme bulunamadı', style: GoogleFonts.inter(color: AC.textMuted)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _matches.length,
                          separatorBuilder: (_, __) => const Divider(color: AC.border, height: 16),
                          itemBuilder: (context, i) {
                            final m = _matches[i];
                            final profile = m['profile'] as Map<String, dynamic>? ?? {};
                            final score = ((m['similarity'] as double? ?? 0) * 100).toInt();
                            final avatarUrl = profile['avatar_url']?.toString();
                            final name = profile['full_name'] ?? profile['username'] ?? 'Kullanıcı';
                            final username = profile['username'] ?? '';
                            final reasons = (m['match_reasons'] as List?)?.cast<String>() ?? [];

                            final scoreColor = score >= 75 ? AC.success : score >= 60 ? AC.indigo : AC.warning;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Rank
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AC.surface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('${i + 1}', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AC.surface,
                                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                  child: avatarUrl == null ? const Icon(Icons.person, size: 14, color: AC.textMuted) : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name.toString(), style: GoogleFonts.inter(color: AC.text, fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('@$username', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
                                      if (reasons.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(reasons.first, style: GoogleFonts.inter(color: AC.textSub, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: scoreColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text('$score%', style: GoogleFonts.inter(color: scoreColor, fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.border),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.inter(color: AC.text, fontSize: 20, fontWeight: FontWeight.w700)),
                Text(label, style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
