import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/helpers/maps_helper.dart';
import '../../core/models/ride_model.dart';
import '../../core/services/ride_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/websocket_service.dart';
import '../chat/chat_screen.dart';
import '../home/widgets/home_ride_request_sheet.dart';
import 'widgets/ride_header_btn.dart';
import 'widgets/ride_status_stepper.dart';
import 'widgets/ride_passenger_card.dart';
import 'widgets/ride_action_cards.dart';
import 'widgets/slide_action_button.dart'; // RideSlider + SlideActionButton

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final _rideService = RideService();
  final _chat        = ChatService();
  final _ws          = WebSocketService();

  GoogleMapController? _mapController;
  RideModel? _ride;
  bool _loading    = true;
  bool _actionBusy = false;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  LatLng? _originLatLng;
  LatLng? _destinationLatLng;

  // Flag: evita chamar _buildMap antes do controller existir
  bool _mapReady = false;

  // back-to-back
  RideModel? _nextRide;
  bool _sheetShowing = false;

  @override
  void initState() {
    super.initState();
    _loadRide();
    _connectWS();
    _startPolling();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _ws
      ..off('ride.status.updated')
      ..off('driver.location.updated')
      ..leaveRide(widget.rideId);
    super.dispose();
  }

  // ── WebSocket ─────────────────────────────────────────────────

  Future<void> _connectWS() async {
    await _ws.connect();
    await _ws.subscribeToRide(widget.rideId);

    _ws.on('ride.status.updated', (payload) async {
      if (!mounted) return;
      final newStatus = payload['status']?.toString();
      if (newStatus == null) return;
      if (_ride != null) {
        setState(() => _ride = _ride!.copyWithStatus(newStatus));
      }
      // Reload completo em transições críticas
      if (newStatus == 'cancelled' || newStatus == 'payment_confirmed') {
        await _loadRide();
      }
    });

    _ws.on('driver.location.updated', (payload) {
      if (!mounted) return;
      final lat = double.tryParse(payload['lat']?.toString() ?? '');
      final lng = double.tryParse(payload['lng']?.toString() ?? '');
      if (lat == null || lng == null) return;
      final pos = LatLng(lat, lng);
      final updated = Set<Marker>.from(_markers)
        ..removeWhere((m) => m.markerId.value == 'driver')
        ..add(Marker(
          markerId: const MarkerId('driver'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet),
          infoWindow: const InfoWindow(title: 'Você'),
        ));
      setState(() => _markers = updated);
    });
  }

  // ── Polling fallback — 8s ─────────────────────────────────────

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 8));
      if (!mounted) return false;
      if (_ride != null && !_ride!.isActive) return false;
      await _loadRide();
      if (_ride?.status == 'in_progress') await _checkNextRide();
      return mounted;
    });
  }

  // ── Carregamento ──────────────────────────────────────────────

  Future<void> _loadRide() async {
    try {
      final ride = await _rideService.getRide(widget.rideId);
      if (!mounted) return;
      setState(() { _ride = ride; _loading = false; });
      // Só atualiza o mapa se o controller já existir
      if (_mapReady) await _buildMap();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Mapa ──────────────────────────────────────────────────────
  //
  // FIX tela escura:
  // - onMapCreated apenas salva o controller e seta _mapReady = true
  // - _buildMap() só é chamado depois que _ride E o controller existem
  // - Nenhum setState dentro do onMapCreated

  Future<void> _buildMap() async {
    if (_ride == null || _mapController == null) return;

    final oLat = _ride!.originLat;
    final oLng = _ride!.originLng;
    final dLat = _ride!.destinationLat;
    final dLng = _ride!.destinationLng;

    if (oLat == null || oLng == null) return;

    _originLatLng      = LatLng(oLat, oLng);
    _destinationLatLng = (dLat != null && dLng != null)
        ? LatLng(dLat, dLng) : null;

    final markers = <Marker>{};

    markers.add(Marker(
      markerId: const MarkerId('origin'),
      position: _originLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title:   'Embarque',
        snippet: _ride!.originAddress ?? ''),
    ));

    if (_destinationLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title:   'Destino',
          snippet: _ride!.destinationAddress ?? ''),
      ));
    }

    if (!mounted) return;
    setState(() => _markers = markers);

    if (_destinationLatLng != null) {
      final centerLat = (oLat + (dLat ?? oLat)) / 2;
      final centerLng = (oLng + (dLng ?? oLng)) / 2;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLng), 13));
      await _drawPolyline();
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_originLatLng!, 15));
    }
  }

  Future<void> _drawPolyline() async {
    if (_originLatLng == null || _destinationLatLng == null) return;
    final points = await MapsHelper.getRoute(
      origin:      _originLatLng!,
      destination: _destinationLatLng!,
    );
    if (points.isEmpty || !mounted) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points:     points,
          color:      AppTheme.primary,
          width:      4,
          jointType:  JointType.round,
          startCap:   Cap.roundCap,
          endCap:     Cap.roundCap,
        ),
      };
    });
  }

  // ── Back-to-back ──────────────────────────────────────────────

  Future<void> _checkNextRide() async {
    if (_nextRide != null) return;
    try {
      final rides = await _rideService.getPendingRides();
      if (rides.isNotEmpty && mounted) {
        await HapticFeedback.lightImpact();
        setState(() => _nextRide = rides.first);
      }
    } catch (_) {}
  }

  Future<void> _acceptNextRide() async {
    if (_nextRide == null) return;
    try {
      await _rideService.acceptRide(_nextRide!.id);
      setState(() => _nextRide = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('Próxima corrida confirmada!'),
          backgroundColor: AppTheme.secondary,
          duration:        Duration(seconds: 3),
        ));
      }
    } catch (_) {}
  }

  Future<void> _rejectNextRide() async {
    if (_nextRide == null) return;
    try { await _rideService.rejectRide(_nextRide!.id); } catch (_) {}
    if (mounted) setState(() => _nextRide = null);
  }

  void _showNextRideSheet() {
    if (_nextRide == null || _sheetShowing) return;
    _sheetShowing = true;
    showModalBottomSheet(
      context:       context,
      isDismissible: false,
      enableDrag:    false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => HomeRideRequestSheet(
        ride:     _nextRide!.toSheetMap(),
        // Sheet fecha sozinho — NÃO chamar Navigator.pop nos callbacks
        onAccept: () async {
          await _acceptNextRide();
        },
        onReject: () async {
          await _rejectNextRide();
        },
      ),
    ).whenComplete(() => _sheetShowing = false);
  }

  // ── Ações ─────────────────────────────────────────────────────

  Future<void> _updateStatus(String status) async {
    setState(() => _actionBusy = true);
    try {
      await _rideService.updateStatus(widget.rideId, status);

      // Navega para home — não faz mais nada após isso
      if (status == 'payment_confirmed' || status == 'cancelled') {
        if (mounted) context.push('/home');
        return;
      }

      // Para outros status, recarrega os dados da corrida
      await _loadRide();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('Erro ao atualizar status. Tente novamente.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      // Só faz setState se ainda estiver na tela
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _openChat() {
    final myId      = _ride?.driver?.userId ?? _ride?.driver?.id ?? '';
    final otherName = _ride?.passenger?.name ?? 'Passageiro';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        rideId:          widget.rideId,
        currentUserId:   myId,
        currentUserRole: 'driver',
        otherUserName:   otherName,
      ),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────

  String get _status  => _ride?.status ?? '';
  bool   get _canChat => _ride?.isActive ?? false;

  // Só retorna próximo para accepted e driver_arriving
  // in_progress → completed e completed → payment_confirmed são tratados
  // diretamente no build com RideSlider próprio
  String? get _nextStatus => switch (_status) {
    'accepted'        => 'driver_arriving',
    'driver_arriving' => 'in_progress',
    _                 => null,
  };

  String _slideLabel(String next) => switch (next) {
    'driver_arriving' => 'Deslize — A caminho',
    'in_progress'     => 'Deslize — Passageiro embarcou',
    'completed'       => 'Deslize — Finalizar corrida',
    _                 => '',
  };

  String? _slideSublabel(String next) => switch (next) {
    'driver_arriving' => 'Confirme que está a caminho',
    'in_progress'     => 'Inicie a viagem',
    'completed'       => 'Chegou ao destino',
    _                 => null,
  };

  Color _slideColor(String next) => switch (next) {
    'driver_arriving' => AppTheme.primary,
    'in_progress'     => AppTheme.secondary,
    'completed'       => AppTheme.danger,
    _                 => AppTheme.gray,
  };

  IconData _slideIcon(String next) => switch (next) {
    'driver_arriving' => Icons.directions_car,
    'in_progress'     => Icons.person,
    'completed'       => Icons.flag,
    _                 => Icons.arrow_forward,
  };

  String _statusLabel(String s) => switch (s) {
    'accepted'          => 'Corrida aceita',
    'driver_arriving'   => 'A caminho',
    'in_progress'       => 'Em viagem',
    'completed'         => 'Finalizada',
    'payment_confirmed' => 'Pagamento confirmado',
    'cancelled'         => 'Cancelada',
    _                   => s,
  };

  Color _statusColor(String s) => switch (s) {
    'accepted'          => AppTheme.primary,
    'driver_arriving'   => Colors.orange,
    'in_progress'       => AppTheme.secondary,
    'completed'         => Colors.green,
    'payment_confirmed' => Colors.green,
    'cancelled'         => AppTheme.danger,
    _                   => AppTheme.gray,
  };

  String _payLabel(String m) => switch (m) {
    'cash'   => 'Dinheiro',
    'pix'    => 'PIX',
    'card'   => 'Cartão',
    'wallet' => 'Carteira',
    _        => m,
  };

  // Labels do slide por próximo status
  String _nextLabel(String next) => switch (next) {
    'driver_arriving' => 'A caminho',
    'in_progress'     => 'Passageiro embarcou',
    _                 => next,
  };

  Color _nextColor(String next) => switch (next) {
    'driver_arriving' => AppTheme.primary,
    'in_progress'     => AppTheme.secondary,
    _                 => AppTheme.gray,
  };

  IconData _nextIcon(String next) => switch (next) {
    'driver_arriving' => Icons.directions_car,
    'in_progress'     => Icons.person,
    _                 => Icons.arrow_forward,
  };

  // Dialog de confirmação de cancelamento
  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar corrida?'),
        content: const Text(
          'Tem certeza que deseja cancelar esta corrida?\n'
          'O passageiro será notificado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Não, continuar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('cancelled');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.danger),
            child: const Text('Sim, cancelar')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()));
    }

    final next      = _nextStatus;
    final payMethod = _ride?.paymentMethod ?? '';

    return Scaffold(
      body: Stack(children: [

        // ── Mapa ─────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _originLatLng ?? const LatLng(-15.78, -47.93),
            zoom: 14,
          ),
          markers:                 _markers,
          polylines:               _polylines,
          myLocationEnabled:       true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled:     false,
          // FIX: onMapCreated NÃO chama _buildMap diretamente
          // Apenas salva o controller e agenda o build após o frame
          onMapCreated: (c) {
            _mapController = c;
            _mapReady      = true;
            // Aguarda o frame completar antes de animar a câmera
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _buildMap();
            });
          },
        ),

        // ── Header ───────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                        color:      Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8)],
                    ),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor(_status),
                          shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(_statusLabel(_status),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:      _statusColor(_status))),
                      if (_ws.isConnected) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.secondary,
                            shape: BoxShape.circle),
                        ),
                      ],
                    ]),
                  ),

                  const Spacer(),

                  if (_canChat)
                    StreamBuilder<int>(
                      stream: _chat.unreadCountStream(
                        rideId:     widget.rideId,
                        readerRole: 'driver',
                      ),
                      builder: (_, snap) => RideHeaderBtn(
                        icon:    Icons.chat_bubble_outline,
                        color:   AppTheme.primary,
                        onTap:   _openChat,
                        tooltip: 'Chat com passageiro',
                        badge:   (snap.data ?? 0) > 0 ? snap.data : null,
                      ),
                    ),
                ]),

                if (_nextRide != null && _status == 'in_progress') ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _showNextRideSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color:      AppTheme.secondary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset:     const Offset(0, 2))],
                      ),
                      child: const Row(children: [
                        Icon(Icons.electric_bolt,
                          color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nova corrida disponível! Toque para ver.',
                            style: TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize:   13),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                          color: Colors.white, size: 18),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Painel inferior ───────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24)),
              boxShadow: [BoxShadow(
                color: Colors.black12, blurRadius: 16)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                RideStatusStepper(currentStatus: _status),
                const SizedBox(height: 20),

                RidePassengerCard(
                  passenger:          _ride?.passenger,
                  payLabel:           _payLabel(payMethod),
                  price:              _ride?.price ?? 0.0,
                  originAddress:      _ride?.originAddress,
                  destinationAddress: _ride?.destinationAddress,
                  canChat:            _canChat,
                  onChatTap:          _canChat ? _openChat : null,
                  unreadStream: _canChat
                    ? _chat.unreadCountStream(
                        rideId:     widget.rideId,
                        readerRole: 'driver')
                    : null,
                ),

                const SizedBox(height: 16),

                if (_status == 'cancelled') ...[
                  RideCancelledCard(onDone: () => context.push('/home')),

                ] else if (_status == 'payment_confirmed') ...[
                  RideSuccessCard(onDone: () => context.push('/home')),

                // ── completed: só confirmar recebimento ──────────
                ] else if (_status == 'completed') ...[
                  RideSlider(
                    key:          const ValueKey('completed'),
                    confirmLabel: 'Confirmar recebimento',
                    confirmColor: Colors.green.shade600,
                    thumbIcon:    Icons.payments_outlined,
                    busy:         _actionBusy,
                    onConfirm:    () => _updateStatus('payment_confirmed'),
                  ),

                // ── in_progress: só finalizar ────────────────────
                ] else if (_status == 'in_progress') ...[
                  RideSlider(
                    key:          const ValueKey('in_progress'),
                    confirmLabel: 'Finalizar corrida',
                    confirmColor: AppTheme.danger,
                    thumbIcon:    Icons.flag,
                    busy:         _actionBusy,
                    onConfirm:    () => _updateStatus('completed'),
                  ),

                // ── accepted / driver_arriving: pode cancelar ────
                ] else if (next != null) ...[
                  RideSlider(
                    key:          ValueKey(next),
                    confirmLabel: _nextLabel(next),
                    rejectLabel:  'Cancelar',
                    confirmColor: _nextColor(next),
                    rejectColor:  AppTheme.danger,
                    thumbIcon:    _nextIcon(next),
                    busy:         _actionBusy,
                    onConfirm:    () => _updateStatus(next),
                    onReject:     _showCancelDialog,
                  ),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}