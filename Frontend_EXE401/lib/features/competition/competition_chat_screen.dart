import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class CompetitionChatScreen extends StatefulWidget {
  final String roomCode;
  final String currentUserId;
  final http.Client? httpClient;

  const CompetitionChatScreen({
    super.key,
    required this.roomCode,
    required this.currentUserId,
    this.httpClient,
  });

  @override
  State<CompetitionChatScreen> createState() => _CompetitionChatScreenState();
}

class _CompetitionChatScreenState extends State<CompetitionChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final http.Client _client;
  Timer? _pollTimer;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _loading = false;
  bool _sending = false;

  String get _url =>
      '${AppConstants.baseUrl}/api/v1/competition/groups/${widget.roomCode}/messages';

  @override
  void initState() {
    super.initState();
    _client = widget.httpClient ?? http.Client();
    _loadMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    if (widget.httpClient == null) _client.close();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await ApiClient.getToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> _loadMessages() async {
    if (_loading || !mounted) return;
    _loading = true;
    try {
      final response = await _client
          .get(Uri.parse(_url), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      final lastId = _messages.isEmpty ? null : _messages.last['id'];
      setState(() {
        _messages = messages;
        _error = null;
      });
      if (messages.isNotEmpty && messages.last['id'] != lastId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không tải được tin nhắn. Kéo xuống để thử lại.',
        );
      }
    } finally {
      _loading = false;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final response = await _client
          .post(
            Uri.parse(_url),
            headers: await _headers(),
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 201) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _messageController.clear();
      await _loadMessages();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không gửi được tin nhắn. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stitchSurfaceLowest,
      appBar: AppBar(
        title: Text('Chat phòng ${widget.roomCode}'),
        actions: [
          IconButton(
            tooltip: 'Tải lại tin nhắn',
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMessages,
                child: ListView.builder(
                  key: const Key('competitionChatMessages'),
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.isEmpty ? 1 : _messages.length,
                  itemBuilder: (context, index) {
                    if (_messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Chưa có tin nhắn. Hãy chào mọi người!'),
                        ),
                      );
                    }
                    final message = _messages[index];
                    final mine = message['user_id'] == widget.currentUserId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                        ),
                        child: Card(
                          color: mine
                              ? AppColors.stitchPrimaryContainer
                              : AppColors.stitchSurfaceContainer,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mine
                                      ? 'Bạn'
                                      : (message['sender_name'] ?? 'Thành viên')
                                            .toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(message['text'].toString()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('competitionChatInput'),
                      controller: _messageController,
                      maxLength: 500,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Nhắn cho cả phòng...',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    key: const Key('competitionChatSend'),
                    onPressed: _sending ? null : _sendMessage,
                    icon: const Icon(Icons.send_rounded),
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
