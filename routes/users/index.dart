import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';
import 'package:my_server/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context) async {
  final payload = context.read<Map<String, dynamic>>();
  final callerRole = payload['role'] as String? ?? 'employee';

  if (callerRole == 'employee') {
    return Response.json(statusCode: 403, body: {'error': 'Ruxsat yoq'});
  }

  final db = await Database.connect();

  switch (context.request.method) {
    case HttpMethod.get:
      try {
        final result = await db.execute(
          '''SELECT u.id, u.username, u.email, COALESCE(u.role, 'employee'),
             u.factory_id, COALESCE(u.is_active, true), u.created_at
             FROM users u
             ORDER BY u.id''',
        );

        final users = <Map<String, dynamic>>[];
        for (final row in result) {
          final userId = row[0];

          final deptResult = await db.execute(
            '''SELECT d.id, d.name FROM departments d
               JOIN user_departments ud ON ud.department_id = d.id
               WHERE ud.user_id = \$1''',
            parameters: [userId],
          );

          users.add({
            'id': userId,
            'username': row[1],
            'email': row[2],
            'role': row[3],
            'factoryId': row[4],
            'isActive': row[5],
            'createdAt': row[6]?.toString(),
            'departments': deptResult.map((d) => {'id': d[0], 'name': d[1]}).toList(),
          });
        }

        return Response.json(body: {'users': users, 'total': users.length});
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
      }

    case HttpMethod.post:
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
        return Response.json(statusCode: 400, body: {'error': 'Xatolik'});
      }

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
