/// features/market/presentation/screens/market_screen.dart
/// Tầng Presentation - Màn hình Chợ hiệu ứng.
/// CHỈ chứa UI. Mọi state và logic đều thông qua MarketProvider.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/market_provider.dart';
import '../widgets/market_card.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  @override
  void initState() {
    super.initState();
    // Gọi fetch khi màn hình khởi tạo, dùng addPostFrameCallback để tránh lỗi setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().fetchTemplates();
    });
  }

  Future<void> _pickFileToUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      showSuccessSnackbar(context, 'Đã chọn file "${file.name}" để upload!');
    }
  }

  Future<void> _uploadDesign() async {
    final provider = context.read<MarketProvider>();
    final success = await provider.uploadTemplate(
      author: 'Vương Đại Hiệp',
      thumbnailUrl: 'assets/images/market_3.png',
      designJson: {
        'type': 'Custom',
        'elements': [
          {'type': 'text', 'content': '15:45', 'x': 50, 'y': 50, 'fontSize': 48}
        ],
      },
    );
    if (mounted) {
      if (success) {
        showSuccessSnackbar(context, 'Đã tải lên Chợ thành công!');
      } else {
        showErrorSnackbar(context, 'Lỗi kết nối máy chủ!');
      }
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
        title: Text(
          'Chợ hiệu ứng',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 22),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Upload Banner
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _UploadBanner(
                onUpload: _uploadDesign,
                onPickFile: _pickFileToUpload,
              ),
            ),
            // Grid Section
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
                    'Kho hiệu ứng cộng đồng',
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Các hiệu ứng được cộng đồng tải lên.',
                    style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  // ========================================
                  // Consumer: Lắng nghe MarketProvider
                  // ========================================
                  Consumer<MarketProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: AppColors.btnOrange),
                          ),
                        );
                      }

                      if (provider.status == MarketStatus.error) {
                        return Center(
                          child: Column(
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black26),
                              const SizedBox(height: 12),
                              Text(
                                provider.errorMessage,
                                style: GoogleFonts.nunito(fontSize: 13, color: Colors.black45),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => provider.fetchTemplates(),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (provider.items.isEmpty) {
                        return Center(
                          child: Text(
                            'Chợ hiện đang trống.',
                            style: GoogleFonts.nunito(fontSize: 14, color: Colors.black45),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: provider.items.length,
                            itemBuilder: (context, index) => MarketCard(
                              item: provider.items[index],
                              displayIndex: index,
                            ),
                          ),
                          const SizedBox(height: 20),
                          EinkButton(
                            label: 'Tải thêm hiệu ứng',
                            icon: Icons.refresh_rounded,
                            backgroundColor: AppColors.btnOrange,
                            onPressed: () => provider.loadMore(),
                          ),
                        ],
                      );
                    },
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

// ============================================================
// Upload Banner Widget (giữ nguyên UI)
// ============================================================
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
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFFFF7043), size: 26),
              ),
              const SizedBox(width: 14),
              Text('Chia sẻ hiệu ứng', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload hiệu ứng của bạn lên máy chủ và\nmọi người có thể sử dụng nó.',
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.95), height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Transform.rotate(
                angle: -0.15,
                child: Container(
                  width: 100,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black38, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(-2, 4))],
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -3.14159 / 2,
                      child: Text('10:28', style: GoogleFonts.sourceCodePro(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF7043),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Upload', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onPickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_add_rounded, size: 20, color: Color(0xFFFF7043)),
                  const SizedBox(width: 8),
                  Text('Hoặc chọn file từ máy để upload',
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFFF7043))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
