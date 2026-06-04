import 'package:dart_frog/dart_frog.dart';
import '../../lib/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      // Foydalanuvchini olish
      final user = UserStorage.getById(id);
      if (user == null) {
        return Response.json(
          statusCode: 404,
          body: {'error': 'Foydalanuvchi topilmadi'},
        );
      }
      return Response.json(body: user.toJson());

    case HttpMethod.put:
      // Foydalanuvchini yangilash
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final username = body['username'] as String?;
        final email = body['email'] as String?;

        final user = UserStorage.update(id, username: username, email: email);

        if (user == null) {
          return Response.json(
            statusCode: 404,
            body: {'error': 'Foydalanuvchi topilmadi'},
          );
        }

        return Response.json(
          body: {
            'message': 'Foydalanuvchi yangilandi',
            'user': user.toJson(),
          },
        );
      } catch (e) {
        return Response.json(
          statusCode: 400,
          body: {'error': 'Noto\'g\'ri JSON format'},
        );
      }

    case HttpMethod.delete:
      // Foydalanuvchini o'chirish
      final deleted = UserStorage.delete(id);
      if (!deleted) {
        return Response.json(
          statusCode: 404,
          body: {'error': 'Foydalanuvchi topilmadi'},
        );
      }
      return Response.json(
        body: {'message': 'Foydalanuvchi o\'chirildi'},
      );

    default:
      return Response.json(
        statusCode: 405,
        body: {'error': 'Ruxsat etilmagan metod'},
      );
  }
}
