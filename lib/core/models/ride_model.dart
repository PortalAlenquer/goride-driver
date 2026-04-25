class RideModel {
  final String id;
  final String status;
  final String? paymentMethod;

  // Origem
  final double? originLat;
  final double? originLng;
  final String? originAddress;

  // Destino
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationAddress;

  // Valores
  final double? estimatedPrice;
  final double? finalPrice;
  final double? distanceKm;
  final int?    durationMinutes;

  // Taxa da plataforma (vinda do mapData)
  final String? feeType;
  final double? feeValue;

  // Rating e corridas do passageiro (vindos do pendingRides enriched)
  final double? passengerRating;
  final int?    passengerRides;

  // Participantes
  final RidePassenger? passenger;
  final RideDriver?    driver;

  // Metadata
  final DateTime? createdAt;

  RideModel({
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
    this.passengerRating,
    this.passengerRides,
    this.passenger,
    this.driver,
    this.createdAt,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
    id:                 json['id']?.toString() ?? '',
    status:             json['status']          ?? '',
    paymentMethod:      json['payment_method'],
    originLat:          double.tryParse(json['origin_lat']?.toString() ?? ''),
    originLng:          double.tryParse(json['origin_lng']?.toString() ?? ''),
    originAddress:      json['origin_address'],
    destinationLat:     double.tryParse(json['destination_lat']?.toString() ?? ''),
    destinationLng:     double.tryParse(json['destination_lng']?.toString() ?? ''),
    destinationAddress: json['destination_address'],
    estimatedPrice:     double.tryParse(json['estimated_price']?.toString() ?? ''),
    finalPrice:         double.tryParse(json['final_price']?.toString() ?? ''),
    distanceKm:         double.tryParse(json['distance_km']?.toString() ?? ''),
    durationMinutes:    json['duration_minutes'] as int?,
    feeType:            json['fee_type']?.toString(),
    feeValue:           double.tryParse(json['fee_value']?.toString() ?? ''),
    passengerRating:    double.tryParse(
        json['passenger']?['rating']?.toString() ?? ''),
    passengerRides:     int.tryParse(
        json['passenger']?['total_rides']?.toString() ?? ''),
    passenger: json['passenger'] != null
        ? RidePassenger.fromJson(json['passenger'])
        : null,
    driver: json['driver'] != null
        ? RideDriver.fromJson(json['driver'])
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'])
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id':                   id,
    'status':               status,
    'payment_method':       paymentMethod,
    'origin_address':       originAddress,
    'destination_address':  destinationAddress,
    'estimated_price':      estimatedPrice,
    'final_price':          finalPrice,
    'distance_km':          distanceKm,
    'created_at':           createdAt?.toIso8601String(),
  };

  // ── Converte para o formato esperado pelo HomeRideRequestSheet ─
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

  // ── Helpers ───────────────────────────────────────────────────

  double get price => finalPrice ?? estimatedPrice ?? 0.0;

  bool get isCompleted        => status == 'completed';
  bool get isCancelled        => status == 'cancelled';
  bool get isPaymentConfirmed => status == 'payment_confirmed';
  bool get isActive =>
    !isCompleted && !isCancelled && !isPaymentConfirmed;

  // Cria uma cópia do modelo com status atualizado — usado pelo WS
  // para atualização otimista sem precisar recarregar da API
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
    passengerRating:    passengerRating,
    passengerRides:     passengerRides,
    passenger:          passenger,
    driver:             driver,
    createdAt:          createdAt,
  );
}

// ── Passageiro da corrida ─────────────────────────────────────────

class RidePassenger {
  final String id;
  final String name;
  final String? phone;

  RidePassenger({
    required this.id,
    required this.name,
    this.phone,
  });

  factory RidePassenger.fromJson(Map<String, dynamic> json) => RidePassenger(
    id:    json['id']?.toString() ?? '',
    name:  json['name']           ?? '',
    phone: json['phone'],
  );
}

// ── Motorista da corrida ──────────────────────────────────────────

class RideDriver {
  final String id;
  final String? userId;
  final String? name;

  RideDriver({
    required this.id,
    this.userId,
    this.name,
  });

  factory RideDriver.fromJson(Map<String, dynamic> json) => RideDriver(
    id:     json['id']?.toString()      ?? '',
    userId: json['user_id']?.toString(),
    name:   json['name'],
  );
}