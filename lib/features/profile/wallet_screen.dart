import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/wallet_model.dart';
import '../../core/services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _service     = WalletService();
  final _depositCtrl = TextEditingController();

  WalletModel?            _wallet;
  Map<String, dynamic>?   _user;
  List<WalletTransaction> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _depositCtrl.dispose();
    super.dispose();
  }

  // ── Dados ─────────────────────────────────────────────────────

  Future<void> _loadWallet() async {
    try {
      final walletRes = await _service.loadWallet();
      final meRes     = await _service.getMe();
      if (!mounted) return;
      setState(() {
        _wallet       = walletRes['wallet']       as WalletModel;
        _transactions = walletRes['transactions'] as List<WalletTransaction>;
        _user         = meRes;
        _loading      = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Criar depósito ────────────────────────────────────────────

  Future<void> _createDeposit() async {
    final amount = double.tryParse(
        _depositCtrl.text.replaceAll(',', '.'));

    if (amount == null || amount < 10) {
      _showSnack('Valor mínimo de R\$ 10,00', AppTheme.danger);
      return;
    }

    // Fecha o sheet de valor
    if (Navigator.canPop(context)) Navigator.pop(context);

    // Loading enquanto gera o PIX
    showDialog(
      context:             context,
      barrierDismissible:  false,
      builder: (_) => const Center(
        child: CircularProgressIndicator()),
    );

    try {
      final result = await _service.createDeposit(amount);
      if (!mounted) return;
      Navigator.pop(context); // fecha loading

      _showPixSheet(
        transactionId: result['transaction_id']?.toString(),
        pixCode:       result['pix_code']?.toString(),
        pixImage:      result['pix_image']?.toString(),
        amount:        amount,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // fecha loading
      _showSnack('Erro ao gerar PIX. Tente novamente.', AppTheme.danger);
    }
  }

  // ── Sheet: escolher valor ─────────────────────────────────────

  void _showDepositSheet() {
    _depositCtrl.clear();
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left:   24,
          right:  24,
          top:    24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adicionar saldo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Pagamento via PIX — Mercado Pago',
              style: TextStyle(color: AppTheme.gray, fontSize: 13)),
            const SizedBox(height: 20),

            TextField(
              controller:   _depositCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus:    true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign:    TextAlign.center,
              decoration:   const InputDecoration(
                prefixText:  'R\$ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                hintText:    '0,00',
                border:      OutlineInputBorder(),
                helperText:  'Mínimo R\$ 10,00 — Máximo R\$ 5.000,00',
              ),
            ),

            const SizedBox(height: 16),

            // Atalhos rápidos
            Row(
              children: [10, 20, 50, 100].map((v) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                      () => _depositCtrl.text = v.toString()),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:        AppTheme.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Text('R\$ $v',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color:      AppTheme.secondary)),
                  ),
                ),
              )).toList(),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createDeposit,
                icon:  const Icon(Icons.pix),
                label: const Text('Gerar PIX',
                  style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sheet: QR Code PIX ────────────────────────────────────────

  void _showPixSheet({
    required String? transactionId,
    required String? pixCode,
    required String? pixImage,
    required double  amount,
  }) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      isDismissible:      false,
      backgroundColor:    Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PixSheet(
        transactionId: transactionId,
        pixCode:       pixCode,
        pixImage:      pixImage,
        amount:        amount,
        service:       _service,
        onConfirmed: () {
          Navigator.pop(ctx);
          _loadWallet(); // recarrega saldo atualizado
          _showSnack('Saldo creditado com sucesso!', AppTheme.secondary);
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _txIcon(String? source) => switch (source) {
    'deposit'      => '⬆️',
    'ride_fee'     => '🚗',
    'delivery_fee' => '📦',
    'refund'       => '↩️',
    _              => '💰',
  };

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final balance  = _wallet?.balance ?? 0.0;
    final negLimit = _wallet?.negativeLimit?.abs() ?? 50.0;
    final isLow    = balance < 10;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Minha carteira'),
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadWallet,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Card de saldo ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLow
                        ? [AppTheme.danger, Colors.red.shade800]
                        : [AppTheme.secondary, Colors.green.shade700],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color:      (isLow ? AppTheme.danger : AppTheme.secondary)
                          .withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset:     const Offset(0, 6),
                    )],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo disponível',
                            style: TextStyle(
                              color: Colors.white70, fontSize: 14)),
                          if (isLow)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:        Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20)),
                              child: const Row(children: [
                                Icon(Icons.warning_amber,
                                  color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Saldo baixo',
                                  style: TextStyle(
                                    color:      Colors.white,
                                    fontSize:   12,
                                    fontWeight: FontWeight.w600)),
                              ]),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'R\$ ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Limite negativo: R\$ ${negLimit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final cpf = _user?['cpf']?.toString().trim() ?? '';
                            if (cpf.isEmpty) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('CPF necessário'),
                                  content: const Text(
                                    'Para realizar depósitos, informe seu CPF no perfil primeiro.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        context.go('/profile');
                                      },
                                      child: const Text('Ir para o perfil'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Fechar'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            _showDepositSheet();
                          },
                          icon:  const Icon(Icons.add, size: 18),
                          label: const Text('Adicionar saldo via PIX'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.secondary,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Extrato ───────────────────────────────────
                const Text('Extrato',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                if (_transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Nenhuma transação ainda.',
                        style: TextStyle(color: AppTheme.gray))))
                else
                  ..._transactions.map((t) {
                    final isCredit  = t.type == 'credit';
                    final isPending = t.status == 'pending';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color:      Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8)],
                      ),
                      child: Row(children: [

                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: (isCredit
                                ? AppTheme.secondary : AppTheme.danger)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(_txIcon(t.source),
                              style: const TextStyle(fontSize: 18))),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.sourceLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Row(children: [
                                Text(t.dateLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color:    AppTheme.gray)),
                                if (isPending) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Pendente',
                                      style: TextStyle(
                                        fontSize:   10,
                                        color:      AppTheme.warning,
                                        fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ]),
                            ],
                          ),
                        ),

                        Text(
                          '${isCredit ? '+' : '-'} R\$ ${t.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   15,
                            color: isCredit
                                ? AppTheme.secondary : AppTheme.danger),
                        ),
                      ]),
                    );
                  }),
              ],
            ),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PixSheet — QR code + polling de confirmação automática
// ─────────────────────────────────────────────────────────────────────────────

class _PixSheet extends StatefulWidget {
  final String?       transactionId;
  final String?       pixCode;
  final String?       pixImage;
  final double        amount;
  final WalletService service;
  final VoidCallback  onConfirmed;

  const _PixSheet({
    required this.transactionId,
    required this.pixCode,
    required this.pixImage,
    required this.amount,
    required this.service,
    required this.onConfirmed,
  });

  @override
  State<_PixSheet> createState() => _PixSheetState();
}

class _PixSheetState extends State<_PixSheet> {
  Timer? _pollTimer;
  bool   _checking  = false;
  bool   _confirmed = false;

  @override
  void initState() {
    super.initState();
    // Polling a cada 5s — o webhookMp do backend já credita automaticamente;
    // este polling chama confirmDeposit como fallback
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_confirmed) _checkPayment();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPayment() async {
    if (_checking || widget.transactionId == null) return;
    setState(() => _checking = true);
    try {
      await widget.service.confirmDeposit(widget.transactionId!);
      // 200 = confirmado
      if (mounted) {
        setState(() { _confirmed = true; });
        _pollTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) widget.onConfirmed();
      }
    } catch (_) {
      // 422 = ainda pendente → continua polling silenciosamente
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          const Text('Pague com PIX',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('R\$ ${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize:   32,
              fontWeight: FontWeight.bold,
              color:      AppTheme.secondary)),

          const SizedBox(height: 20),

          // QR Code (imagem base64) ou ícone fallback
          if (widget.pixImage != null && widget.pixImage!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12)],
              ),
              child: Image.memory(
                base64Decode(widget.pixImage!),
                width: 200, height: 200,
                fit:   BoxFit.contain,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color:        AppTheme.secondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.secondary.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.pix,
                size: 80, color: AppTheme.secondary),
            ),

          const SizedBox(height: 20),

          // Copia-e-cola
          if (widget.pixCode != null && widget.pixCode!.isNotEmpty) ...[
            const Text('Ou copie o código PIX:',
              style: TextStyle(color: AppTheme.gray, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:        const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(
                  child: Text(widget.pixCode!,
                    style:    const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.pixCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:  Text('Código copiado!'),
                        duration: Duration(seconds: 2)));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.copy,
                      color: AppTheme.primary, size: 18),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_checking && !_confirmed)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              if (_checking && !_confirmed) const SizedBox(width: 8),
              Text(
                _confirmed
                  ? 'Pagamento confirmado! ✅'
                  : 'Aguardando pagamento...',
                style: TextStyle(
                  color:      _confirmed
                      ? AppTheme.secondary : AppTheme.gray,
                  fontWeight: _confirmed
                      ? FontWeight.bold : FontWeight.normal,
                  fontSize:   13),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Text(
            'O saldo é creditado automaticamente após o pagamento.',
            style:     TextStyle(color: AppTheme.gray, fontSize: 12),
            textAlign: TextAlign.center),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.gray,
                  side:            const BorderSide(color: AppTheme.gray),
                  minimumSize:     const Size(0, 44)),
                child: const Text('Fechar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _checking ? null : _checkPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  minimumSize:     const Size(0, 44)),
                child: const Text('Já paguei'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}