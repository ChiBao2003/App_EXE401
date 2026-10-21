/// features/market/presentation/screens/market_screen.dart
/// Tầng Presentation - Màn hình TFT LCD Watch Face Market.
/// Chuẩn Google Stitch Screen 13 (Screen ID: f18025ad2e464dcdb4dd090d84c54c21)
/// Design System: Aether Synapse.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/market_item.dart';
import '../providers/market_provider.dart';
import '../widgets/market_card.dart';
import '../widgets/market_json_import_sheet.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Tự động kiểm tra Provider trong cây Widget để tương thích cả khi chạy qua router lẫn khi test riêng lẻ
    MarketProvider? existing;
    try {
      existing = Provider.of<MarketProvider>(context, listen: false);
    } catch (_) {}

    if (existing != null) {
      return const _MarketScreenContent();
    }

    return ChangeNotifierProvider<MarketProvider>(
      create: (_) => MarketProvider()..fetchTemplates(),
      child: const _MarketScreenContent(),
    );
  }
}

class _MarketScreenContent extends StatefulWidget {
  const _MarketScreenContent();

  @override
  State<_MarketScreenContent> createState() => _MarketScreenContentState();
}

class _MarketScreenContentState extends State<_MarketScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Phổ biến nhất';

  final List<Map<String, dynamic>> _filterChips = [
    {'label': 'Phổ biến nhất', 'icon': Icons.local_fire_department_rounded},
    {'label': 'Mới nhất', 'icon': Icons.access_time_rounded},
    {'label': 'Tối giản (Minimal)', 'icon': Icons.tune_rounded},
    {'label': 'Anime & Pixel', 'icon': Icons.videogame_asset_rounded},
    {'label': 'Kỹ thuật số (Digital)', 'icon': Icons.numbers_rounded},
    {'label': 'Được chứng nhận AI', 'icon': Icons.verified_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MarketProvider>();
      if (provider.status == MarketStatus.initial) {
        provider.fetchTemplates();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MarketItem> _filterAndSortItems(List<MarketItem> items) {
    var result = List<MarketItem>.from(items);

    // Lọc theo search text
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((it) {
        final author = it.author.toLowerCase();
        final title = it.title.toLowerCase();
        final id = it.id.toLowerCase();
        final preview = it.previewText.toLowerCase();
        return author.contains(query) ||
            title.contains(query) ||
            id.contains(query) ||
            preview.contains(query);
      }).toList();
    }

    // Sắp xếp / Lọc theo danh mục chip
    if (_selectedCategory == 'Phổ biến nhất') {
      result.sort((a, b) => b.likes.compareTo(a.likes));
    } else if (_selectedCategory == 'Mới nhất') {
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else if (_selectedCategory == 'Tối giản (Minimal)') {
      // Ưu tiên các item có layout số hoặc text
      result = result.where((it) => it.previewText.length <= 6).toList();
    } else if (_selectedCategory == 'Anime & Pixel') {
      result = result
          .where(
            (it) =>
                it.author.toLowerCase().contains('zen') ||
                it.id.contains('pixel'),
          )
          .toList();
    } else if (_selectedCategory == 'Được chứng nhận AI') {
      result = result.where((it) => it.likes >= 50).toList();
    }

    return result;
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191B23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF32353D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bộ Lọc Hiển Thị',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE1E2EC),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filterChips.map((chip) {
                final isSelected = _selectedCategory == chip['label'];
                return ChoiceChip(
                  label: Text(chip['label'] as String),
                  selected: isSelected,
                  selectedColor: const Color(0xFF7C4DFF),
                  backgroundColor: const Color(0xFF1D1F27),
                  labelStyle: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(0xFFCAC3D8),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(
                        () => _selectedCategory = chip['label'] as String,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSpotlightModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF191B23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.terminal_rounded,
              color: Color(0xFF00E3FD),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bộ Sưu Tập Cyberpunk 2025',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE1E2EC),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thiết kế độc quyền từ Synapse Labs:',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE1E2EC),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Thuật toán màu RGB565 16-bit\n• 3 biến thể mặt đồng hồ: Chronos, Bento Terminal, Neural Matrix\n• Tối ưu cho màn hình TFT LCD ILI9341 320×240',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFCAC3D8),
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Đóng',
              style: GoogleFonts.inter(color: const Color(0xFFCDBDFF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _searchQuery = 'Cyberpunk';
                _searchController.text = 'Cyberpunk';
              });
            },
            child: Text(
              'Khám phá',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10131A), // surface background
      body: SafeArea(
        child: Column(
          children: [
            // Top App Header
            _buildTopHeader(context),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const MarketJsonImportSheet(),
                        ),
                        icon: const Icon(Icons.file_open_rounded),
                        label: const Text('Nhập hoặc dán mặt đồng hồ JSON'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Input & Filter Pills
                    _buildSearchAndFilters(context),

                    const SizedBox(height: 20),

                    // Featured Spotlight Banner
                    _buildFeaturedSpotlight(context),

                    const SizedBox(height: 24),

                    // Section Header: "Cộng đồng sáng chế"
                    _buildCommunityHeader(context),

                    const SizedBox(height: 16),

                    // 2-Column Grid of Watch Faces
                    _buildWatchFaceGrid(context),

                    const SizedBox(height: 24),

                    // Community Callout Box: Synapse Watch SDK v2.4
                    _buildSdkCalloutBox(context),

                    const SizedBox(height: 100), // Khoảng trống cho FAB
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  /// 1. Top Header theo Stitch Screen 13
  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF10131A),
        border: Border(bottom: BorderSide(color: Color(0xFF1D1F27), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Nút Back + Brand Synapse AI
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Color(0xFFE1E2EC),
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1F27),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3F7C4DFF),
                      blurRadius: 10,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFF7C4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Synapse',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE1E2EC),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x337C4DFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'AI',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFCDBDFF),
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
                        decoration: const BoxDecoration(
                          color: Color(0xFF4EDEA3), // Mint tertiary
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'TFT LCD RGB565',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFCAC3D8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Right: Watch Battery Pill + Avatar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF191B23),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.watch_rounded,
                      size: 14,
                      color: Color(0xFF00E3FD), // Cyan
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '98%',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00E3FD),
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
                  color: Color(0xFF7C4DFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Search & Category Filters
  Widget _buildSearchAndFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF191B23), // surface-container-low
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF272A32)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF948EA1),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFE1E2EC),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm mặt đồng hồ TFT LCD, tác giả, tag...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF948EA1),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF948EA1),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              IconButton(
                icon: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF948EA1),
                  size: 18,
                ),
                onPressed: () => _showFilterBottomSheet(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterChips.map((chip) {
              final label = chip['label'] as String;
              final icon = chip['icon'] as IconData;
              final isSelected = _selectedCategory == label;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    setState(() => _selectedCategory = label);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C4DFF)
                          : const Color(0xFF1D1F27),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: Color(0x4D7C4DFF),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 15,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFCAC3D8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFCAC3D8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 3. Featured Spotlight Banner
  Widget _buildFeaturedSpotlight(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF191B23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF272A32)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0E15), Color(0xFF191B23), Color(0x227C4DFF)],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E3FD),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SPOTLIGHT DROP',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF00E3FD),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bộ Sưu Tập Cyberpunk TFT LCD 2025',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE1E2EC),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF272A32),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: Color(0xFFCDBDFF),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thiết kế bởi Synapse Labs. Bố cục màu RGB565 16-bit cho màn hình TFT LCD ILI9341 320×240.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFFCAC3D8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF32353D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '3 Mặt Đồng Hồ',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00E3FD),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF32353D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Miễn Phí',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4EDEA3),
                      ),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  elevation: 0,
                ),
                onPressed: () => _showSpotlightModal(context),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(
                  'Khám phá ngay',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. Section Header: "Cộng đồng sáng chế"
  Widget _buildCommunityHeader(BuildContext context) {
    return Consumer<MarketProvider>(
      builder: (context, provider, _) {
        final filtered = _filterAndSortItems(provider.items);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Cộng đồng sáng chế',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE1E2EC),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272A32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${filtered.length} designs',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFCAC3D8),
                    ),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _showFilterBottomSheet(context),
              child: Row(
                children: [
                  Text(
                    'Bộ lọc',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFCDBDFF),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: Color(0xFFCDBDFF),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 5. 2-Column Grid
  Widget _buildWatchFaceGrid(BuildContext context) {
    return Consumer<MarketProvider>(
      builder: (context, provider, _) {
        // Trạng thái Đang tải
        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                  SizedBox(height: 12),
                  Text(
                    'Đang đồng bộ mặt đồng hồ TFT LCD...',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCAC3D8)),
                  ),
                ],
              ),
            ),
          );
        }

        // Trạng thái Lỗi kết nối
        if (provider.status == MarketStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 44,
                    color: Color(0xFFFFB4AB),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.errorMessage,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFFFB4AB),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => provider.fetchTemplates(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Thử lại',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final filteredItems = _filterAndSortItems(provider.items);

        // Trạng thái Rỗng
        if (filteredItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 44,
                    color: Color(0xFF948EA1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chưa có mẫu mặt đồng hồ nào phù hợp.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFCAC3D8),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Grid 2 Cột hiển thị Cards
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.56,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            return MarketCard(item: filteredItems[index], displayIndex: index);
          },
        );
      },
    );
  }

  /// 6. Community Callout Box: Synapse Watch SDK v2.4
  Widget _buildSdkCalloutBox(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF191B23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272A32)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF008259).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.code_rounded,
              color: Color(0xFF4EDEA3), // Mint tertiary
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Synapse Watch SDK v2.4',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE1E2EC),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tải bộ thư viện C++ & MicroPython để tự tạo mặt đồng hồ TFT LCD theo ý bạn.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFCAC3D8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFE1E2EC),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Bộ SDK Synapse Watch v2.4 đang sẵn sàng trên GitHub repo.',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 7. Floating Action Button: Đăng tải thiết kế
  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFF7C4DFF),
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
      label: Text(
        'Đăng tải thiết kế',
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      onPressed: () {
        Navigator.pushNamed(context, '/design');
      },
    );
  }
}
