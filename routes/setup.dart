import 'package:dart_frog/dart_frog.dart';
import '../lib/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST'});
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final username = body['username'] as String?;
    final email = body['email'] as String?;
    final password = body['password'] as String?;
    final secretKey = body['secret_key'] as String?;

    if (secretKey != 'factory_hub_2026_secret') {
      return Response.json(statusCode: 403, body: {'error': 'Maxfiy kalit noto\'g\'ri'});
    }

    if (username == null || email == null || password == null) {
      return Response.json(statusCode: 400, body: {'error': 'username, email, password majburiy'});
    }

    final user = await UserStorage.createSuperAdmin(username, email, password);

    if (user == null) {
      return Response.json(statusCode: 409, body: {'error': 'Super admin allaqachon mavjud yoki yaratib bo\'lmadi'});
    }

    return Response.json(statusCode: 201, body: {
      'message': 'Super admin yaratildi',
      'user': user.toJson(),
    });
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': 'Xatolik: $e'});
  }
}
