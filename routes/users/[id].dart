import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';
import 'package:my_server/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final userId = int.tryParse(id);
  if (userId == null) {
    return Response.json(statusCode: 400, body: {"error": "Notogri ID"});
  }

  final payload = context.read<Map<String, dynamic>>();
  final callerRole = payload["role"] as String? ?? "employee";
  final callerId = payload["user_id"] as int?;

  if (callerRole == "employee" && callerId != userId) {
    return Response.json(statusCode: 403, body: {"error": "Ruxsat yoq"});
  }

  final db = await Database.connect();

  switch (context.request.method) {
    case HttpMethod.get:
      try {
        final userResult = await db.execute(
          "SELECT id, username, email, role, factory_id, COALESCE(is_active, true) FROM users WHERE id = \$1",
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

    case HttpMethod.put:
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final user = await UserStorage.update(
          userId,
          username: body["username"] as String?,
          email: body["email"] as String?,
          password: body["password"] as String?,
          role: callerRole == "super_admin" ? body["role"] as String? : null,
          factoryId: callerRole == "super_admin" ? body["factory_id"] as int? : null,
          isActive: body["is_active"] as bool?,
        );
        if (user == null) {
          return Response.json(statusCode: 404, body: {"error": "Topilmadi"});
        }
        return Response.json(body: {"message": "Yangilandi", "user": user.toJson()});
      } catch (e) {
        return Response.json(statusCode: 400, body: {"error": "\$e"});
      }

    case HttpMethod.delete:
      if (callerRole != "super_admin") {
        return Response.json(statusCode: 403, body: {"error": "Faqat super_admin"});
      }
      final user = await UserStorage.update(userId, isActive: false);
      if (user == null) {
        return Response.json(statusCode: 404, body: {"error": "Topilmadi"});
      }
      return Response.json(body: {"message": "Ochirildi"});

    default:
      return Response.json(statusCode: 405, body: {"error": "Method not allowed"});
  }
}
