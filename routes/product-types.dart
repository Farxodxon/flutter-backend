import 'package:dart_frog/dart_frog.dart';
import '../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getProductTypes();
    case HttpMethod.post:
      return _createProductType(await context.request.json());
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getProductTypes() async {
  final db = await Database.connect();
  
  try {
    final result = await db.execute(
      r'''SELECT pt.id, pt.name, pt.category_id, pc.name as category_name, pt.unit, pt.description, pt.factory_id, pt.created_at 
         FROM product_types pt
         LEFT JOIN product_categories pc ON pt.category_id = pc.id
         ORDER BY pt.id''',
    );
    
    final types = result.map((row) => {
      'id': row[0],
      'name': row[1],
      'categoryId': row[2],
      'categoryName': row[3],
      'unit': row[4],
      'description': row[5],
      'factoryId': row[6],
      'createdAt': row[7]?.toString(),
    }).toList();
    
    return Response.json(body: {'productTypes': types, 'total': types.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _createProductType(Map<String, dynamic> body) async {
  final db = await Database.connect();
  
  final name = body['name'] as String?;
  final categoryId = body['category_id'] as int?;
  final unit = body['unit'] as String? ?? 'dona';
  final description = body['description'] as String?;
  final factoryId = body['factory_id'] as int?;
  
  if (name == null) {
    return Response.json(statusCode: 400, body: {'error': 'name majburiy'});
  }
  
  try {
    final result = await db.execute(
      r'INSERT INTO product_types (name, category_id, unit, description, factory_id) VALUES ($1, $2, $3, $4, $5) RETURNING id, name, category_id, unit, description, factory_id, created_at',
      parameters: [name, categoryId, unit, description, factoryId],
    );
    
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Mahsulot turi yaratildi',
      'productType': {
        'id': row[0],
        'name': row[1],
        'categoryId': row[2],
        'unit': row[3],
        'description': row[4],
        'factoryId': row[5],
        'createdAt': row[6]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
