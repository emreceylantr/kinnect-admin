import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../admin_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  late TabController _tabController;
  final _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _fetchReports();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredReports = q.isEmpty
          ? _allReports
          : _allReports.where((r) {
              final username = (r['reporter']?['username'] ?? '').toString().toLowerCase();
              final reason = (r['reason'] ?? '').toString().toLowerCase();
              final desc = (r['description'] ?? '').toString().toLowerCase();
              return username.contains(q) || reason.contains(q) || desc.contains(q);
            }).toList();
    });
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('reports')
          .select('*, reporter:profiles!reporter_id(username, avatar_url, full_name)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _allReports = List<Map<String, dynamic>>.from(response);
          _filteredReports = _allReports;
          _isLoading = false;
        });
        if (_searchController.text.isNotEmpty) _onSearch();
      }
    } catch (e) {
      debugPrint('Reports fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_currentlyPlayingUrl == url) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingUrl = null);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        setState(() => _currentlyPlayingUrl = url);
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _currentlyPlayingUrl = null);
        });
      }
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  List<Map<String, dynamic>> _getTabList(String status) {
    return _filteredReports.where((r) {
      final s = r['status'] ?? 'pending';
      if (status == 'pending') return s == 'pending';
      return s == status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allReports.where((r) => (r['status'] ?? 'pending') == 'pending').length;

    return Scaffold(
      backgroundColor: AC.bg,
      body: Padding(
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
                    Text('Şikayetler', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AC.text)),
                    const SizedBox(height: 2),
                    Text('${_allReports.length} toplam şikayet', style: GoogleFonts.inter(fontSize: 12, color: AC.textMuted)),
                  ],
                ),
                const Spacer(),
                if (pendingCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AC.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AC.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AC.warning, size: 13),
                        const SizedBox(width: 6),
                        Text('$pendingCount bekliyor', style: GoogleFonts.inter(color: AC.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                // Search
                Container(
                  width: 220,
                  height: 38,
                  decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.border)),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: AC.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Şikayet ara...',
                      hintStyle: GoogleFonts.inter(color: AC.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AC.textMuted, size: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      fillColor: Colors.transparent,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _IconBtn(icon: Icons.refresh_rounded, onTap: _fetchReports),
              ],
            ),
            const SizedBox(height: 20),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: AC.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AC.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Tab(label: 'Bekleyenler', index: 0, tabController: _tabController,
                    count: _getTabList('pending').length, countColor: AC.warning),
                  _Tab(label: 'Çözülenler', index: 1, tabController: _tabController,
                    count: _getTabList('resolved').length, countColor: AC.success),
                  _Tab(label: 'Arşiv', index: 2, tabController: _tabController,
                    count: _getTabList('archived').length, countColor: AC.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AC.indigo))
                  : IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildList('pending'),
                        _buildList('resolved'),
                        _buildList('archived'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String status) {
    final list = _getTabList(status);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: AC.textMuted),
            const SizedBox(height: 12),
            Text('Kayıt yok', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) => _ReportCard(
        reportData: list[i],
        status: status,
        onRefresh: _fetchReports,
        onDetailTap: () => _showDetailDialog(list[i]),
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 1000,
          height: 700,
          decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.border)),
          child: FutureBuilder(
            future: report['type'] == 'user'
                ? Supabase.instance.client.from('profiles').select().eq('id', report['target_id']).maybeSingle()
                : Supabase.instance.client.from('posts').select('*, profiles(*), comments(*, profiles(*))').eq('id', report['target_id']).order('created_at', referencedTable: 'comments', ascending: false).maybeSingle(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AC.indigo));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_outlined, color: AC.textMuted, size: 40),
                      const SizedBox(height: 12),
                      Text('İçerik bulunamadı (silinmiş olabilir)', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 13)),
                      const SizedBox(height: 16),
                      _DialogBtn(label: 'Kapat', onTap: () => Navigator.pop(ctx)),
                    ],
                  ),
                );
              }

              final data = snapshot.data as Map<String, dynamic>;

              if (report['type'] == 'user') {
                return _UserDetailPane(data: data, onClose: () => Navigator.pop(ctx));
              } else {
                return _PostDetailPane(
                  data: data,
                  onClose: () => Navigator.pop(ctx),
                  currentlyPlayingUrl: _currentlyPlayingUrl,
                  onPlayAudio: _playAudio,
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final TabController tabController;
  final int count;
  final Color countColor;
  const _Tab({required this.label, required this.index, required this.tabController, required this.count, required this.countColor});

  @override
  Widget build(BuildContext context) {
    final isSelected = tabController.index == index;
    return GestureDetector(
      onTap: () => tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AC.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: AC.border) : null,
        ),
        child: Row(
          children: [
            Text(label, style: GoogleFonts.inter(
              color: isSelected ? AC.text : AC.textSub,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: countColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count', style: GoogleFonts.inter(color: countColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback onDetailTap;
  const _ReportCard({required this.reportData, required this.status, required this.onRefresh, required this.onDetailTap});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _isLoading = false;
  int _warningCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.status == 'pending') _fetchWarningCount();
  }

  Future<void> _fetchWarningCount() async {
    final userId = widget.reportData['reported_user_id'];
    if (userId == null) return;
    final resp = await Supabase.instance.client.from('profiles').select('warning_count').eq('id', userId).maybeSingle();
    if (resp != null && mounted) setState(() => _warningCount = resp['warning_count'] ?? 0);
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('reports').update({'status': newStatus}).eq('id', widget.reportData['id']);
      widget.onRefresh();
    } catch (e) {
      if (mounted) _showSnack('Hata: $e', AC.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _warnUser() async {
    final userId = widget.reportData['reported_user_id'] ?? widget.reportData['target_id'];
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final newCount = _warningCount + 1;
      await Supabase.instance.client.from('profiles').update({'warning_count': newCount}).eq('id', userId);
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'content': 'Topluluk kurallarını ihlal ettiğiniz için uyarıldınız. (Uyarı $newCount/3)',
        'type': 'warning',
      });
      if (mounted) {
        setState(() => _warningCount = newCount);
        _showSnack('Kullanıcı uyarıldı ($newCount/3)', AC.warning);
      }
    } catch (e) {
      if (mounted) _showSnack('Uyarı hatası: $e', AC.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTarget() async {
    final type = widget.reportData['type'];
    final targetId = widget.reportData['target_id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AC.border)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kalıcı Olarak Sil?', style: GoogleFonts.inter(color: AC.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'Bu ${type == 'user' ? 'kullanıcıyı' : 'içeriği'} silmek üzeresin. Bu işlem geri alınamaz!',
                style: GoogleFonts.inter(color: AC.textSub, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogBtn(label: 'İptal', onTap: () => Navigator.pop(ctx, false)),
                  const SizedBox(width: 10),
                  _DialogBtn(label: 'Sil', danger: true, onTap: () => Navigator.pop(ctx, true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      if (type == 'user') {
        await Supabase.instance.client.rpc('delete_user_by_admin', params: {'target_user_id': targetId});
      } else {
        await Supabase.instance.client.rpc('delete_content_by_admin', params: {'target_id': targetId, 'content_type': type});
      }
      await Supabase.instance.client.from('reports').update({'status': 'resolved'}).eq('id', widget.reportData['id']);
      widget.onRefresh();
      if (mounted) _showSnack('Silme başarılı', AC.success);
    } catch (e) {
      if (mounted) _showSnack('Silme hatası: $e', AC.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reportData;
    final reporter = r['reporter'] as Map<String, dynamic>? ?? {};
    final isPending = widget.status == 'pending';
    final isArchived = widget.status == 'archived';
    final avatarUrl = reporter['avatar_url']?.toString();

    String timeStr = '';
    try { timeStr = timeago.format(DateTime.parse(r['created_at'])); } catch (_) {}

    final typeColor = r['type'] == 'user' ? AC.purple : AC.info;
    final typeLabel = (r['type'] ?? 'post').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AC.surface,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 14, color: AC.textMuted) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('@${reporter['username'] ?? 'Gizli'}',
                              style: GoogleFonts.inter(color: AC.text, fontSize: 13, fontWeight: FontWeight.w600)),
                          if (isPending && _warningCount > 0) ...[
                            const SizedBox(width: 8),
                            StatusBadge(text: '$_warningCount uyarı', color: AC.danger),
                          ],
                        ],
                      ),
                      Text(timeStr, style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                StatusBadge(text: typeLabel, color: typeColor),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: AC.warning, size: 13),
                    const SizedBox(width: 6),
                    Text(r['reason'] ?? '', style: GoogleFonts.inter(color: AC.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                if ((r['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r['description'] ?? '', style: GoogleFonts.inter(color: AC.textSub, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AC.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(label: 'İncele', icon: Icons.visibility_outlined, color: AC.info, onTap: widget.onDetailTap),
                const SizedBox(width: 8),
                if (_isLoading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AC.indigo))
                else if (isPending) ...[
                  _ActionBtn(label: 'Arşiv', icon: Icons.archive_outlined, color: AC.textMuted, onTap: () => _updateStatus('archived')),
                  const SizedBox(width: 8),
                  if (_warningCount >= 3)
                    _ActionBtn(label: 'Sil (İhlal)', icon: Icons.delete_forever_outlined, color: AC.danger, onTap: _deleteTarget)
                  else
                    _ActionBtn(label: 'Uyar (${3 - _warningCount})', icon: Icons.notifications_active_outlined, color: AC.warning, onTap: _warnUser),
                  const SizedBox(width: 8),
                  _ActionBtn(label: 'Çözüldü', icon: Icons.check_circle_outline, color: AC.success, onTap: () => _updateStatus('resolved')),
                ] else if (isArchived) ...[
                  _ActionBtn(label: 'Çözüldü Yap', icon: Icons.check_circle_outline, color: AC.success, onTap: () => _updateStatus('resolved')),
                ] else ...[
                  Row(children: [
                    const Icon(Icons.check_circle_rounded, color: AC.success, size: 14),
                    const SizedBox(width: 6),
                    Text('Tamamlandı', style: GoogleFonts.inter(color: AC.success, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
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

class _DialogBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  const _DialogBtn({required this.label, required this.onTap, this.primary = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    Color bg = AC.surface;
    Color fg = AC.textSub;
    Color border = AC.border;
    if (primary) { bg = AC.indigoDark; fg = Colors.white; border = AC.indigoDark; }
    if (danger) { bg = AC.danger.withValues(alpha: 0.15); fg = AC.danger; border = AC.danger.withValues(alpha: 0.4); }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
        child: Text(label, style: GoogleFonts.inter(color: fg, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ── Detail Panes ──────────────────────────────────────────────────────────────

class _UserDetailPane extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  const _UserDetailPane({required this.data, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = data['avatar_url']?.toString();
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AC.border))),
          child: Row(
            children: [
              Text('Kullanıcı Detayı', style: GoogleFonts.inter(color: AC.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: AC.textMuted, size: 18)),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: AC.card,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 40, color: AC.textMuted) : null,
                ),
                const SizedBox(height: 16),
                Text('@${data['username'] ?? ''}', style: GoogleFonts.inter(color: AC.indigo, fontSize: 22, fontWeight: FontWeight.w700)),
                if ((data['full_name'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(data['full_name'], style: GoogleFonts.inter(color: AC.text, fontSize: 15)),
                ],
                const SizedBox(height: 20),
                if ((data['bio'] ?? '').toString().isNotEmpty)
                  Container(
                    width: 400,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.border)),
                    child: Text(data['bio'], style: GoogleFonts.inter(color: AC.textSub, fontSize: 13), textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PostDetailPane extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  final String? currentlyPlayingUrl;
  final Future<void> Function(String) onPlayAudio;
  const _PostDetailPane({required this.data, required this.onClose, required this.currentlyPlayingUrl, required this.onPlayAudio});

  @override
  Widget build(BuildContext context) {
    final owner = data['profiles'] as Map<String, dynamic>? ?? {};
    final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
    final likeCount = data['like_count'] ?? 0;
    final harlamaCount = data['harlama_count'] ?? 0;
    String timeStr = '';
    try { timeStr = timeago.format(DateTime.parse(data['created_at'])); } catch (_) {}

    return Row(
      children: [
        // Media side
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            ),
            child: Center(
              child: data['image_url'] != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                      child: Image.network(data['image_url'], fit: BoxFit.contain),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(data['content'] ?? '', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 20, color: AC.text)),
                    ),
            ),
          ),
        ),
        // Info side
        Expanded(
          flex: 4,
          child: Column(
            children: [
              // Post header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AC.border))),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AC.card,
                      backgroundImage: owner['avatar_url'] != null ? NetworkImage(owner['avatar_url']) : null,
                      child: owner['avatar_url'] == null ? const Icon(Icons.person, size: 14, color: AC.textMuted) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${owner['username'] ?? ''}', style: GoogleFonts.inter(color: AC.text, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(timeStr, style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: AC.textMuted, size: 18)),
                  ],
                ),
              ),
              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _StatPill(icon: Icons.favorite_rounded, value: likeCount, color: AC.danger),
                    const SizedBox(width: 10),
                    _StatPill(icon: Icons.local_fire_department_rounded, value: harlamaCount, color: Colors.orange),
                    const SizedBox(width: 10),
                    _StatPill(icon: Icons.comment_outlined, value: comments.length, color: AC.info),
                  ],
                ),
              ),
              Container(height: 1, color: AC.border),
              // Comments
              Expanded(
                child: comments.isEmpty
                    ? Center(child: Text('Yorum yok', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 13)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder: (_, i) {
                          final c = comments[i];
                          final isPlaying = currentlyPlayingUrl == c['audio_url'];
                          final commenterUrl = c['profiles']?['avatar_url']?.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AC.card,
                                  backgroundImage: commenterUrl != null ? NetworkImage(commenterUrl) : null,
                                  child: commenterUrl == null ? const Icon(Icons.person, size: 12, color: AC.textMuted) : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c['profiles']?['username'] ?? 'User',
                                          style: GoogleFonts.inter(color: AC.text, fontSize: 12, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      if (c['audio_url'] != null)
                                        GestureDetector(
                                          onTap: () => onPlayAudio(c['audio_url']),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AC.info.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: AC.info.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                                    color: AC.info, size: 22),
                                                const SizedBox(width: 6),
                                                Text(isPlaying ? 'Çalıyor...' : 'Sesli Yorum',
                                                    style: GoogleFonts.inter(color: AC.info, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        )
                                      else
                                        Text(c['content'] ?? '', style: GoogleFonts.inter(color: AC.textSub, fontSize: 12)),
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
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  const _StatPill({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text('$value', style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
