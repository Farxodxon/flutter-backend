import 'package:dart_frog/dart_frog.dart';
import '../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getMaterials(context);
    case HttpMethod.post:
      return _createMaterial(await context.request.json(), context);
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getMaterials(RequestContext context) async {
  final db = await Database.connect();
  
  // Query parametrlardan foydalanuvchi ma'lumotini olish
  final userId = context.request.uri.queryParameters['user_id'];
  final role = context.request.uri.queryParameters['role'];
  final factoryId = context.request.uri.queryParameters['factory_id'];
  
  try {
    String query = r'SELECT id, name, type, unit, current_stock, min_stock, max_stock, supplier_id, lead_time_days, factory_id, assigned_to, created_at FROM materials WHERE 1=1';
    final params = <dynamic>[];
    
    if (role == 'employee' && userId != null) {
      query += ' AND assigned_to = \$1';
      params.add(int.tryParse(userId));
    } else if (role == 'admin' && factoryId != null) {
      query += ' AND factory_id = \$1';
      params.add(int.tryParse(factoryId));
    }
    // super_admin hammasini ko'radi
    
    query += ' ORDER BY id';
    
    final result = params.isEmpty 
        ? await db.execute(query)
        : await db.execute(query, parameters: params);
    
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
      'assignedTo': row[10],
      'createdAt': row[11]?.toString(),
    }).toList();
    
    return Response.json(body: {'materials': materials, 'total': materials.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _createMaterial(Map<String, dynamic> body, RequestContext context) async {
  final db = await Database.connect();
  
  final name = body['name'] as String?;
  final type = body['type'] as String?;
  final unit = body['unit'] as String? ?? 'kg';
  final minStock = body['min_stock'] as num? ?? 0;
  final maxStock = body['max_stock'] as num? ?? 0;
  final supplierId = body['supplier_id'] as int?;
  final leadTimeDays = body['lead_time_days'] as int? ?? 30;
  final factoryId = body['factory_id'] as int?;
  final assignedTo = body['assigned_to'] as int?;
  final createdBy = body['created_by'] as int?;
  
  if (name == null || type == null) {
    return Response.json(statusCode: 400, body: {'error': 'name va type majburiy'});
  }
  
  // Kim yaratayotganini tekshirish
  if (createdBy != null) {
    final userResult = await db.execute(
      r'SELECT role FROM users WHERE id = $1',
      parameters: [createdBy],
    );
    if (userResult.isEmpty) {
      return Response.json(statusCode: 403, body: {'error': 'Foydalanuvchi topilmadi'});
    }
    final userRole = userResult.first[0] as String;
    if (userRole == 'employee') {
      return Response.json(statusCode: 403, body: {'error': 'Xodimlar material qo\'sha olmaydi'});
    }
  }
  
  try {
    final result = await db.execute(
      r'''INSERT INTO materials (name, type, unit, min_stock, max_stock, supplier_id, lead_time_days, factory_id, assigned_to) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) 
         RETURNING id, name, type, unit, current_stock, min_stock, max_stock, assigned_to, created_at''',
      parameters: [name, type, unit, minStock, maxStock, supplierId, leadTimeDays, factoryId, assignedTo],
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
        'assignedTo': row[7],
        'createdAt': row[8]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
