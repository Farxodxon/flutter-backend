import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final batchId = int.tryParse(id);
  if (batchId == null) {
    return Response.json(statusCode: 400, body: {'error': 'ID noto\'g\'ri formatda'});
  }

  switch (context.request.method) {
    case HttpMethod.get:
      return _getBatch(batchId);
    case HttpMethod.put:
      return _updateBatch(context, batchId);
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getBatch(int id) async {
  try {
    final db = await Database.connect();
    final result = await db.execute(
      r'''SELECT pb.id, pb.batch_number, pb.bom_id, pb2.name as bom_name,
         pb.planned_quantity, pb.actual_quantity, pb.unit, pb.status,
         pb.started_at, pb.completed_at, pb.notes
         FROM production_batches pb
         LEFT JOIN product_boms pb2 ON pb.bom_id = pb2.id
         WHERE pb.id = $1''',
      parameters: [id],
    );

    if (result.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Partiya topilmadi'});
    }

    final row = result.first;
    return Response.json(body: {
      'batch': {
        'id': row[0],
        'batchNumber': row[1],
        'bomId': row[2],
        'bomName': row[3],
        'plannedQuantity': _parseDouble(row[4], 0),
        'actualQuantity': _parseDouble(row[5], 0),
        'unit': row[6] ?? 'dona',
        'status': row[7] ?? 'unknown',
        'startedAt': row[8]?.toString(),
        'completedAt': row[9]?.toString(),
        'notes': row[10],
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Server xatosi: $e'});
  }
}

Future<Response> _updateBatch(RequestContext context, int id) async {
  Map<String, dynamic> body;
  try {
    final parsed = await context.request.json();
    if (parsed is! Map<String, dynamic>) {
      return Response.json(statusCode: 400, body: {'error': 'JSON obyekt bo\'lishi kerak'});
    }
    body = parsed;
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': 'Noto\'g\'ri JSON format'});
  }

  final status = body['status'];
  if (status == null || status is! String) {
    return Response.json(statusCode: 400, body: {'error': 'status majburiy (string)'});
  }

  const validStatuses = ['planned', 'in_progress', 'quality_check', 'completed', 'cancelled'];
  if (!validStatuses.contains(status)) {
    return Response.json(statusCode: 400, body: {'error': 'Status noto\'g\'ri'});
  }

  double? actualQuantity;
  if (body.containsKey('actual_quantity')) {
    final aq = body['actual_quantity'];
    if (aq is num) {
      actualQuantity = aq.toDouble();
    } else if (aq is String) {
      actualQuantity = double.tryParse(aq);
    }
  }

  try {
    final db = await Database.connect();

    final updates = <String>[];
    final params = <dynamic>[];

    updates.add('status = \$1');
    params.add(status);

    if (actualQuantity != null) {
      updates.add('actual_quantity = \$2');
      params.add(actualQuantity);
    }

    if (status == 'completed') {
      updates.add('completed_at = NOW()');
    }

    params.add(id);

    final sql = 'UPDATE production_batches SET ${updates.join(', ')} WHERE id = \$${params.length} RETURNING id, batch_number, status, actual_quantity, completed_at';

    final result = await db.execute(sql, parameters: params);

    if (result.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Partiya topilmadi'});
    }

    final row = result.first;

    if (status == 'completed' && actualQuantity != null && actualQuantity > 0) {
      try {
        final warehouseResult = await db.execute(
          r"SELECT id FROM warehouses WHERE type = 'semi_finished' LIMIT 1",
        );
        if (warehouseResult.isNotEmpty) {
          final warehouseId = warehouseResult.first[0] as int;
          await db.execute(
            r"INSERT INTO warehouse_transactions (warehouse_id, transaction_type, quantity, unit, reference_type, reference_id, batch_number) VALUES ($1, 'in', $2, 'dona', 'production', $3, $4)",
            parameters: [warehouseId, actualQuantity, row[0], row[1]],
          );
        }
      } catch (_) {}
    }

    return Response.json(body: {
      'message': 'Partiya yangilandi',
      'batch': {
        'id': row[0],
        'batchNumber': row[1],
        'status': row[2],
        'actualQuantity': _parseDouble(row[3], 0),
        'completedAt': row[4]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Server xatosi: $e'});
  }
}

double _parseDouble(dynamic value, double defaultValue) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}
