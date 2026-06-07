import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final payload = context.read<Map<String, dynamic>>();
  final role = payload["role"] as String? ?? "";

  if (role != "super_admin") {
    return Response.json(statusCode: 403, body: {"error": "Faqat super_admin uchun"});
  }

  final factoryId = int.tryParse(id);
  if (factoryId == null) {
    return Response.json(statusCode: 400, body: {"error": "Notogri ID"});
  }

  final db = await Database.connect();

  switch (context.request.method) {
    case HttpMethod.get:
      try {
        final result = await db.execute(
          """SELECT f.id, f.name, f.address, f.is_active, f.created_at,
              COUNT(DISTINCT u.id) as user_count,
              COUNT(DISTINCT m.id) as material_count
             FROM factories f
             LEFT JOIN users u ON u.factory_id = f.id
             LEFT JOIN materials m ON m.factory_id = f.id
             WHERE f.id = \$1
             GROUP BY f.id""",
          parameters: [factoryId],
        );
        if (result.isEmpty) {
          return Response.json(statusCode: 404, body: {"error": "Zavod topilmadi"});
        }
        final row = result.first;
        return Response.json(body: {
          "factory": {
            "id": row[0], "name": row[1], "address": row[2],
            "isActive": row[3], "createdAt": row[4]?.toString(),
            "userCount": row[5] as int, "materialCount": row[6] as int,
          },
        });
      } catch (e) {
        return Response.json(statusCode: 500, body: {"error": "Xatolik: $e"});
      }

    case HttpMethod.put:
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final name = body["name"] as String?;
        final address = body["address"] as String?;
        final isActive = body["isActive"] as bool?;

        final setParts = <String>[];
        final params = <dynamic>[];
        var idx = 1;

        if (name != null && name.trim().isNotEmpty) {
          setParts.add("name = \$"); params.add(name.trim()); idx++;
        }
        if (address != null) {
          setParts.add("address = \$"); params.add(address); idx++;
        }
        if (isActive != null) {
          setParts.add("is_active = \$"); params.add(isActive); idx++;
        }

        if (setParts.isEmpty) {
          return Response.json(statusCode: 400, body: {"error": "Ozgartirish yoq"});
        }

        params.add(factoryId);
        final result = await db.execute(
          "UPDATE factories SET ${setParts.join(", ")} WHERE id = \$ RETURNING id, name, address, is_active, created_at",
          parameters: params,
        );
        if (result.isEmpty) {
          return Response.json(statusCode: 404, body: {"error": "Zavod topilmadi"});
        }
        final row = result.first;
        return Response.json(body: {
          "message": "Yangilandi",
          "factory": {
            "id": row[0], "name": row[1], "address": row[2],
            "isActive": row[3], "createdAt": row[4]?.toString(),
          },
        });
      } catch (e) {
        return Response.json(statusCode: 500, body: {"error": "Xatolik: $e"});
      }

    case HttpMethod.delete:
      try {
        final users = await db.execute(
          "SELECT COUNT(*) FROM users WHERE factory_id = \$1",
          parameters: [factoryId],
        );
        if ((users.first[0] as int) > 0) {
          return Response.json(statusCode: 409, body: {
            "error": "Zavodda foydalanuvchilar bor. Avval ularni boshqa zavodga otkazing."
          });
        }
        await db.execute(
          "UPDATE factories SET is_active = FALSE WHERE id = \$1",
          parameters: [factoryId],
        );
        return Response.json(body: {"message": "Zavod ochirildi"});
      } catch (e) {
        return Response.json(statusCode: 500, body: {"error": "Xatolik: $e"});
      }

    default:
      return Response.json(statusCode: 405, body: {"error": "Method not allowed"});
  }
}
