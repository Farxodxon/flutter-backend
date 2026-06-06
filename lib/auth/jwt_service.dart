import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  static const String _secret = 'factory_hub_2026_super_secret_key_change_in_production';
  static const Duration _expiry = Duration(hours: 24);

  /// Token yaratish
  static String generateToken({
    required int userId,
    required String email,
    required String role,
    int? factoryId,
  }) {
    final jwt = JWT({
      'user_id': userId,
      'email': email,
      'role': role,
      'factory_id': factoryId,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(_expiry).millisecondsSinceEpoch ~/ 1000,
    });

    return jwt.sign(SecretKey(_secret));
  }

  /// Tokenni tekshirish
  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Token ichidan user ma'lumotini olish
  static Map<String, dynamic>? getUserFromToken(String? authHeader) {
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    final token = authHeader.substring(7);
    return verifyToken(token);
  }
}
