import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final payload = context.read<Map<String, dynamic>>();
  final role = payload['role'] as String? ?? 'employee';
  final factoryId = payload['factory_id'] as int?;

  final db = await Database.connect();

  switch (context.request.method) {
    case HttpMethod.get:
      try {
        String sql = 'SELECT id, name, type, factory_id, created_at FROM warehouses WHERE 1=1';
        final params = <dynamic>[];
        var idx = 1;

        if (role != 'super_admin' && factoryId != null) {
          sql += ' AND factory_id = \$$idx';
          params.add(factoryId);
          idx++;
        }
        sql += ' ORDER BY id';

        final result = params.isEmpty
            ? await db.execute(sql)
            : await db.execute(sql, parameters: params);

        final warehouses = <Map<String, dynamic>>[];
        for (final row in result) {
          final wId = row[0];

          // Bu omborga oid tranzaksiyalardan material sonini hisoblash
          final countResult = await db.execute(
            'SELECT COUNT(DISTINCT material_id) FROM warehouse_transactions WHERE warehouse_id = \$1',
            parameters: [wId],
          );

          warehouses.add({
            'id': wId,
            'name': row[1],
            'type': row[2],
            'factoryId': row[3],
            'createdAt': row[4]?.toString(),
            'materialCount': countResult.isNotEmpty ? countResult.first[0] : 0,
          });
        }

        return Response.json(body: {'warehouses': warehouses, 'total': warehouses.length});
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
      }

    case HttpMethod.post:
      if (role == 'employee') {
        return Response.json(statusCode: 403, body: {'error': 'Ruxsat yoq'});
      }
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final name = body['name'] as String?;
        final type = body['type'] as String?;

        if (name == null || name.trim().isEmpty || type == null) {
          return Response.json(statusCode: 400, body: {'error': 'name va type majburiy'});
        }

        final targetFactoryId = role == 'super_admin'
            ? (body['factory_id'] as int?)
            : factoryId;

        final result = await db.execute(
          'INSERT INTO warehouses (name, type, factory_id) VALUES (\$1, \$2, \$3) RETURNING id, name, type, factory_id, created_at',
          parameters: [name.trim(), type, targetFactoryId],
        );
        final row = result.first;
        return Response.json(statusCode: 201, body: {
          'message': 'Ombor yaratildi',
          'warehouse': {'id': row[0], 'name': row[1], 'type': row[2], 'factoryId': row[3]},
        });
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
      }

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
