class User {
  final String id;
  final String username;
  final String email;
  final String password; // Haqiqiy loyihada hech qachon saqlanmaydi!
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonWithPassword() {
    return {
      ...toJson(),
      'password': password,
    };
  }
}
