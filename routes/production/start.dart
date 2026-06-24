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

    final bomId = body['bom_id'] as int?;
    final plannedQuantity = (body['planned_quantity'] as num?)?.toDouble();
    final unit = body['unit'] as String? ?? 'dona';
    final operatorId = body['operator_id'] as int?;
    final factoryId = body['factory_id'] as int?;

    if (bomId == null || plannedQuantity == null || operatorId == null) {
      return Response.json(statusCode: 400, body: {'error': 'bom_id, planned_quantity, operator_id majburiy'});
    }

    final db = await Database.connect();

    // BOM mavjudligini tekshirish
    final bomResult = await db.execute(
      r'SELECT id, batch_size FROM product_boms WHERE id = $1',
      parameters: [bomId],
    );
    if (bomResult.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'BOM topilmadi'});
    }
    final batchSize = bomResult.first[1] != null
        ? double.parse(bomResult.first[1].toString())
        : 1.0;

    // BOM ingredientlarini olish
    final ingredients = await db.execute(
      r'''SELECT bi.material_id, m.name, bi.quantity, bi.unit
          FROM bom_ingredients bi
          JOIN materials m ON m.id = bi.material_id
          WHERE bi.bom_id = $1''',
      parameters: [bomId],
    );

    if (ingredients.isEmpty) {
      return Response.json(statusCode: 400, body: {'error': 'BOM da ingredientlar yo\'q'});
    }

    // Multiplier: nechta batch kerak
    final multiplier = batchSize > 0 ? plannedQuantity / batchSize : plannedQuantity;

    // Har bir ingredient uchun ombordan zaxirani tekshirish
    final shortages = <Map<String, dynamic>>[];
    for (final ing in ingredients) {
      final materialId = ing[0] as int;
      final materialName = ing[1] as String;
      final needed = double.parse(ing[2].toString()) * multiplier;

      // Ombordagi jami balans
      final stockResult = await db.execute(
        r'''SELECT COALESCE(SUM(CASE WHEN transaction_type = 'in' THEN quantity ELSE -quantity END), 0)
            FROM warehouse_transactions
            WHERE material_id = $1''',
        parameters: [materialId],
      );
      final available = stockResult.isNotEmpty
          ? double.parse(stockResult.first[0].toString())
          : 0.0;

      if (available < needed) {
        shortages.add({
          'materialName': materialName,
          'needed': needed,
          'available': available,
          'unit': ing[3],
        });
      }
    }

    if (shortages.isNotEmpty) {
      return Response.json(statusCode: 400, body: {
        'error': 'Zaxira yetarli emas',
        'shortages': shortages,
      });
    }

    // Tranzaksiyani boshlash
    await db.execute(r'BEGIN');
    try {
      final batchNumber = 'PRD-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      final result = await db.execute(
        r"INSERT INTO production_batches (batch_number, bom_id, planned_quantity, unit, operator_id, factory_id, status, started_at) VALUES ($1, $2, $3, $4, $5, $6, 'in_progress', NOW()) RETURNING id, batch_number, planned_quantity, unit, status, started_at",
        parameters: [batchNumber, bomId, plannedQuantity, unit, operatorId, factoryId],
      );
      final row = result.first;
      final batchId = row[0] as int;

      // Xom ashyo ombordan chiqim
      for (final ing in ingredients) {
        final materialId = ing[0] as int;
        final needed = double.parse(ing[2].toString()) * multiplier;
        final ingUnit = ing[3] as String;

        // Materialning omborini topish
        final whResult = await db.execute(
          r'''SELECT wt.warehouse_id FROM warehouse_transactions wt
              WHERE wt.material_id = $1
              GROUP BY wt.warehouse_id
              ORDER BY SUM(CASE WHEN wt.transaction_type = 'in' THEN wt.quantity ELSE -wt.quantity END) DESC
              LIMIT 1''',
          parameters: [materialId],
        );

        if (whResult.isNotEmpty) {
          final warehouseId = whResult.first[0] as int;
          await db.execute(
            r"INSERT INTO warehouse_transactions (warehouse_id, material_id, transaction_type, quantity, unit, reference_type, reference_id, batch_number, performed_by) VALUES ($1, $2, 'out', $3, $4, 'production', $5, $6, $7)",
            parameters: [warehouseId, materialId, needed, ingUnit, batchId, batchNumber, operatorId],
          );
        }
      }

      await db.execute(r'COMMIT');

      return Response.json(statusCode: 201, body: {
        'message': 'Ishlab chiqarish boshlandi',
        'batch': {
          'id': row[0], 'batchNumber': row[1],
          'plannedQuantity': double.parse(row[2].toString()),
          'unit': row[3], 'status': row[4], 'startedAt': row[5]?.toString(),
        }
      });
    } catch (e) {
      await db.execute(r'ROLLBACK');
      rethrow;
    }
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
