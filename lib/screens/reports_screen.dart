import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';

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
  final TextEditingController _searchController = TextEditingController();

  // 🎵 Ses Oynatıcı
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReports();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // 🎵 Ses Çalma Fonksiyonu
  Future<void> _playAudio(String url) async {
    try {
      if (_currentlyPlayingUrl == url) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingUrl = null);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        setState(() => _currentlyPlayingUrl = url);

        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) setState(() => _currentlyPlayingUrl = null);
        });
      }
    } catch (e) {
      debugPrint("Ses çalma hatası: $e");
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReports = _allReports.where((report) {
        final username = (report['reporter']?['username'] ?? '').toString().toLowerCase();
        final reason = (report['reason'] ?? '').toString().toLowerCase();
        final desc = (report['description'] ?? '').toString().toLowerCase();
        return username.contains(query) || reason.contains(query) || desc.contains(query);
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

      setState(() {
        _allReports = List<Map<String, dynamic>>.from(response);
        _filteredReports = _allReports;
        _isLoading = false;
      });
      if (_searchController.text.isNotEmpty) _onSearchChanged();
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Listeyi güncelleme callback'i
  void _refreshList() {
    _fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF27293D),
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Ara...",
              prefixIcon: Icon(Icons.search, color: Colors.white38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE14eca),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: "📥 GELENLER", icon: Icon(Icons.inbox, size: 20)),
            Tab(text: "✅ ÇÖZÜLENLER", icon: Icon(Icons.check_circle_outline, size: 20)),
            Tab(text: "🗂️ ARŞİV", icon: Icon(Icons.archive_outlined, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildReportList('pending'),
          _buildReportList('resolved'),
          _buildReportList('archived'),
        ],
      ),
    );
  }

  Widget _buildReportList(String statusFilter) {
    final list = _filteredReports.where((r) {
      final status = r['status'] ?? 'pending';
      if (statusFilter == 'pending') return status == 'pending';
      return status == statusFilter;
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            Text("Kayıt yok.", style: GoogleFonts.poppins(color: Colors.white24)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final report = list[index];
        // 🔥 YENİ: Akıllı Item Widget'ını kullanıyoruz
        return ReportItemWidget(
          reportData: report,
          statusFilter: statusFilter,
          onRefresh: _refreshList,
          onDetailTap: () => _showSmartDetailDialog(report),
        );
      },
    );
  }

  // --- DETAY PENCERESİ (İstatistikler Eklendi) ---
  void _showSmartDetailDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: 1100,
            height: 800,
            decoration: BoxDecoration(color: const Color(0xFF212332), borderRadius: BorderRadius.circular(16)),
            child: FutureBuilder(
              future: report['type'] == 'user'
                  ? Supabase.instance.client.from('profiles').select().eq('id', report['target_id']).maybeSingle()
                  : Supabase.instance.client.from('posts').select('*, profiles(*), comments(*, profiles(*))').eq('id', report['target_id']).order('created_at', referencedTable: 'comments', ascending: false).maybeSingle(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError || snapshot.data == null) return const Center(child: Text("İçerik bulunamadı (Silinmiş olabilir).", style: TextStyle(color: Colors.white)));

                final data = snapshot.data as Map<String, dynamic>;

                if (report['type'] == 'user') {
                  // KULLANICI DETAYI
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(radius: 80, backgroundImage: NetworkImage(data['avatar_url'] ?? '')),
                        const SizedBox(height: 20),
                        Text("@${data['username']}", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 20),
                        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: Text(data['bio'] ?? 'Bio yok', style: const TextStyle(color: Colors.white70))),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(icon: const Icon(Icons.close), label: const Text("Kapat"), onPressed: () => Navigator.pop(ctx))
                      ],
                    ),
                  );
                } else {
                  // POST DETAYI
                  final owner = data['profiles'] ?? {};
                  final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
                  // İstatistikleri çekiyoruz (veritabanında like_count/harlama_count yoksa 0 döner)
                  final likeCount = data['like_count'] ?? 0;
                  final harlamaCount = data['harlama_count'] ?? 0; // Eğer sütun adı farklıysa burayı düzelt

                  return Row(
                    children: [
                      // SOL: GÖRSEL
                      Expanded(
                        flex: 6,
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16))),
                          child: Center(
                            child: data['image_url'] != null
                                ? Image.network(data['image_url'], fit: BoxFit.contain)
                                : Text(data['content'] ?? '', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 24, color: Colors.white)),
                          ),
                        ),
                      ),
                      // SAĞ: YORUMLAR VE BİLGİ
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            // Başlık Kısmı
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(backgroundImage: NetworkImage(owner['avatar_url'] ?? '')),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("@${owner['username']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(timeago.format(DateTime.parse(data['created_at'])), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                  const Spacer(),
                                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                                ],
                              ),
                            ),

                            // 🔥 YENİ: İSTATİSTİKLER (BEĞENİ VE HARLAMA)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 6),
                                  Text("$likeCount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  const Text("Beğeni", style: TextStyle(color: Colors.grey, fontSize: 12)),

                                  const SizedBox(width: 20),

                                  Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                                  const SizedBox(width: 6),
                                  Text("$harlamaCount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  const Text("Harlama", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white10),

                            // Yorumlar Listesi
                            Expanded(
                              child: comments.isEmpty
                                  ? const Center(child: Text("Yorum yok.", style: TextStyle(color: Colors.white24)))
                                  : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  final c = comments[index];
                                  final isPlaying = _currentlyPlayingUrl == c['audio_url'];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(backgroundImage: NetworkImage(c['profiles']?['avatar_url'] ?? ''), radius: 16),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(c['profiles']?['username'] ?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              if (c['audio_url'] != null)
                                                GestureDetector(
                                                  onTap: () => _playAudio(c['audio_url']),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.blueAccent)),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.blueAccent, size: 30),
                                                        const SizedBox(width: 8),
                                                        Text(isPlaying ? "Çalıyor..." : "Sesli Yorum", style: const TextStyle(color: Colors.white)),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              else
                                                Text(c['content'] ?? '', style: const TextStyle(color: Colors.white70)),
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
              },
            ),
          ),
        );
      },
    );
  }
}

// 🔥🔥 YENİ VE GÜÇLÜ ITEM WIDGET (3 Uyarı Kuralı Burada) 🔥🔥
class ReportItemWidget extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final String statusFilter;
  final VoidCallback onRefresh;
  final VoidCallback onDetailTap;

  const ReportItemWidget({
    super.key,
    required this.reportData,
    required this.statusFilter,
    required this.onRefresh,
    required this.onDetailTap,
  });

  @override
  State<ReportItemWidget> createState() => _ReportItemWidgetState();
}

class _ReportItemWidgetState extends State<ReportItemWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  int _userWarningCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.statusFilter == 'pending') {
      _fetchUserWarningCount();
    }
  }

  Future<void> _fetchUserWarningCount() async {
    final userId = widget.reportData['reported_user_id']; // reported_user_id yoksa tablonuzu kontrol edin (örn: target_id eğer type='user' ise)

    // Eğer 'reported_user_id' tabloda yoksa, ve post şikayetiyse, postun sahibini bulmak gerekebilir.
    // Şimdilik tabloda 'reporter' değil, 'suçlu' olan kişinin ID'sinin report row'unda olduğunu varsayıyoruz.
    // Eğer yoksa, reportData['target_id'] üzerinden profile gitmeliyiz.

    // Basitlik adına target_id'nin bir user olduğunu veya post sahibine ulaştığımızı varsayalım.
    // Düzeltme: Genelde rapor tablosunda 'reported_by' ve 'reported_user' olur.

    // Eğer reportData'da 'reported_user_id' sütunu varsa:
    if (userId != null) {
      final response = await _supabase.from('profiles').select('warning_count').eq('id', userId).maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _userWarningCount = response['warning_count'] ?? 0;
        });
      }
    }
  }

  // --- EYLEMLER ---

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('reports').update({'status': newStatus}).eq('id', widget.reportData['id']);
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newStatus == 'resolved' ? "Çözüldü" : "Arşivlendi"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 1. UYAR (Sayacı arttır, bildirim at, şikayeti çözüldü yapma - belki?)
  Future<void> _warnUser() async {
    setState(() => _isLoading = true);
    final userId = widget.reportData['reported_user_id'] ?? widget.reportData['target_id']; // User ID bulma mantığı

    try {
      // Sayacı arttır
      final newCount = _userWarningCount + 1;
      await _supabase.from('profiles').update({'warning_count': newCount}).eq('id', userId);

      // Bildirim at
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'content': 'Topluluk kurallarını ihlal ettiğiniz için uyarıldınız. (Uyarı $newCount/3)',
        'type': 'warning',
      });

      if (mounted) {
        setState(() => _userWarningCount = newCount);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kullanıcı uyarıldı! (Toplam: $newCount)")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uyarı Hatası: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. SİL (Kullanıcıyı veya içeriği sil)
  Future<void> _deleteTarget() async {
    final type = widget.reportData['type'];
    final targetId = widget.reportData['target_id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF27293D),
        title: const Text("Kalıcı Olarak Sil?", style: TextStyle(color: Colors.white)),
        content: Text("Bu ${type == 'user' ? 'kullanıcıyı' : 'içeriği'} silmek üzeresin. Bu işlem geri alınamaz!", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text("Evet, Yok Et")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      if (type == 'user') {
        await _supabase.rpc('delete_user_by_admin', params: {'target_user_id': targetId});
      } else {
        await _supabase.rpc('delete_content_by_admin', params: {'target_id': targetId, 'content_type': type});
      }

      // Şikayeti çözüldü yap
      await _supabase.from('reports').update({'status': 'resolved'}).eq('id', widget.reportData['id']);

      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silme başarılı."), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Silme Hatası: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reportData;
    final reporter = r['reporter'] ?? {};
    final isPending = widget.statusFilter == 'pending';
    final isArchived = widget.statusFilter == 'archived';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF27293D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Kısım: Profil ve İçerik Bilgisi
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(backgroundImage: NetworkImage(reporter['avatar_url'] ?? ''), radius: 18, backgroundColor: Colors.grey[800]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("@${reporter['username'] ?? 'Gizli'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          if (isPending && _userWarningCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text("$_userWarningCount Uyarı", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                            )
                        ],
                      ),
                      Text(timeago.format(DateTime.parse(r['created_at'])), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: r['type'] == 'user' ? Colors.purple.withOpacity(0.2) : Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(r['type'].toString().toUpperCase(), style: TextStyle(color: r['type'] == 'user' ? Colors.purpleAccent : Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(r['reason'] ?? '', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                Text(r['description'] ?? '', style: const TextStyle(color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),

          // Alt Kısım: Butonlar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. İNCELE (Her zaman var)
                OutlinedButton.icon(
                  onPressed: widget.onDetailTap,
                  icon: const Icon(Icons.visibility, size: 16, color: Colors.blueGrey),
                  label: const Text("İncele", style: TextStyle(color: Colors.blueGrey)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueGrey)),
                ),
                const SizedBox(width: 8),

                // 2. DURUMA GÖRE BUTONLAR
                if (_isLoading)
                  const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))

                else if (isPending) ...[
                  // Arşivle
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                    onPressed: () => _updateStatus('archived'),
                    child: const Text("Arşiv", style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),

                  // UYARI SİSTEMİ MANTIĞI
                  if (_userWarningCount >= 3)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                      onPressed: _deleteTarget,
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text("İhlal Sınırı Doldu: SİL"),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                      onPressed: _warnUser,
                      icon: const Icon(Icons.notifications_active, size: 16),
                      label: Text("Uyar (${3 - _userWarningCount})"),
                    ),

                  const SizedBox(width: 8),
                  // Direkt Temiz Çözüldü
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: "Sorunsuz Çözüldü",
                    onPressed: () => _updateStatus('resolved'),
                  )

                ] else if (isArchived) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _updateStatus('resolved'),
                    child: const Text("Çözüldü Yap", style: TextStyle(color: Colors.white)),
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text("TAMAMLANDI ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}