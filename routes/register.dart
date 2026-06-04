import 'package:dart_frog/dart_frog.dart';
import '../lib/storage/user_storage.dart';

/// Faqat POST so'rovlarni qabul qiladi
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Faqat POST so\'rov ruxsat etilgan'},
    );
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final username = body['username'] as String?;
    final email = body['email'] as String?;
    final password = body['password'] as String?;

    // Tekshirish
    if (username == null || email == null || password == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'username, email va password majburiy'},
      );
    }

    if (password.length < 6) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Parol kamida 6 ta belgidan iborat bo\'lishi kerak'},
      );
    }

    // Ro'yxatdan o'tish
    final user = UserStorage.register(username, email, password);

    if (user == null) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'Bu email yoki username allaqachon band'},
      );
    }

    // Muvaffaqiyatli
    return Response.json(
      statusCode: 201,
      body: {
        'message': 'Ro\'yxatdan o\'tish muvaffaqiyatli',
        'user': user.toJson(),
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Noto\'g\'ri JSON format'},
    );
  }
}
