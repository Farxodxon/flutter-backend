class User {
  final int id;
  final String username;
  final String email;
  final String role;
  final int? factoryId;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.factoryId,
    required this.createdAt,
  });

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'factoryId': factoryId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
