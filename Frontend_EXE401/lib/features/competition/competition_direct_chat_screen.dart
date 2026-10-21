import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';

class CompetitionDirectChatScreen extends StatefulWidget {
  const CompetitionDirectChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.currentUserId,
    this.httpClient,
  });

  final String friendId;
  final String friendName;
  final String currentUserId;
  final http.Client? httpClient;

  @override
  State<CompetitionDirectChatScreen> createState() =>
      _CompetitionDirectChatScreenState();
}

class _CompetitionDirectChatScreenState
    extends State<CompetitionDirectChatScreen> {
  late final http.Client _client;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<dynamic> _messages = [];
  bool _busy = false;
  String? _error;

  String get _url =>
      '${AppConstants.baseUrl}/api/v1/competition/friends/messages';

  Future<Map<String, String>> _headers() async {
    final token = await ApiClient.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _client = widget.httpClient ?? http.Client();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    if (widget.httpClient == null) _client.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final uri = Uri.parse(
        _url,
      ).replace(queryParameters: {'friend_id': widget.friendId});
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      final oldLast = _messages.isEmpty ? null : _messages.last['id'];
      setState(() {
        _messages = data['messages'] as List<dynamic>? ?? [];
        _error = null;
      });
      if (_messages.isNotEmpty && oldLast != _messages.last['id']) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được tin nhắn');
    } finally {
      _busy = false;
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    try {
      final response = await _client
          .post(
            Uri.parse(_url),
            headers: await _headers(),
            body: jsonEncode({'receiver_id': widget.friendId, 'text': text}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 201) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _input.clear();
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Không gửi được tin nhắn');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Chat với ${widget.friendName}'),
      actions: [
        IconButton(
          tooltip: 'Đóng',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index] as Map<String, dynamic>;
              final mine = message['sender_id'] == widget.currentUserId;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${mine ? 'Bạn' : widget.friendName}: ${message['text']}',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Nhắn tin...',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
