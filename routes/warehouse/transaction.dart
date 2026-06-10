import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST'});
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;

    final warehouseId = body['warehouse_id'] as int?;
    final materialId = body['material_id'] as int?;
    final transactionType = body['transaction_type'] as String?;
    final quantity = body['quantity'] as num?;
    final unit = body['unit'] as String?;
    final performedBy = body['performed_by'] as int?;
    final notes = body['notes'] as String?;

    if (warehouseId == null || materialId == null ||
        transactionType == null || quantity == null || unit == null) {
      return Response.json(statusCode: 400, body: {
        'error': 'warehouse_id, material_id, transaction_type, quantity, unit majburiy'
      });
    }

    if (transactionType != 'in' && transactionType != 'out') {
      return Response.json(statusCode: 400, body: {
        'error': 'transaction_type faqat "in" yoki "out" bo\'lishi kerak'
      });
    }

    if (quantity <= 0) {
      return Response.json(statusCode: 400, body: {
        'error': 'Miqdor 0 dan katta bo\'lishi kerak'
      });
    }

    final db = await Database.connect();

    // Chiqim bo'lsa, yetarli zaxira borligini tekshirish
    if (transactionType == 'out') {
      final stockResult = await db.execute(
        'SELECT current_stock FROM materials WHERE id = \$1',
        parameters: [materialId],
      );
      if (stockResult.isEmpty) {
        return Response.json(statusCode: 404, body: {'error': 'Material topilmadi'});
      }
      final currentStock = double.parse(stockResult.first[0].toString());
      if (currentStock < quantity) {
        return Response.json(statusCode: 400, body: {
          'error': 'Yetarli zaxira yo\'q. Mavjud: $currentStock $unit',
        });
      }
    }

    // ATOMIC TRANSACTION — ikkalasi birga bajariladi
    await db.execute('BEGIN');
    try {
      // 1. Transaction yozuvi
      final result = await db.execute(
        '''INSERT INTO warehouse_transactions
           (warehouse_id, material_id, transaction_type, quantity, unit, performed_by, notes)
           VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)
           RETURNING id, warehouse_id, material_id, transaction_type, quantity, unit, created_at''',
        parameters: [warehouseId, materialId, transactionType, quantity, unit, performedBy, notes],
      );

      // 2. Material stock yangilash
      final stockChange = transactionType == 'in' ? quantity : -quantity;
      await db.execute(
        'UPDATE materials SET current_stock = current_stock + \$1 WHERE id = \$2',
        parameters: [stockChange, materialId],
      );

      await db.execute('COMMIT');

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
          'createdAt': row[6]?.toString(),
        },
      });
    } catch (e) {
      await db.execute('ROLLBACK');
      rethrow;
    }
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
