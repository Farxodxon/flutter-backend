import 'package:dart_frog/dart_frog.dart';
import '../../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getBoms();
    case HttpMethod.post:
      return _createBom(await context.request.json());
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getBoms() async {
  final db = await Database.connect();
  
  try {
    final result = await db.execute(
      r'''SELECT pb.id, pb.name, pb.product_type_id, pt.name as product_name, 
         pb.version, pb.is_active, pb.production_type, pb.batch_size, pb.batch_unit,
         pb.factory_id, pb.created_at
         FROM product_boms pb
         LEFT JOIN product_types pt ON pb.product_type_id = pt.id
         ORDER BY pb.id''',
    );
    
    final boms = result.map((row) => {
      'id': row[0],
      'name': row[1],
      'productTypeId': row[2],
      'productName': row[3],
      'version': row[4],
      'isActive': row[5],
      'productionType': row[6],
      'batchSize': row[7] != null ? double.parse(row[7].toString()) : null,
      'batchUnit': row[8],
      'factoryId': row[9],
      'createdAt': row[10]?.toString(),
    }).toList();
    
    return Response.json(body: {'boms': boms, 'total': boms.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _createBom(Map<String, dynamic> body) async {
  final db = await Database.connect();
  
  final name = body['name'] as String?;
  final productTypeId = body['product_type_id'] as int?;
  final productionType = body['production_type'] as String? ?? 'batch';
  final batchSize = body['batch_size'] as num?;
  final batchUnit = body['batch_unit'] as String?;
  final factoryId = body['factory_id'] as int?;
  final createdBy = body['created_by'] as int?;
  
  if (name == null) {
    return Response.json(statusCode: 400, body: {'error': 'name majburiy'});
  }
  
  try {
    final result = await db.execute(
      r'''INSERT INTO product_boms (name, product_type_id, production_type, batch_size, batch_unit, factory_id, created_by) 
         VALUES ($1, $2, $3, $4, $5, $6, $7) 
         RETURNING id, name, product_type_id, version, is_active, production_type, batch_size, batch_unit, factory_id, created_at''',
      parameters: [name, productTypeId, productionType, batchSize, batchUnit, factoryId, createdBy],
    );
    
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Mahsulot tarkibi yaratildi',
      'bom': {
        'id': row[0],
        'name': row[1],
        'productTypeId': row[2],
        'version': row[3],
        'isActive': row[4],
        'productionType': row[5],
        'batchSize': row[6] != null ? double.parse(row[6].toString()) : null,
        'batchUnit': row[7],
        'factoryId': row[8],
        'createdAt': row[9]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
