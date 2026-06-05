import 'package:dart_frog/dart_frog.dart';
import '../../lib/database.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getBatch(id);
    case HttpMethod.put:
      return _updateBatch(id, await context.request.json());
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getBatch(String id) async {
  final db = await Database.connect();
  
  try {
    final result = await db.execute(
      r'''SELECT pb.id, pb.batch_number, pb.bom_id, pb2.name as bom_name,
         pb.planned_quantity, pb.actual_quantity, pb.unit, pb.status,
         pb.started_at, pb.completed_at, pb.notes
         FROM production_batches pb
         LEFT JOIN product_boms pb2 ON pb.bom_id = pb2.id
         WHERE pb.id = $1''',
      parameters: [int.tryParse(id)],
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
        'plannedQuantity': double.parse(row[4].toString()),
        'actualQuantity': row[5] != null ? double.parse(row[5].toString()) : 0,
        'unit': row[6],
        'status': row[7],
        'startedAt': row[8]?.toString(),
        'completedAt': row[9]?.toString(),
        'notes': row[10],
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _updateBatch(String id, Map<String, dynamic> body) async {
  final db = await Database.connect();
  
  final status = body['status'] as String?;
  final actualQuantity = body['actual_quantity'] as num?;
  
  if (status == null) {
    return Response.json(statusCode: 400, body: {'error': 'status majburiy'});
  }
  
  try {
    final updates = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;
    
    updates.add('status = \$${paramIdx++}');
    params.add(status);
    
    if (actualQuantity != null) {
      updates.add('actual_quantity = \$${paramIdx++}');
      params.add(actualQuantity);
    }
    
    if (status == 'completed') {
      updates.add('completed_at = NOW()');
    }
    
    params.add(int.tryParse(id));
    
    final result = await db.execute(
      'UPDATE production_batches SET ${updates.join(', ')} WHERE id = \$${paramIdx} RETURNING id, batch_number, status, actual_quantity, completed_at',
      parameters: params,
    );
    
    if (result.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Partiya topilmadi'});
    }
    
    if (status == 'completed' && actualQuantity != null && actualQuantity > 0) {
      final batch = result.first;
      
      final warehouseResult = await db.execute(r"SELECT id FROM warehouses WHERE type = 'semi_finished' LIMIT 1");
      
      if (warehouseResult.isNotEmpty) {
        final warehouseId = warehouseResult.first[0] as int;
        
        await db.execute(
          r'''INSERT INTO warehouse_transactions (warehouse_id, material_id, transaction_type, quantity, unit, reference_type, reference_id, batch_number) 
             VALUES ($1, NULL, 'in', $2, 'dona', 'production', $3, $4)''',
          parameters: [warehouseId, actualQuantity, batch[0], batch[1]],
        );
      }
    }
    
    final row = result.first;
    return Response.json(body: {
      'message': 'Partiya yangilandi',
      'batch': {
        'id': row[0],
        'batchNumber': row[1],
        'status': row[2],
        'actualQuantity': row[3] != null ? double.parse(row[3].toString()) : null,
        'completedAt': row[4]?.toString(),
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
