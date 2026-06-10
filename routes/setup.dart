import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST'});
  }

  try {
    final parsed = await context.request.json();
    if (parsed is! Map<String, dynamic>) {
      return Response.json(statusCode: 400, body: {'error': 'JSON obyekt kutilgan'});
    }
    final body = parsed;

    final username = body['username'] as String?;
    final email = body['email'] as String?;
    final password = body['password'] as String?;
    final secretKey = body['secret_key'] as String?;

    if (secretKey != Platform.environment['SETUP_SECRET_KEY']) {
      return Response.json(statusCode: 403, body: {'error': 'Maxfiy kalit noto\'g\'ri'});
    }

    if (username == null || email == null || password == null) {
      return Response.json(statusCode: 400, body: {'error': 'username, email, password majburiy'});
    }

    final user = await UserStorage.createSuperAdmin(username, email, password);

    if (user == null) {
      return Response.json(statusCode: 409, body: {'error': 'Super admin allaqachon mavjud'});
    }

    return Response.json(statusCode: 201, body: {
      'message': 'Super admin yaratildi', 'user': user.toJson(),
    });
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': 'Xatolik: $e'});
  }
}
