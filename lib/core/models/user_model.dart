class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final String? avatar;
  final String? cpf;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.avatar,
    this.cpf,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:     json['id'],
    name:   json['name'],
    email:  json['email'],
    phone:  json['phone'] ?? '',
    role:   json['role'] ?? 'passenger',
    status: json['status'] ?? 'active',
    avatar: json['avatar'],
    cpf:    json['cpf'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'email': email,
    'phone': phone, 'role': role, 'status': status,
  };
}