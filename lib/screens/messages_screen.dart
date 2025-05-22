import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_pet/services/api_service.dart';
import 'chat_screen.dart';
import 'dart:convert';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await ApiService().getUserChats();
      debugPrint('MessagesScreen: Chats fetched: $chats');
      setState(() {
        _chats = chats;
      });
    } catch (e) {
      final errorMessage = _extractErrorMessage(e);
      setState(() {
        _error = errorMessage;
      });
      debugPrint('MessagesScreen: Fetch chats error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $errorMessage',
            style: GoogleFonts.oldenburg(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _extractErrorMessage(dynamic error) {
    try {
      final errorString = error.toString().replaceFirst('Exception: ', '');
      try {
        final errorJson = jsonDecode(errorString);
        if (errorJson is Map<String, dynamic>) {
          if (errorJson['detail'] is Map<String, dynamic>) {
            return errorJson['detail']['message']?.toString() ?? 'An error occurred';
          }
          return errorJson['detail']?.toString() ?? 'An error occurred';
        }
        return errorString;
      } catch (_) {
        return errorString;
      }
    } catch (e) {
      return 'An error occurred';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFDAB9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: const Color(0xFF7D6199),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7D6199)))
          : _error != null
          ? Center(
        child: Text(
          _error!,
          style: GoogleFonts.oldenburg(fontSize: 18, color: Colors.red),
        ),
      )
          : _chats.isEmpty
          ? Center(
        child: Text(
          'No chats',
          style: GoogleFonts.oldenburg(
            fontSize: 20,
            color: const Color(0xFF7D6199),
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final announcementId = chat['announcement_id'] as int;
          final announcementTitle = chat['announcement_title'] as String? ?? 'No title';
          final lastMessage = chat['last_message'] as Map<String, dynamic>?;
          final hasUnread = chat['has_unread'] == true;

          // Извлекаем первый URL из image_paths
          String? imageUrl;
          final imagePaths = chat['image_paths'] as List<dynamic>?;
          if (imagePaths != null && imagePaths.isNotEmpty && imagePaths.first is String) {
            imageUrl = imagePaths.first as String;
            debugPrint('MessagesScreen: Using image URL: $imageUrl');
          }

          return Card(
            color: const Color(0xFFFFF8E8),
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[200],
                  child: imageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircularProgressIndicator(color: Color(0xFF7D6199)),
                    errorWidget: (context, url, error) {
                      debugPrint('MessagesScreen: Image load error for $imageUrl: $error');
                      return const Icon(
                        Icons.pets,
                        color: Color(0xFF7D6199),
                        size: 30,
                      );
                    },
                  )
                      : const Icon(
                    Icons.pets,
                    color: Color(0xFF7D6199),
                    size: 30,
                  ),
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      announcementTitle,
                      style: GoogleFonts.oldenburg(
                        fontSize: 22,
                        color: const Color(0xFF7D6199),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB8B272),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lastMessage != null) ...[
                    Text(
                      'From: ${lastMessage['sender']['username']}',
                      style: GoogleFonts.oldenburg(
                        fontSize: 18,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Last message: ',
                            style: GoogleFonts.oldenburg(
                              fontSize: 18,
                              color: const Color(0xFF7D6199),
                            ),
                          ),
                          TextSpan(
                            text: lastMessage['content'],
                            style: GoogleFonts.oldenburg(
                              fontSize: 18,
                              color: hasUnread
                                  ? const Color(0xFFB8B272)
                                  : const Color(0xFF7D6199),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Time: ${DateTime.parse(lastMessage['timestamp']).toLocal().toString().substring(0, 16)}',
                      style: GoogleFonts.oldenburg(
                        fontSize: 18,
                        color: const Color(0xFF7D6199),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () async {
                await ApiService().markMessagesAsRead(announcementId);
                debugPrint('MessagesScreen: Marked messages as read for announcement $announcementId');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(announcementId: announcementId),
                  ),
                ).then((_) async {
                  debugPrint('Returning to MessagesScreen, refreshing chats');
                  await _fetchChats();
                });
                debugPrint('Navigating to ChatScreen for announcement $announcementId');
              },
            ),
          );
        },
      ),
    );
  }
}