import 'package:dart_frog/dart_frog.dart';
import '../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getWarehouses();
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getWarehouses() async {
  final db = await Database.connect();
  
  try {
    final result = await db.execute(
      r'SELECT id, name, type, factory_id, created_at FROM warehouses ORDER BY id',
    );
    
    final warehouses = result.map((row) => {
      'id': row[0],
      'name': row[1],
      'type': row[2],
      'factoryId': row[3],
      'createdAt': row[4]?.toString(),
    }).toList();
    
    return Response.json(body: {'warehouses': warehouses, 'total': warehouses.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
