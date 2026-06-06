import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/storage/user_storage.dart';
import 'package:my_server/auth/jwt_service.dart';

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

    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (email == null || password == null) {
      return Response.json(statusCode: 400, body: {'error': 'email va password majburiy'});
    }

    final user = await UserStorage.login(email, password);
    if (user == null) {
      return Response.json(statusCode: 401, body: {'error': 'Email yoki parol noto\'g\'ri'});
    }

    final token = JwtService.generateToken(
      userId: int.parse(user.id), email: user.email, role: user.role,
      factoryId: user.factoryId != null ? int.tryParse(user.factoryId!) : null,
    );

    return Response.json(body: {
      'message': 'Muvaffaqiyatli kirish', 'token': token,
      'user': user.toJson(),
    });
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': 'Xatolik: $e'});
  }
}
