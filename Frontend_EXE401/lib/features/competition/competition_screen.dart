// ==========================================
// THI_DUA_FEATURE_START (By Gemini)
// ==========================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

String get API_BASE => "${AppConstants.baseUrl}/api/v1/competition";

class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  String? currentRoomCode;
  String? groupName;
  int? durationDays;
  bool isExpired = false;
  List<dynamic> leaderboard = [];
  bool isLoading = false;
  String _selectedPeriod = "all"; // today | week | month | all

  // Controllers
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController(text: "user_bao");
  int _durationDays = 7;

  @override
  void dispose() {
    _roomNameController.dispose();
    _joinCodeController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  // API Call: Tạo phòng
  Future<void> _createRoom() async {
    if (_roomNameController.text.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/groups'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": _roomNameController.text,
          "duration_days": _durationDays
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          currentRoomCode = data["room_code"];
        });
        _joinRoomSilent(currentRoomCode!); // Tự động join khi tạo xong
        _showSuccess("Đã tạo phòng! Mã: ${data["room_code"]}");
      }
    } catch (e) {
      _showError("Lỗi kết nối server");
    }
    setState(() => isLoading = false);
  }

  // API Call: Join phòng
  Future<void> _joinRoomSilent(String code) async {
    await http.post(
      Uri.parse('$API_BASE/groups/join'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "room_code": code,
        "user_id": _userIdController.text
      }),
    );
    _fetchLeaderboard(code);
  }

  Future<void> _joinRoomBtn() async {
    if (_joinCodeController.text.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final code = _joinCodeController.text.toUpperCase();
      final res = await http.post(
        Uri.parse('$API_BASE/groups/join'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_code": code,
          "user_id": _userIdController.text
        }),
      );
      if (res.statusCode == 200) {
        setState(() => currentRoomCode = code);
        _fetchLeaderboard(code);
        _showSuccess("Vào phòng thành công!");
      } else {
        final data = jsonDecode(res.body);
        _showError(data["detail"] ?? "Phòng không tồn tại hoặc đã đầy");
      }
    } catch (e) {
      _showError("Lỗi kết nối");
    }
    setState(() => isLoading = false);
  }

  // Lấy BXH với filter period
  Future<void> _fetchLeaderboard(String code) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('$API_BASE/leaderboard/$code?period=$_selectedPeriod'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          leaderboard = data["leaderboard"];
          groupName = data["group_name"];
          durationDays = data["duration_days"];
          isExpired = data["expired"] ?? false;
        });
      }
    } catch (e) {}
    setState(() => isLoading = false);
  }

  // Giả lập nộp điểm Pomodoro để TEST trên App
  Future<void> _submitFakeSession() async {
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$API_BASE/submit'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": _userIdController.text,
          "work_min": 25, // Giả lập học 25 phút
          "completed": true,
          "pauses": 0
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _showSuccess(data["message"]);
        // Gọi lại BXH để thấy điểm tăng lên
        if (currentRoomCode != null) _fetchLeaderboard(currentRoomCode!);
      }
    } catch (e) {
      _showError("Lỗi submit điểm test");
    }
    setState(() => isLoading = false);
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🏆 Đấu Trường Năng Suất", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFD54F),
        foregroundColor: Colors.black87,
      ),
      body: currentRoomCode == null ? _buildLobby() : _buildArena(),
    );
  }

  // Màn hình lúc chưa vào phòng
  Widget _buildLobby() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 80, color: Color(0xFFFFD54F)),
          const SizedBox(height: 16),
          Text(
            "Thi Đua Làm Việc",
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Cùng bạn bè bứt phá giới hạn.\nNhận 1 điểm cho mỗi phút tập trung!",
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _userIdController,
            decoration: InputDecoration(
              labelText: "Tên hiển thị của bạn (Ví dụ: user_thang)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
          // Tạo phòng
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)),
            child: Column(
              children: [
                TextField(
                  controller: _roomNameController,
                  decoration: const InputDecoration(
                    labelText: "Tên phòng mới (Ví dụ: Thi hết môn)",
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _durationDays,
                  decoration: const InputDecoration(
                    labelText: "Thời gian thi đua",
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text("1 Tuần (7 ngày)")),
                    DropdownMenuItem(value: 30, child: Text("1 Tháng (30 ngày)")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _durationDays = val);
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : _createRoom,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
                  child: isLoading ? const CircularProgressIndicator() : const Text("Tạo Phòng Mới"),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("Hoặc", textAlign: TextAlign.center, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          // Tham gia phòng
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue)),
            child: Column(
              children: [
                TextField(
                  controller: _joinCodeController,
                  decoration: const InputDecoration(labelText: "Nhập Mã Phòng (6 chữ số)"),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : _joinRoomBtn,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: isLoading ? const CircularProgressIndicator() : const Text("Vào Phòng"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Màn hình lúc đã vào phòng (Hiển thị BXH)
  Widget _buildArena() {
    return Column(
      children: [
        // Header phòng
        Container(
          padding: const EdgeInsets.all(20),
          color: isExpired ? Colors.grey.shade400 : const Color(0xFFFFD54F),
          width: double.infinity,
          child: Column(
            children: [
              if (groupName != null)
                Text(groupName!, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
              Text("Mã phòng: $currentRoomCode", style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(
                isExpired 
                  ? "⛔ Phòng đã kết thúc (hết ${durationDays ?? 7} ngày)" 
                  : "Thời hạn: ${durationDays ?? 7} ngày • Mời bạn bè nhập mã để tham gia",
                style: GoogleFonts.nunito(fontSize: 13, color: isExpired ? Colors.red.shade800 : Colors.black54),
              ),
              const SizedBox(height: 12),
              if (!isExpired) Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _fetchLeaderboard(currentRoomCode!),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Làm mới"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _submitFakeSession,
                    icon: const Icon(Icons.add_task, size: 18),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    label: const Text("Test Cộng Điểm"),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Period Filter Tabs: Ngày / Tuần / Tháng / Tất cả
        Container(
          color: Colors.white,
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

        // Bảng xếp hạng
        Expanded(
          child: isLoading 
            ? const Center(child: CircularProgressIndicator())
            : leaderboard.isEmpty 
              ? Center(
                  child: Text(
                    _selectedPeriod == "all" ? "Chưa có dữ liệu thi đua nào" : "Không có dữ liệu cho khoảng thời gian này",
                    style: GoogleFonts.nunito(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: leaderboard.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final lb = leaderboard[index];
                    final isTop1 = index == 0;
                    final isTop3 = index < 3;
                    return Card(
                      elevation: isTop1 ? 4 : 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isTop1 ? Colors.amber.shade100 : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTop1 
                            ? Colors.amber 
                            : index == 1 
                              ? Colors.grey.shade400 
                              : index == 2 
                                ? Colors.brown.shade300 
                                : Colors.grey.shade200,
                          child: Text(
                            isTop3 ? ["🥇", "🥈", "🥉"][index] : "#${lb['rank']}", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTop3 ? 20 : 14, color: isTop3 ? null : Colors.black87)
                          ),
                        ),
                        title: Text(lb['user_id'], style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text("⏱ ${lb['work_min']} phút | 🍅 ${lb['completed']} phiên"),
                        trailing: Text(
                          "${lb['score']} điểm",
                          style: GoogleFonts.sourceCodePro(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.blueAccent),
                        ),
                      ),
                    );
                  }
                ),
        ),

        // Nút quay lại sảnh
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton.icon(
            onPressed: () => setState(() {
              currentRoomCode = null;
              leaderboard = [];
              groupName = null;
              isExpired = false;
              _selectedPeriod = "all";
            }),
            icon: const Icon(Icons.arrow_back),
            label: const Text("Quay lại sảnh chờ"),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD54F) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.amber.shade700 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
// ==========================================
// THI_DUA_FEATURE_END
// ==========================================
