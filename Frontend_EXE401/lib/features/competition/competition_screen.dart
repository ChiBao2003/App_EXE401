// ==========================================
// THI_DUA_FEATURE_START (Aether Synapse — Stitch Screen 7)
// ==========================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
<<<<<<< HEAD
import '../../core/constants/app_constants.dart';
import '../../core/api/auth_api.dart';
=======
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/auth_api.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'competition_chat_screen.dart';
import 'competition_direct_chat_screen.dart';
>>>>>>> thang

String get competitionApiBase => '${AppConstants.baseUrl}/api/v1/competition';

/// Screen 7 — Productivity Arena & Leaderboard (Đấu Trường Năng Suất)
/// Stitch Project ID: 10749545399411306725
/// Stitch Screen ID: bbfd3e32ff4542bf9c67d38affbf7ce5
/// Design System: Aether Synapse
class CompetitionScreen extends StatefulWidget {
  final String? initialRoomCode;
  final List<dynamic>? initialLeaderboard;
  final String? initialGroupName;
  final int? initialDurationDays;
  final bool? initialExpired;
  final String? initialUserId;
  final http.Client? httpClient;

  const CompetitionScreen({
    super.key,
    this.initialRoomCode,
    this.initialLeaderboard,
    this.initialGroupName,
    this.initialDurationDays,
    this.initialExpired,
    this.initialUserId,
    this.httpClient,
  });

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

<<<<<<< HEAD
class _CompetitionScreenState extends State<CompetitionScreen> {
  // State phòng thi đua
=======
class _CompetitionScreenState extends State<CompetitionScreen>
    with SingleTickerProviderStateMixin {
>>>>>>> thang
  String? currentRoomCode;
  String? groupName;
  int? durationDays;
  bool isExpired = false;
  List<dynamic> leaderboard = [];
  bool isLoading = false;
<<<<<<< HEAD
  String _selectedPeriod = "all"; // today | week | month | all
  int _arenaTabIndex = 0; // 0: BXH, 1: Kênh Trao Đổi

  // Thống kê ngoài Sảnh (1 Ngày / 1 Tuần / 1 Tháng)
  String _lobbyPeriod = "today"; // today | week | month
  Map<String, dynamic>? _userSummary;
  List<dynamic> _globalTopUsers = [];
  bool _loadingLobbyStats = false;

  // Danh sách Bạn Bè, Lời mời & Tin nhắn
  List<String> _friendsList = [];
  List<String> _sentRequests = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  int _incomingCount = 0;
  int _unreadDmsCount = 0;
  Map<String, int> _unreadBySender = {};
  int get _totalFriendNotifications => _incomingCount + _unreadDmsCount;
  Timer? _friendsPollingTimer;

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
=======
  String? errorMessage;
  String _selectedPeriod = 'all'; // 'today' | 'week' | 'month' | 'all'
>>>>>>> thang

  // Controllers
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
<<<<<<< HEAD
  final TextEditingController _roomMsgController = TextEditingController();
  final TextEditingController _dmController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
=======
>>>>>>> thang
  int _durationDays = 7;
  bool _loadingUser = true;
  String? _currentAuthUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _friendsPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchFriendsAndNotifications();
    });
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _loadingUser = true);
    try {
      final name = await AuthApi.getUserName();
      final id = await AuthApi.getUserId();
      _currentAuthUserId = id;
      String resolvedUser = "";
      if (name != "Ban" && name.trim().isNotEmpty) {
        resolvedUser = name.trim();
      } else if (id != null && id.trim().isNotEmpty) {
        resolvedUser = id.trim();
      } else {
        resolvedUser = "user_bao";
      }
      if (mounted) {
        setState(() {
          _userIdController.text = resolvedUser;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userIdController.text = "user_bao";
        });
      }
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
    await _fetchLobbyStats();
    await _fetchFriendsAndNotifications();
  }

  // Animations & UI state
  bool _copiedRecently = false;
  String _currentUserId = '';
  late http.Client _client;
  Timer? _leaderboardTimer;
  Timer? _socialTimer;
  Map<String, dynamic> _social = {};
  Map<String, dynamic> _unread = {};
  Map<String, dynamic> _summary = {};
  String _summaryPeriod = 'today';
  bool _socialLoading = false;
  int _roomUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.httpClient ?? http.Client();
    _leaderboardTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || currentRoomCode == null || isLoading) return;
      if (ModalRoute.of(context)?.isCurrent == true) {
        _fetchLeaderboard(currentRoomCode!);
      }
    });
    _socialTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted &&
          _currentUserId.isNotEmpty &&
          ModalRoute.of(context)?.isCurrent == true) {
        _loadSocial();
        _loadRoomUnread();
      }
    });

    if (widget.initialUserId != null) {
      _userIdController.text = widget.initialUserId!;
      _currentUserId = widget.initialUserId!;
    }

    if (widget.initialRoomCode != null) {
      currentRoomCode = widget.initialRoomCode;
      leaderboard = widget.initialLeaderboard ?? [];
      groupName = widget.initialGroupName;
      durationDays = widget.initialDurationDays ?? 7;
      isExpired = widget.initialExpired ?? false;
      if (widget.initialLeaderboard == null) {
        _fetchLeaderboard(currentRoomCode!);
      }
    } else {
      _loadSavedState();
    }
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final userId = await AuthApi.getUserId();
      final userName = await AuthApi.getUserName();
      if (!mounted) return;
      if (userId != null && userId.isNotEmpty) {
        setState(() {
          _currentUserId = userId;
          _userIdController.text = userName;
        });
        _loadSocial();
        _loadSummary();
      }

      final savedRoom = prefs.getString('last_competition_room_$userId');
      if (savedRoom != null && savedRoom.isNotEmpty) {
        setState(() {
          currentRoomCode = savedRoom;
        });
        _fetchLeaderboard(savedRoom);
        _loadRoomUnread();
      }
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _currentUserId;
      if (currentRoomCode != null) {
        await prefs.setString(
          'last_competition_room_$userId',
          currentRoomCode!,
        );
      } else {
        await prefs.remove('last_competition_room_$userId');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _friendsPollingTimer?.cancel();
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

      // 3. Danh sách bạn bè & thông báo
      await _fetchFriendsAndNotifications();
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
=======
    _leaderboardTimer?.cancel();
    _socialTimer?.cancel();
    _roomNameController.dispose();
    _joinCodeController.dispose();
    _userIdController.dispose();
    if (widget.httpClient == null) {
      _client.close();
    }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // API CALLS (Giữ nguyên backend API contract)
  // ══════════════════════════════════════════════════════════

  Future<Map<String, String>> _headers() async {
    final headers = {'Content-Type': 'application/json'};
    if (widget.httpClient != null) {
      return headers;
    }
    try {
      final token = await ApiClient.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Future<Map<String, dynamic>> _socialGet(String path) async {
    final response = await _client
        .get(Uri.parse('$competitionApiBase$path'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _socialPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$competitionApiBase$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
        detail is Map
            ? detail['detail'] ?? 'HTTP ${response.statusCode}'
            : 'HTTP ${response.statusCode}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> _loadSocial() async {
    if (_currentUserId.isEmpty || _socialLoading) return;
    _socialLoading = true;
>>>>>>> thang
    try {
      final status = await _socialGet('/friends/unread-status');
      final friends = await _socialGet('/friends/$_currentUserId');
      if (mounted) {
        setState(() {
<<<<<<< HEAD
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
=======
          _unread = status;
          _social = friends;
        });
      }
    } catch (_) {
    } finally {
      _socialLoading = false;
>>>>>>> thang
    }
  }

<<<<<<< HEAD
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
  // 4. KẾT BẠN & CHAT RIÊNG (1-1) (HƯỚNG 1: DUYỆT LỜI MỜI & THÔNG BÁO)
  // ============================================================
  Future<void> _fetchFriendsAndNotifications() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) return;
    try {
      // 1. Lấy trạng thái thông báo chưa đọc
      final resUnread = await http.get(Uri.parse('$API_BASE/friends/unread-status?user_id=$userId'));
      if (resUnread.statusCode == 200) {
        final data = jsonDecode(resUnread.body);
        if (mounted) {
          setState(() {
            _incomingCount = (data["incoming_count"] as num?)?.toInt() ?? 0;
            _unreadDmsCount = (data["unread_dms_count"] as num?)?.toInt() ?? 0;
            final map = data["unread_by_sender"] as Map<String, dynamic>? ?? {};
            _unreadBySender = map.map((k, v) => MapEntry(k, (v as num).toInt()));
          });
        }
      }

      // 2. Lấy danh sách bạn bè & danh sách lời mời
      final resFriends = await http.get(Uri.parse('$API_BASE/friends/$userId'));
      if (resFriends.statusCode == 200) {
        final data = jsonDecode(resFriends.body);
        if (mounted) {
          setState(() {
            _friendsList = List<String>.from(data["friends"] ?? []);
            _sentRequests = List<String>.from(data["sent_requests"] ?? []);
            _incomingRequests = List<Map<String, dynamic>>.from(data["incoming_requests"] ?? []);
          });
        }
      }
    } catch (_) {}
  }

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
        final data = jsonDecode(res.body);
        _showSuccess(data["message"] ?? "Đã gửi lời mời kết bạn! 🤝");
        await _fetchFriendsAndNotifications();
      } else {
        final data = jsonDecode(res.body);
        _showError(data["detail"] ?? "Lỗi gửi lời mời kết bạn");
      }
    } catch (_) {
      _showError("Lỗi gửi lời mời kết bạn");
    }
  }

  Future<void> _respondFriend(String requesterId, String action) async {
    final myId = _userIdController.text.trim();
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/friends/respond'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": myId,
          "requester_id": requesterId,
          "action": action,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _showSuccess(data["message"] ?? (action == "accept" ? "Đã đồng ý kết bạn! 🤝" : "Đã từ chối lời mời."));
        await _fetchFriendsAndNotifications();
      } else {
        final data = jsonDecode(res.body);
        _showError(data["detail"] ?? "Thao tác thất bại");
      }
    } catch (_) {
      _showError("Lỗi kết nối máy chủ");
    }
  }

  void _openDirectChat(String friendId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DirectChatModal(
        myUserId: _userIdController.text.trim(),
        friendId: friendId,
      ),
    );
    await _fetchFriendsAndNotifications();
  }

  void _showFriendsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return DefaultTabController(
            length: 2,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text("Quản Lý Bạn Bè", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
                        tooltip: "Làm mới",
                        onPressed: () async {
                          await _fetchFriendsAndNotifications();
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blueAccent,
                    labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Lời mời"),
                            if (_incomingRequests.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                                child: Text("${_incomingRequests.length}", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Bạn bè (${_friendsList.length})"),
                            if (_unreadDmsCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                                child: Text("$_unreadDmsCount", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                height: 340,
                child: TabBarView(
                  children: [
                    // TAB 1: LỜI MỜI KẾT BẠN
                    _incomingRequests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text("Không có lời mời kết bạn nào", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                const SizedBox(height: 4),
                                Text("Khi có người gửi lời mời, bạn sẽ thấy ở đây.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 8),
                            itemCount: _incomingRequests.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final req = _incomingRequests[idx];
                              final reqId = (req['requester_id'] ?? "").toString();
                              final time = (req['time'] ?? "").toString();
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.shade100,
                                  child: Text(
                                    reqId.isNotEmpty ? reqId[0].toUpperCase() : "?",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                ),
                                title: Text(reqId, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                subtitle: Text(time.isNotEmpty ? "Lúc $time" : "Muốn kết bạn thi đua", style: const TextStyle(fontSize: 11)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () async {
                                        await _respondFriend(reqId, "accept");
                                        setDialogState(() {});
                                      },
                                      child: const Text("Đồng ý", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        minimumSize: Size.zero,
                                        side: BorderSide(color: Colors.red.shade200),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () async {
                                        await _respondFriend(reqId, "decline");
                                        setDialogState(() {});
                                      },
                                      child: const Text("Từ chối", style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                    // TAB 2: DANH SÁCH BẠN BÈ
                    _friendsList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text("Chưa có bạn bè nào", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Hãy vào phòng thi đua và nhấn nút [+ Kết bạn] bên cạnh đối thủ để cùng kết nối nhé!",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 8),
                            itemCount: _friendsList.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final f = _friendsList[idx];
                              final unreadCount = _unreadBySender[f] ?? 0;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.amber.shade200,
                                  child: Text(
                                    f.isNotEmpty ? f[0].toUpperCase() : "?",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(f, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                                    if (unreadCount > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                                        child: Text("$unreadCount mới", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: const Text("🤝 Bạn cùng thi đua", style: TextStyle(fontSize: 12)),
                                trailing: IconButton(
                                  icon: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.chat_bubble_rounded, color: Colors.blueAccent),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                          ),
                                        ),
                                    ],
                                  ),
                                  tooltip: "Nhắn tin riêng",
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openDirectChat(f);
                                  },
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  void _showChangeNicknameDialog() {
    final oldName = _userIdController.text.trim();
    final newNameController = TextEditingController(text: oldName);
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Icon(Icons.badge_rounded, color: Color(0xFFEA580C), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Đổi Biệt Danh Thi Đua",
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                      Text(
                        "Cập nhật tên hiển thị trong phòng & bạn bè",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 18, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(
                        "Tên hiện tại: ",
                        style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      Text(
                        oldName,
                        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Biệt danh mới của bạn:",
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: newNameController,
                  autofocus: true,
                  maxLength: 25,
                  decoration: InputDecoration(
                    hintText: "VD: ChiBao_Pro, Baobao_99...",
                    prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                    errorText: errorMessage,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA000), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Toàn bộ điểm tích lũy, phòng thi đua và danh sách bạn bè sẽ được chuyển giao đầy đủ sang tên mới.",
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade800, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text("Hủy", style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: isSubmitting ? null : () async {
                  final newName = newNameController.text.trim();
                  if (newName.isEmpty) {
                    setDialogState(() => errorMessage = "Vui lòng nhập biệt danh mới");
                    return;
                  }
                  if (newName.length < 2) {
                    setDialogState(() => errorMessage = "Biệt danh phải có tối thiểu 2 ký tự");
                    return;
                  }
                  if (newName == oldName) {
                    setDialogState(() => errorMessage = "Biệt danh mới phải khác biệt danh hiện tại");
                    return;
                  }

                  setDialogState(() {
                    isSubmitting = true;
                    errorMessage = null;
                  });

                  try {
                    final res = await http.post(
                      Uri.parse('$API_BASE/nickname/update'),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode({
                        "old_nickname": oldName,
                        "new_nickname": newName,
                        "user_id": _currentAuthUserId,
                      }),
                    );

                    if (res.statusCode == 200) {
                      await AuthApi.updateUserName(newName);
                      if (mounted) {
                        setState(() {
                          _userIdController.text = newName;
                        });
                      }
                      Navigator.pop(ctx);
                      _showSuccess("Đổi biệt danh sang '$newName' thành công! 🎉");
                      await _fetchLobbyStats();
                      await _fetchFriendsAndNotifications();
                      if (currentRoomCode != null) {
                        await _fetchLeaderboard(currentRoomCode!);
                      }
                    } else {
                      final data = jsonDecode(res.body);
                      setDialogState(() {
                        isSubmitting = false;
                        errorMessage = data["detail"] ?? "Đổi biệt danh thất bại";
                      });
                    }
                  } catch (e) {
                    setDialogState(() {
                      isSubmitting = false;
                      errorMessage = "Lỗi kết nối máy chủ";
                    });
                  }
                },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Xác nhận đổi", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
=======
  Future<void> _loadSummary() async {
    try {
      final data = await _socialGet('/stats/summary?period=$_summaryPeriod');
      if (mounted) setState(() => _summary = data);
    } catch (_) {}
  }

  Future<void> _loadRoomUnread() async {
    final code = currentRoomCode;
    if (code == null || _currentUserId.isEmpty) return;
    try {
      final data = await _socialGet('/groups/$code/unread-status');
      if (mounted && currentRoomCode == code) {
        setState(
          () => _roomUnreadCount = (data['unread_count'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
  }

  Future<void> _changeNickname() async {
    var candidate = _userIdController.text;
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi Biệt Danh Thi Đua'),
        content: TextFormField(
          initialValue: candidate,
          onChanged: (value) => candidate = value,
          maxLength: 25,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Biệt danh mới (2-25 ký tự)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, candidate.trim()),
            child: const Text('Lưu'),
          ),
        ],
>>>>>>> thang
      ),
    );
    if (newName == null) return;
    if (newName.length < 2 ||
        newName.length > 25 ||
        newName == _userIdController.text) {
      _showToast('Tên mới phải khác tên cũ và dài 2-25 ký tự', isError: true);
      return;
    }
    try {
      final result = await _socialPost('/nickname/update', {
        'nickname': newName,
      });
      final displayName = result['display_name'] as String;
      await AuthApi.updateUserName(displayName);
      if (mounted) setState(() => _userIdController.text = displayName);
      await _loadSocial();
      await _loadSummary();
      if (currentRoomCode != null) await _fetchLeaderboard(currentRoomCode!);
      _showToast('Đã đổi biệt danh');
    } catch (error) {
      _showToast('Không đổi được tên: $error', isError: true);
    }
  }

<<<<<<< HEAD
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
                if (_totalFriendNotifications > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$_totalFriendNotifications",
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: "Bạn bè & Lời mời ($_totalFriendNotifications)",
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

          // Thông tin tài khoản thi đua (Khóa cố định theo phiên đăng nhập)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Center(
                    child: Text(
                      _userIdController.text.isNotEmpty ? _userIdController.text[0].toUpperCase() : "U",
                      style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Tài khoản của bạn",
                            style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 11, color: Colors.green),
                                SizedBox(width: 3),
                                Text(
                                  "Đã xác thực",
                                  style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _loadingUser
                          ? const SizedBox(
                              height: 18,
                              width: 100,
                              child: LinearProgressIndicator(minHeight: 2),
                            )
                          : Text(
                              _userIdController.text,
                              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                            ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 12, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "Bảo mật tài khoản • Nhấn [Đổi tên] để cập nhật biệt danh",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text("Đổi tên", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7ED),
                    foregroundColor: const Color(0xFFEA580C),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFFED7AA)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showChangeNicknameDialog,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.grey, size: 20),
                  tooltip: "Tải lại dữ liệu",
                  onPressed: () {
                    _fetchLobbyStats();
                    _fetchFriendsAndNotifications();
                  },
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
=======
  Future<void> _friendAction(String path, Map<String, dynamic> body) async {
    try {
      await _socialPost(path, body);
      await _loadSocial();
      _showToast('Đã cập nhật bạn bè');
    } catch (error) {
      _showToast('Lỗi: $error', isError: true);
    }
  }

  void _openDirectChat(String friendId, String friendName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: CompetitionDirectChatScreen(
          friendId: friendId,
          friendName: friendName,
          currentUserId: _currentUserId,
          httpClient: widget.httpClient,
        ),
      ),
    ).then((_) => _loadSocial());
  }

  void _showFriendsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          title: const Text('Quản lý Bạn bè'),
          content: SizedBox(
            width: 420,
            height: 380,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Lời mời'),
                    Tab(text: 'Bạn bè'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        children: [
                          for (final person
                              in (_social['incoming_requests'] as List? ?? []))
                            ListTile(
                              title: Text(person['display_name'].toString()),
                              subtitle: const Text('Đã mời bạn'),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Đồng ý',
                                    icon: const Icon(Icons.check),
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      _friendAction('/friends/respond', {
                                        'requester_id': person['user_id'],
                                        'action': 'accept',
                                      });
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Từ chối',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      _friendAction('/friends/respond', {
                                        'requester_id': person['user_id'],
                                        'action': 'decline',
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          for (final person
                              in (_social['sent_requests'] as List? ?? []))
                            ListTile(
                              title: Text(person['display_name'].toString()),
                              subtitle: const Text('Đã gửi lời mời'),
                            ),
                        ],
                      ),
                      ListView(
                        children: [
                          for (final person
                              in (_social['friends'] as List? ?? []))
                            ListTile(
                              title: Text(person['display_name'].toString()),
                              subtitle: Text(
                                '${(_unread['unread_by_sender'] as Map?)?[person['user_id']] ?? 0} tin mới',
                              ),
                              trailing: const Icon(Icons.chat_bubble_outline),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                _openDirectChat(
                                  person['user_id'].toString(),
                                  person['display_name'].toString(),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  /// Tạo phòng mới
  Future<void> _createRoom() async {
    final name = _roomNameController.text.trim();
    if (name.isEmpty) {
      _showToast('Vui lòng nhập tên phòng thi đua', isError: true);
      return;
    }
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final res = await _client.post(
        Uri.parse('$competitionApiBase/groups'),
        headers: await _headers(),
        body: jsonEncode({'name': name, 'duration_days': _durationDays}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final code = data['room_code'] as String;
        setState(() {
          currentRoomCode = code;
          _roomUnreadCount = 0;
          groupName = name;
          durationDays = _durationDays;
          isExpired = false;
        });
        await _saveState();
        await _joinRoomSilent(code);
        _showToast('Đã tạo phòng! Mã: $code');
      } else {
        _showToast('Không thể tạo phòng (${res.statusCode})', isError: true);
      }
    } catch (e) {
      setState(() => errorMessage = 'Lỗi kết nối máy chủ');
      _showToast('Lỗi kết nối máy chủ', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Tự động join khi tạo phòng
  Future<void> _joinRoomSilent(String code) async {
    try {
      await _client.post(
        Uri.parse('$competitionApiBase/groups/join'),
        headers: await _headers(),
        body: jsonEncode({'room_code': code}),
      );
      await _fetchLeaderboard(code);
      await _loadRoomUnread();
    } catch (_) {}
  }

  /// Tham gia phòng qua nút "Vào phòng"
  Future<void> _joinRoomBtn([String? explicitCode]) async {
    final code = (explicitCode ?? _joinCodeController.text)
        .trim()
        .toUpperCase();
    if (code.isEmpty) {
      _showToast('Vui lòng nhập mã phòng 6 ký tự', isError: true);
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final res = await _client.post(
        Uri.parse('$competitionApiBase/groups/join'),
        headers: await _headers(),
        body: jsonEncode({'room_code': code}),
      );

      if (res.statusCode == 200) {
        setState(() {
          currentRoomCode = code;
          _roomUnreadCount = 0;
        });
        await _saveState();
        await _fetchLeaderboard(code);
        await _loadRoomUnread();
        _showToast('Vào phòng $code thành công!');
      } else {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final detail = data['detail'] ?? 'Phòng không tồn tại hoặc đã đầy';
        setState(() => errorMessage = detail.toString());
        _showToast(detail.toString(), isError: true);
      }
    } catch (e) {
      setState(() => errorMessage = 'Lỗi kết nối tới máy chủ');
      _showToast('Lỗi kết nối tới máy chủ', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Tải Bảng Xếp Hạng với Period Filter
  Future<void> _fetchLeaderboard(String code, {String? period}) async {
    final activePeriod = period ?? _selectedPeriod;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final res = await _client.get(
        Uri.parse('$competitionApiBase/leaderboard/$code?period=$activePeriod'),
        headers: await _headers(),
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          leaderboard = data['leaderboard'] ?? [];
          groupName = data['group_name'];
          durationDays = data['duration_days'];
          isExpired = data['expired'] ?? false;
          _selectedPeriod = activePeriod;
        });
      } else {
        setState(() => errorMessage = 'Không thể tải bảng xếp hạng');
      }
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'Lỗi kết nối khi tải BXH');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Nộp phiên Pomodoro thật / test vào phòng
  Future<void> _submitSession({
    int workMin = 25,
    bool completed = true,
    int pauses = 0,
  }) async {
    setState(() => isLoading = true);
    try {
      final res = await _client.post(
        Uri.parse('$competitionApiBase/submit'),
        headers: await _headers(),
        body: jsonEncode({
          'work_min': workMin,
          'completed': completed,
          'pauses': pauses,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        _showToast(data['message'] ?? 'Đã cộng điểm phiên tập trung!');
        if (currentRoomCode != null) {
          await _fetchLeaderboard(currentRoomCode!);
        }
        await _loadSummary();
      } else {
        _showToast('Lỗi gửi kết quả phiên', isError: true);
      }
    } catch (e) {
      _showToast('Lỗi kết nối khi gửi điểm', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  // HELPER ACTIONS & TOAST
  // ══════════════════════════════════════════════════════════

  void _copyRoomCode() {
    if (currentRoomCode == null) return;
    Clipboard.setData(ClipboardData(text: currentRoomCode!));
    setState(() => _copiedRecently = true);
    _showToast('Đã sao chép mã phòng $currentRoomCode');
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _copiedRecently = false);
    });
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: isError ? AppColors.stitchError : AppColors.stitchTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.stitchOnSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.stitchSurfaceBright,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLeaveConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.stitchSurfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rời phòng thi đua?',
          style: GoogleFonts.outfit(
            color: AppColors.stitchOnSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn rời phòng "${groupName ?? currentRoomCode}"? Điểm số tích luỹ của bạn vẫn được lưu trong hệ thống.',
          style: GoogleFonts.inter(
            color: AppColors.stitchOnSurfaceVariant,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Ở lại',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stitchErrorContainer,
              foregroundColor: AppColors.stitchError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                currentRoomCode = null;
                leaderboard = [];
                groupName = null;
                isExpired = false;
                _selectedPeriod = 'all';
                _roomUnreadCount = 0;
              });
              _saveState();
              _showToast('Đã rời phòng thi đua');
            },
            child: const Text('Rời phòng'),
          ),
>>>>>>> thang
        ],
      ),
    );
  }

<<<<<<< HEAD
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
=======
  void _showSwitchRoomModal() {
    final switchPinCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.stitchSurfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stitchOutlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Đổi Phòng Hoặc Nhập PIN',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.stitchOnSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nhập mã PIN 6 ký tự để chuyển sang phòng thi đấu khác.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: switchPinCtrl,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.stitchSecondaryContainer,
              ),
              decoration: InputDecoration(
                hintText: 'VD: SYN-882',
                hintStyle: GoogleFonts.outfit(
                  color: AppColors.stitchOutline,
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: AppColors.stitchSurfaceLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.stitchSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stitchPrimaryContainer,
                foregroundColor: AppColors.stitchOnPrimaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                final code = switchPinCtrl.text.trim();
                if (code.isNotEmpty) {
                  Navigator.pop(ctx);
                  _joinRoomBtn(code);
                }
              },
              child: Text(
                'Chuyển Đến Phòng Này',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWorkDuration(dynamic minutes) {
    final m = (minutes is num)
        ? minutes.toInt()
        : int.tryParse('$minutes') ?? 0;
    if (m <= 0) return '0m';
    if (m < 60) return '${m}m';
    final hours = m ~/ 60;
    final mins = m % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  // ══════════════════════════════════════════════════════════
  // BUILD METHOD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    BleService? ble;
    try {
      ble = context.watch<BleService>();
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      floatingActionButton: currentRoomCode == null
          ? null
          : Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  key: const Key('btnRoomChat'),
                  tooltip: 'Chat phòng',
                  onPressed: _openRoomChat,
                  child: const Icon(Icons.chat_bubble_rounded),
                ),
                if (_roomUnreadCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      key: const Key('roomChatUnreadBadge'),
                      height: 20,
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _roomUnreadCount > 99 ? '99+' : '$_roomUnreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(ble),
            Expanded(
              child: currentRoomCode == null
                  ? _buildLobbyView()
                  : _buildArenaView(ble),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoomChat() {
    if (currentRoomCode == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => CompetitionChatScreen(
              roomCode: currentRoomCode!,
              currentUserId: _currentUserId,
              httpClient: widget.httpClient,
            ),
          ),
        )
        .then((_) => _loadRoomUnread());
  }

  // ══════════════════════════════════════════════════════════
  // TOP APP BAR (Stitch Screen 7 Header)
  // ══════════════════════════════════════════════════════════
  Widget _buildTopAppBar(BleService? ble) {
    final isBleOnline = ble?.isConnected ?? false;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.stitchSurface.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.stitchSurfaceLow, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Left: Back button & POMO SMART Logo
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.stitchOnSurface,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.stitchPrimaryContainer.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: AppColors.stitchPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'POMO SMART',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stitchOnSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.stitchPrimaryContainer
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AI',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stitchPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isBleOnline
                                  ? AppColors.stitchTertiary
                                  : AppColors.stitchOutline,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isBleOnline
                                  ? 'TFT LCD Sync 12ms'
                                  : 'Offline Mode',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Watch Battery Badge & User Profile
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    tooltip: 'Bạn bè',
                    onPressed: _showFriendsDialog,
                    icon: const Icon(Icons.group_rounded, size: 23),
                  ),
                  if ((_unread['total'] as num? ?? 0) > 0)
                    Positioned(
                      right: 2,
                      top: 0,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${_unread['total']}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (MediaQuery.sizeOf(context).width >= 460)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.watch_rounded,
                        size: 14,
                        color: isBleOnline
                            ? AppColors.stitchSecondaryContainer
                            : AppColors.stitchOutline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBleOnline ? '98%' : 'Chưa kết nối',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isBleOnline
                              ? AppColors.stitchSecondary
                              : AppColors.stitchOutline,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.stitchPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: Color(0xFF370096),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ARENA VIEW (Màn chính lúc đã vào phòng thi đua)
  // ══════════════════════════════════════════════════════════
  Widget _buildArenaView(BleService? ble) {
    final currentUserId = _currentUserId;
    final userIndex = leaderboard.indexWhere(
      (item) => item['user_id'] == currentUserId,
    );
    final myEntry = userIndex != -1 ? leaderboard[userIndex] : null;

    return RefreshIndicator(
      color: AppColors.stitchPrimaryContainer,
      backgroundColor: AppColors.stitchSurfaceContainer,
      onRefresh: () => _fetchLeaderboard(currentRoomCode!),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Room Header Banner (Bento Card)
            _buildRoomHeaderBanner(),
            const SizedBox(height: 10),
            // 2. Time Period Filter Chips
            _buildPeriodFilterChips(),
            const SizedBox(height: 14),

            // Loading / Error indicator if fetching
            if (isLoading && leaderboard.isEmpty)
              Container(
                height: 180,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  color: AppColors.stitchPrimaryContainer,
                ),
              )
            else if (errorMessage != null && leaderboard.isEmpty)
              _buildErrorCard()
            else ...[
              // 3. Top 3 Podium (Bục Vinh Quang)
              if (leaderboard.isNotEmpty)
                _buildTop3Podium()
              else
                _buildEmptyLeaderboardCard(),
              const SizedBox(height: 14),

              // 4. Your Position Card (Thẻ riêng Vị trí của bạn)
              _buildYourPositionCard(myEntry, userIndex),
              const SizedBox(height: 16),

              // 5. Detailed Ranking List (Đối thủ bám đuổi sát nút - Top 4+)
              if (leaderboard.length > 3) ...[
                _buildChasersSection(),
                const SizedBox(height: 16),
              ],

              _buildMemberActions(),
              const SizedBox(height: 16),

              // 6. Real-time Arena Telemetry Card & Actions
              _buildArenaTelemetryCard(ble),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 1. Room Header Banner
  // ──────────────────────────────────────────────────────────
  Widget _buildRoomHeaderBanner() {
    final daysRemaining = durationDays ?? 7;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Glow Top-Right
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top status row & switch button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.stitchSurfaceLowest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isExpired
                                    ? AppColors.stitchError
                                    : AppColors.stitchTertiary,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                isExpired
                                    ? 'ĐÃ KẾT THÚC'
                                    : 'ĐANG DIỄN RA • CÒN $daysRemaining NGÀY',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isExpired
                                      ? AppColors.stitchError
                                      : AppColors.stitchTertiary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      key: const Key('btnSwitchRoom'),
                      onTap: _showSwitchRoomModal,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.stitchSurfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 14,
                              color: AppColors.stitchPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Đổi / Nhập PIN',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Room Title & Subtitle
                Text(
                  groupName ?? 'Phòng Luyện Code ESP32 & AI 2025',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stitchOnSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Giải đấu năng suất • ${leaderboard.length} chiến binh tham gia',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Room Code Container & Participants stack
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceLowest.withValues(
                          alpha: 0.85,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MÃ PHÒNG',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.stitchOnSurfaceVariant,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                currentRoomCode ?? 'SYN-882',
                                key: const Key('roomCodeText'),
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.stitchSecondaryContainer,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            key: const Key('btnCopyCode'),
                            onTap: _copyRoomCode,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.stitchSurfaceHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _copiedRecently
                                    ? Icons.check_rounded
                                    : Icons.content_copy_rounded,
                                size: 16,
                                color: _copiedRecently
                                    ? AppColors.stitchTertiary
                                    : AppColors.stitchOnSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Avatar pile
                    Row(
                      children: [
                        for (int i = 0; i < 3 && i < leaderboard.length; i++)
                          Align(
                            widthFactor: 0.68,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.stitchSurfaceHighest,
                              child: Text(
                                ((leaderboard[i]['display_name'] ??
                                                leaderboard[i]['user_id'])
                                            as String? ??
                                        'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.stitchPrimary,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.stitchPrimaryContainer,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+${leaderboard.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchOnPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
>>>>>>> thang
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

<<<<<<< HEAD
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
=======
  // ──────────────────────────────────────────────────────────
  // 2. Time Period Filter Chips
  // ──────────────────────────────────────────────────────────
  Widget _buildPeriodFilterChips() {
    final periods = [
      {'label': 'Hôm nay', 'value': 'today'},
      {'label': 'Tuần này', 'value': 'week'},
      {'label': 'Tháng này', 'value': 'month'},
      {'label': 'Toàn thời gian', 'value': 'all'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                if (_selectedPeriod != p['value']) {
                  setState(() => _selectedPeriod = p['value']!);
                  if (currentRoomCode != null) {
                    _fetchLeaderboard(currentRoomCode!, period: p['value']);
                  }
                  _showToast('Đã cập nhật bảng xếp hạng: ${p['label']}');
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.stitchPrimaryContainer
                      : AppColors.stitchSurfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.stitchPrimaryContainer.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  p['label']!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? AppColors.stitchOnPrimaryContainer
                        : AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
>>>>>>> thang
      ),
    );
  }

<<<<<<< HEAD
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
                        final isIncomingReq = _incomingRequests.any((r) => r['requester_id'] == memberId);
                        final isSentReq = _sentRequests.contains(memberId);
                        final unreadDm = _unreadBySender[memberId] ?? 0;
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
                                            )
                                          else if (isIncomingReq && !isMe)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(Icons.mark_email_unread_rounded, size: 16, color: Colors.teal),
                                            )
                                          else if (isSentReq && !isMe)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.grey),
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
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.chat, size: 12, color: Colors.green),
                                                const SizedBox(width: 4),
                                                const Text("Chat", style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                                if (unreadDm > 0) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                                                    child: Text("$unreadDm", style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        )
                                      else if (isIncomingReq)
                                        InkWell(
                                          onTap: () => _respondFriend(memberId, "accept"),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.shade300)),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.teal),
                                                SizedBox(width: 4),
                                                Text("Chấp nhận", style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        )
                                      else if (isSentReq)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.hourglass_top_rounded, size: 12, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Text("Đã mời", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                            ],
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
=======
  // ──────────────────────────────────────────────────────────
  // 3. Top 3 Podium (Bục Vinh Quang)
  // ──────────────────────────────────────────────────────────
  Widget _buildTop3Podium() {
    final rank1 = leaderboard.isNotEmpty ? leaderboard[0] : null;
    final rank2 = leaderboard.length > 1 ? leaderboard[1] : null;
    final rank3 = leaderboard.length > 2 ? leaderboard[2] : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient light at the top
          Positioned(
            top: 0,
            left: 30,
            right: 30,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.stitchPrimaryContainer.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Rank 2: Silver (Left)
                Expanded(
                  child: _buildPodiumColumn(
                    rank: 2,
                    data: rank2,
                    podiumHeight: 68,
                    color: const Color(0xFFCBD5E1),
                    badgeBg: AppColors.stitchSurfaceBright,
                    icon: Icons.workspace_premium_rounded,
                    tierTag: 'Kim Cương',
                  ),
                ),
                const SizedBox(width: 8),

                // Rank 1: Gold (Center & Tallest)
                Expanded(
                  child: _buildPodiumColumn(
                    rank: 1,
                    data: rank1,
                    podiumHeight: 100,
                    color: const Color(0xFFFBBF24),
                    badgeBg: const Color(0xFFFBBF24),
                    icon: Icons.military_tech_rounded,
                    isGold: true,
                    tierTag: 'Master Focus',
                  ),
                ),
                const SizedBox(width: 8),

                // Rank 3: Bronze (Right)
                Expanded(
                  child: _buildPodiumColumn(
                    rank: 3,
                    data: rank3,
                    podiumHeight: 52,
                    color: const Color(0xFFD97706),
                    badgeBg: const Color(0xFFB45309),
                    icon: Icons.stars_rounded,
                    tierTag: 'Huy hiệu Vàng',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required int rank,
    required dynamic data,
    required double podiumHeight,
    required Color color,
    required Color badgeBg,
    required IconData icon,
    bool isGold = false,
    required String tierTag,
  }) {
    if (data == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.stitchSurfaceContainer,
            child: Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: AppColors.stitchOutline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chờ đối thủ',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.stitchOutline,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: podiumHeight,
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),
        ],
      );
    }

    final userId =
        (data['display_name'] ?? data['user_id']) as String? ?? 'N/A';
    final workMin = data['work_min'] ?? 0;
    final timeStr = _formatWorkDuration(workMin);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isGold)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFBBF24),
              size: 24,
            ),
          ),

        // Avatar with podium border
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isGold
                      ? [const Color(0xFFF59E0B), const Color(0xFFFEF08A)]
                      : [color, color.withValues(alpha: 0.5)],
                ),
                boxShadow: isGold
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: isGold ? 26 : 22,
                backgroundColor: AppColors.stitchSurfaceContainer,
                child: Text(
                  userId.isNotEmpty
                      ? userId.substring(0, 1).toUpperCase()
                      : '?',
                  style: GoogleFonts.outfit(
                    fontSize: isGold ? 18 : 15,
                    fontWeight: FontWeight.bold,
                    color: isGold ? const Color(0xFFFBBF24) : color,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isGold ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // User Name
        Text(
          userId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isGold ? FontWeight.bold : FontWeight.w600,
            color: AppColors.stitchOnSurface,
          ),
        ),

        // Focus time
        Text(
          timeStr,
          style: GoogleFonts.outfit(
            fontSize: isGold ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: isGold ? const Color(0xFFFBBF24) : AppColors.stitchSecondary,
>>>>>>> thang
          ),
        ),

        // Tier / Badge
        Container(
          margin: const EdgeInsets.only(top: 2, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: isGold
                ? const Color(0xFFFBBF24).withValues(alpha: 0.2)
                : AppColors.stitchSurfaceContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGold) ...[
                const Icon(
                  Icons.star_rounded,
                  size: 10,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  tierTag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isGold
                        ? const Color(0xFFFBBF24)
                        : AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Podium pedestal
        Container(
          width: double.infinity,
          height: podiumHeight,
          decoration: BoxDecoration(
            color: isGold
                ? AppColors.stitchSurfaceHigh
                : AppColors.stitchSurfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: isGold ? 26 : 20),
        ),
      ],
    );
  }

<<<<<<< HEAD
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
=======
  // ──────────────────────────────────────────────────────────
  // 4. Your Position Card (Thẻ Vị Trí Của Bạn)
  // ──────────────────────────────────────────────────────────
  Widget _buildYourPositionCard(dynamic myEntry, int userIndex) {
    final currentUserId = _userIdController.text.trim();
    final isRanked = myEntry != null;
    final rank = isRanked ? myEntry['rank'] : '--';
    final workMin = isRanked ? myEntry['work_min'] ?? 0 : 0;
    final score = isRanked ? myEntry['score'] ?? 0 : 0;
    final completed = isRanked ? myEntry['completed'] ?? 0 : 0;

    String gapText = '';
    if (isRanked && userIndex > 0) {
      final prevEntry = leaderboard[userIndex - 1];
      final diff = (prevEntry['work_min'] ?? 0) - workMin;
      gapText = '• Cách #$userIndex: ${_formatWorkDuration(diff)}';
    } else if (isRanked && userIndex == 0) {
      gapText = '• Đang dẫn đầu phòng thi đua! 🏆';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
>>>>>>> thang
          ),
        ],
        border: Border.all(
          color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Rank Box
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.stitchPrimaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.stitchPrimaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stitchOnPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Avatar with online status
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.stitchSurfaceHigh,
                      child: Text(
                        currentUserId.isNotEmpty
                            ? currentUserId.substring(0, 1).toUpperCase()
                            : 'B',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stitchPrimary,
                        ),
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.stitchTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),

                // Name & details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Bạn ($currentUserId)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.stitchTertiary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Watch Sync',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stitchTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '$completed phiên $gapText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Total focus time & PRS points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatWorkDuration(workMin),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stitchPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 12,
                    color: AppColors.stitchTertiary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '+$score pts',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 5. Detailed Ranking List (Đối thủ bám đuổi sát nút - Top 4+)
  // ──────────────────────────────────────────────────────────
  Widget _buildChasersSection() {
    final chasers = leaderboard.sublist(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'ĐỐI THỦ BÁM ĐUỔI SÁT NÚT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stitchOnSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Top 4 - ${leaderboard.length}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chasers.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final entry = chasers[i];
            final rank = entry['rank'] ?? (i + 4);
            final userId =
                (entry['display_name'] ?? entry['user_id']) as String? ?? 'N/A';
            final workMin = entry['work_min'] ?? 0;
            final completed = entry['completed'] ?? 0;

            // Gap to previous rank in leaderboard
            final prevEntry = leaderboard[i + 2];
            final diff = (prevEntry['work_min'] ?? 0) - workMin;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '#$rank',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.stitchSurfaceContainer,
                          child: Text(
                            userId.isNotEmpty
                                ? userId.substring(0, 1).toUpperCase()
                                : '?',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchOnSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.stitchOnSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.stitchSurfaceHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Bền bỉ',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        color: AppColors.stitchOnSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 12,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      '$completed phiên tập trung',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.stitchOnSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatWorkDuration(workMin),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                      Text(
                        diff > 0 ? '-${_formatWorkDuration(diff)}' : '0m',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.stitchOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // 6. Real-time Arena Telemetry Card & Quick Buttons
  // ──────────────────────────────────────────────────────────
  Widget _buildArenaTelemetryCard(BleService? ble) {
    final isBleOnline = ble?.isConnected ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header telemetry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.stitchSecondaryContainer.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: AppColors.stitchSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đồng bộ TFT LCD Watch',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchOnSurface,
                            ),
                          ),
                          Text(
                            isBleOnline
                                ? 'Đồng bộ điểm tự động qua Bluetooth LE'
                                : 'Đang kết nối ngoại tuyến với máy chủ',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBleOnline
                            ? AppColors.stitchTertiary
                            : AppColors.stitchOutline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBleOnline ? '12ms Live' : 'Offline',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isBleOnline
                            ? AppColors.stitchTertiary
                            : AppColors.stitchOutline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Button: Thêm phiên tập trung vào phòng ngay
          InkWell(
            key: const Key('btnAddSessionBtn'),
            onTap: () {
              Navigator.pushNamed(context, '/pomodoro');
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.stitchPrimaryContainer, Color(0xFF6833EA)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.stitchPrimaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    size: 18,
                    color: AppColors.stitchOnPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thêm phiên tập trung vào phòng ngay',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stitchOnPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary row: Leave Room & Quick Test Session
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('btnLeaveRoom'),
                  onTap: _showLeaveConfirmation,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.stitchErrorContainer.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          size: 15,
                          color: AppColors.stitchError,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Rời phòng thi đua',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.stitchError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  key: const Key('btnTestSession'),
                  onTap: () => _submitSession(workMin: 25, completed: true),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_task_rounded,
                          size: 15,
                          color: AppColors.stitchTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Test nộp điểm (+25m)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.stitchTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Empty & Error states for Arena
  // ──────────────────────────────────────────────────────────
  Widget _buildEmptyLeaderboardCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: AppColors.stitchOutline,
          ),
          const SizedBox(height: 12),
          Text(
            _selectedPeriod == 'all'
                ? 'Chưa có dữ liệu thi đua trong phòng này'
                : 'Chưa có dữ liệu cho khoảng thời gian này',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.stitchOnSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hãy hoàn thành một phiên Pomodoro để trở thành người dẫn đầu!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.stitchOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.stitchErrorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stitchError.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.stitchError,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Lỗi kết nối máy chủ',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.stitchError,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stitchSurfaceContainer,
              foregroundColor: AppColors.stitchOnSurface,
            ),
            onPressed: () {
              if (currentRoomCode != null) _fetchLeaderboard(currentRoomCode!);
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // LOBBY VIEW (Khi chưa vào phòng)
  // ══════════════════════════════════════════════════════════
  Widget _buildLobbyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          // Hero Icon & Title
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 40,
                color: Color(0xFFFBBF24),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Đấu Trường Năng Suất',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.stitchOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cùng bạn bè bứt phá giới hạn.\nNhận 1 điểm PRS cho mỗi phút tập trung!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.stitchOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // User Name Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TÊN HIỂN THỊ CỦA BẠN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stitchOnSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple, Colors.orangeAccent],
                        ),
                      ),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userIdController.text.isEmpty
                                ? 'Đang tải tài khoản'
                                : _userIdController.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            '✔ Đã xác thực',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _changeNickname,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Đổi tên'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '🛡️ Bảo mật tài khoản • Nhấn Đổi tên để cập nhật biệt danh',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(),
          const SizedBox(height: 16),

          // Bento Card 1: Nhập PIN phòng
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'THAM GIA PHÒNG THI ĐUA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stitchSecondaryContainer,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _joinCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppColors.stitchSecondaryContainer,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mã phòng (6 ký tự)',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                    hintText: 'SYN-882',
                    filled: true,
                    fillColor: AppColors.stitchSurfaceLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      Icons.key_rounded,
                      color: AppColors.stitchSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : () => _joinRoomBtn(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.stitchSecondaryContainer,
                    foregroundColor: const Color(0xFF00363D),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Vào Phòng Thi Đua',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bento Card 2: Tạo phòng mới
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'HOẶC TẠO PHÒNG MỚI',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stitchPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _roomNameController,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.stitchOnSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Tên phòng mới',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                    hintText: 'Ví dụ: Thi hết môn Bách Khoa',
                    filled: true,
                    fillColor: AppColors.stitchSurfaceLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      Icons.group_work_rounded,
                      color: AppColors.stitchPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _durationDays,
                  dropdownColor: AppColors.stitchSurfaceContainer,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.stitchOnSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Thời hạn thi đua',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: AppColors.stitchSurfaceLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('1 Tuần (7 ngày)')),
                    DropdownMenuItem(
                      value: 30,
                      child: Text('1 Tháng (30 ngày)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _durationDays = val);
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : _createRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.stitchPrimaryContainer,
                    foregroundColor: AppColors.stitchOnPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Tạo Phòng Mới Ngay',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final days = (_summary['last_7_days'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final percent = ((_summary['completion_percent'] as num?)?.toDouble() ?? 0)
        .clamp(0.0, 100.0);
    final top = (_summary['top_five'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tiến độ năng suất',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Làm mới',
                  onPressed: _loadSummary,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final p in ['today', 'week', 'month'])
                  ChoiceChip(
                    label: Text(
                      {'today': 'Ngày', 'week': 'Tuần', 'month': 'Tháng'}[p]!,
                    ),
                    selected: _summaryPeriod == p,
                    onSelected: (_) {
                      setState(() => _summaryPeriod = p);
                      _loadSummary();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 9,
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Text(
                '${_summary['minutes'] ?? 0}/${_summary['target_minutes'] ?? 0} phút · Chuỗi ${_summary['streak'] ?? 0} ngày',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '7 ngày qua',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 78,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height:
                                      (((day['minutes'] as num?)?.toDouble() ??
                                                  0) /
                                              120 *
                                              50)
                                          .clamp(3, 50)
                                          .toDouble(),
                                  decoration: BoxDecoration(
                                    color: AppColors.stitchPrimary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              day['date'].toString().substring(8),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bảng Vàng Cao Thủ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (var i = 0; i < top.length; i++)
              Text(
                '${i + 1}. ${top[i]['display_name']} · ${top[i]['score']} PRS',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberActions() {
    final friends = (_social['friends'] as List? ?? []);
    final sent = (_social['sent_requests'] as List? ?? []);
    final incoming = (_social['incoming_requests'] as List? ?? []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thành viên trong phòng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final entry in leaderboard)
              if (entry['user_id'] != _currentUserId)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    (entry['display_name'] ?? entry['user_id']).toString(),
                  ),
                  subtitle: Text('${entry['score'] ?? 0} PRS'),
                  trailing: Builder(
                    builder: (context) {
                      final id = entry['user_id'].toString();
                      final name = (entry['display_name'] ?? id).toString();
                      if (friends.any((person) => person['user_id'] == id)) {
                        final count =
                            (_unread['unread_by_sender'] as Map?)?[id] ?? 0;
                        return TextButton(
                          onPressed: () => _openDirectChat(id, name),
                          child: Text('💬 Chat${count > 0 ? ' ($count)' : ''}'),
                        );
                      }
                      if (incoming.any((person) => person['user_id'] == id)) {
                        return TextButton(
                          onPressed: () => _friendAction('/friends/respond', {
                            'requester_id': id,
                            'action': 'accept',
                          }),
                          child: const Text('✓ Chấp nhận'),
                        );
                      }
                      if (sent.any((person) => person['user_id'] == id)) {
                        return const Text('⏳ Đã mời');
                      }
                      return TextButton(
                        onPressed: () =>
                            _friendAction('/friends/add', {'receiver_id': id}),
                        child: const Text('+ Kết bạn'),
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
  Timer? _dmPollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchDMs();
    _dmPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _fetchDMs(silent: true);
    });
  }

  @override
  void dispose() {
    _dmPollingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDMs({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$API_BASE/friends/messages?user_id=${widget.myUserId}&friend_id=${widget.friendId}')
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data["messages"] ?? [];
        if (list.length != _messages.length) {
          if (mounted) {
            setState(() => _messages = list);
            _scrollToBottom();
          }
        }
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => _loading = false);
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
