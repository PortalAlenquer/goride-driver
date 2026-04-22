// lib/core/models/ride_model.dart

class RideModel {
  final String  id;
  final String  status;
  final String? paymentMethod;

  final double? originLat;
  final double? originLng;
  final String? originAddress;

  final double? destinationLat;
  final double? destinationLng;
  final String? destinationAddress;

  final double? estimatedPrice;
  final double? finalPrice;
  final double? distanceKm;
  final int?    durationMinutes;

  final String? feeType;
  final double? feeValue;

  final RidePassenger? passenger;
  final RideDriver?    driver;

  final DateTime? createdAt;

  const RideModel({
    required this.id,
    required this.status,
    this.paymentMethod,
    this.originLat,
    this.originLng,
    this.originAddress,
    this.destinationLat,
    this.destinationLng,
    this.destinationAddress,
    this.estimatedPrice,
    this.finalPrice,
    this.distanceKm,
    this.durationMinutes,
    this.feeType,
    this.feeValue,
    this.passenger,
    this.driver,
    this.createdAt,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
    id:                 json['id']?.toString()              ?? '',
    status:             json['status']?.toString()          ?? '',
    paymentMethod:      json['payment_method']?.toString(),
    originLat:          double.tryParse(json['origin_lat']?.toString()      ?? ''),
    originLng:          double.tryParse(json['origin_lng']?.toString()      ?? ''),
    originAddress:      json['origin_address']?.toString(),
    destinationLat:     double.tryParse(json['destination_lat']?.toString() ?? ''),
    destinationLng:     double.tryParse(json['destination_lng']?.toString() ?? ''),
    destinationAddress: json['destination_address']?.toString(),
    estimatedPrice:     double.tryParse(json['estimated_price']?.toString() ?? ''),
    finalPrice:         double.tryParse(json['final_price']?.toString()     ?? ''),
    distanceKm:         double.tryParse(json['distance_km']?.toString()     ?? ''),
    durationMinutes:    json['duration_minutes'] as int?,
    feeType:            json['fee_type']?.toString(),
    feeValue:           double.tryParse(json['fee_value']?.toString()       ?? ''),
    passenger: json['passenger'] != null
        ? RidePassenger.fromJson(json['passenger'] as Map<String, dynamic>)
        : null,
    driver: json['driver'] != null
        ? RideDriver.fromJson(json['driver'] as Map<String, dynamic>)
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())
        : null,
  );

  // Cria cópia com status diferente — usado pelo WebSocket
  RideModel copyWithStatus(String newStatus) => RideModel(
    id:                 id,
    status:             newStatus,
    paymentMethod:      paymentMethod,
    originLat:          originLat,
    originLng:          originLng,
    originAddress:      originAddress,
    destinationLat:     destinationLat,
    destinationLng:     destinationLng,
    destinationAddress: destinationAddress,
    estimatedPrice:     estimatedPrice,
    finalPrice:         finalPrice,
    distanceKm:         distanceKm,
    durationMinutes:    durationMinutes,
    feeType:            feeType,
    feeValue:           feeValue,
    passenger:          passenger,
    driver:             driver,
    createdAt:          createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id':                  id,
    'status':              status,
    'payment_method':      paymentMethod,
    'origin_address':      originAddress,
    'destination_address': destinationAddress,
    'estimated_price':     estimatedPrice,
    'final_price':         finalPrice,
    'distance_km':         distanceKm,
    'created_at':          createdAt?.toIso8601String(),
  };

  Map<String, dynamic> toSheetMap() => {
    'id':                  id,
    'estimated_price':     estimatedPrice ?? 0.0,
    'distance_km':         distanceKm,
    'duration_minutes':    durationMinutes,
    'origin_address':      originAddress,
    'destination_address': destinationAddress,
    'payment_method':      paymentMethod,
    'fee_type':            feeType  ?? 'fixed',
    'fee_value':           feeValue ?? 0.0,
  };

  double get price => finalPrice ?? estimatedPrice ?? 0.0;

  bool get isCompleted        => status == 'completed';
  bool get isCancelled        => status == 'cancelled';
  bool get isPaymentConfirmed => status == 'payment_confirmed';
  bool get isActive           => !isCompleted && !isCancelled && !isPaymentConfirmed;
}

// ─────────────────────────────────────────────────────────────────

class RidePassenger {
  final String  id;
  final String  name;
  final String? phone;
  final String? avatar;

  const RidePassenger({
    required this.id,
    required this.name,
    this.phone,
    this.avatar,
  });

  factory RidePassenger.fromJson(Map<String, dynamic> json) => RidePassenger(
    id:     json['id']?.toString()   ?? '',
    name:   json['name']?.toString() ?? '',
    phone:  json['phone']?.toString(),
    avatar: json['avatar']?.toString(),
  );
}

// ─────────────────────────────────────────────────────────────────

class RideDriver {
  final String  id;
  final String? userId;
  final String? name;
  final String? avatar;
  final double? rating;

  const RideDriver({
    required this.id,
    this.userId,
    this.name,
    this.avatar,
    this.rating,
  });

  factory RideDriver.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return RideDriver(
      id:     json['id']?.toString()      ?? '',
      userId: json['user_id']?.toString(),
      name:   user?['name']?.toString()   ?? json['name']?.toString(),
      avatar: user?['avatar']?.toString() ?? json['avatar']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? ''),
    );
  }
}
