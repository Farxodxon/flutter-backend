import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final payload = context.read<Map<String, dynamic>>();
  final role = payload['role'] as String? ?? 'employee';
  final factoryId = payload['factory_id'] as int?;
  final userId = payload['user_id'] as int?;

  final db = await Database.connect();

  switch (context.request.method) {
    case HttpMethod.get:
      try {
        final query = context.request.uri.queryParameters;
        final search = query['search'];
        final type = query['type'];

        String sql = '''
          SELECT id, name, type, unit, current_stock, min_stock, max_stock,
                 supplier_id, lead_time_days, factory_id, assigned_to, created_at
          FROM materials WHERE 1=1
        ''';
        final params = <dynamic>[];
        var idx = 1;

        // Zavod bo'yicha filtrlash — super_admin barchasini ko'radi
        if (role != 'super_admin') {
          if (factoryId != null) {
            sql += ' AND factory_id = \$$idx';
            params.add(factoryId);
            idx++;
          }
          // Xodim bo'lsa, faqat o'ziga biriktirilgan materiallarni ko'radi
          if (role == 'employee' && userId != null) {
            sql += ''' AND (assigned_to = \$$idx OR assigned_to IS NULL)''';
            params.add(userId);
            idx++;
          }
        }

        if (search != null && search.isNotEmpty) {
          sql += ' AND name ILIKE \$$idx';
          params.add('%$search%');
          idx++;
        }

        if (type != null && type.isNotEmpty) {
          sql += ' AND type = \$$idx';
          params.add(type);
          idx++;
        }

        sql += ' ORDER BY name';

        final result = params.isEmpty
            ? await db.execute(sql)
            : await db.execute(sql, parameters: params);

        final materials = result.map((row) => {
          'id': row[0], 'name': row[1], 'type': row[2], 'unit': row[3],
          'currentStock': double.parse(row[4].toString()),
          'minStock': double.parse(row[5].toString()),
          'maxStock': double.parse(row[6].toString()),
          'supplierId': row[7], 'leadTimeDays': row[8],
          'factoryId': row[9], 'assignedTo': row[10],
          'createdAt': row[11]?.toString(),
        }).toList();

        return Response.json(body: {'materials': materials, 'total': materials.length});
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
          '''INSERT INTO materials
             (name, type, unit, min_stock, max_stock, supplier_id, lead_time_days, factory_id, assigned_to)
             VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)
             RETURNING id, name, type, unit, current_stock, min_stock, max_stock, factory_id, assigned_to, created_at''',
          parameters: [
            name.trim(), type, body['unit'] ?? 'kg',
            body['min_stock'] ?? 0, body['max_stock'] ?? 0,
            body['supplier_id'], body['lead_time_days'] ?? 30,
            targetFactoryId, body['assigned_to'],
          ],
        );
        final row = result.first;
        return Response.json(statusCode: 201, body: {
          'message': 'Material yaratildi',
          'material': {
            'id': row[0], 'name': row[1], 'type': row[2], 'unit': row[3],
            'currentStock': double.parse(row[4].toString()),
            'minStock': double.parse(row[5].toString()),
            'maxStock': double.parse(row[6].toString()),
            'factoryId': row[7], 'assignedTo': row[8],
            'createdAt': row[9]?.toString(),
          },
        });
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
      }

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
