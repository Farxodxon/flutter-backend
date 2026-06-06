import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST'});
  }

  try {
    final parsed = await context.request.json();
    if (parsed is! Map<String, dynamic>) {
      return Response.json(statusCode: 400, body: {'error': 'JSON obyekt kutilgan'});
    }
    final body = parsed;

    final warehouseId = body['warehouse_id'] as int?;
    final materialId = body['material_id'] as int?;
    final transactionType = body['transaction_type'] as String?;
    final quantity = body['quantity'] as num?;
    final unit = body['unit'] as String?;

    if (warehouseId == null || materialId == null || transactionType == null || quantity == null || unit == null) {
      return Response.json(statusCode: 400, body: {'error': 'warehouse_id, material_id, transaction_type, quantity, unit majburiy'});
    }

    final db = await Database.connect();

    final result = await db.execute(
      r'INSERT INTO warehouse_transactions (warehouse_id, material_id, transaction_type, quantity, unit) VALUES ($1, $2, $3, $4, $5) RETURNING id, warehouse_id, material_id, transaction_type, quantity, unit, created_at',
      parameters: [warehouseId, materialId, transactionType, quantity, unit],
    );

    final stockChange = transactionType == 'in' ? quantity : -quantity;
    await db.execute(r'UPDATE materials SET current_stock = current_stock + $1 WHERE id = $2', parameters: [stockChange, materialId]);

    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Ombor harakati qo\'shildi',
      'transaction': {
        'id': row[0], 'warehouseId': row[1], 'materialId': row[2],
        'transactionType': row[3], 'quantity': double.parse(row[4].toString()),
        'unit': row[5], 'createdAt': row[6]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
