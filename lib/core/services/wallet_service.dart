import '../config/api_client.dart';
import '../config/api_constants.dart';
import '../models/wallet_model.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final _api = ApiClient();

  Future<Map<String, dynamic>> getMe() async {
    final res = await _api.dio.get('/auth/me');
    return res.data['user'] as Map<String, dynamic>;
  }

  // ── Carregar carteira + extrato ───────────────────────────────

  Future<Map<String, dynamic>> loadWallet() async {
    final walletRes = await _api.dio.get(ApiConstants.walletBalance);
    final transRes  = await _api.dio.get(ApiConstants.walletTransactions);

    final wallet = WalletModel.fromJson(walletRes.data);

    final transactions = (transRes.data['data'] as List? ?? [])
        .map((t) => WalletTransaction.fromJson(t))
        .toList();

    return {'wallet': wallet, 'transactions': transactions};
  }

  // ── Gerar depósito PIX via Mercado Pago ──────────────────────
  //
  // POST /wallet/deposit
  // Retorna:
  //   payment_id     → ID do pagamento no MP
  //   transaction_id → UUID da WalletTransaction (para polling de confirm)
  //   pix_code       → string copia-e-cola
  //   pix_image      → base64 do QR code (pode ser null)
  //   amount         → valor solicitado
  //   expires_at     → data/hora de expiração

  Future<Map<String, dynamic>> createDeposit(double amount) async {
    final res = await _api.dio.post(
      ApiConstants.walletDeposit,
      data: {'amount': amount},
    );

    final data = res.data as Map<String, dynamic>;

    return {
      'payment_id':     data['payment_id'],
      'transaction_id': data['transaction_id'],
      'pix_code':       data['pix_code'],
      'pix_image':      data['pix_image'],   // base64 QR, pode ser null
      'amount':         data['amount'],
      'expires_at':     data['expires_at'],
    };
  }

  // ── Confirmar depósito manualmente (botão "Já paguei") ────────
  // POST /wallet/deposit/confirm
  // Usado como fallback caso o webhook MP não chegue a tempo.
  // Retorna 200 se confirmado, 422 se ainda pendente.

  Future<Map<String, dynamic>> confirmDeposit(String transactionId) async {
    final res = await _api.dio.post(
      ApiConstants.walletDepositConfirm,
      data: {'transaction_id': transactionId},
    );
    return res.data as Map<String, dynamic>;
  }
}