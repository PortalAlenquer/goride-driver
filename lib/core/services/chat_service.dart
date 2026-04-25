import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/api_client.dart';
import '../models/chat_message.dart';

export '../models/chat_message.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _fcm  = FirebaseMessaging.instance;

  // ── Autenticação anônima no Firebase ─────────────────────────
  // Necessária para satisfazer as regras do Firestore
  // A identidade real é gerenciada pelo Laravel (senderId + rideId)

  Future<void> ensureAnonymousAuth() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  // ── Referências ───────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _messagesRef(String rideId) =>
    _db.collection('chats').doc(rideId).collection('messages');

  // ── Stream de mensagens em tempo real ─────────────────────────

  Stream<List<ChatMessage>> messagesStream(String rideId) {
    return _messagesRef(rideId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs
        .map((d) => ChatMessage.fromFirestore(d))
        .toList());
  }

  // ── Enviar mensagem ───────────────────────────────────────────

  Future<void> sendMessage({
    required String rideId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Garante autenticação antes de escrever
    await ensureAnonymousAuth();

    // 1. Salva no Firestore
    await _messagesRef(rideId).add({
      'senderId':   senderId,
      'senderRole': senderRole,
      'text':       trimmed,
      'createdAt':  FieldValue.serverTimestamp(),
      'read':       false,
    });

    // 2. Notificação FCM via backend — best-effort
    try {
      await ApiClient().dio.post('/chat/notify', data: {
        'ride_id':     rideId,
        'sender_role': senderRole,
        'text':        trimmed,
      });
    } catch (_) {}
  }

  // ── Marcar mensagens como lidas ───────────────────────────────

  Future<void> markAsRead({
    required String rideId,
    required String readerRole,
  }) async {
    await ensureAnonymousAuth();

    final opposite = readerRole == 'driver' ? 'passenger' : 'driver';
    final unread   = await _messagesRef(rideId)
      .where('senderRole', isEqualTo: opposite)
      .where('read', isEqualTo: false)
      .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Contagem de não lidas (stream) ────────────────────────────

  Stream<int> unreadCountStream({
    required String rideId,
    required String readerRole,
  }) {
    final opposite = readerRole == 'driver' ? 'passenger' : 'driver';
    return _messagesRef(rideId)
      .where('senderRole', isEqualTo: opposite)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);
  }

  // ── FCM: salvar/atualizar token no backend ────────────────────

  Future<void> saveFcmToken() async {
    try {
      await _fcm.requestPermission();
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiClient().dio.post('/fcm/token', data: {'token': token});
      }
      _fcm.onTokenRefresh.listen((newToken) async {
        try {
          await ApiClient().dio.post('/fcm/token', data: {'token': newToken});
        } catch (_) {}
      });
    } catch (_) {}
  }
}