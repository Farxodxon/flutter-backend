import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Method not allowed'},
    );
  }

  final db = await Database.connect();

  try {
    final result = await db.execute(
      r'''SELECT u.id, u.username, u.email, COALESCE(u.role, 'employee'), 
         u.factory_id, u.department_id, u.created_at,
         d.name as department_name
         FROM users u
         LEFT JOIN departments d ON u.department_id = d.id
         ORDER BY u.id''',
    );

    final users = result.map((row) => {
      'id': row[0],
      'username': row[1],
      'email': row[2],
      'role': row[3],
      'factoryId': row[4],
      'departmentId': row[5],
      'createdAt': row[6]?.toString(),
      'departmentName': row[7],
    }).toList();

    return Response.json(body: {'users': users, 'total': users.length});
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Xatolik: $e'},
    );
  }
}
