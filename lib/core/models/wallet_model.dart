class WalletModel {
  final double balance;
  final double negativeLimit;

  WalletModel({
    required this.balance,
    required this.negativeLimit,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
    balance:       double.tryParse(json['balance']?.toString()        ?? '0') ?? 0,
    negativeLimit: double.tryParse(json['negative_limit']?.toString() ?? '0') ?? 0,
  );

  // ── Helpers ───────────────────────────────────────────────────

  bool get isNegative     => balance < 0;
  bool get hasNegLimit    => negativeLimit < 0;
  String get balanceLabel => 'R\$ ${balance.toStringAsFixed(2)}';
}

// ── Transação ─────────────────────────────────────────────────────

class WalletTransaction {
  final String id;
  final double amount;
  final String type;    // 'credit' | 'debit'
  final String status;  // 'pending' | 'completed' | 'failed'
  final String? source;
  final DateTime? createdAt;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    this.source,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
    WalletTransaction(
      id:        json['id']?.toString()     ?? '',
      amount:    double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      type:      json['type']               ?? 'debit',
      status:    json['status']             ?? 'completed',
      source:    json['source'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );

  // ── Helpers ───────────────────────────────────────────────────

  bool get isCredit  => type == 'credit';
  bool get isPending => status == 'pending';

  String get sourceLabel => switch (source) {
    'deposit'      => 'Depósito PIX',
    'ride_fee'     => 'Taxa de corrida',
    'delivery_fee' => 'Taxa de entrega',
    'refund'       => 'Estorno',
    'bonus'        => 'Bônus',
    'withdrawal'   => 'Saque',
    _              => source ?? '—',
  };

  String get amountLabel =>
    '${isCredit ? '+' : '-'}R\$ ${amount.toStringAsFixed(2)}';

  String get dateLabel {
    if (createdAt == null) return '—';
    return '${createdAt!.day.toString().padLeft(2,'0')}/'
           '${createdAt!.month.toString().padLeft(2,'0')}/'
           '${createdAt!.year}';
  }
}