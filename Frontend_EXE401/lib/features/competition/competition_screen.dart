// ==========================================
// THI_DUA_FEATURE_START (By Gemini)
// ==========================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

String get API_BASE => "${AppConstants.baseUrl}/api/v1/competition";

class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  // State phòng thi đua
  String? currentRoomCode;
  String? groupName;
  int? durationDays;
  bool isExpired = false;
  List<dynamic> leaderboard = [];
  bool isLoading = false;
  String _selectedPeriod = "all"; // today | week | month | all
  int _arenaTabIndex = 0; // 0: BXH, 1: Kênh Trao Đổi

  // Thống kê ngoài Sảnh (1 Ngày / 1 Tuần / 1 Tháng)
  String _lobbyPeriod = "today"; // today | week | month
  Map<String, dynamic>? _userSummary;
  List<dynamic> _globalTopUsers = [];
  bool _loadingLobbyStats = false;

  // Danh sách Bạn Bè & Tin nhắn
  List<String> _friendsList = [];
  List<dynamic> _roomMessages = [];
  bool _loadingRoomMsgs = false;
  int _lastReadMsgCount = 0;

  int get _unreadRoomMsgCount {
    final count = _roomMessages.length - _lastReadMsgCount;
    return count > 0 ? count : 0;
  }

  void _markRoomChatAsRead() {
    if (_lastReadMsgCount != _roomMessages.length) {
      setState(() {
        _lastReadMsgCount = _roomMessages.length;
      });
    }
  }

  // Controllers
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController(text: "user_bao");
  final TextEditingController _roomMsgController = TextEditingController();
  final TextEditingController _dmController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  int _durationDays = 7;

  @override
  void initState() {
    super.initState();
    _fetchLobbyStats();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _joinCodeController.dispose();
    _userIdController.dispose();
    _roomMsgController.dispose();
    _dmController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // 1. CÁC HÀM LẤY DỮ LIỆU THỐNG KÊ NGOÀI SẢNH
  // ============================================================
  Future<void> _fetchLobbyStats() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) return;
    setState(() => _loadingLobbyStats = true);
    try {
      // 1. Tóm tắt cá nhân
      final resSummary = await http.get(
        Uri.parse('$API_BASE/stats/summary?user_id=$userId&period=$_lobbyPeriod')
      );
      if (resSummary.statusCode == 200) {
        _userSummary = jsonDecode(resSummary.body);
      }

      // 2. Top cao thủ toàn hệ thống
      final resTop = await http.get(
        Uri.parse('$API_BASE/stats/global-top?period=$_lobbyPeriod&limit=5')
      );
      if (resTop.statusCode == 200) {
        final data = jsonDecode(resTop.body);
        _globalTopUsers = data["top_users"] ?? [];
      }

      // 3. Danh sách bạn bè
      final resFriends = await http.get(
        Uri.parse('$API_BASE/friends/$userId')
      );
      if (resFriends.statusCode == 200) {
        final data = jsonDecode(resFriends.body);
        _friendsList = List<String>.from(data["friends"] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLobbyStats = false);
  }

  // ============================================================
  // 2. CÁC HÀM TƯƠNG TÁC PHÒNG & BẢNG XẾP HẠNG
  // ============================================================
  Future<void> _createRoom() async {
    if (_roomNameController.text.trim().isEmpty) {
      _showError("Vui lòng nhập tên phòng");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/groups'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": _roomNameController.text.trim(),
          "duration_days": _durationDays
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final code = data["room_code"];
        setState(() {
          currentRoomCode = code;
          _arenaTabIndex = 0;
        });
        await _joinRoomSilent(code);
        _showSuccess("Đã tạo phòng '$code' thành công!");
      }
    } catch (e) {
      _showError("Lỗi kết nối máy chủ");
    }
    setState(() => isLoading = false);
  }

  Future<void> _joinRoomSilent(String code) async {
    final userId = _userIdController.text.trim();
    await http.post(
      Uri.parse('$API_BASE/groups/join'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"room_code": code, "user_id": userId}),
    );
    await _fetchLeaderboard(code);
    await _fetchRoomMessages(code);
  }

  Future<void> _joinRoomBtn() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showError("Vui lòng nhập mã phòng");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/groups/join'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_code": code,
          "user_id": _userIdController.text.trim()
        }),
      );
      if (res.statusCode == 200) {
        setState(() {
          currentRoomCode = code;
          _arenaTabIndex = 0;
        });
        await _fetchLeaderboard(code);
        await _fetchRoomMessages(code);
        _showSuccess("Tham gia phòng thành công!");
      } else {
        final data = jsonDecode(res.body);
        _showError(data["detail"] ?? "Phòng không tồn tại hoặc đã đầy");
      }
    } catch (e) {
      _showError("Lỗi kết nối máy chủ");
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchLeaderboard(String code) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('$API_BASE/leaderboard/$code?period=$_selectedPeriod'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          leaderboard = data["leaderboard"] ?? [];
          groupName = data["group_name"];
          durationDays = data["duration_days"];
          isExpired = data["expired"] ?? false;
        });
      }
    } catch (_) {}
    setState(() => isLoading = false);
  }

  // Giả lập nộp điểm Pomodoro để TEST trên App
  Future<void> _submitFakeSession() async {
    setState(() => isLoading = true);
    try {
      final userId = _userIdController.text.trim();
      final res = await http.post(
        Uri.parse('$API_BASE/submit'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "work_min": 25,
          "completed": true,
          "pauses": 0
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _showSuccess(data["message"]);
        if (currentRoomCode != null) {
          await _fetchLeaderboard(currentRoomCode!);
          await _fetchRoomMessages(currentRoomCode!);
        }
        await _fetchLobbyStats();
      }
    } catch (_) {
      _showError("Lỗi submit điểm");
    }
    setState(() => isLoading = false);
  }

  // ============================================================
  // 3. CÁC HÀM CHAT CỘNG ĐỒNG TRONG PHÒNG
  // ============================================================
  Future<void> _fetchRoomMessages(String roomCode) async {
    setState(() => _loadingRoomMsgs = true);
    try {
      final res = await http.get(Uri.parse('$API_BASE/rooms/$roomCode/messages'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _roomMessages = data["messages"] ?? [];
          if (_arenaTabIndex == 1) {
            _lastReadMsgCount = _roomMessages.length;
          }
        });
        _scrollChatToBottom();
      }
    } catch (_) {}
    setState(() => _loadingRoomMsgs = false);
  }

  Future<void> _sendRoomMsg() async {
    final text = _roomMsgController.text.trim();
    if (text.isEmpty || currentRoomCode == null) return;
    _roomMsgController.clear();
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/rooms/$currentRoomCode/messages'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sender_id": _userIdController.text.trim(),
          "message": text,
          "msg_type": "user"
        }),
      );
      if (res.statusCode == 200) {
        await _fetchRoomMessages(currentRoomCode!);
      }
    } catch (_) {
      _showError("Lỗi gửi tin nhắn");
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================
  // 4. KẾT BẠN & CHAT RIÊNG (1-1)
  // ============================================================
  Future<void> _addFriend(String targetFriend) async {
    final myId = _userIdController.text.trim();
    if (targetFriend == myId) return;
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/friends/add'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": myId, "friend_id": targetFriend}),
      );
      if (res.statusCode == 200) {
        _showSuccess("Đã kết bạn với $targetFriend! 🤝");
        await _fetchLobbyStats();
      }
    } catch (_) {
      _showError("Lỗi gửi lời mời kết bạn");
    }
  }

  void _openDirectChat(String friendId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DirectChatModal(
        myUserId: _userIdController.text.trim(),
        friendId: friendId,
      ),
    );
  }

  void _showFriendsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Text("Bạn Bè Thi Đua (${_friendsList.length})", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: _friendsList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "Chưa có bạn bè nào. Hãy vào phòng thi đua và nhấn nút [+ Kết Bạn] bên cạnh đối thủ nhé!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(color: Colors.grey.shade600),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _friendsList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final f = _friendsList[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.shade200,
                        child: Text(f.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      title: Text(f, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      subtitle: const Text("🤝 Bạn cùng thi đua", style: TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat_bubble_rounded, color: Colors.blueAccent),
                        tooltip: "Nhắn tin riêng",
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openDirectChat(f);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
        ],
      ),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  // ============================================================
  // BUILD CHÍNH
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("🏆 Đấu Trường Năng Suất", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: const Color(0xFFFFD54F),
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.group_rounded, color: Colors.black87),
                if (_friendsList.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text("${_friendsList.length}", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            tooltip: "Danh sách bạn bè",
            onPressed: _showFriendsDialog,
          ),
        ],
      ),
      body: currentRoomCode == null ? _buildLobby() : _buildArena(),
      floatingActionButton: _buildFloatingChatBubble(),
    );
  }

  // ============================================================
  // BONG BÓNG CHAT NỔI (FLOATING CHAT BUBBLE) Ở GÓC DƯỚI PHẢI
  // ============================================================
  Widget _buildFloatingChatBubble() {
    // Chỉ hiện bong bóng chat khi đã vào phòng thi đua
    if (currentRoomCode == null || _arenaTabIndex == 1) {
      return const SizedBox.shrink();
    }

    final unread = _unreadRoomMsgCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 6),
      child: Tooltip(
        message: "Chat nhanh phòng ($currentRoomCode)",
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _openQuickChatSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8F65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                      if (unread > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              "$unread",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Chat Phòng",
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openQuickChatSheet() {
    if (currentRoomCode == null) return;
    _markRoomChatAsRead();
    _fetchRoomMessages(currentRoomCode!).then((_) {
      _markRoomChatAsRead();
    });

    final sheetScrollController = ScrollController();
    final quickMsgController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Future<void> sendQuickMsg() async {
              final text = quickMsgController.text.trim();
              if (text.isEmpty || currentRoomCode == null) return;
              quickMsgController.clear();
              try {
                final res = await http.post(
                  Uri.parse('$API_BASE/rooms/$currentRoomCode/messages'),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "sender_id": _userIdController.text.trim(),
                    "message": text,
                    "msg_type": "user"
                  }),
                );
                if (res.statusCode == 200) {
                  await _fetchRoomMessages(currentRoomCode!);
                  _markRoomChatAsRead();
                  setSheetState(() {});
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (sheetScrollController.hasClients) {
                      sheetScrollController.animateTo(
                        sheetScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              } catch (_) {
                _showError("Lỗi gửi tin nhắn");
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(sheetCtx).size.height * 0.72,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F65)]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Kênh Trao Đổi Phòng $currentRoomCode",
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                Text(
                                  "${_roomMessages.length} tin nhắn • Cùng nhau tiến bộ",
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Colors.grey, size: 20),
                            tooltip: "Tải lại",
                            onPressed: () async {
                              await _fetchRoomMessages(currentRoomCode!);
                              _markRoomChatAsRead();
                              setSheetState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.grey),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loadingRoomMsgs && _roomMessages.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : _roomMessages.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text("Chưa có tin nhắn nào trong phòng.", style: GoogleFonts.nunito(color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  controller: sheetScrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _roomMessages.length,
                                  itemBuilder: (ctx, idx) {
                                    final m = _roomMessages[idx];
                                    final isSys = m["msg_type"] == "system";
                                    final isMe = m["sender_id"] == _userIdController.text.trim();

                                    if (isSys) {
                                      return Center(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.amber.shade300),
                                          ),
                                          child: Text(
                                            m["message"],
                                            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.brown.shade800),
                                          ),
                                        ),
                                      );
                                    }

                                    return Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                        decoration: BoxDecoration(
                                          color: isMe ? const Color(0xFFFFD54F) : Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                                            bottomRight: Radius.circular(isMe ? 4 : 16),
                                          ),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe)
                                              Text(
                                                m["sender_id"] ?? "",
                                                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueAccent),
                                              ),
                                            const SizedBox(height: 2),
                                            Text(
                                              m["message"],
                                              style: GoogleFonts.nunito(fontSize: 14, color: Colors.black87),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              m["time"] ?? "",
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: Colors.white,
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: quickMsgController,
                                decoration: InputDecoration(
                                  hintText: "Gửi tin nhắn trao đổi trong phòng...",
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: (_) => sendQuickMsg(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: const Color(0xFFFFD54F),
                              child: IconButton(
                                icon: const Icon(Icons.send_rounded, color: Colors.black87, size: 18),
                                onPressed: sendQuickMsg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _markRoomChatAsRead();
    });
  }

  // ============================================================
  // MÀN HÌNH SẢNH CHỜ (LOBBY + THỐNG KÊ 1 NGÀY / 1 TUẦN / 1 THÁNG)
  // ============================================================
  Widget _buildLobby() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner tiêu đề
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 64, color: Color(0xFFFFA000)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Thi Đua Làm Việc & Học Tập",
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            "Tập trung nhận 1 điểm/phút • Cùng bạn bè chinh phục mục tiêu",
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // Tên hiển thị người dùng
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFD54F),
                  child: const Icon(Icons.person, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: "Tên hiển thị của bạn",
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _fetchLobbyStats(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
                  tooltip: "Tải lại thống kê",
                  onPressed: _fetchLobbyStats,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ========================================================
          // THỐNG KÊ THI ĐUA NGOÀI SẢNH (1 NGÀY / 1 TUẦN / 1 THÁNG)
          // ========================================================
          _buildLobbyStatsSection(),
          const SizedBox(height: 24),

          // Mục Tạo phòng mới
          _buildCreateRoomCard(),
          const SizedBox(height: 16),

          // Mục Tham gia phòng có sẵn
          _buildJoinRoomCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatTime(int totalMinutes) {
    if (totalMinutes <= 0) return "0p";
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return "${h}h ${m}p";
    if (h > 0) return "${h}h";
    return "${m}p";
  }

  Widget _buildLobbyStatsSection() {
    int toInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    double toDouble(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    final workMin = toInt(_userSummary?['total_work_min']);
    final score = toInt(_userSummary?['total_score']);
    final sessions = toInt(_userSummary?['completed_sessions']);
    final rank = toInt(_userSummary?['rank']);
    final goalProgress = toDouble(_userSummary?['goal_progress']);
    final goalMin = toInt(_userSummary?['goal_min'], 120);
    final avgMin = toInt(_userSummary?['avg_min_per_session']);
    final streak = toInt(_userSummary?['streak']);
    final dailyBreakdown = (_userSummary?['daily_breakdown'] as List<dynamic>?) ?? [];

    final isGoalReached = workMin >= goalMin;
    final periodName = _lobbyPeriod == 'today'
        ? 'Hôm Nay'
        : _lobbyPeriod == 'week'
            ? 'Tuần Này'
            : 'Tháng Này';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // === HEADER & BỘ CHỌN KHOẢNG THỜI GIAN ===
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F65)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  "Thống Kê Năng Suất",
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                ),
              ],
            ),
            if (_loadingLobbyStats)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35))),
          ],
        ),
        const SizedBox(height: 12),

        // TABS: Hôm Nay / Tuần Này / Tháng Này
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              _buildLobbyPeriodBtn("Hôm Nay", "today"),
              _buildLobbyPeriodBtn("Tuần Này", "week"),
              _buildLobbyPeriodBtn("Tháng Này", "month"),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // === THẺ MỤC TIÊU CHÍNH (HERO GOAL CARD) ===
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isGoalReached ? Colors.green.shade200 : Colors.orange.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Vòng tròn tiến độ mục tiêu to rõ
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 9,
                            backgroundColor: Colors.transparent,
                            color: Colors.grey.shade200,
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: goalProgress.clamp(0.0, 1.0),
                            strokeWidth: 9,
                            backgroundColor: Colors.transparent,
                            color: isGoalReached ? const Color(0xFF22C55E) : const Color(0xFFFF6B35),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${(goalProgress * 100).toInt()}%",
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isGoalReached ? const Color(0xFF16A34A) : const Color(0xFFFF6B35),
                              ),
                            ),
                            Text(
                              "mục tiêu",
                              style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Thông tin giải thích dễ hiểu
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isGoalReached ? Colors.green.shade50 : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isGoalReached ? Colors.green.shade300 : const Color(0xFFFFD8A8)),
                              ),
                              child: Text(
                                isGoalReached ? "🏆 ĐÃ ĐẠT CHỈ TIÊU" : "🎯 ĐANG CỐ GẮNG",
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isGoalReached ? Colors.green.shade800 : const Color(0xFFEA580C),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (streak > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "🔥 $streak ngày liên tiếp",
                                  style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.deepOrange),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Đã tập trung: ${_formatTime(workMin)}",
                          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Chỉ tiêu $periodName: ${_formatTime(goalMin)}",
                          style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        // Thanh đo tiến độ ngang trực quan
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: goalProgress.clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: Colors.grey.shade100,
                            color: isGoalReached ? const Color(0xFF22C55E) : const Color(0xFFFF6B35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              // Lời động viên dễ hiểu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isGoalReached ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isGoalReached ? Icons.celebration_rounded : Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: isGoalReached ? Colors.green : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isGoalReached
                            ? "Xuất sắc! Bạn đã vượt mục tiêu ${_formatTime(workMin - goalMin)} trong $periodName!"
                            : (workMin > 0
                                ? "Còn ${_formatTime(goalMin - workMin)} nữa là bạn sẽ hoàn thành mục tiêu $periodName!"
                                : "Hãy bật Pomodoro để bắt đầu học và tích điểm thi đua nhé!"),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isGoalReached ? Colors.green.shade800 : Colors.blueGrey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // === 3 THẺ CHỈ SỐ RÕ RÀNG (KHÔNG DÙNG THUẬT NGỮ KHÓ HIỂU) ===
        Row(
          children: [
            _buildFriendlyStatCard(
              icon: Icons.timer_outlined,
              color: const Color(0xFFFF6B35),
              title: "Thời Gian",
              value: _formatTime(workMin),
              subtitle: "$workMin phút tập trung",
            ),
            const SizedBox(width: 10),
            _buildFriendlyStatCard(
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF3B82F6),
              title: "Số Phiên",
              value: "$sessions phiên",
              subtitle: avgMin > 0 ? "TB $avgMin phút/phiên" : "Chưa có phiên",
            ),
            const SizedBox(width: 10),
            _buildFriendlyStatCard(
              icon: Icons.stars_rounded,
              color: const Color(0xFFF59E0B),
              title: "Điểm & Hạng",
              value: "$score điểm",
              subtitle: rank > 0 ? "Hạng #$rank toàn app" : "Chưa xếp hạng",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // === BIỂU ĐỒ HOẠT ĐỘNG 7 NGÀY (CHUẨN SMARTWATCH) ===
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bar_chart_rounded, color: Color(0xFFFF6B35), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Thời Gian Học 7 Ngày Qua",
                            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                          ),
                          Text(
                            "Thống kê chuẩn theo thời gian thực (Giờ & Phút)",
                            style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag_rounded, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          "Chỉ tiêu: 2h/ngày",
                          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              dailyBreakdown.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text("Chưa có dữ liệu tuần này", style: GoogleFonts.nunito(color: Colors.grey)),
                    ))
                  : _buildBarChart(dailyBreakdown),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // === BẢNG VÀNG CAO THỦ (TOP 5) ===
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "🔥 Bảng Vàng Cao Thủ ($periodName)",
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                  ),
                  Text(
                    "${_userSummary?['total_users'] ?? 0} người tham gia",
                    style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_globalTopUsers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text("Chưa có ai thi đua.", style: GoogleFonts.nunito(color: Colors.grey))),
                )
              else
                Column(
                  children: _globalTopUsers.map((u) {
                    final uRank = (u is Map && u["rank"] is num) ? (u["rank"] as num).toInt() : int.tryParse('${u["rank"]}') ?? 999;
                    final isTop3 = uRank <= 3;
                    final badge = uRank == 1 ? "🥇" : uRank == 2 ? "🥈" : uRank == 3 ? "🥉" : "#$uRank";
                    final userId = (u is Map ? u["user_id"] : '')?.toString() ?? '';
                    final isMe = userId == _userIdController.text.trim();
                    final workM = (u is Map && u['work_min'] is num) ? (u['work_min'] as num).toInt() : int.tryParse('${u['work_min']}') ?? 0;
                    final sc = (u is Map && u['score'] is num) ? (u['score'] as num).toInt() : int.tryParse('${u['score']}') ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isMe ? const Color(0xFFFBBF24) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Text(badge, style: TextStyle(fontSize: isTop3 ? 20 : 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              userId + (isMe ? " (Bạn)" : ""),
                              style: GoogleFonts.nunito(
                                fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                                color: isMe ? const Color(0xFFEA580C) : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Text(
                            "⏱ ${_formatTime(workM)}",
                            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$sc điểm",
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendlyStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<dynamic> data) {
    int maxMin = 0;
    int total7Mins = 0;
    for (final d in data) {
      final v = (d is Map && d['work_min'] is num)
          ? (d['work_min'] as num).toInt()
          : int.tryParse('${d['work_min']}') ?? 0;
      if (v > maxMin) maxMin = v;
      total7Mins += v;
    }
    // Chuẩn hoá trục: tối thiểu 180 phút (3h) để mốc 2h (120 phút) nằm cân đối ở 66% chiều cao
    final chartMax = maxMin > 180 ? maxMin : 180;
    const double trackHeight = 90.0;
    final avgDailyMin = (total7Mins / (data.isEmpty ? 1 : data.length)).round();

    final vnDayMap = {
      'Mon': 'T2', 'Tue': 'T3', 'Wed': 'T4', 'Thu': 'T5', 'Fri': 'T6', 'Sat': 'T7', 'Sun': 'CN',
      'T2': 'T2', 'T3': 'T3', 'T4': 'T4', 'T5': 'T5', 'T6': 'T6', 'T7': 'T7', 'CN': 'CN',
    };

    final vnFullNameMap = {
      'Mon': 'Thứ Hai', 'Tue': 'Thứ Ba', 'Wed': 'Thứ Tư', 'Thu': 'Thứ Năm', 'Fri': 'Thứ Sáu', 'Sat': 'Thứ Bảy', 'Sun': 'Chủ Nhật',
      'T2': 'Thứ Hai', 'T3': 'Thứ Ba', 'T4': 'Thứ Tư', 'T5': 'Thứ Năm', 'T6': 'Thứ Sáu', 'T7': 'Thứ Bảy', 'CN': 'Chủ Nhật',
    };

    return Column(
      children: [
        // Thanh tóm tắt nhanh tuần
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tổng 7 ngày: ${_formatTime(total7Mins)}",
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
              Text(
                "Trung bình: ${_formatTime(avgDailyMin)} / ngày",
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        // Khung biểu đồ với đường mốc chỉ tiêu 2h (120 phút)
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Đường chỉ tiêu nét đứt chạy ngang biểu đồ
            Positioned(
              left: 0,
              right: 0,
              bottom: 44 + (120.0 / chartMax * trackHeight).clamp(0.0, trackHeight),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.amber.shade400.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Mục tiêu 2h",
                      style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),

            // Các cột ngày
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (idx) {
                final d = data[idx];
                final mins = (d is Map && d['work_min'] is num)
                    ? (d['work_min'] as num).toInt()
                    : int.tryParse('${d['work_min']}') ?? 0;
                final sessions = (d is Map && d['sessions'] != null) ? d['sessions'] : 0;
                final score = (d is Map && d['score'] != null) ? d['score'] : 0;
                final rawLabel = (d is Map ? (d['en_label'] ?? d['label']) : '')?.toString() ?? '';
                final isToday = (d is Map && d['is_today'] == true) || idx == data.length - 1;

                // Tên thứ tiếng Việt chuẩn
                final vnDay = vnDayMap[rawLabel] ?? rawLabel;
                final fullDayName = vnFullNameMap[rawLabel] ?? vnDay;

                // Ngày tháng ngắn (VD: 15/10)
                String shortDate = (d is Map && d['short_date'] != null) ? d['short_date'].toString() : '';
                if (shortDate.isEmpty && d is Map && d['date'] != null) {
                  final parts = d['date'].toString().split('-');
                  if (parts.length == 3) shortDate = "${parts[2]}/${parts[1]}";
                }

                // Chiều cao cột
                final fillHeight = mins > 0 ? (mins / chartMax * trackHeight).clamp(10.0, trackHeight) : 0.0;
                final isGoalMet = mins >= 120;

                final timeDisplay = mins >= 60
                    ? "${mins ~/ 60}h${mins % 60 > 0 ? '${mins % 60}p' : ''}"
                    : (mins > 0 ? "${mins}p" : "-");

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "$fullDayName ($shortDate): ${_formatTime(mins)} tập trung • $sessions phiên • $score điểm",
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Nhãn thời gian trên đầu cột
                        Text(
                          timeDisplay,
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isToday
                                ? const Color(0xFFFF6B35)
                                : (mins > 0 ? const Color(0xFF1E293B) : Colors.grey.shade400),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Cột chuẩn phong cách Smartwatch (Rãnh mờ + Thanh đổ màu)
                        Container(
                          width: 28,
                          height: trackHeight,
                          decoration: BoxDecoration(
                            color: isToday ? const Color(0xFFFFF1EB) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: isToday
                                ? Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.35), width: 1.2)
                                : null,
                          ),
                          alignment: Alignment.bottomCenter,
                          child: mins > 0
                              ? AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  width: 28,
                                  height: fillHeight,
                                  decoration: BoxDecoration(
                                    gradient: isToday
                                        ? const LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [Color(0xFFFF6B35), Color(0xFFFF8F65)],
                                          )
                                        : (isGoalMet
                                            ? const LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                                              )
                                            : const LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                                              )),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: isToday
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                )
                              : Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),

                        // Nhãn thứ tiếng Việt
                        Text(
                          isToday ? "Nay" : vnDay,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                            color: isToday ? const Color(0xFFFF6B35) : const Color(0xFF475569),
                          ),
                        ),
                        // Nhãn ngày ngắn (VD: 15/10)
                        if (shortDate.isNotEmpty)
                          Text(
                            shortDate,
                            style: GoogleFonts.nunito(
                              fontSize: 9,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isToday ? const Color(0xFFFF6B35) : Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLobbyPeriodBtn(String title, String val) {
    final isSelected = _lobbyPeriod == val;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _lobbyPeriod = val);
          _fetchLobbyStats();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F65)])
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRoomCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text("Tạo Phòng Thi Đua Mới", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _roomNameController,
            decoration: InputDecoration(
              labelText: "Tên phòng thi đua (Ví dụ: Thi hết môn, Cày 100 giờ)",
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _durationDays,
            decoration: InputDecoration(
              labelText: "Thời gian diễn ra thi đua",
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 7, child: Text("1 Tuần (7 ngày)")),
              DropdownMenuItem(value: 30, child: Text("1 Tháng (30 ngày)")),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _durationDays = val);
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: isLoading ? null : _createRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text("Tạo Phòng Mới", style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoomCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.login_rounded, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              Text("Tham Gia Bằng Mã Phòng", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _joinCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "Nhập mã 6 ký tự (VD: A3F82C)",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: isLoading ? null : _joinRoomBtn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Vào Phòng", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MÀN HÌNH TRONG PHÒNG THI ĐUA (ARENA: TAB BXH + TAB CHAT CỘNG ĐỒNG)
  // ============================================================
  Widget _buildArena() {
    return Column(
      children: [
        // Header thông tin phòng
        Container(
          padding: const EdgeInsets.all(16),
          color: isExpired ? Colors.grey.shade400 : const Color(0xFFFFD54F),
          width: double.infinity,
          child: Column(
            children: [
              if (groupName != null)
                Text(groupName!, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
              Text("Mã phòng: $currentRoomCode", style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(
                isExpired ? "⛔ Phòng đã kết thúc thi đua" : "Thời hạn: ${durationDays ?? 7} ngày • Mời bạn bè nhập mã để cùng thi đua",
                style: GoogleFonts.nunito(fontSize: 12, color: isExpired ? Colors.red.shade900 : Colors.black54),
              ),
              const SizedBox(height: 10),
              if (!isExpired)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (currentRoomCode != null) {
                          _fetchLeaderboard(currentRoomCode!);
                          _fetchRoomMessages(currentRoomCode!);
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text("Làm mới"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _submitFakeSession,
                      icon: const Icon(Icons.add_task_rounded, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      label: const Text("Test Nộp Điểm"),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Navigation Tabs: Bảng Xếp Hạng vs Kênh Trao Đổi
        Container(
          color: Colors.white,
          child: Row(
            children: [
              _buildArenaNavTab("🏆 Bảng Xếp Hạng", 0),
              _buildArenaNavTab("💬 Kênh Trao Đổi", 1, unreadCount: _unreadRoomMsgCount),
            ],
          ),
        ),
        const Divider(height: 1),

        // Nội dung Tab
        Expanded(
          child: _arenaTabIndex == 0 ? _buildLeaderboardTab() : _buildRoomChatTab(),
        ),

        // Nút quay lại sảnh
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    currentRoomCode = null;
                    leaderboard = [];
                    _roomMessages = [];
                    _lastReadMsgCount = 0;
                    _selectedPeriod = "all";
                  });
                  _fetchLobbyStats();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text("Quay lại sảnh chờ"),
              ),
              Text(
                "Bạn: ${_userIdController.text}",
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArenaNavTab(String title, int idx, {int unreadCount = 0}) {
    final isSelected = _arenaTabIndex == idx;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _arenaTabIndex = idx);
          if (idx == 1 && currentRoomCode != null) {
            _markRoomChatAsRead();
            _fetchRoomMessages(currentRoomCode!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSelected ? Colors.amber.shade700 : Colors.transparent, width: 3)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? Colors.black87 : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$unreadCount",
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: BẢNG XẾP HẠNG & KẾT BẠN ---
  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        // Filter Hôm nay / Tuần này / Tháng này / Tất cả
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              _buildPeriodChip("Hôm nay", "today"),
              const SizedBox(width: 8),
              _buildPeriodChip("Tuần này", "week"),
              const SizedBox(width: 8),
              _buildPeriodChip("Tháng này", "month"),
              const SizedBox(width: 8),
              _buildPeriodChip("Tất cả", "all"),
            ],
          ),
        ),
        const Divider(height: 1),

        // Danh sách đối thủ
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : leaderboard.isEmpty
                  ? Center(
                      child: Text(
                        "Chưa có dữ liệu thi đua trong phòng",
                        style: GoogleFonts.nunito(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: leaderboard.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final lb = leaderboard[index];
                        final memberId = lb['user_id'];
                        final isMe = memberId == _userIdController.text.trim();
                        final isFriend = _friendsList.contains(memberId);
                        final isTop1 = index == 0;
                        final isTop3 = index < 3;

                        return Card(
                          elevation: isTop1 ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: isTop1 ? Colors.amber.shade100 : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isTop1
                                      ? Colors.amber
                                      : index == 1
                                          ? Colors.grey.shade400
                                          : index == 2
                                              ? Colors.brown.shade300
                                              : Colors.grey.shade200,
                                  child: Text(
                                    isTop3 ? ["🥇", "🥈", "🥉"][index] : "#${lb['rank']}",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTop3 ? 20 : 14),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            memberId,
                                            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          if (isMe)
                                            Container(
                                              margin: const EdgeInsets.only(left: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(6)),
                                              child: const Text("Bạn", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          if (isFriend && !isMe)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(Icons.handshake_rounded, size: 16, color: Colors.green),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "⏱ ${lb['work_min']} phút • 🍅 ${lb['completed']} phiên",
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${lb['score']} đ",
                                      style: GoogleFonts.sourceCodePro(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.blueAccent),
                                    ),
                                    const SizedBox(height: 4),
                                    if (!isMe)
                                      if (isFriend)
                                        InkWell(
                                          onTap: () => _openDirectChat(memberId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.chat, size: 12, color: Colors.green),
                                                SizedBox(width: 4),
                                                Text("Chat", style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        )
                                      else
                                        InkWell(
                                          onTap: () => _addFriend(memberId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade600)),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.person_add_alt_1, size: 12, color: Colors.orange),
                                                SizedBox(width: 4),
                                                Text("Kết bạn", style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- TAB 2: CỘNG ĐỒNG CHAT TRONG PHÒNG ---
  Widget _buildRoomChatTab() {
    return Column(
      children: [
        // Danh sách tin nhắn
        Expanded(
          child: _loadingRoomMsgs && _roomMessages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _roomMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text("Chưa có tin nhắn nào trong phòng.", style: GoogleFonts.nunito(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text("Hãy gửi lời chúc và chia sẻ mục tiêu học tập nhé!", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _roomMessages.length,
                      itemBuilder: (ctx, idx) {
                        final m = _roomMessages[idx];
                        final isSys = m["msg_type"] == "system";
                        final isMe = m["sender_id"] == _userIdController.text.trim();

                        if (isSys) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Text(
                                m["message"],
                                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.brown.shade800),
                              ),
                            ),
                          );
                        }

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFFFFD54F) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(
                                    m["sender_id"],
                                    style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueAccent),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  m["message"],
                                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m["time"] ?? "",
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // Thanh nhập tin nhắn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomMsgController,
                  decoration: InputDecoration(
                    hintText: "Gửi tin nhắn trao đổi trong phòng...",
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendRoomMsg(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFFFFD54F),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.black87, size: 18),
                  onPressed: _sendRoomMsg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = value);
        if (currentRoomCode != null) _fetchLeaderboard(currentRoomCode!);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.amber.shade700 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MODAL CHAT RIÊNG 1-1 VỚI BẠN BÈ
// ============================================================
class _DirectChatModal extends StatefulWidget {
  final String myUserId;
  final String friendId;

  const _DirectChatModal({required this.myUserId, required this.friendId});

  @override
  State<_DirectChatModal> createState() => _DirectChatModalState();
}

class _DirectChatModalState extends State<_DirectChatModal> {
  List<dynamic> _messages = [];
  bool _loading = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchDMs();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDMs() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$API_BASE/friends/messages?user_id=${widget.myUserId}&friend_id=${widget.friendId}')
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _messages = data["messages"] ?? []);
        _scrollToBottom();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _sendDM() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/friends/messages'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sender_id": widget.myUserId,
          "receiver_id": widget.friendId,
          "message": text
        }),
      );
      if (res.statusCode == 200) {
        await _fetchDMs();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Thanh gạt modal
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.amber.shade200,
                    child: Text(widget.friendId.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.friendId, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
                        const Text("🤝 Bạn bè thi đua • Chat trực tiếp", style: TextStyle(fontSize: 12, color: Colors.green)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.grey, size: 20),
                    tooltip: "Tải lại tin nhắn",
                    onPressed: _fetchDMs,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: _loading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                        child: Text(
                          "Chưa có tin nhắn nào.\nHãy gửi lời chào để cùng nhau thi đua nhé!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, idx) {
                          final m = _messages[idx];
                          final isMe = m["sender_id"] == widget.myUserId;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blueAccent : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m["message"],
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: isMe ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m["time"] ?? "",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Nhắn tin cho ${widget.friendId}...",
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendDM(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendDM,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
// ==========================================
// THI_DUA_FEATURE_END
// ==========================================
