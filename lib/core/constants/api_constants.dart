class ApiConstants {
  static const String baseUrl = 'http://89.116.73.59:8082/api';

  static const String storageUrl = 'http://89.116.73.59:8082/storage';

// Helper para montar URL de imagem
static String imageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return '$storageUrl/$path';
}

  // Google Maps
  static const String mapsKey = 'AIzaSyDps3qV7l_f_pSgCK45oDuKvMF06NThCgY';
  static const String directionsUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  
  // Auth
  static const String login    = '/auth/login';
  static const String register = '/auth/register';
  static const String logout   = '/auth/logout';
  static const String me       = '/auth/me';

  // Rides
  static const String rides           = '/rides';
  static const String rideAccept      = '/rides/{id}/accept';
  static const String rideStatus      = '/rides/{id}/status';
  static const String driverLocation  = '/rides/driver/location';

  // Deliveries
  static const String deliveries = '/deliveries';

  // Wallet
  static const String walletBalance      = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletDeposit      = '/wallet/deposit';
}