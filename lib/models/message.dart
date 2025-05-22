import 'user.dart';

class Message {
  final int id;
  final int chatId;  // Новое поле
  final int senderId;
  final String content;
  final String timestamp;
  final User? sender;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'],
        chatId: json['chat_id'],  // Новое поле
        senderId: json['sender_id'],
        content: json['content'],
        timestamp: json['timestamp'],
        sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat_id': chatId,
        'sender_id': senderId,
        'content': content,
        'timestamp': timestamp,
        'sender': sender?.toJson(),
      };
}
