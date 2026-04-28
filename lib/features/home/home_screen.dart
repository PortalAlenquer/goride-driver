import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/config/app_theme.dart';
import 'home_controller.dart';
import 'widgets/home_bottom_panel.dart';
import 'widgets/home_ride_request_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = HomeController();
    _ctrl.addListener(_onControllerUpdate);

    _ctrl.onShowRideRequest = _showRideRequest;
    _ctrl.onRideMarkerTap   = _showMapRideSheet;
    _ctrl.onNavigateToRide  = () {
      final id = _ctrl.activeNavigateRideId;
      if (id != null && mounted) context.go('/ride-detail/$id');
    };
    _ctrl.onRideCancelledExternally = () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Corrida não está mais disponível.'),
          backgroundColor: AppTheme.warning,
          duration:        Duration(seconds: 3),
        ),
      );
      _ctrl.clearRide();
    };

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ctrl.startUserPolling();
      if (_ctrl.isOnline && !_ctrl.hasNewRide) _ctrl.startWsRideListener();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Sheet de corrida — WS / FCM
  // ─────────────────────────────────────────────────────────────

  void _showRideRequest() {
    if (_ctrl.pendingRide == null || !mounted) return;
    showModalBottomSheet(
      context:       context,
      isDismissible: false,
      enableDrag:    false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HomeRideRequestSheet(
        ride:           _ctrl.pendingRide!,
        timeoutSeconds: 20,
        onAccept: () => _acceptRide(_ctrl.pendingRide!['id']?.toString() ?? ''),
        onReject: () async {
          final rideId = _ctrl.pendingRide?['id']?.toString();
          if (rideId != null && rideId.isNotEmpty) {
            try { await _ctrl.homeService.rejectRide(rideId); } catch (_) {}
          }
        },
      ),
    ).whenComplete(() => _ctrl.clearRide());
  }

  // ─────────────────────────────────────────────────────────────
  // Sheet de corrida — pino no mapa
  // Usa rideClosedStream para fechar via WS sem polling
  // ─────────────────────────────────────────────────────────────

  void _showMapRideSheet(Map<String, dynamic> ride) {
    final rideId = ride['id'].toString();
    showModalBottomSheet(
      context:       context,
      isDismissible: true,
      enableDrag:    true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HomeRideRequestSheet(
        ride:             ride,
        rideClosedStream: _ctrl.rideClosedStream, // ← WS fecha o sheet
        onAccept:         () => _acceptRide(rideId),
        onReject: () async {
          try { await _ctrl.homeService.rejectRide(rideId); } catch (_) {}
        },
      ),
    ).whenComplete(() => _ctrl.removeRideFromLayer(rideId));
  }

  Future<void> _acceptRide(String rideId) async {
    try {
      await _ctrl.homeService.acceptRide(rideId);
      if (mounted) context.go('/ride-detail/$rideId');
    } catch (e) {
      if (!mounted) return;
      String msg = 'Erro ao aceitar corrida.';
      try {
        final data = (e as dynamic).response?.data;
        msg = data?['message'] as String? ?? msg;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.warning),
      );
    }
  }

  Future<void> _toggleOnline() async {
    final error = await _ctrl.toggleOnline();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.warning),
      );
    }
  }

  void _centerMap() {
    if (_ctrl.currentPosition == null) return;
    _ctrl.mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          _ctrl.currentPosition!.latitude,
          _ctrl.currentPosition!.longitude,
        ),
        15,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_ctrl.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title:   const Text('Sair do app?'),
            content: const Text('Deseja realmente fechar o aplicativo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Não'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                child: const Text('Sim, sair'),
              ),
            ],
          ),
        );
        if ((shouldExit ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Stack(children: [

          // ── Mapa ──────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _ctrl.currentPosition != null
                ? LatLng(_ctrl.currentPosition!.latitude,
                         _ctrl.currentPosition!.longitude)
                : const LatLng(-15.7801, -47.9292),
              zoom: 15,
            ),
            myLocationEnabled:       true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled:     false,
            circles:  _ctrl.circles,
            markers:  _ctrl.rideMarkers,
            onMapCreated: (c) => _ctrl.mapController = c,
          ),

          // ── Topo — saldo + perfil ─────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Card saldo
                  GestureDetector(
                    onTap: () => context.go('/wallet'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: _ctrl.isBalanceNegative
                              ? AppTheme.danger.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        )],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (_ctrl.isBalanceNegative
                                    ? AppTheme.danger
                                    : AppTheme.secondary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: _ctrl.isBalanceNegative
                                ? AppTheme.danger
                                : AppTheme.secondary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Saldo',
                              style: TextStyle(
                                  fontSize: 10, color: AppTheme.gray)),
                            Text(_ctrl.balanceLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize:   15,
                                color: _ctrl.isBalanceNegative
                                    ? AppTheme.danger
                                    : AppTheme.dark,
                              )),
                          ],
                        ),
                      ]),
                    ),
                  ),

                  const Spacer(),

                  // Botão perfil com badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _MapIconBtn(
                        icon:  Icons.person_outline,
                        color: AppTheme.dark,
                        onTap: () => context.go('/profile'),
                      ),
                      if (_ctrl.unreadNotifications > 0)
                        Positioned(
                          right: -4, top: -4,
                          child: Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(
                              color:  AppTheme.danger,
                              shape:  BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                _ctrl.unreadNotifications > 9
                                    ? '9+'
                                    : '${_ctrl.unreadNotifications}',
                                style: const TextStyle(
                                  fontSize:   9,
                                  color:      Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Coluna lateral direita ─────────────────────────
          Positioned(
            top: 100, right: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  _LayerBtn(
                    icon:    Icons.location_on,
                    label:   'Agora',
                    color:   Colors.green.shade600,
                    active:  _ctrl.layerRides,
                    badge:   _ctrl.layerRides ? _ctrl.ridesCount : 0,
                    loading: _ctrl.mapPanelLoading &&
                             !_ctrl.layerHeat && !_ctrl.layerDrivers,
                    onTap:   _ctrl.toggleLayerRides,
                  ),

                  const SizedBox(height: 10),

                  _LayerBtn(
                    icon:    Icons.local_fire_department,
                    label:   '20min',
                    color:   Colors.deepOrange,
                    active:  _ctrl.layerHeat,
                    badge:   _ctrl.layerHeat ? _ctrl.heatCount : 0,
                    loading: _ctrl.mapPanelLoading &&
                             !_ctrl.layerRides && !_ctrl.layerDrivers,
                    onTap:   _ctrl.toggleLayerHeat,
                  ),

                  const SizedBox(height: 10),

                  _LayerBtn(
                    icon:    Icons.directions_car,
                    label:   'Outros',
                    color:   Colors.blue,
                    active:  _ctrl.layerDrivers,
                    badge:   _ctrl.layerDrivers ? _ctrl.driversCount : 0,
                    loading: _ctrl.mapPanelLoading &&
                             !_ctrl.layerRides && !_ctrl.layerHeat,
                    onTap:   _ctrl.toggleLayerDrivers,
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: 36, height: 1,
                    color: Colors.grey.shade300,
                  ),

                  const SizedBox(height: 20),

                  _MapIconBtn(
                    icon:  Icons.my_location,
                    color: AppTheme.primary,
                    onTap: _centerMap,
                  ),
                ],
              ),
            ),
          ),

          // ── Legenda heatmap ───────────────────────────────
          if (_ctrl.layerHeat && _ctrl.heatLastUpdate != null)
            Positioned(
              bottom: 180, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                  )],
                ),
                child: Row(children: [
                  const Icon(Icons.local_fire_department,
                      size: 12, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Text(
                    'Demanda últ. 20min · '
                    '${_ctrl.heatLastUpdate!.hour.toString().padLeft(2, '0')}:'
                    '${_ctrl.heatLastUpdate!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.gray),
                  ),
                ]),
              ),
            ),

          // ── Painel inferior ───────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: HomeBottomPanel(
              isOnline:       _ctrl.isOnline,
              needsVehicle:   _ctrl.needsVehicle,
              needsApproval:  _ctrl.needsApproval,
              rating:         _ctrl.driverInfo?['rating']?.toString() ?? '5.0',
              balanceLabel:   _ctrl.balanceLabel,
              onToggleOnline: _toggleOnline,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Widgets locais
// ─────────────────────────────────────────────────────────────────

class _LayerBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final bool     active;
  final bool     loading;
  final int      badge;
  final VoidCallback onTap;

  const _LayerBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.loading,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color:      Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          )],
        ),
        child: loading
          ? Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: active ? Colors.white : color,
                ),
              ),
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                        size:  20,
                        color: active ? Colors.white : color),
                      const SizedBox(height: 2),
                      Text(label,
                        style: TextStyle(
                          fontSize:   8,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppTheme.gray,
                        )),
                    ],
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4, top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color:        active ? Colors.white : color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: TextStyle(
                          fontSize:   8,
                          fontWeight: FontWeight.bold,
                          color:      active ? color : Colors.white,
                        )),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

class _MapIconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  const _MapIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color:      Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          )],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}