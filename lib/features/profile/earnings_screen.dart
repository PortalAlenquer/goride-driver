import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final _api = ApiClient();

  String _period = 'week';
  bool   _loading = true;
  int    _page    = 1;
  bool   _loadingMore = false;

  Map<String, dynamic>  _summary = {};
  List<dynamic>         _daily   = [];
  List<dynamic>         _rides   = [];
  int                   _totalPages = 1;

  static const _periods = [
    ('today', 'Hoje'),
    ('week',  'Semana'),
    ('month', 'Mês'),
    ('all',   'Total'),
  ];

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento ──────────────────────────────────────────────

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() { _loading = true; _page = 1; _rides = []; });
    }
    try {
      final res = await _api.dio.get(
        '/driver/earnings',
        queryParameters: {'period': _period, 'page': _page},
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _summary    = data['summary'] ?? {};
        _daily      = data['daily']   ?? [];
        if (reset) {
          _rides = data['rides'] ?? [];
        } else {
          _rides.addAll(data['rides'] ?? []);
        }
        _totalPages = data['pagination']?['pages'] ?? 1;
        _loading    = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() { _loadingMore = true; _page++; });
    await _load(reset: false);
  }

  void _changePeriod(String period) {
    if (_period == period) return;
    setState(() => _period = period);
    _load();
  }

  // ── Formatação ────────────────────────────────────────────────

  String _currency(dynamic val) {
    final d = double.tryParse(val?.toString() ?? '0') ?? 0.0;
    return 'R\$ ${d.toStringAsFixed(2)}';
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
             '${dt.month.toString().padLeft(2, '0')} '
             '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return '—'; }
  }

  String _payLabel(String? m) => switch (m) {
    'cash'   => 'Dinheiro',
    'pix'    => 'PIX',
    'card'   => 'Cartão',
    'wallet' => 'Carteira',
    _        => m ?? '—',
  };

  IconData _payIcon(String? m) => switch (m) {
    'cash'   => Icons.attach_money,
    'pix'    => Icons.pix,
    'card'   => Icons.credit_card,
    'wallet' => Icons.account_balance_wallet,
    _        => Icons.payment,
  };

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Ganhos'),
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back),
          onPressed: () => context.push('/profile'),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [

                // ── Seletor de período ───────────────────────
                _PeriodSelector(
                  current:  _period,
                  periods:  _periods,
                  onChange: _changePeriod,
                ),

                const SizedBox(height: 16),

                // ── Card principal: ganho líquido ────────────
                _NetEarningsCard(
                  net:   _summary['net_earnings'],
                  gross: _summary['gross_earnings'],
                  fees:  _summary['fees'],
                ),

                const SizedBox(height: 12),

                // ── Cards de métricas ────────────────────────
                Row(children: [
                  Expanded(child: _MetricCard(
                    icon:  Icons.local_taxi,
                    color: AppTheme.primary,
                    label: 'Corridas',
                    value: '${_summary['total_rides'] ?? 0}',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard(
                    icon:  Icons.star,
                    color: AppTheme.warning,
                    label: 'Ticket médio',
                    value: _currency(_summary['avg_price']),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard(
                    icon:  Icons.route,
                    color: AppTheme.secondary,
                    label: 'KM rodados',
                    value: '${(_summary['total_km'] ?? 0).toStringAsFixed(1)} km',
                  )),
                ]),

                const SizedBox(height: 16),

                // ── Gráfico de barras por dia ────────────────
                if (_daily.isNotEmpty) ...[
                  _DailyChart(daily: _daily),
                  const SizedBox(height: 16),
                ],

                // ── Lista de corridas ────────────────────────
                const Text('Corridas',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                if (_rides.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Nenhuma corrida no período.',
                        style: TextStyle(color: AppTheme.gray))))
                else ...[
                  ..._rides.map((r) => _RideRow(
                    ride:      r as Map<String, dynamic>,
                    currency:  _currency,
                    formatDate: _formatDate,
                    payLabel:  _payLabel,
                    payIcon:   _payIcon,
                  )),

                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator())),
                ],
              ],
            ),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final String                          current;
  final List<(String, String)>          periods;
  final ValueChanged<String>            onChange;

  const _PeriodSelector({
    required this.current,
    required this.periods,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color:      Colors.black.withValues(alpha: 0.05),
          blurRadius: 6)],
      ),
      child: Row(
        children: periods.map((p) {
          final selected = current == p.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:        selected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      selected ? Colors.white : AppTheme.gray)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _NetEarningsCard extends StatelessWidget {
  final dynamic net;
  final dynamic gross;
  final dynamic fees;

  const _NetEarningsCard({
    required this.net,
    required this.gross,
    required this.fees,
  });

  String _fmt(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '0') ?? 0.0;
    return 'R\$ ${d.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.secondary, Color(0xFF059669)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color:      AppTheme.secondary.withValues(alpha: 0.4),
          blurRadius: 16,
          offset:     const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ganho líquido',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(_fmt(net),
            style: const TextStyle(
              color:       Colors.white,
              fontSize:    36,
              fontWeight:  FontWeight.bold,
              letterSpacing: -1)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _EarningsLine(
              label: 'Valor bruto',
              value: _fmt(gross),
              color: Colors.white70)),
            Container(
              width: 1, height: 32,
              color: Colors.white.withValues(alpha: 0.3)),
            Expanded(child: _EarningsLine(
              label: 'Taxas',
              value: '- ${_fmt(fees)}',
              color: Colors.red.shade200)),
          ]),
        ],
      ),
    );
  }
}

class _EarningsLine extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _EarningsLine({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
            style: TextStyle(
              color:      color,
              fontSize:   14,
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color:      Colors.black.withValues(alpha: 0.04),
          blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
            style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
            style: const TextStyle(
              fontSize: 11, color: AppTheme.gray)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _DailyChart extends StatelessWidget {
  final List<dynamic> daily;

  const _DailyChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox.shrink();

    final maxVal = daily
        .map((d) => (d['total'] as num?)?.toDouble() ?? 0.0)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color:      Colors.black.withValues(alpha: 0.04),
          blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ganhos por dia',
            style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: daily.map((d) {
                final val      = (d['total'] as num?)?.toDouble() ?? 0.0;
                final fraction = maxVal > 0 ? val / maxVal : 0.0;
                final dateStr  = d['date']?.toString() ?? '';
                final day      = dateStr.length >= 10
                    ? dateStr.substring(8, 10) : dateStr;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: fraction.clamp(0.05, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color:        AppTheme.primary
                                    .withValues(alpha: 0.8),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(day,
                          style: const TextStyle(
                            fontSize: 9, color: AppTheme.gray)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _RideRow extends StatelessWidget {
  final Map<String, dynamic>        ride;
  final String Function(dynamic)    currency;
  final String Function(String?)    formatDate;
  final String Function(String?)    payLabel;
  final IconData Function(String?)  payIcon;

  const _RideRow({
    required this.ride,
    required this.currency,
    required this.formatDate,
    required this.payLabel,
    required this.payIcon,
  });

  @override
  Widget build(BuildContext context) {
    final price  = ride['price'] ?? 0;
    final method = ride['payment_method']?.toString();
    final dist   = (ride['distance_km'] as num?)?.toStringAsFixed(1) ?? '—';

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color:      Colors.black.withValues(alpha: 0.04),
          blurRadius: 6)],
      ),
      child: Row(children: [

        // Ícone de pagamento
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        AppTheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(payIcon(method),
            color: AppTheme.secondary, size: 20),
        ),

        const SizedBox(width: 12),

        // Endereços + data
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride['destination']?.toString() ?? '—',
                style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '${formatDate(ride['completed_at']?.toString())} · $dist km · ${payLabel(method)}',
                style: const TextStyle(
                  fontSize: 11, color: AppTheme.gray)),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Valor
        Text(
          currency(price),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize:   15,
            color:      AppTheme.secondary)),
      ]),
    );
  }
}