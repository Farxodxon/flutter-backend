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
    final plannedQuantity = body['planned_quantity'] as num?;
    final unit = body['unit'] as String? ?? 'dona';
    final operatorId = body['operator_id'] as int?;
    final factoryId = body['factory_id'] as int?;

    if (bomId == null || plannedQuantity == null || operatorId == null) {
      return Response.json(statusCode: 400, body: {'error': 'bom_id, planned_quantity, operator_id majburiy'});
    }

    final db = await Database.connect();
    final batchNumber = 'PRD-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final result = await db.execute(
      r"INSERT INTO production_batches (batch_number, bom_id, planned_quantity, unit, operator_id, factory_id, status, started_at) VALUES ($1, $2, $3, $4, $5, $6, 'in_progress', NOW()) RETURNING id, batch_number, planned_quantity, unit, status, started_at",
      parameters: [batchNumber, bomId, plannedQuantity, unit, operatorId, factoryId],
    );

    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Ishlab chiqarish boshlandi',
      'batch': {'id': row[0], 'batchNumber': row[1], 'plannedQuantity': double.parse(row[2].toString()), 'unit': row[3], 'status': row[4], 'startedAt': row[5]?.toString()}
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
