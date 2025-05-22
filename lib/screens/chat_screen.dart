import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_pet/services/api_service.dart';
import 'package:get_pet/models/message.dart';
import 'package:provider/provider.dart';
import 'package:get_pet/providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final int announcementId;

  const ChatScreen({super.key, required this.announcementId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await ApiService().getChat(widget.announcementId);
      debugPrint('ChatScreen: Messages fetched for announcement ${widget.announcementId}: $messages');
      setState(() {
        _messages = messages ?? [];
      });
      if (_messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      debugPrint('ChatScreen: Fetch messages error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ApiService().sendMessage(
        widget.announcementId,
        _messageController.text.trim(),
      );
      debugPrint('ChatScreen: Message sent for announcement ${widget.announcementId}: ${_messageController.text}');
      _messageController.clear();
      await _fetchMessages();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      debugPrint('ChatScreen: Send message error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.userId?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFDAB9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Chat',
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: const Color(0xFF7D6199),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: 200,
            left: -10,
            right: 0,
            child: Transform.rotate(
              angle: 340 * 3.14159 / 180,
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'assets/images/paws.png',
                  width: MediaQuery.of(context).size.height * 0.900,
                  height: MediaQuery.of(context).size.height * 0.900,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _error!,
                    style: GoogleFonts.oldenburg(
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet',
                              style: GoogleFonts.oldenburg(
                                fontSize: 18,
                                color: const Color(0xFF7D6199),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe = message.senderId?.toString() == userId;

                              debugPrint('Message $index: sender=${message.sender?.username}, senderId=${message.senderId}');

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment:
                                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                                        ),
                                        padding: const EdgeInsets.all(12.0),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? const Color(0xFFD8C4E6)
                                              : const Color(0xFFFFF8E8),
                                          borderRadius: BorderRadius.circular(12.0),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              message.sender?.username ?? 'Unknown',
                                              style: GoogleFonts.oldenburg(
                                                fontSize: 16,
                                                color: const Color(0xFF7D6199),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              message.content ?? '',
                                              style: GoogleFonts.oldenburg(
                                                fontSize: 18,
                                                color: const Color(0xFF7D6199),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              message.timestamp.isNotEmpty
                                                  ? DateTime.parse(message.timestamp)
                                                      .toLocal()
                                                      .toString()
                                                      .substring(0, 16)
                                                  : '',
                                              style: GoogleFonts.oldenburg(
                                                fontSize: 16,
                                                color: const Color(0xFF7D6199).withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFF2A03D)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFF2A03D), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          hintStyle: GoogleFonts.oldenburg(
                            fontSize: 16,
                            color: const Color(0xFF7D6199).withOpacity(0.6),
                          ),
                        ),
                        style: GoogleFonts.oldenburg(
                          fontSize: 18,
                          color: const Color(0xFF7D6199),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(
                              Icons.send,
                              color: Color(0xFF7D6199),
                              size: 30,
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
