import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PassengerRatingScreen
//
// Exibida após payment_confirmed. O motorista avalia o passageiro
// com 1-5 estrelas + comentário opcional.
//
// Endpoint: PUT /rides/{rideId}/status
//   body: { status: 'payment_confirmed', passenger_rating: 5, passenger_comment: '' }
//
// Rota: /ride-rating/:rideId
// Parâmetros opcionais via extras: passengerName, price
// ─────────────────────────────────────────────────────────────────────────────

class PassengerRatingScreen extends StatefulWidget {
  final String  rideId;
  final String? passengerName;
  final double? price;

  const PassengerRatingScreen({
    super.key,
    required this.rideId,
    this.passengerName,
    this.price,
  });

  @override
  State<PassengerRatingScreen> createState() => _PassengerRatingScreenState();
}

class _PassengerRatingScreenState extends State<PassengerRatingScreen> {
  int    _rating     = 5;
  String _comment    = '';
  bool   _submitting = false;

  // Tags rápidas — padrão Uber/99
  static const _positiveTags = [
    'Pontual',
    'Educado',
    'Boa comunicação',
    'Local correto',
    'Sem problemas',
  ];

  static const _negativeTags = [
    'Atrasou',
    'Local errado',
    'Mal educado',
    'Cancelou depois',
    'Sem comunicação',
  ];

  final Set<String> _selectedTags = {};

  List<String> get _currentTags =>
      _rating >= 4 ? _positiveTags : _negativeTags;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // Monta comentário com tags + texto livre
      final tagText    = _selectedTags.join(', ');
      final fullComment = [tagText, _comment.trim()]
          .where((s) => s.isNotEmpty)
          .join(' · ');

      await ApiClient().dio.put(
        '/rides/${widget.rideId}/status',
        data: {
          'status':            'payment_confirmed',
          'passenger_rating':  _rating,
          if (fullComment.isNotEmpty) 'passenger_comment': fullComment,
        },
      );

      if (mounted) context.go('/home');
    } catch (_) {
      // Mesmo com erro, deixa ir para home — avaliação não é bloqueante
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _skip() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final name  = widget.passengerName?.split(' ').first ?? 'o passageiro';
    final price = widget.price;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [

          // ── Cabeçalho verde com valor recebido ─────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF059669)),
            child: Column(children: [

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2)),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white, size: 36)),

              const SizedBox(height: 14),

              const Text('Corrida concluída!',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   18,
                  fontWeight: FontWeight.w600)),

              if (price != null) ...[
                const SizedBox(height: 8),
                Text(
                  'R\$ ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color:         Colors.white,
                    fontSize:      48,
                    fontWeight:    FontWeight.bold,
                    height:        1.0,
                    letterSpacing: -2)),
                const SizedBox(height: 6),
                Text('recebido com sucesso',
                  style: TextStyle(
                    color:    Colors.white.withValues(alpha: 0.75),
                    fontSize: 13)),
              ],
            ]),
          ),

          // ── Avaliação ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Pergunta
                  Text(
                    'Como foi $name?',
                    style: const TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.bold,
                      color:      AppTheme.dark)),

                  const SizedBox(height: 6),

                  const Text('Sua avaliação é anônima para o passageiro.',
                    style: TextStyle(fontSize: 13, color: AppTheme.gray)),

                  const SizedBox(height: 24),

                  // Estrelas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < _rating;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _rating = i + 1;
                          _selectedTags.clear(); // reseta tags ao mudar nota
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              key:   ValueKey(filled),
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: filled
                                  ? AppTheme.warning : Colors.grey.shade300,
                              size: 48),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  // Label da nota
                  Center(
                    child: Text(
                      _ratingLabel,
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      _ratingColor)),
                  ),

                  const SizedBox(height: 24),

                  // Tags rápidas
                  const Text('O que se destacou?',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      AppTheme.dark)),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _currentTags.map((tag) {
                      final sel = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.secondary.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppTheme.secondary
                                  : Colors.grey.shade300,
                              width: sel ? 1.5 : 1)),
                          child: Text(tag,
                            style: TextStyle(
                              fontSize:   13,
                              fontWeight: FontWeight.w500,
                              color:      sel
                                  ? AppTheme.secondary
                                  : AppTheme.dark)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Comentário livre (opcional)
                  TextField(
                    onChanged: (v) => _comment = v,
                    maxLines:  3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText:     'Adicionar comentário (opcional)',
                      hintStyle:    const TextStyle(color: AppTheme.gray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.secondary, width: 1.5)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Botões ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(children: [

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                  child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : const Text('Enviar avaliação',
                        style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: _skip,
                child: const Text('Pular',
                  style: TextStyle(
                    color: AppTheme.gray, fontSize: 14)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String get _ratingLabel => switch (_rating) {
    1 => 'Muito ruim',
    2 => 'Ruim',
    3 => 'Regular',
    4 => 'Bom',
    _ => 'Excelente!',
  };

  Color get _ratingColor => switch (_rating) {
    1 || 2 => AppTheme.danger,
    3      => AppTheme.warning,
    _      => AppTheme.secondary,
  };
}