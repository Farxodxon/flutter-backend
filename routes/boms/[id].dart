import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final bomId = int.tryParse(id);
  if (bomId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Noto\'g\'ri ID'});
  }
  switch (context.request.method) {
    case HttpMethod.get:
      return _getBomDetail(bomId);
    case HttpMethod.post:
      final body = await context.request.json();
      if (body is! Map<String, dynamic>) {
        return Response.json(statusCode: 400, body: {'error': 'JSON kerak'});
      }
      return _addIngredient(bomId, body);
    case HttpMethod.delete:
      return _deleteBom(bomId);
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getBomDetail(int bomId) async {
  final db = await Database.connect();
  try {
    final bomResult = await db.execute(
      r'''SELECT pb.id, pb.name, pb.product_type_id, pt.name as product_name,
             pb.version, pb.is_active, pb.production_type, pb.batch_size, pb.batch_unit,
             pb.factory_id, pb.created_at
           FROM product_boms pb
           LEFT JOIN product_types pt ON pb.product_type_id = pt.id
           WHERE pb.id = $1''',
      parameters: [bomId],
    );
    if (bomResult.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'BOM topilmadi'});
    }
    final b = bomResult.first;
    final bom = {
      'id': b[0], 'name': b[1], 'productTypeId': b[2], 'productName': b[3],
      'version': b[4], 'isActive': b[5], 'productionType': b[6],
      'batchSize': b[7] != null ? double.parse(b[7].toString()) : null,
      'batchUnit': b[8], 'factoryId': b[9], 'createdAt': b[10]?.toString(),
    };

    final ingResult = await db.execute(
      r'''SELECT bi.id, bi.material_id, m.name, m.type, bi.quantity, bi.unit, bi.notes
           FROM bom_ingredients bi
           JOIN materials m ON m.id = bi.material_id
           WHERE bi.bom_id = $1
           ORDER BY m.type, m.name''',
      parameters: [bomId],
    );
    final ingredients = ingResult.map((row) => {
      'id': row[0], 'materialId': row[1], 'materialName': row[2],
      'materialType': row[3],
      'quantity': double.parse(row[4].toString()),
      'unit': row[5], 'notes': row[6],
    }).toList();

    return Response.json(body: {'bom': bom, 'ingredients': ingredients});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _addIngredient(int bomId, Map<String, dynamic> body) async {
  final db = await Database.connect();
  final materialId = body['material_id'] as int?;
  final quantity = body['quantity'] as num?;
  final unit = body['unit'] as String?;
  final notes = body['notes'] as String?;

  if (materialId == null || quantity == null || unit == null) {
    return Response.json(statusCode: 400, body: {'error': 'material_id, quantity, unit majburiy'});
  }

  try {
    final result = await db.execute(
      r'''INSERT INTO bom_ingredients (bom_id, material_id, quantity, unit, notes)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (bom_id, material_id) DO UPDATE
             SET quantity = EXCLUDED.quantity, unit = EXCLUDED.unit, notes = EXCLUDED.notes
           RETURNING id, material_id, quantity, unit, notes''',
      parameters: [bomId, materialId, quantity, unit, notes],
    );
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Ingredient qo\'shildi',
      'ingredient': {
        'id': row[0], 'materialId': row[1],
        'quantity': double.parse(row[2].toString()),
        'unit': row[3], 'notes': row[4],
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _deleteBom(int bomId) async {
  final db = await Database.connect();
  try {
    await db.execute(r'DELETE FROM product_boms WHERE id = $1', parameters: [bomId]);
    return Response.json(body: {'message': 'BOM o\'chirildi'});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
