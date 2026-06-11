import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final userId = int.tryParse(id);
  if (userId == null) {
    return Response.json(statusCode: 400, body: {"error": "Notogri ID"});
  }

  final db = await Database.connect();

  try {
    final userResult = await db.execute(
      "SELECT id, username, email, role, factory_id, is_active FROM users WHERE id = \$1",
      parameters: [userId],
    );
    if (userResult.isEmpty) {
      return Response.json(statusCode: 404, body: {"error": "Topilmadi"});
    }
    final u = userResult.first;

    final deptResult = await db.execute(
      """SELECT d.id, d.name, d.description FROM departments d
         JOIN user_departments ud ON ud.department_id = d.id
         WHERE ud.user_id = \$1""",
      parameters: [userId],
    );

    final wareResult = await db.execute(
      """SELECT w.id, w.name FROM warehouses w
         JOIN user_warehouses uw ON uw.warehouse_id = w.id
         WHERE uw.user_id = \$1""",
      parameters: [userId],
    );

    return Response.json(body: {
      "user": {
        "id": u[0], "username": u[1], "email": u[2],
        "role": u[3], "factoryId": u[4], "isActive": u[5],
      },
      "departments": deptResult.map((r) => {"id": r[0], "name": r[1], "description": r[2]}).toList(),
      "warehouses": wareResult.map((r) => {"id": r[0], "name": r[1]}).toList(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {"error": "Server xatosi"});
  }
}
