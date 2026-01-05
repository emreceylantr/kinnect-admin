import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class UserProfileDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;

  const UserProfileDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
  });

  @override
  State<UserProfileDetailScreen> createState() => _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _postsFuture;
  late Future<List<dynamic>> _messagesFuture;
  late Future<List<Map<String, dynamic>>> _logsFuture;
  String _selectedLogFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _postsFuture = Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      _messagesFuture = _fetchMessagesWithManualJoin();
      _logsFuture = _fetchAllUserActivity();
    });
  }

  // 🔥 GÜVENLİ LOG ÇEKME
  Future<List<Map<String, dynamic>>> _fetchAllUserActivity() async {
    try {
      final client = Supabase.instance.client;
      List<Map<String, dynamic>> allLogs = [];

      // A. POSTLAR
      final posts = await client.from('posts').select('id, content, created_at').eq('user_id', widget.userId);
      for (var p in posts) {
        allLogs.add({
          'type': 'post',
          'icon': Icons.grid_view,
          'color': Colors.blueAccent,
          'title': 'Yeni Gönderi',
          'detail': (p['content'] ?? 'Görsel Paylaşımı').toString(),
          'date': DateTime.parse(p['created_at']),
          'target_post_id': p['id'],
        });
      }

      // B. YORUMLAR
      final comments = await client.from('comments').select('id, content, audio_url, created_at, post_id').eq('user_id', widget.userId);
      for (var c in comments) {
        String detailText = c['audio_url'] != null ? "🎤 Sesli Yorum" : '"${c['content'] ?? ''}"';
        allLogs.add({
          'type': 'comment',
          'icon': Icons.comment,
          'color': Colors.greenAccent,
          'title': 'Yorum Yaptı',
          'detail': detailText,
          'date': DateTime.parse(c['created_at']),
          'target_post_id': c['post_id'],
        });
      }

      // C. BEĞENİLER
      final likes = await client.from('likes').select('id, created_at, post_id').eq('user_id', widget.userId);
      for (var l in likes) {
        allLogs.add({
          'type': 'like',
          'icon': Icons.favorite,
          'color': Colors.redAccent,
          'title': 'Beğendi',
          'detail': 'Bir gönderiyi beğendi.',
          'date': DateTime.parse(l['created_at']),
          'target_post_id': l['post_id'],
        });
      }

      allLogs.sort((a, b) => b['date'].compareTo(a['date']));
      return allLogs;
    } catch (e) {
      debugPrint("Log hatası: $e");
      return [];
    }
  }

  Future<void> _findAndShowPost(String postId) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
      final data = await Supabase.instance.client.from('posts').select().eq('id', postId).maybeSingle();
      if (mounted) Navigator.pop(context);

      if (data != null) {
        _showPostDetailDialog(data);
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu gönderi silinmiş.")));
      }
    } catch (e) {
      if(mounted) Navigator.pop(context);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMessagesWithManualJoin() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .or('sender_id.eq.${widget.userId},receiver_id.eq.${widget.userId}')
          .order('created_at', ascending: false)
          .limit(50);

      final List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(response);
      if (messages.isEmpty) return [];

      final Set<String> userIds = {};
      for (var msg in messages) {
        if (msg['sender_id'] != null) userIds.add(msg['sender_id']);
        if (msg['receiver_id'] != null) userIds.add(msg['receiver_id']);
      }

      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url')
          .filter('id', 'in', userIds.toList());

      final List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final Map<String, Map<String, dynamic>> profileMap = { for (var p in profiles) p['id']: p };

      return messages.map((msg) {
        return {
          ...msg,
          'sender': profileMap[msg['sender_id']] ?? {'username': '?', 'avatar_url': null},
          'receiver': profileMap[msg['receiver_id']] ?? {'username': '?', 'avatar_url': null},
        };
      }).toList();
    } catch (e) { return []; }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: const Color(0xFF27293D), title: const Text("Sil?", style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("İptal")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text("SİL"))]));
    if (confirm == true) {
      await Supabase.instance.client.from('messages').delete().eq('id', messageId);
      _refreshData();
    }
  }

  void _showPostDetailDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => PostDetailPopup(
        post: post,
        userAvatar: widget.avatarUrl,
        userName: widget.userName,
        onDelete: () => _refreshData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = const Color(0xFF27293D);
    final bgColor = const Color(0xFF1E1E2C);

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250.0,
              pinned: true,
              backgroundColor: cardColor,
              leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(widget.userName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.blueAccent.withOpacity(0.6), cardColor]))),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(radius: 50, backgroundColor: Colors.grey[800], backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null, child: widget.avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white54) : null),
                          const SizedBox(height: 10),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: Text("@${widget.userName}", style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on), text: "Postlar"),
                    Tab(icon: Icon(Icons.message), text: "Mesajlar"),
                    Tab(icon: Icon(Icons.history), text: "Loglar"),
                  ],
                ),
                cardColor,
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(),
            _buildMessagesTab(),
            _buildLogsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    return FutureBuilder(
      future: _postsFuture,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final List posts = snapshot.data ?? [];
        if (posts.isEmpty) return Center(child: Text("Post yok.", style: GoogleFonts.poppins(color: Colors.white54)));

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return InkWell(
              onTap: () => _showPostDetailDialog(post),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF27293D), borderRadius: BorderRadius.circular(4), image: (post['image_url'] != null) ? DecorationImage(image: NetworkImage(post['image_url']), fit: BoxFit.cover) : null),
                child: (post['image_url'] == null) ? Center(child: Text(post['content'] ?? '', textAlign: TextAlign.center, maxLines: 4, style: const TextStyle(color: Colors.white70, fontSize: 10))) : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    return FutureBuilder(
      future: _messagesFuture,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final List messages = snapshot.data ?? [];
        if (messages.isEmpty) return Center(child: Text("Mesaj yok.", style: GoogleFonts.poppins(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg['sender_id'] == widget.userId;
            final other = isMe ? msg['receiver'] : msg['sender'];
            return GestureDetector(
              onLongPress: () => _deleteMessage(msg['id']),
              child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
                if(!isMe) CircleAvatar(radius: 16, backgroundImage: other['avatar_url'] != null ? NetworkImage(other['avatar_url']) : null),
                if(!isMe) const SizedBox(width: 8),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isMe ? Colors.blueAccent : const Color(0xFF27293D), borderRadius: BorderRadius.circular(12)), child: Text(msg['content'] ?? '', style: const TextStyle(color: Colors.white)))
              ])),
            );
          },
        );
      },
    );
  }

  Widget _buildLogsTab() {
    return FutureBuilder(
      future: _logsFuture,
      builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final allLogs = snapshot.data ?? [];
        final logs = _selectedLogFilter == 'all' ? allLogs : allLogs.where((l) => l['type'] == _selectedLogFilter).toList();

        String lastSeenText = "Bilinmiyor";
        if (allLogs.isNotEmpty) {
          lastSeenText = DateFormat('dd/MM/yyyy HH:mm').format(allLogs.first['date']);
        }

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [const Text("Son Aktivite", style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text(lastSeenText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                Container(width: 1, height: 30, color: Colors.white24),
                Column(children: [const Text("Toplam İşlem", style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text("${allLogs.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
              ]),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _filterChip("Tümü", "all", Icons.list), const SizedBox(width: 8),
                _filterChip("Postlar", "post", Icons.grid_view), const SizedBox(width: 8),
                _filterChip("Yorumlar", "comment", Icons.comment), const SizedBox(width: 8),
                _filterChip("Beğeniler", "like", Icons.favorite),
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: logs.isEmpty ? Center(child: Text("Kayıt bulunamadı.", style: GoogleFonts.poppins(color: Colors.white54)))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: logs.length,
                itemBuilder: (context, index) => _buildTimelineItem(logs[index], index == logs.length - 1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, String value, IconData icon) {
    final isSelected = _selectedLogFilter == value;
    return ChoiceChip(
      label: Row(children: [Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white54), const SizedBox(width: 6), Text(label)]),
      selected: isSelected,
      onSelected: (bool selected) => setState(() => _selectedLogFilter = value),
      backgroundColor: const Color(0xFF27293D),
      selectedColor: Colors.blueAccent,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white54),
      side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.white12),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> log, bool isLast) {
    final dateStr = DateFormat('dd/MM HH:mm').format(log['date']);
    final Color itemColor = log['color'];

    return InkWell(
      onTap: () { if (log['target_post_id'] != null) _findAndShowPost(log['target_post_id']); },
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              Container(width: 16, height: 16, margin: const EdgeInsets.only(top: 20), decoration: BoxDecoration(color: itemColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: itemColor.withOpacity(0.5), blurRadius: 8)])),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.white10)),
            ]),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF27293D), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(log['icon'], color: itemColor, size: 18),
                    const SizedBox(width: 8),
                    Text(log['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
                  const SizedBox(height: 8),
                  Text(log['detail'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (log['type'] != 'post')
                    Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [Icon(Icons.touch_app, size: 12, color: itemColor), const SizedBox(width: 4), Text("Posta Git", style: TextStyle(color: itemColor, fontSize: 10, fontWeight: FontWeight.bold))])),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar; final Color _backgroundColor;
  _SliverAppBarDelegate(this._tabBar, this._backgroundColor);
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: _backgroundColor, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

// 🔥🔥🔥 POST DETAIL POPUP (GÜNCELLENMİŞ HALİ) 🔥🔥🔥
class PostDetailPopup extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? userAvatar;
  final String userName;
  final VoidCallback onDelete;

  const PostDetailPopup({super.key, required this.post, required this.userAvatar, required this.userName, required this.onDelete});

  @override
  State<PostDetailPopup> createState() => _PostDetailPopupState();
}

class _PostDetailPopupState extends State<PostDetailPopup> {
  bool _isLoading = true;
  int _likeCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final postId = widget.post['id'];
      final likeResponse = await Supabase.instance.client.from('likes').count(CountOption.exact).eq('post_id', postId);
      final commentsResponse = await Supabase.instance.client.from('comments').select('id, content, audio_url, created_at, user_id, profiles(username, avatar_url)').eq('post_id', postId).order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _likeCount = likeResponse;
          _comments = List<Map<String, dynamic>>.from(commentsResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playCommentAudio(String url) async {
    try { await _audioPlayer.stop(); await _audioPlayer.play(UrlSource(url)); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"))); }
  }

  // 🔥 TEKİL YORUM SİLME (YENİ HALİ)
  Future<void> _deleteSingleComment(String commentId) async {
    try {
      await Supabase.instance.client.from('comments').delete().eq('id', commentId);
      setState(() { _comments.removeWhere((c) => c['id'] == commentId); });
      widget.onDelete(); // Ana sayfadaki logları yenilemek için tetikle
    } catch (e) {
      debugPrint("Yorum silinemedi: $e");
    }
  }

  // 🔥 POST SİLME (CASCADE DESTEKLİ)
  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: const Color(0xFF27293D), title: const Text("Postu Sil?", style: TextStyle(color: Colors.white)), content: const Text("Post, yorumlar, beğeniler tamamen silinecek.", style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("İptal", style: TextStyle(color: Colors.white70))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text("SİL"))]));

    if (confirm == true) {
      try {
        final postId = widget.post['id'];
        // Cascade aktif olduğu için sadece postu siliyoruz
        await Supabase.instance.client.from('posts').delete().eq('id', postId);

        if (mounted) {
          Navigator.pop(context);
          widget.onDelete(); // Ana listeyi tazele
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post başarıyla silindi.")));
        }
      } catch (e) {
        debugPrint("Silme hatası: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;
    final imageUrl = widget.post['image_url'];
    final content = widget.post['content'] ?? '';
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2C),
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: isLargeScreen ? 900 : screenWidth * 0.95,
        height: 600,
        child: isLargeScreen
            ? Row(children: [Expanded(flex: 5, child: _media(imageUrl, content)), Expanded(flex: 3, child: _panel())])
            : Column(children: [Expanded(child: _media(imageUrl, content)), SizedBox(height: 350, child: _panel())]),
      ),
    );
  }

  Widget _media(String? url, String content) => Container(color: Colors.black, child: Center(child: url != null ? Image.network(url, fit: BoxFit.contain) : Text(content, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18))));

  Widget _panel() => Container(color: const Color(0xFF27293D), child: Column(children: [
    ListTile(leading: CircleAvatar(backgroundImage: widget.userAvatar != null ? NetworkImage(widget.userAvatar!) : null), title: Text(widget.userName, style: GoogleFonts.poppins(color: Colors.white)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
    const Divider(color: Colors.white10),
    Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: _comments.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 14, backgroundImage: c['profiles']['avatar_url'] != null ? NetworkImage(c['profiles']['avatar_url']) : null), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c['profiles']['username'] ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        c['audio_url'] != null ? ElevatedButton.icon(onPressed: () => _playCommentAudio(c['audio_url']), icon: const Icon(Icons.play_arrow, size: 16), label: const Text("Ses")) : Text(c['content'], style: const TextStyle(color: Colors.white70)),
      ])),
      IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteSingleComment(c['id']))
    ]))).toList())),
    Padding(padding: const EdgeInsets.all(16), child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red, minimumSize: const Size(double.infinity, 45)), onPressed: _deletePost, icon: const Icon(Icons.delete), label: const Text("POSTU SİL (ADMIN)")))
  ]));
}