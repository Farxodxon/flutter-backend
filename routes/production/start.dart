import 'package:dart_frog/dart_frog.dart';
import '../../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST ruxsat etilgan'});
  }
  
  final body = await context.request.json() as Map<String, dynamic>;
  final db = await Database.connect();
  
  final bomId = body['bom_id'] as int?;
  final productTypeId = body['product_type_id'] as int?;
  final plannedQuantity = body['planned_quantity'] as num?;
  final unit = body['unit'] as String? ?? 'dona';
  final operatorId = body['operator_id'] as int?;
  final factoryId = body['factory_id'] as int?;
  final notes = body['notes'] as String?;
  
  if (bomId == null || plannedQuantity == null || operatorId == null) {
    return Response.json(statusCode: 400, body: {'error': 'bom_id, planned_quantity, operator_id majburiy'});
  }
  
  try {
    final bomItems = await db.execute(
      r'''SELECT bi.material_id, m.name as material_name, bi.quantity_per_unit, bi.unit, m.current_stock
         FROM bom_items bi
         JOIN materials m ON bi.material_id = m.id
         WHERE bi.bom_id = $1''',
      parameters: [bomId],
    );
    
    final shortages = <Map<String, dynamic>>[];
    for (final item in bomItems) {
      final requiredQty = double.parse(item[2].toString()) * plannedQuantity;
      final currentStock = double.parse(item[4].toString());
      
      if (currentStock < requiredQty) {
        shortages.add({
          'materialId': item[0],
          'materialName': item[1],
          'required': requiredQty,
          'available': currentStock,
          'shortage': requiredQty - currentStock,
          'unit': item[3],
        });
      }
    }
    
    if (shortages.isNotEmpty) {
      return Response.json(statusCode: 400, body: {
        'error': 'Yetarli xom ashyo yo\'q',
        'shortages': shortages,
      });
    }
    
    final batchNumber = 'PRD-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    
    final result = await db.execute(
      r'''INSERT INTO production_batches (batch_number, bom_id, product_type_id, planned_quantity, unit, operator_id, factory_id, status, notes, started_at) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'in_progress', $8, NOW()) 
         RETURNING id, batch_number, bom_id, planned_quantity, unit, status, started_at''',
      parameters: [batchNumber, bomId, productTypeId, plannedQuantity, unit, operatorId, factoryId, notes],
    );
    
    final warehouseResult = await db.execute(r"SELECT id FROM warehouses WHERE type = 'raw' LIMIT 1");
    
    if (warehouseResult.isNotEmpty) {
      final rawWarehouseId = warehouseResult.first[0] as int;
      
      for (final item in bomItems) {
        final requiredQty = double.parse(item[2].toString()) * plannedQuantity;
        
        await db.execute(
          r'''INSERT INTO warehouse_transactions (warehouse_id, material_id, transaction_type, quantity, unit, reference_type, reference_id, batch_number, performed_by) 
             VALUES ($1, $2, 'out', $3, $4, 'production', $5, $6, $7)''',
          parameters: [rawWarehouseId, item[0], requiredQty, item[3], result.first[0], batchNumber, operatorId],
        );
        
        await db.execute(
          r'UPDATE materials SET current_stock = current_stock - $1 WHERE id = $2',
          parameters: [requiredQty, item[0]],
        );
      }
    }
    
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Ishlab chiqarish boshlandi',
      'batch': {
        'id': row[0],
        'batchNumber': row[1],
        'bomId': row[2],
        'plannedQuantity': double.parse(row[3].toString()),
        'unit': row[4],
        'status': row[5],
        'startedAt': row[6]?.toString(),
      },
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
