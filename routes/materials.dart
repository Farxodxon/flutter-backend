import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getMaterials(context);
    case HttpMethod.post:
      final body = await context.request.json();
      if (body is! Map<String, dynamic>) {
        return Response.json(statusCode: 400, body: {'error': 'JSON obyekt kerak'});
      }
      return _createMaterial(body);
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getMaterials(RequestContext context) async {
  final db = await Database.connect();
  final result = await db.execute(r'SELECT id, name, type, unit, current_stock, min_stock, max_stock, supplier_id, lead_time_days, factory_id, assigned_to, created_at FROM materials ORDER BY id');
  final materials = result.map((row) => {
    'id': row[0], 'name': row[1], 'type': row[2], 'unit': row[3],
    'currentStock': double.parse(row[4].toString()), 'minStock': double.parse(row[5].toString()),
    'maxStock': double.parse(row[6].toString()), 'supplierId': row[7], 'leadTimeDays': row[8],
    'factoryId': row[9], 'assignedTo': row[10], 'createdAt': row[11]?.toString(),
  }).toList();
  return Response.json(body: {'materials': materials, 'total': materials.length});
}

Future<Response> _createMaterial(Map<String, dynamic> body) async {
  final db = await Database.connect();
  final name = body['name'] as String?;
  final type = body['type'] as String?;
  if (name == null || type == null) return Response.json(statusCode: 400, body: {'error': 'name va type majburiy'});
  final result = await db.execute(
    r'INSERT INTO materials (name, type, unit, min_stock, max_stock, supplier_id, lead_time_days, factory_id, assigned_to) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id, name, type, unit, current_stock, min_stock, max_stock, assigned_to, created_at',
    parameters: [name, type, body['unit'] ?? 'kg', body['min_stock'] ?? 0, body['max_stock'] ?? 0, body['supplier_id'], body['lead_time_days'] ?? 30, body['factory_id'], body['assigned_to']],
  );
  final row = result.first;
  return Response.json(statusCode: 201, body: {'message': 'Material yaratildi', 'material': {'id': row[0], 'name': row[1], 'type': row[2], 'unit': row[3], 'currentStock': double.parse(row[4].toString()), 'minStock': double.parse(row[5].toString()), 'maxStock': double.parse(row[6].toString()), 'assignedTo': row[7], 'createdAt': row[8]?.toString()}});
}
