import 'package:dart_frog/dart_frog.dart';
import '../lib/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final users = await UserStorage.getAll();
      return Response.json(
        body: {
          'users': users.map((u) => u.toJson()).toList(),
          'total': users.length,
        },
      );

    case HttpMethod.post:
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final username = body['username'] as String?;
        final email = body['email'] as String?;
        final password = body['password'] as String?;

        if (username == null || email == null || password == null) {
          return Response.json(
            statusCode: 400,
            body: {'error': 'username, email va password majburiy'},
          );
        }

        final user = await UserStorage.register(username, email, password);

        if (user == null) {
          return Response.json(
            statusCode: 409,
            body: {'error': 'Bu email yoki username allaqachon band'},
          );
        }

        return Response.json(
          statusCode: 201,
          body: {
            'message': 'Foydalanuvchi yaratildi',
            'user': user.toJson(),
          },
        );
      } catch (e) {
        return Response.json(
          statusCode: 400,
          body: {'error': 'Noto\'g\'ri JSON format'},
        );
      }

    default:
      return Response.json(
        statusCode: 405,
        body: {'error': 'Ruxsat etilmagan metod'},
      );
  }
}
