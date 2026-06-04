import 'package:dart_frog/dart_frog.dart';
import '../lib/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Faqat POST so\'rov ruxsat etilgan'},
    );
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (email == null || password == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'email va password majburiy'},
      );
    }

    final user = await UserStorage.login(email, password);

    if (user == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Email yoki parol noto\'g\'ri'},
      );
    }

    return Response.json(
      body: {
        'message': 'Muvaffaqiyatli kirish',
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
