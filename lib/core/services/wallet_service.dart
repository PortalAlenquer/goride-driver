import '../api/api_client.dart';
import '../constants/api_constants.dart';
import '../models/wallet_model.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final _api = ApiClient();

  // ── Carregar carteira + extrato ───────────────────────────────

  Future<Map<String, dynamic>> loadWallet() async {
    final walletRes = await _api.dio.get(ApiConstants.walletBalance);
    final transRes  = await _api.dio.get(ApiConstants.walletTransactions);

    // balance retorna direto (não aninhado em 'wallet')
    final wallet = WalletModel.fromJson(walletRes.data);

    // transactions retorna estrutura paginate() do Laravel
    final transactions = (transRes.data['data'] as List? ?? [])
        .map((t) => WalletTransaction.fromJson(t))
        .toList();

    return {'wallet': wallet, 'transactions': transactions};
  }

  // ── Gerar depósito PIX ────────────────────────────────────────
  // Endpoint: POST /wallet/deposit
  // Backend valida: amount min:10, max:5000
  // Retorna: { transaction_id, amount, pix_code }
  // Nota: não há pix_image (QR code base64) — apenas pix_code texto

  Future<Map<String, dynamic>> createDeposit(double amount) async {
    final res = await _api.dio.post(
      ApiConstants.walletDeposit,
      data: {'amount': amount},
    );
    return {
      'transaction_id': res.data['transaction_id'],
      'pix_code':       res.data['pix_code'],
      'amount':         res.data['amount'],
    };
  }
}