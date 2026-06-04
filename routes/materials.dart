import 'package:dart_frog/dart_frog.dart';
import '../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getMaterials();
    case HttpMethod.post:
      return _createMaterial(await context.request.json());
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getMaterials() async {
  final db = await Database.connect();
  
  try {
    final result = await db.execute(
      r'SELECT id, name, type, unit, current_stock, min_stock, max_stock, supplier_id, lead_time_days, factory_id, created_at FROM materials ORDER BY id',
    );
    
    final materials = result.map((row) => {
      'id': row[0],
      'name': row[1],
      'type': row[2],
      'unit': row[3],
      'currentStock': double.parse(row[4].toString()),
      'minStock': double.parse(row[5].toString()),
      'maxStock': double.parse(row[6].toString()),
      'supplierId': row[7],
      'leadTimeDays': row[8],
      'factoryId': row[9],
      'createdAt': row[10]?.toString(),
    }).toList();
    
    return Response.json(body: {'materials': materials, 'total': materials.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _createMaterial(Map<String, dynamic> body) async {
  final db = await Database.connect();
  
  final name = body['name'] as String?;
  final type = body['type'] as String?;
  final unit = body['unit'] as String? ?? 'kg';
  final minStock = body['min_stock'] as num? ?? 0;
  final maxStock = body['max_stock'] as num? ?? 0;
  final supplierId = body['supplier_id'] as int?;
  final leadTimeDays = body['lead_time_days'] as int? ?? 30;
  final factoryId = body['factory_id'] as int?;
  
  if (name == null || type == null) {
    return Response.json(statusCode: 400, body: {'error': 'name va type majburiy'});
  }
  
  try {
    final result = await db.execute(
      r'''INSERT INTO materials (name, type, unit, min_stock, max_stock, supplier_id, lead_time_days, factory_id) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) 
         RETURNING id, name, type, unit, current_stock, min_stock, max_stock, supplier_id, lead_time_days, factory_id, created_at''',
      parameters: [name, type, unit, minStock, maxStock, supplierId, leadTimeDays, factoryId],
    );
    
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Material yaratildi',
      'material': {
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'unit': row[3],
        'currentStock': double.parse(row[4].toString()),
        'minStock': double.parse(row[5].toString()),
        'maxStock': double.parse(row[6].toString()),
        'supplierId': row[7],
        'leadTimeDays': row[8],
        'factoryId': row[9],
        'createdAt': row[10]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Yaratishda xatolik: $e'});
  }
}
