import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST'});
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final username = body['username'] as String?;
    final email = body['email'] as String?;
    final password = body['password'] as String?;
    final role = body['role'] as String? ?? 'employee';
    final factoryId = body['factory_id'] as int?;

    if (username == null || email == null || password == null) {
      return Response.json(statusCode: 400, body: {'error': 'username, email, password majburiy'});
    }

    final user = await UserStorage.createUser(
      username: username, email: email, password: password,
      role: role, factoryId: factoryId,
    );

    if (user == null) {
      return Response.json(statusCode: 409, body: {'error': 'Email band'});
    }

    return Response.json(statusCode: 201, body: {
      'message': 'Foydalanuvchi yaratildi', 'user': user.toJson(),
    });
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': 'Xatolik: $e'});
  }
}
