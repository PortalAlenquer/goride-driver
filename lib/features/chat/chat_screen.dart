import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String currentUserId;
  final String currentUserRole;   // 'driver' | 'passenger'
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chat       = ChatService();
  bool _sending     = false;

  @override
  void initState() {
    super.initState();
    _chat.markAsRead(
      rideId:     widget.rideId,
      readerRole: widget.currentUserRole,
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Envio ─────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textCtrl.clear();

    await _chat.sendMessage(
      rideId:     widget.rideId,
      senderId:   widget.currentUserId,
      senderRole: widget.currentUserRole,
      text:       text,
    );

    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.currentUserRole == 'driver';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isDriver
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.secondary.withValues(alpha: 0.1),
            child: Text(
              widget.otherUserName.isNotEmpty
                ? widget.otherUserName[0].toUpperCase()
                : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDriver ? AppTheme.primary : AppTheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.otherUserName,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                isDriver ? 'Passageiro' : 'Motorista',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.gray,
                  fontWeight: FontWeight.normal)),
            ],
          ),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Seu número não é compartilhado',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.lock, size: 12, color: AppTheme.secondary),
                  SizedBox(width: 4),
                  Text('Privado',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Aviso de privacidade ─────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
            color: AppTheme.secondary.withValues(alpha: 0.05),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, size: 13, color: AppTheme.secondary),
                SizedBox(width: 6),
                Text(
                  'Seus dados pessoais estão protegidos',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // ── Lista de mensagens ───────────────────────────────
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chat.messagesStream(widget.rideId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snap.data ?? [];

                if (messages.isEmpty) {
                  return _EmptyChat(otherName: widget.otherUserName);
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg    = messages[i];
                    final prev   = i > 0 ? messages[i - 1] : null;
                    final isMine = msg.senderRole == widget.currentUserRole;
                    final showDate = prev == null ||
                      !_sameDay(prev.createdAt, msg.createdAt);

                    return Column(children: [
                      if (showDate) _DateDivider(date: msg.createdAt),
                      _MessageBubble(message: msg, isMine: isMine),
                    ]);
                  },
                );
              },
            ),
          ),

          // ── Campo de envio ───────────────────────────────────
          _InputBar(
            controller: _textCtrl,
            sending:    _sending,
            onSend:     _send,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ── Estado vazio ──────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String otherName;
  const _EmptyChat({required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
            size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Nenhuma mensagem ainda.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Diga olá para $otherName!',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Campo de entrada ──────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Digite uma mensagem...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: sending ? null : onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: sending
                ? AppTheme.secondary.withValues(alpha: 0.5)
                : AppTheme.secondary,
              shape: BoxShape.circle,
            ),
            child: sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ── Bolha de mensagem ─────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.secondary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4  : 18),
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.text,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.white : AppTheme.dark,
                height: 1.4,
              )),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.gray,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.read ? Icons.done_all : Icons.done,
                    size: 12,
                    color: message.read
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2,'0')}:'
           '${dt.minute.toString().padLeft(2,'0')}';
  }
}

// ── Separador de data ─────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime? date;
  const _DateDivider({this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date!.year, date!.month, date!.day);

    final label = d == today
      ? 'Hoje'
      : d == today.subtract(const Duration(days: 1))
        ? 'Ontem'
        : '${date!.day.toString().padLeft(2,'0')}/'
          '${date!.month.toString().padLeft(2,'0')}/'
          '${date!.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ]),
    );
  }
}