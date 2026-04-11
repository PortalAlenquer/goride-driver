import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime? createdAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.createdAt,
    required this.read,
  });

  factory ChatMessage.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ChatMessage(
      id:         doc.id,
      senderId:   d['senderId']   ?? '',
      senderRole: d['senderRole'] ?? '',
      text:       d['text']       ?? '',
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate(),
      read:       d['read']       ?? false,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  bool get isDriver    => senderRole == 'driver';
  bool get isPassenger => senderRole == 'passenger';
}