import 'package:dart_frog/dart_frog.dart';
import '../../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
  
  final db = await Database.connect();
  
  // Sana filtri (query parametrdan)
  final params = context.request.uri.queryParameters;
  final period = params['period'] ?? 'month'; // 'today', 'week', 'month', 'year', 'all'
  
  try {
    String dateCondition;
    switch (period) {
      case 'today':
        dateCondition = "created_at::date = CURRENT_DATE";
        break;
      case 'week':
        dateCondition = "created_at >= date_trunc('week', CURRENT_DATE)";
        break;
      case 'year':
        dateCondition = "created_at >= date_trunc('year', CURRENT_DATE)";
        break;
      case 'all':
        dateCondition = 'TRUE';
        break;
      default: // month
        dateCondition = "created_at >= date_trunc('month', CURRENT_DATE)";
    }
    
    // Partiyalar hisoboti
    final batches = await db.execute(
      'SELECT id, batch_number, bom_id, planned_quantity, actual_quantity, unit, status, started_at, completed_at, notes FROM production_batches WHERE $dateCondition ORDER BY id DESC',
    );
    
    // Statistika
    final stats = await db.execute(
      'SELECT COUNT(*) as total, COUNT(CASE WHEN status = \'completed\' THEN 1 END) as completed, COUNT(CASE WHEN status = \'in_progress\' THEN 1 END) as in_progress, COUNT(CASE WHEN status = \'cancelled\' THEN 1 END) as cancelled, COALESCE(SUM(CASE WHEN status = \'completed\' THEN actual_quantity ELSE 0 END), 0) as total_produced FROM production_batches WHERE $dateCondition',
    );
    
    // Kunlik ishlab chiqarish (oxirgi 30 kun)
    final dailyProduction = await db.execute(
      r'''SELECT DATE(started_at) as date, COUNT(*) as batches, 
         COALESCE(SUM(actual_quantity), 0) as quantity
         FROM production_batches 
         WHERE started_at >= CURRENT_DATE - INTERVAL '30 days'
         GROUP BY DATE(started_at)
         ORDER BY date''',
    );
    
    return Response.json(body: {
      'report': 'Ishlab chiqarish hisoboti',
      'period': period,
      'generatedAt': DateTime.now().toIso8601String(),
      'statistics': {
        'totalBatches': stats.first[0],
        'completedBatches': stats.first[1] ?? 0,
        'inProgressBatches': stats.first[2] ?? 0,
        'cancelledBatches': stats.first[3] ?? 0,
        'totalProduced': double.parse((stats.first[4] ?? 0).toString()),
      },
      'dailyProduction': dailyProduction.map((row) => {
        'date': row[0]?.toString(),
        'batches': row[1],
        'quantity': double.parse(row[2].toString()),
      }).toList(),
      'batches': batches.map((row) => {
        'id': row[0],
        'batchNumber': row[1],
        'bomId': row[2],
        'plannedQuantity': double.parse(row[3].toString()),
        'actualQuantity': row[4] != null ? double.parse(row[4].toString()) : 0,
        'unit': row[5],
        'status': row[6],
        'startedAt': row[7]?.toString(),
        'completedAt': row[8]?.toString(),
        'notes': row[9],
      }).toList(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
