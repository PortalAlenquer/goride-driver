import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WebSocketService — Singleton
//
// Protocolo: Pusher (Laravel Reverb é compatível)
// Canal público  → subscribeToPublic('rides')    → ride.requested
// Canal privado  → subscribeToRide('uuid')        → private-ride.{id}
//
// Reconexão automática com backoff exponencial: 5s → 10s → 20s
// Re-subscrição automática de todos os canais após reconexão
// ─────────────────────────────────────────────────────────────────────────────

typedef WsEventCallback = void Function(Map<String, dynamic> payload);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // ── Conexão ───────────────────────────────────────────────────
  static const _wsUrl = 'ws://89.116.73.59:8083/app/goride2-key';

  WebSocketChannel?   _channel;
  StreamSubscription? _sub;
  Timer?              _pingTimer;
  Timer?              _reconnectTimer;
  String?             _socketId;

  bool _connected        = false;
  bool _intentionalClose = false;
  int  _reconnectDelay   = 5;

  // ── Canais ativos ─────────────────────────────────────────────
  final Set<String> _publicChannels = {};
  String?           _privateRideId;

  // ── Listeners ─────────────────────────────────────────────────
  final Map<String, List<WsEventCallback>> _listeners = {};

  bool get isConnected => _connected;

  // ─────────────────────────────────────────────────────────────
  // Conectar
  // ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_connected) return;
    _intentionalClose = false;
    _reconnectDelay   = 5;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _sub     = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
      );
      _pingTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _sendPing());
    } catch (_) {
      _scheduleReconnect();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Canais públicos — ex: 'rides'
  // ─────────────────────────────────────────────────────────────

  Future<void> subscribeToPublic(String channelName) async {
    if (!_connected) await connect();
    if (_publicChannels.contains(channelName)) return;
    _publicChannels.add(channelName);
    _send({'event': 'pusher:subscribe', 'data': {'channel': channelName}});
  }

  // ─────────────────────────────────────────────────────────────
  // Canal privado — private-ride.{rideId}
  // ─────────────────────────────────────────────────────────────

  Future<void> subscribeToRide(String rideId) async {
    if (!_connected) await connect();
    if (_privateRideId == rideId) return;

    if (_privateRideId != null) {
      _send({'event': 'pusher:unsubscribe',
             'data': {'channel': 'private-ride.$_privateRideId'}});
    }

    _privateRideId    = rideId;
    final channelName = 'private-ride.$rideId';
    final auth        = await _authPrivateChannel(channelName);
    if (auth == null) return;

    _send({
      'event': 'pusher:subscribe',
      'data':  {'channel': channelName, 'auth': auth['auth']},
    });
  }

  void leaveRide(String rideId) {
    if (_privateRideId != rideId) return;
    _send({'event': 'pusher:unsubscribe',
           'data': {'channel': 'private-ride.$rideId'}});
    _privateRideId = null;
  }

  Future<Map<String, dynamic>?> _authPrivateChannel(String channelName) async {
    try {
      if (_socketId == null) return null;
      final res = await ApiClient().dio.post(
        '/broadcasting/auth',
        data: {'socket_id': _socketId, 'channel_name': channelName},
      );
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Listeners
  // ─────────────────────────────────────────────────────────────

  void on(String event, WsEventCallback cb) =>
      _listeners.putIfAbsent(event, () => []).add(cb);

  void off(String event, [WsEventCallback? cb]) {
    if (cb == null) {
      _listeners.remove(event);
    } else {
      _listeners[event]?.remove(cb);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Desconectar
  // ─────────────────────────────────────────────────────────────

  void disconnect() {
    _intentionalClose = true;
    _publicChannels.clear();
    _privateRideId = null;
    _cleanup();
  }

  // ─────────────────────────────────────────────────────────────
  // Internos
  // ─────────────────────────────────────────────────────────────

  void _onMessage(dynamic raw) {
    try {
      final msg     = jsonDecode(raw as String) as Map<String, dynamic>;
      final event   = msg['event']  as String?;
      final dataRaw = msg['data'];

      switch (event) {
        case 'pusher:connection_established':
          final data = dataRaw is String ? jsonDecode(dataRaw) : dataRaw;
          _socketId       = data['socket_id']?.toString();
          _connected      = true;
          _reconnectDelay = 5;
          _resubscribeAll();
          return;
        case 'pusher:pong':
        case 'pusher_internal:subscription_succeeded':
        case 'pusher:error':
          return;
      }

      if (event == null) return;

      final Map<String, dynamic> payload = switch (dataRaw) {
        String s => (jsonDecode(s) as Map<String, dynamic>?) ?? {},
        Map    m => Map<String, dynamic>.from(m),
        _        => {},
      };

      final callbacks = _listeners[event];
      if (callbacks != null) {
        for (final cb in List<WsEventCallback>.from(callbacks)) {
          cb(payload);
        }
      }
    } catch (_) {}
  }

  void _resubscribeAll() {
    for (final ch in Set<String>.from(_publicChannels)) {
      _send({'event': 'pusher:subscribe', 'data': {'channel': ch}});
    }
    if (_privateRideId != null) {
      final prev = _privateRideId!;
      _privateRideId = null;
      subscribeToRide(prev);
    }
  }

  void _onError(dynamic _) {
    _connected = false;
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _onDone() {
    _connected = false;
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _sendPing() => _send({'event': 'pusher:ping', 'data': {}});

  void _send(Map<String, dynamic> data) {
    try { _channel?.sink.add(jsonEncode(data)); } catch (_) {}
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _connected = false;
    _socketId  = null;
  }

  void _scheduleReconnect() {
    _cleanup();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (_intentionalClose) return;
      _reconnectDelay = (_reconnectDelay * 2).clamp(5, 20);
      _doConnect();
    });
  }
}
