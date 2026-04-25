import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/ride_model.dart';
import '../../core/services/ride_service.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final _service    = RideService();
  final _scrollCtrl = ScrollController();

  List<RideModel> _rides      = [];
  bool _loading               = true;   // carregamento inicial
  bool _loadingMore           = false;  // carregando próxima página
  bool _hasMore               = true;
  int  _currentPage           = 1;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Scroll listener — dispara load quando chega perto do fim ──

  void _onScroll() {
    final threshold = _scrollCtrl.position.maxScrollExtent - 200;
    if (_scrollCtrl.position.pixels >= threshold &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  // ── Carregamento inicial ──────────────────────────────────────

  Future<void> _loadPage(int page) async {
    try {
      final result = await _service.getRideHistory(page: page);
      setState(() {
        _rides       = result.rides;
        _currentPage = result.currentPage;
        _hasMore     = result.hasMore;
        _loading     = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Carrega próxima página ────────────────────────────────────

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _service.getRideHistory(page: _currentPage + 1);
      setState(() {
        _rides.addAll(result.rides);
        _currentPage = result.currentPage;
        _hasMore     = result.hasMore;
      });
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Pull-to-refresh ───────────────────────────────────────────

  Future<void> _refresh() async {
    setState(() { _hasMore = true; _currentPage = 1; });
    await _loadPage(1);
  }

  // ── Helpers de status ─────────────────────────────────────────

  Color _statusColor(String status) => switch (status) {
    'completed'       => AppTheme.secondary,
    'cancelled'       => AppTheme.danger,
    'in_progress'     => AppTheme.primary,
    _                 => AppTheme.warning,
  };

  String _statusLabel(String status) => switch (status) {
    'completed'       => 'Concluída',
    'cancelled'       => 'Cancelada',
    'in_progress'     => 'Em andamento',
    'searching'       => 'Buscando',
    'accepted'        => 'Aceita',
    'driver_arriving' => 'A caminho',
    _                 => status,
  };

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Histórico de corridas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/profile'),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _rides.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: _refresh,
              color: AppTheme.secondary,
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                // +1 para o indicador de loading no fim
                itemCount: _rides.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  // Último item → indicador de carregamento
                  if (i == _rides.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.secondary)),
                    );
                  }
                  final ride = _rides[i];
                  return _RideCard(
                    ride:        ride,
                    statusColor: _statusColor(ride.status),
                    statusLabel: _statusLabel(ride.status),
                  );
                },
              ),
            ),
    );
  }
}

// ── Card de corrida ───────────────────────────────────────────────

class _RideCard extends StatelessWidget {
  final RideModel ride;
  final Color statusColor;
  final String statusLabel;

  const _RideCard({
    required this.ride,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Status + valor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
              ),
              Text(
                'R\$ ${ride.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
            ],
          ),

          const SizedBox(height: 12),

          // Origem
          Row(children: [
            const Icon(Icons.my_location,
              color: AppTheme.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              ride.originAddress ?? '—',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),

          // Destino
          Row(children: [
            const Icon(Icons.location_on,
              color: AppTheme.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              ride.destinationAddress ?? '—',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis)),
          ]),

          const SizedBox(height: 12),

          // Distância + data
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (ride.distanceKm != null)
                _InfoChip(
                  icon:  Icons.route,
                  label: '${ride.distanceKm!.toStringAsFixed(1)} km'),
              if (ride.createdAt != null)
                _InfoChip(
                  icon:  Icons.calendar_today,
                  label: _formatDate(ride.createdAt!)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';
}

// ── Estado vazio ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined,
            size: 64, color: AppTheme.gray),
          SizedBox(height: 16),
          Text('Nenhuma corrida ainda',
            style: TextStyle(fontSize: 18, color: AppTheme.gray)),
        ],
      ),
    );
  }
}

// ── Chip de info ──────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: AppTheme.gray),
      const SizedBox(width: 4),
      Text(label,
        style: const TextStyle(fontSize: 12, color: AppTheme.gray)),
    ]);
  }
}