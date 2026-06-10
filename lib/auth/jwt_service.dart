import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  static String get _secret {
    final secret = Platform.environment['JWT_SECRET'];
    if (secret == null || secret.isEmpty) {
      throw Exception('JWT_SECRET environment variable sozlanmagan!');
    }
    return secret;
  }

  static const Duration _expiry = Duration(hours: 24);

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

  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? getUserFromToken(String? authHeader) {
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    final token = authHeader.substring(7);
    return verifyToken(token);
  }
}
