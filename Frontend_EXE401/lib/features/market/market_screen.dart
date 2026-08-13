import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';

// === Model ===
class MarketItem {
  final String author;
  final String timestamp;
  final String previewText; 
  final String imagePath;
  final int index;
  final int likes;
  
  MarketItem({required this.author, required this.timestamp, required this.previewText, required this.imagePath, required this.index, this.likes = 0});

  factory MarketItem.fromJson(Map<String, dynamic> json, int index) {
    String text = "00:00";
    if (json['design_json'] != null && json['design_json']['elements'] != null) {
      try {
        var elements = json['design_json']['elements'] as List;
        if (elements.isNotEmpty) {
           text = elements[0]['content'] ?? "12:00";
        }
      } catch (e) {
        text = "12:00";
      }
    }

    // Định dạng lại thời gian hiển thị
    String timeStr = json['timestamp'] ?? '';
    if (timeStr.contains('T')) {
      timeStr = timeStr.replaceAll('T', ' ').substring(0, 19);
    }

    return MarketItem(
      author: json['author'] ?? 'Unknown',
      timestamp: timeStr,
      previewText: text,
      imagePath: json['thumbnail_url'] ?? 'assets/images/market_1.png',
      likes: json['likes'] ?? 0,
      index: index,
    );
  }
}

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<MarketItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchMarketItems();
  }

  Future<void> _fetchMarketItems() async {
    setState(() => _isLoading = true);
    try {
      // Tự động nhận diện nền tảng để gọi đúng địa chỉ localhost
      String baseUrl = "http://127.0.0.1:8000";
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          baseUrl = "http://10.0.2.2:8000";
        }
      }

      final response = await http.get(Uri.parse('$baseUrl/api/market/'));
      if (response.statusCode == 200) {
        // Decode byte stream using UTF-8 to fix Vietnamese accents
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _items = data.asMap().entries.map((entry) {
            return MarketItem.fromJson(entry.value, entry.key);
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Lỗi khi fetch API: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Chợ hiệu ứng', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 22)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // White background for Banner
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _UploadBanner(
                onUpload: () => _uploadDesign(context),
                onPickFile: () => _pickFileToUpload(context),
              ),
            ),
            // Beige background for the Grid
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFFDF8EE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kho hiệu ứng cộng đồng (158)',
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đây là các hiệu ứng được cộng đồng tải lên.',
                    style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: AppColors.btnOrange))
                    : _items.isEmpty 
                      ? const Center(child: Text("Chợ hiện đang trống"))
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (context, index) => _MarketCard(item: _items[index]),
                        ),
                  const SizedBox(height: 20),
                  EinkButton(
                    label: _isLoadingMore ? 'Đang tải...' : 'Tải thêm hiệu ứng',
                    icon: Icons.refresh_rounded,
                    backgroundColor: AppColors.btnOrange,
                    onPressed: _isLoadingMore ? () {} : () => _loadMore(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadMore() {
    setState(() => _isLoadingMore = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _items.addAll(
          List.generate(
            10,
            (i) => MarketItem(
              author: ['Dev_${i + 1}', 'Maker_${i + 1}'][i % 2],
              timestamp: '2026-08-09 ${(8 + i).toString().padLeft(2, '0')}:00:00',
              previewText: ['15:30', '23:59', '06:45', '10:00', '12:12'][i % 5],
              imagePath: 'assets/images/market_${(i % 4) + 1}.png',
              index: _items.length + i,
            ),
          ),
        );
        _isLoadingMore = false;
      });
    });
  }

  Future<void> _uploadDesign(BuildContext context) async {
    showSuccessSnackbar(context, 'Đang gửi thiết kế lên máy chủ...');
    try {
      String baseUrl = "http://127.0.0.1:8000";
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          baseUrl = "http://10.0.2.2:8000";
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/market/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "author": "Vương Đại Hiệp",
          "thumbnail_url": "assets/images/market_3.png",
          "design_json": {
            "type": "Custom",
            "elements": [
              {"type": "text", "content": "15:45", "x": 50, "y": 50, "fontSize": 48}
            ]
          },
          "timestamp": DateTime.now().toUtc().toIso8601String(),
          "likes": 999
        }),
      );

      if (response.statusCode == 200) {
        if (context.mounted) showSuccessSnackbar(context, 'Đã tải lên Chợ thành công!');
        _fetchMarketItems(); // Load lại dữ liệu chợ để thấy thiết kế mới
      } else {
        if (context.mounted) showErrorSnackbar(context, 'Lỗi tải lên: ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, 'Lỗi kết nối máy chủ!');
    }
  }

  Future<void> _pickFileToUpload(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && context.mounted) {
      showSuccessSnackbar(context, 'Đã chọn file "${file.name}" để upload!');
    }
  }
}

// === Upload Banner Widget ===
class _UploadBanner extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onPickFile;

  const _UploadBanner({required this.onUpload, required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFCA28), Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFFFF7043), size: 26),
              ),
              const SizedBox(width: 14),
              Text(
                'Chia sẻ hiệu ứng',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload hiệu ứng của bạn lên máy chủ và\nmọi người có thể sử dụng nó.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Mock tilted E-ink device
              Transform.rotate(
                angle: -0.15,
                child: Container(
                  width: 100,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black38, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(-2, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -3.14159 / 2, // Rotate text -90 deg
                      child: Text(
                        '10:28',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Upload Button
              ElevatedButton(
                onPressed: onUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF7043),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Upload',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onPickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_add_rounded, size: 20, color: Color(0xFFFF7043)),
                  const SizedBox(width: 8),
                  Text(
                    'Hoặc chọn file từ máy để upload',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF7043),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === Market Card Widget ===
class _MarketCard extends StatelessWidget {
  final MarketItem item;

  const _MarketCard({required this.item});

  Widget _buildMockEinkFace(int index) {
    if (index % 2 == 0) {
      return Container(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Dương Lịch', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold)),
                Text('09', style: GoogleFonts.sourceCodePro(fontSize: 32, fontWeight: FontWeight.w900, height: 1.0)),
                Text('Th 08\n2026', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('08:30', style: GoogleFonts.sourceCodePro(fontSize: 24, fontWeight: FontWeight.w900, height: 1.0)),
                const SizedBox(height: 2),
                Text('Hoàng Thịnh PRO', style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w900)),
                Text('0925448838', style: GoogleFonts.sourceCodePro(fontSize: 11, fontWeight: FontWeight.w900)),
                Text('C.Nhật', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Âm Lịch', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold)),
                Text('27', style: GoogleFonts.sourceCodePro(fontSize: 32, fontWeight: FontWeight.w900, height: 1.0)),
                Text('Th 06\n2026', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RotatedBox(
              quarterTurns: 3,
              child: Text('Tháng 08', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            Text('09', style: GoogleFonts.sourceCodePro(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0)),
            RotatedBox(
              quarterTurns: 3,
              child: Text('Chủ Nhật', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
            Text('27', style: GoogleFonts.sourceCodePro(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0)),
            RotatedBox(
              quarterTurns: 3,
              child: Text('Tháng 06\n16:20', style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/design',
          arguments: {'preview': item.previewText},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      item.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildMockEinkFace(item.index);
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tác giả: ${item.author}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.timestamp,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
