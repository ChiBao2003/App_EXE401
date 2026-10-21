// ==========================================
// THI_DUA_FEATURE_START (Aether Synapse — Stitch Screen 7)
// ==========================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/auth_api.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'competition_chat_screen.dart';
import 'competition_direct_chat_screen.dart';

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

class _CompetitionScreenState extends State<CompetitionScreen>
    with SingleTickerProviderStateMixin {
  String? currentRoomCode;
  String? groupName;
  int? durationDays;
  bool isExpired = false;
  List<dynamic> leaderboard = [];
  bool isLoading = false;
  String? errorMessage;
  String _selectedPeriod = 'all'; // 'today' | 'week' | 'month' | 'all'

  // Controllers
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  int _durationDays = 7;

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
    try {
      final status = await _socialGet('/friends/unread-status');
      final friends = await _socialGet('/friends/$_currentUserId');
      if (mounted) {
        setState(() {
          _unread = status;
          _social = friends;
        });
      }
    } catch (_) {
    } finally {
      _socialLoading = false;
    }
  }

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
        ],
      ),
    );
  }

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
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      ),
    );
  }

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
// ==========================================
// THI_DUA_FEATURE_END
// ==========================================
