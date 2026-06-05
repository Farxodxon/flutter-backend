import 'package:dart_frog/dart_frog.dart';
import '../../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST ruxsat etilgan'});
  }
  
  final body = await context.request.json() as Map<String, dynamic>;
  final db = await Database.connect();
  
  final warehouseId = body['warehouse_id'] as int?;
  final materialId = body['material_id'] as int?;
  final transactionType = body['transaction_type'] as String?;
  final quantity = body['quantity'] as num?;
  final unit = body['unit'] as String?;
  final referenceType = body['reference_type'] as String?;
  final referenceId = body['reference_id'] as int?;
  final batchNumber = body['batch_number'] as String?;
  final performedBy = body['performed_by'] as int?;
  final notes = body['notes'] as String?;
  
  if (warehouseId == null || materialId == null || transactionType == null || quantity == null || unit == null) {
    return Response.json(statusCode: 400, body: {'error': 'warehouse_id, material_id, transaction_type, quantity, unit majburiy'});
  }
  
  try {
    final result = await db.execute(
      r'''INSERT INTO warehouse_transactions (warehouse_id, material_id, transaction_type, quantity, unit, reference_type, reference_id, batch_number, performed_by, notes) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) 
         RETURNING id, warehouse_id, material_id, transaction_type, quantity, unit, batch_number, created_at''',
      parameters: [warehouseId, materialId, transactionType, quantity, unit, referenceType, referenceId, batchNumber, performedBy, notes],
    );
    
    final stockChange = transactionType == 'in' ? quantity : -quantity;
    await db.execute(
      r'UPDATE materials SET current_stock = current_stock + $1 WHERE id = $2',
      parameters: [stockChange, materialId],
    );
    
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Ombor harakati qo\'shildi',
      'transaction': {
        'id': row[0],
        'warehouseId': row[1],
        'materialId': row[2],
        'transactionType': row[3],
        'quantity': double.parse(row[4].toString()),
        'unit': row[5],
        'batchNumber': row[6],
        'createdAt': row[7]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
