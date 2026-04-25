class ApiConstants {
  ApiConstants._();

  // ── Base ──────────────────────────────────────────────────────
  static const baseUrl   = 'http://89.116.73.59:8082/api';
  static const storageUrl = 'http://89.116.73.59:8082/storage';

  // Helper para montar URL de imagem
static String imageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return '$storageUrl/$path';
}

  // Google Maps
  static const String mapsKey = 'AIzaSyDps3qV7l_f_pSgCK45oDuKvMF06NThCgY';
  static const String directionsUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  // ── WebSocket Reverb ──────────────────────────────────────────
  static const wsUrl = 'ws://89.116.73.59:8083/app/goride2-key';

  // ── Auth ──────────────────────────────────────────────────────
  static const login  = '/auth/login';
  static const register = '/auth/register';
  static const me     = '/auth/me';
  static const logout = '/auth/logout';

  // ── Broadcasting ──────────────────────────────────────────────
  static const broadcastingAuth = '/broadcasting/auth';

  // ── Perfil ────────────────────────────────────────────────────
  static const profile       = '/profile';
  static const profileAvatar = '/profile/avatar';
  static const profilePassword = '/profile/password';

  // ── Driver ────────────────────────────────────────────────────
  static const driverMe             = '/driver/me';
  static const driverStatus         = '/driver/status';
  static const driverPendingRides   = '/driver/rides/pending';
  static const driverPaymentMethods = '/driver/payment-methods';
  static const driverLocation       = '/rides/driver/location';
  static const driverFeeByLocation  = '/driver/fee-by-location';

  // ── Corridas ──────────────────────────────────────────────────
  static const rides = '/rides';
  static String rideDetail(String id)       => '/rides/$id';
  static String rideAccept(String id)       => '/rides/$id/accept';
  static String rideReject(String id)       => '/rides/$id/reject';
  static String rideStatus(String id)       => '/rides/$id/status';

  // ── Carteira ──────────────────────────────────────────────────
  static const walletBalance      = '/wallet/balance';
  static const walletTransactions = '/wallet/transactions';
  static const walletDeposit      = '/wallet/deposit';
  static const walletDepositConfirm = '/wallet/deposit/confirm'; 

  // ── Veículos ──────────────────────────────────────────────────
  static const vehicles = '/vehicles';
  static String vehicleUpdate(String id)   => '/vehicles/$id';
  static String vehicleDocument(String id) => '/vehicles/$id/document';

  // ── CNH ───────────────────────────────────────────────────────
  static const cnhUpdate   = '/driver/cnh';
  static const cnhDocument = '/driver/cnh/document';

  // ── FCM ───────────────────────────────────────────────────────
  static const fcmToken = '/fcm/token';
}