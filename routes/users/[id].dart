import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final user = await UserStorage.getById(id);
      if (user == null) {
        return Response.json(
          statusCode: 404,
          body: {'error': 'Foydalanuvchi topilmadi'},
        );
      }
      return Response.json(body: user.toJson());

    case HttpMethod.put:
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final username = body['username'] as String?;
        final email = body['email'] as String?;

        final user = await UserStorage.update(id, username: username, email: email);

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
      final deleted = await UserStorage.delete(id);
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
