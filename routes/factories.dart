import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final payload = context.read<Map<String, dynamic>>();
  final role = payload['role'] as String? ?? '';

  if (role != 'super_admin') {
    return Response.json(statusCode: 403, body: {'error': 'Faqat super_admin uchun'});
  }

  final db = await Database.connect();

  switch (context.request.method) {
    case HttpMethod.get:
      try {
        final result = await db.execute('''
          SELECT f.id, f.name, f.address, f.is_active, f.created_at,
            COUNT(DISTINCT u.id) as user_count,
            COUNT(DISTINCT m.id) as material_count,
            COUNT(DISTINCT w.id) as warehouse_count
          FROM factories f
          LEFT JOIN users u ON u.factory_id = f.id
          LEFT JOIN materials m ON m.factory_id = f.id
          LEFT JOIN warehouses w ON w.factory_id = f.id
          GROUP BY f.id, f.name, f.address, f.is_active, f.created_at
          ORDER BY f.id
        ''');
        final factories = result.map((row) => {
          'id': row[0],
          'name': row[1],
          'address': row[2],
          'isActive': row[3],
          'createdAt': row[4]?.toString(),
          'userCount': row[5] as int,
          'materialCount': row[6] as int,
          'warehouseCount': row[7] as int,
        }).toList();
        return Response.json(body: {'factories': factories, 'total': factories.length});
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
      }

    case HttpMethod.post:
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final name = body['name'] as String?;
        final address = body['address'] as String?;

        if (name == null || name.trim().isEmpty) {
          return Response.json(statusCode: 400, body: {'error': 'Zavod nomi majburiy'});
        }

        final result = await db.execute(
          'INSERT INTO factories (name, address) VALUES (\$1, \$2) RETURNING id, name, address, is_active, created_at',
          parameters: [name.trim(), address],
        );
        final row = result.first;
        return Response.json(statusCode: 201, body: {
          'message': 'Zavod yaratildi',
          'factory': {
            'id': row[0], 'name': row[1], 'address': row[2],
            'isActive': row[3], 'createdAt': row[4]?.toString(),
            'userCount': 0, 'materialCount': 0, 'warehouseCount': 0,
          },
        });
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
      }

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
