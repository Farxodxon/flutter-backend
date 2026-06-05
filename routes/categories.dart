import 'package:dart_frog/dart_frog.dart';
import '../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getCategories();
    case HttpMethod.post:
      return _createCategory(await context.request.json());
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getCategories() async {
  final db = await Database.connect();
  
  try {
    final result = await db.execute(
      r'SELECT id, name, parent_id, factory_id, created_at FROM product_categories ORDER BY id',
    );
    
    final categories = result.map((row) => {
      'id': row[0],
      'name': row[1],
      'parentId': row[2],
      'factoryId': row[3],
      'createdAt': row[4]?.toString(),
    }).toList();
    
    return Response.json(body: {'categories': categories, 'total': categories.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _createCategory(Map<String, dynamic> body) async {
  final db = await Database.connect();
  
  final name = body['name'] as String?;
  final parentId = body['parent_id'] as int?;
  final factoryId = body['factory_id'] as int?;
  
  if (name == null) {
    return Response.json(statusCode: 400, body: {'error': 'name majburiy'});
  }
  
  try {
    final result = await db.execute(
      r'INSERT INTO product_categories (name, parent_id, factory_id) VALUES ($1, $2, $3) RETURNING id, name, parent_id, factory_id, created_at',
      parameters: [name, parentId, factoryId],
    );
    
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Kategoriya yaratildi',
      'category': {
        'id': row[0],
        'name': row[1],
        'parentId': row[2],
        'factoryId': row[3],
        'createdAt': row[4]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
