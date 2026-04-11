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

  WalletModel?             _wallet;
  List<WalletTransaction>  _transactions = [];
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

  // ── Carregamento ──────────────────────────────────────────────

  Future<void> _loadWallet() async {
    try {
      final result = await _service.loadWallet();
      setState(() {
        _wallet       = result['wallet']       as WalletModel;
        _transactions = result['transactions'] as List<WalletTransaction>;
        _loading      = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Depósito PIX ──────────────────────────────────────────────

  Future<void> _createDeposit() async {
    final amount = double.tryParse(
      _depositCtrl.text.replaceAll(',', '.'));

    // Backend valida min:10, max:5000
    if (amount == null || amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor mínimo de R\$ 10,00')));
      return;
    }

    try {
      final result = await _service.createDeposit(amount);
      if (!mounted) return;
      Navigator.pop(context);
      _showPixSheet(
        pixCode:       result['pix_code'],
        transactionId: result['transaction_id'],
        amount:        amount,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao gerar PIX.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  // ── Sheets ────────────────────────────────────────────────────

  void _showDepositSheet() {
    _depositCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adicionar saldo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _depositCtrl,
              keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixIcon: Icon(Icons.attach_money),
                helperText: 'Mínimo R\$ 10,00 — Máximo R\$ 5.000,00',
              ),
            ),
            const SizedBox(height: 16),
            // Atalhos de valor
            Row(
              children: [10, 20, 50, 100].map((v) => Expanded(
                child: GestureDetector(
                  onTap: () => _depositCtrl.text = v.toString(),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('R\$ $v',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _createDeposit,
              icon: const Icon(Icons.pix),
              label: const Text('Gerar PIX'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showPixSheet({
    required String? pixCode,
    required String? transactionId,
    required double amount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pague com PIX',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('R\$ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary)),
            const SizedBox(height: 24),

            // Ícone PIX
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.secondary.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.pix,
                size: 64, color: AppTheme.secondary),
            ),

            const SizedBox(height: 20),

            // Código copia-e-cola
            if (pixCode != null) ...[
              const Text('Copie o código PIX abaixo:',
                style: TextStyle(color: AppTheme.gray)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Expanded(child: Text(
                    pixCode,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  )),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppTheme.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pixCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado!')));
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            const Text(
              'Após o pagamento, o saldo será creditado automaticamente.',
              style: TextStyle(color: AppTheme.gray, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gray,
                    side: const BorderSide(color: AppTheme.gray),
                    minimumSize: const Size(0, 48)),
                  child: const Text('Fechar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadWallet();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    minimumSize: const Size(0, 48)),
                  child: const Text('Já paguei'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Minha carteira'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [

            // ── Card de saldo ─────────────────────────────────
            _WalletCard(
              wallet:    _wallet!,
              onDeposit: _showDepositSheet,
            ),

            // ── Extrato ───────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('Extrato',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _transactions.isEmpty
                ? const Center(
                    child: Text('Nenhuma transação ainda.',
                      style: TextStyle(color: AppTheme.gray)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _transactions.length,
                    itemBuilder: (_, i) =>
                      _TransactionCard(transaction: _transactions[i]),
                  ),
            ),
          ]),
    );
  }
}

// ── Card de saldo ─────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onDeposit;

  const _WalletCard({required this.wallet, required this.onDeposit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: wallet.isNegative
            ? [AppTheme.danger, const Color(0xFFB91C1C)]
            : [AppTheme.secondary, const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo disponível',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(wallet.balanceLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold)),
          if (wallet.hasNegLimit) ...[
            const SizedBox(height: 4),
            Text(
              'Limite negativo: R\$ ${wallet.negativeLimit.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white70, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onDeposit,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar saldo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de transação ─────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final WalletTransaction transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t         = transaction;
    final iconColor = t.isPending
      ? AppTheme.warning
      : t.isCredit ? AppTheme.secondary : AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [

        // Ícone
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            t.isPending
              ? Icons.access_time
              : t.isCredit
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color: iconColor, size: 20,
          ),
        ),

        const SizedBox(width: 12),

        // Descrição + data
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.sourceLabel,
              style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(children: [
              if (t.isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Pendente',
                    style: TextStyle(
                      fontSize: 10, color: AppTheme.warning)),
                ),
              Text(t.dateLabel,
                style: const TextStyle(
                  fontSize: 12, color: AppTheme.gray)),
            ]),
          ],
        )),

        // Valor
        Text(t.amountLabel,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: iconColor,
          )),
      ]),
    );
  }
}