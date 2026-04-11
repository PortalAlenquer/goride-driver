import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/helpers/maps_helper.dart';
import '../../core/models/ride_model.dart';
import '../../core/services/ride_service.dart';
import '../../core/services/chat_service.dart';
import '../chat/chat_screen.dart';
import '../home/widgets/home_ride_request_sheet.dart';
import 'widgets/ride_header_btn.dart';
import 'widgets/ride_status_stepper.dart';
import 'widgets/ride_passenger_card.dart';
import 'widgets/ride_action_cards.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final _rideService = RideService();
  final _chat        = ChatService();

  GoogleMapController? _mapController;
  RideModel? _ride;
  bool _loading    = true;
  bool _actionBusy = false;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  LatLng? _originLatLng;
  LatLng? _destinationLatLng;

  // ── Back-to-back ──────────────────────────────────────────────
  RideModel? _nextRide;       // próxima corrida enfileirada
  bool _sheetShowing = false; // evita abrir sheet duplo

  @override
  void initState() {
    super.initState();
    _loadRide();
    _startPolling();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Carregamento ──────────────────────────────────────────────

  Future<void> _loadRide() async {
    try {
      final ride = await _rideService.getRide(widget.rideId);
      setState(() {
        _ride    = ride;
        _loading = false;
      });
      await _buildMap();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Mapa ──────────────────────────────────────────────────────

  Future<void> _buildMap() async {
    if (_ride == null) return;

    final oLat = _ride!.originLat;
    final oLng = _ride!.originLng;
    final dLat = _ride!.destinationLat;
    final dLng = _ride!.destinationLng;

    if (oLat == null || oLng == null) return;

    _originLatLng      = LatLng(oLat, oLng);
    _destinationLatLng = (dLat != null && dLng != null)
        ? LatLng(dLat, dLng)
        : null;

    final markers = <Marker>{};

    markers.add(Marker(
      markerId: const MarkerId('origin'),
      position: _originLatLng!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title:   'Embarque',
        snippet: _ride!.originAddress ?? '',
      ),
    ));

    if (_destinationLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title:   'Destino',
          snippet: _ride!.destinationAddress ?? '',
        ),
      ));
    }

    setState(() => _markers = markers);

    if (_destinationLatLng != null) {
      final centerLat = (oLat + dLat!) / 2;
      final centerLng = (oLng + dLng!) / 2;
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

  // ── Polling ───────────────────────────────────────────────────

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 8));
      if (!mounted) return false;
      if (_ride != null && !_ride!.isActive) return false;
      await _loadRide();

      // Verifica próxima corrida apenas quando em viagem
      if (_ride?.status == 'in_progress') {
        await _checkNextRide();
      }

      return true;
    });
  }

  // ── Back-to-back ──────────────────────────────────────────────

  Future<void> _checkNextRide() async {
    if (_nextRide != null) return; // já tem uma enfileirada
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
          content: Text('Próxima corrida confirmada!'),
          backgroundColor: AppTheme.secondary,
          duration: Duration(seconds: 3),
        ));
      }
    } catch (_) {}
  }

  Future<void> _rejectNextRide() async {
    if (_nextRide == null) return;
    try {
      await _rideService.rejectRide(_nextRide!.id);
    } catch (_) {}
    if (mounted) setState(() => _nextRide = null);
  }

  void _showNextRideSheet() {
    if (_nextRide == null || _sheetShowing) return;
    _sheetShowing = true;

    // Reutiliza HomeRideRequestSheet via toSheetMap()
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag:    false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => HomeRideRequestSheet(
        ride:     _nextRide!.toSheetMap(),
        onAccept: () async {
          Navigator.pop(context);
          await _acceptNextRide();
        },
        onReject: () async {
          Navigator.pop(context);
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
      await _loadRide();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao atualizar status. Tente novamente.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
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

  String get _status => _ride?.status ?? '';
  bool get _canChat  => _ride?.isActive ?? false;

  String? get _nextStatus => switch (_status) {
    'accepted'        => 'driver_arriving',
    'driver_arriving' => 'in_progress',
    'in_progress'     => 'completed',
    'completed'       => 'payment_confirmed',
    _                 => null,
  };

  String _nextLabel(String? next) => switch (next) {
    'driver_arriving'   => 'Iniciar — A caminho',
    'in_progress'       => 'Passageiro embarcou',
    'completed'         => 'Finalizar corrida',
    'payment_confirmed' => 'Confirmar recebimento',
    _                   => '',
  };

  Color _nextColor(String? next) => switch (next) {
    'driver_arriving'   => AppTheme.primary,
    'in_progress'       => AppTheme.secondary,
    'completed'         => AppTheme.danger,
    'payment_confirmed' => Colors.green.shade600,
    _                   => AppTheme.gray,
  };

  IconData _nextIcon(String? next) => switch (next) {
    'driver_arriving'   => Icons.directions_car,
    'in_progress'       => Icons.person,
    'completed'         => Icons.flag,
    'payment_confirmed' => Icons.check_circle,
    _                   => Icons.circle,
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
    'payment_confirmed' => Colors.green.shade700,
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

        // ── Mapa ───────────────────────────────────────────────
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
          onMapCreated: (c) {
            _mapController = c;
            _buildMap();
          },
        ),

        // ── Header ─────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [

                  // Badge de status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
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
                          color: _statusColor(_status))),
                    ]),
                  ),

                  const Spacer(),

                  // Botão chat
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

                // ── Banner back-to-back ───────────────────────
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
                          color: AppTheme.secondary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        const Icon(Icons.electric_bolt,
                          color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Nova corrida disponível! Toque para ver.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                          color: Colors.white, size: 18),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Painel inferior ────────────────────────────────────
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

                if (_status == 'completed') ...[
                  RidePaymentConfirmCard(
                    payMethod: payMethod,
                    price:     _ride?.price ?? 0.0,
                    onConfirm: () => _updateStatus('payment_confirmed'),
                    busy:      _actionBusy,
                  ),
                ] else if (_status == 'payment_confirmed') ...[
                  RideSuccessCard(onDone: () => context.go('/home')),
                ] else if (_status == 'cancelled') ...[
                  RideCancelledCard(onDone: () => context.go('/home')),
                ] else if (next != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _actionBusy
                        ? null
                        : () => _updateStatus(next),
                      icon: _actionBusy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : Icon(_nextIcon(next), size: 20),
                      label: Text(_nextLabel(next),
                        style: const TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _nextColor(next),
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
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