import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../admin_theme.dart';
import 'user_profile_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              final name = (u['full_name'] ?? '').toString().toLowerCase();
              final username = (u['username'] ?? '').toString().toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _filtered = _users;
          _isLoading = false;
        });
        if (_searchController.text.isNotEmpty) _onSearch();
      }
    } catch (e) {
      debugPrint('Users fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId, String username) async {
    final confirm = await _showConfirmDialog(
      title: 'Kullanıcıyı Sil',
      body: '@$username kullanıcısını ve tüm verilerini kalıcı olarak silmek istediğine emin misin?',
      confirmLabel: 'Kalıcı Sil',
      isDanger: true,
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client.rpc('delete_user_by_admin', params: {'target_user_id': userId});
      setState(() {
        _users.removeWhere((u) => u['id'] == userId);
        _filtered.removeWhere((u) => u['id'] == userId);
      });
      if (mounted) _showSnack('@$username silindi', AC.success);
    } catch (e) {
      if (mounted) _showSnack('Silme hatası: $e', AC.danger);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(text: user['full_name']);
    final bioCtrl = TextEditingController(text: user['bio']);
    final usernameCtrl = TextEditingController(text: user['username']);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AC.border)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kullanıcı Düzenle', style: GoogleFonts.inter(color: AC.text, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('@${user['username']}', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 12)),
              const SizedBox(height: 24),
              _editField('Kullanıcı Adı', usernameCtrl),
              const SizedBox(height: 12),
              _editField('Ad Soyad', nameCtrl),
              const SizedBox(height: 12),
              _editField('Biyografi', bioCtrl, maxLines: 3),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogBtn(label: 'İptal', onTap: () => Navigator.pop(ctx)),
                  const SizedBox(width: 10),
                  _DialogBtn(
                    label: 'Kaydet',
                    primary: true,
                    onTap: () async {
                      try {
                        await Supabase.instance.client.from('profiles').update({
                          'full_name': nameCtrl.text,
                          'bio': bioCtrl.text,
                          'username': usernameCtrl.text,
                        }).eq('id', user['id']);
                        Navigator.pop(ctx);
                        _fetchUsers();
                        _showSnack('Kullanıcı güncellendi', AC.success);
                      } catch (e) {
                        _showSnack('Güncelleme hatası: $e', AC.danger);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: AC.textSub, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: AC.text, fontSize: 13),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AC.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AC.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AC.indigo, width: 1.5)),
            fillColor: AC.card,
            filled: true,
          ),
        ),
      ],
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AC.border)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: AC.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(body, style: GoogleFonts.inter(color: AC.textSub, fontSize: 13)),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogBtn(label: 'İptal', onTap: () => Navigator.pop(ctx, false)),
                  const SizedBox(width: 10),
                  _DialogBtn(
                    label: confirmLabel,
                    danger: isDanger,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: AC.bg,
      body: SingleChildScrollView(
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
                    Text('Kullanıcılar', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AC.text)),
                    const SizedBox(height: 2),
                    Text('${_filtered.length} kullanıcı', style: GoogleFonts.inter(fontSize: 12, color: AC.textMuted)),
                  ],
                ),
                const Spacer(),
                // Search
                Container(
                  width: 240,
                  height: 38,
                  decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.border)),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: AC.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı ara...',
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
                _IconBtn(icon: Icons.refresh_rounded, onTap: _fetchUsers),
              ],
            ),
            const SizedBox(height: 24),

            // Table
            Container(
              decoration: BoxDecoration(color: AC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: CircularProgressIndicator(color: AC.indigo)),
                    )
                  : _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Text(
                              _searchController.text.isEmpty ? 'Kullanıcı yok' : 'Sonuç bulunamadı',
                              style: GoogleFonts.inter(color: AC.textMuted, fontSize: 13),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AC.border)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 38),
                                  Expanded(flex: 3, child: Text('Kullanıcı', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                                  Expanded(flex: 3, child: Text('Ad Soyad', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                                  Expanded(flex: 4, child: Text('Biyografi', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                                  SizedBox(width: 120, child: Text('Katılım', style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 80),
                                ],
                              ),
                            ),
                            // Rows
                            ..._filtered.map((user) => _UserRow(
                                  user: user,
                                  onView: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileDetailScreen(
                                    userId: user['id'],
                                    userName: user['username'] ?? 'Kullanıcı',
                                    avatarUrl: user['avatar_url'],
                                  ))),
                                  onEdit: () => _showEditDialog(user),
                                  onDelete: () => _deleteUser(user['id'], user['username'] ?? ''),
                                )),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _UserRow({required this.user, required this.onView, required this.onEdit, required this.onDelete});

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final avatarUrl = u['avatar_url']?.toString();
    String joinDate = '';
    try {
      joinDate = DateFormat('dd MMM yy').format(DateTime.parse(u['created_at']));
    } catch (_) {}

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? AC.cardHover : Colors.transparent,
          border: const Border(bottom: BorderSide(color: AC.border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: widget.onView,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AC.surface,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person, size: 14, color: AC.textMuted) : null,
              ),
            ),
            const SizedBox(width: 10),
            // Username
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: widget.onView,
                child: Text(
                  '@${u['username'] ?? ''}',
                  style: GoogleFonts.inter(color: AC.indigo, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(u['full_name'] ?? '-', style: GoogleFonts.inter(color: AC.text, fontSize: 13)),
            ),
            Expanded(
              flex: 4,
              child: Text(
                u['bio'] ?? '-',
                style: GoogleFonts.inter(color: AC.textSub, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(joinDate, style: GoogleFonts.inter(color: AC.textMuted, fontSize: 11)),
            ),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _RowIconBtn(icon: Icons.edit_outlined, color: AC.indigo, onTap: widget.onEdit),
                  const SizedBox(width: 4),
                  _RowIconBtn(icon: Icons.delete_outline_rounded, color: AC.danger, onTap: widget.onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RowIconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 13, color: color),
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
