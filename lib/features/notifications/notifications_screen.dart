import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/api_client.dart';
import '../../core/config/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient();

  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int  _unread  = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.dio.get('/notifications');
      if (!mounted) return;
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(
            res.data['notifications'] ?? []);
        _unread  = res.data['unread_count'] ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await _api.dio.post('/notifications/$id/read');
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1 && _notifications[idx]['read'] == false) {
          _notifications[idx] = {..._notifications[idx], 'read': true};
          _unread = (_unread - 1).clamp(0, 999);
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.dio.post('/notifications/read-all');
      setState(() {
        _notifications = _notifications
            .map((n) => {...n, 'read': true})
            .toList();
        _unread = 0;
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers visuais
  // ─────────────────────────────────────────────────────────────

  IconData _icon(String type) => switch (type) {
    'warning' => Icons.warning_amber_rounded,
    'promo'   => Icons.local_offer_rounded,
    'system'  => Icons.settings_rounded,
    'ride'    => Icons.directions_car_rounded,
    _         => Icons.notifications_rounded,
  };

  Color _color(String type) => switch (type) {
    'warning' => AppTheme.warning,
    'promo'   => AppTheme.secondary,
    'system'  => AppTheme.primary,
    'ride'    => Colors.blue,
    _         => AppTheme.gray,
  };

  String _typeLabel(String type) => switch (type) {
    'warning' => 'Alerta',
    'promo'   => 'Promoção',
    'system'  => 'Sistema',
    'ride'    => 'Corrida',
    _         => 'Informativo',
  };

  String _timeAgo(String iso) {
    final dt   = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours   < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(children: [
          const Text('Avisos'),
          if (_unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        AppTheme.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_unread',
                style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ]),
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                itemBuilder: (_, i) => _buildCard(_notifications[i]),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
            size: 64, color: AppTheme.gray.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('Nenhum aviso por aqui',
            style: TextStyle(color: AppTheme.gray, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Você receberá alertas e informações aqui',
            style: TextStyle(color: AppTheme.gray, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final type  = n['type'] as String? ?? 'info';
    final read  = n['read'] as bool? ?? false;
    final color = _color(type);

    return GestureDetector(
      onTap: () {
        if (!read) _markRead(n['id'] as int);
        _showDetail(n);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color:        read ? Colors.white : color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: read
                ? Colors.transparent
                : color.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset:     const Offset(0, 2),
          )],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Ícone
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(type), color: color, size: 22),
              ),

              const SizedBox(width: 12),

              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:        color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _typeLabel(type),
                          style: TextStyle(
                            fontSize:   10,
                            color:      color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(n['created_at'] as String? ?? ''),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.gray),
                      ),
                    ]),

                    const SizedBox(height: 6),

                    Text(
                      n['title'] as String? ?? '',
                      style: TextStyle(
                        fontWeight: read ? FontWeight.w500 : FontWeight.bold,
                        fontSize:   14,
                        color:      AppTheme.dark,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      n['body'] as String? ?? '',
                      maxLines:  2,
                      overflow:  TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.gray),
                    ),
                  ],
                ),
              ),

              // Indicador de não lida
              if (!read)
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 4, left: 8),
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> n) {
    final type  = n['type'] as String? ?? 'info';
    final color = _color(type);

    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize:     0.3,
        maxChildSize:     0.9,
        expand:           false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color:        Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),

              // Ícone grande
              Center(
                child: Container(
                  padding:    const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(_icon(type), color: color, size: 40),
                ),
              ),
              const SizedBox(height: 20),

              // Badge tipo + data
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _typeLabel(type),
                    style: TextStyle(
                        color:      color,
                        fontWeight: FontWeight.w600,
                        fontSize:   12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timeAgo(n['created_at'] as String? ?? ''),
                  style: const TextStyle(
                      color: AppTheme.gray, fontSize: 12),
                ),
              ]),

              const SizedBox(height: 20),

              Text(
                n['title'] as String? ?? '',
                style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      AppTheme.dark,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                n['body'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 15, color: AppTheme.gray, height: 1.6),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}