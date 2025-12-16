import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 👇 YENİ DOSYAYI IMPORT ETMEYİ UNUTMA
import 'user_profile_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // 📡 1. Supabase'den Kullanıcıları Çekme
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('username', ascending: true);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Kullanıcı çekme hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ 2. Kullanıcı Silme Fonksiyonu
  Future<void> _deleteUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF27293D),
        title: const Text("Kullanıcıyı Tamamen Sil", style: TextStyle(color: Colors.white)),
        content: Text(
          "@$username kullanıcısını, giriş bilgilerini ve tüm verilerini kalıcı olarak silmek istediğine emin misin?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Kalıcı Olarak Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.rpc('delete_user_by_admin', params: {
          'target_user_id': userId,
        });

        setState(() {
          _users.removeWhere((user) => user['id'] == userId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("@$username tamamen silindi.")),
          );
        }
      } catch (e) {
        debugPrint("Silme hatası: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Silme başarısız: $e")),
          );
        }
      }
    }
  }

  // ✏️ 3. Kullanıcı Düzenleme Penceresi
  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['full_name']);
    final bioController = TextEditingController(text: user['bio']);
    final usernameController = TextEditingController(text: user['username']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF27293D),
        title: Text("Düzenle: @${user['username']}", style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Kullanıcı Adı", labelStyle: TextStyle(color: Colors.white70)),
              ),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Ad Soyad", labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bioController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Biyografi", labelStyle: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.from('profiles').update({
                  'full_name': nameController.text,
                  'bio': bioController.text,
                  'username': usernameController.text,
                }).eq('id', user['id']);

                Navigator.pop(context);
                _fetchUsers();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Kullanıcı güncellendi!")),
                );
              } catch (e) {
                debugPrint("Güncelleme hatası: $e");
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Kullanıcı Yönetimi",
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: _fetchUsers,
                icon: const Icon(Icons.refresh),
                label: const Text("Yenile"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tablo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF27293D),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                : _users.isEmpty
                ? const Center(child: Text("Hiç kullanıcı bulunamadı.", style: TextStyle(color: Colors.white)))
                : Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.white10),
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 10,
                headingTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white70),
                dataTextStyle: GoogleFonts.poppins(color: Colors.white),
                columns: const [
                  DataColumn(label: Text("Avatar")),
                  DataColumn(label: Text("Kullanıcı Adı")),
                  DataColumn(label: Text("Ad Soyad")),
                  DataColumn(label: Text("Biyografi")),
                  DataColumn(label: Text("İşlemler")),
                ],
                rows: _users.map((user) {
                  return DataRow(cells: [
                    // Avatar (Tıklanabilir)
                    DataCell(
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileDetailScreen(
                                userId: user['id'],
                                userName: user['username'] ?? 'Kullanıcı',
                                avatarUrl: user['avatar_url'],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Tooltip(
                          message: "Profili İncele",
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty)
                                ? NetworkImage(user['avatar_url'])
                                : null,
                            child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 18, color: Colors.white54)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text("@${user['username'] ?? 'Yok'}")),
                    DataCell(Text(user['full_name'] ?? '-')),
                    DataCell(SizedBox(width: 200, child: Text(user['bio'] ?? '-', overflow: TextOverflow.ellipsis))),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                            onPressed: () => _showEditDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteUser(user['id'], user['username'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}