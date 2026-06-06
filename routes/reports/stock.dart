import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
  
  final db = await Database.connect();
  
  try {
    // Materiallar bo'yicha to'liq zaxira hisoboti
    final materials = await db.execute(
      r'''SELECT id, name, type, unit, current_stock, min_stock, max_stock,
         CASE 
           WHEN current_stock <= 0 THEN 'critical'
           WHEN current_stock <= min_stock THEN 'low'
           WHEN current_stock <= (min_stock * 1.5) THEN 'warning'
           ELSE 'ok'
         END as status
         FROM materials
         ORDER BY 
           CASE 
             WHEN current_stock <= 0 THEN 1
             WHEN current_stock <= min_stock THEN 2
             WHEN current_stock <= (min_stock * 1.5) THEN 3
             ELSE 4
           END''',
    );
    
    // Omborlar bo'yicha xulosa
    final warehouseSummary = await db.execute(
      r'''SELECT w.id, w.name, w.type, 
         COUNT(wt.id) as total_transactions,
         COALESCE(SUM(CASE WHEN wt.transaction_type = 'in' THEN wt.quantity ELSE 0 END), 0) as total_in,
         COALESCE(SUM(CASE WHEN wt.transaction_type = 'out' THEN wt.quantity ELSE 0 END), 0) as total_out
         FROM warehouses w
         LEFT JOIN warehouse_transactions wt ON w.id = wt.warehouse_id
         GROUP BY w.id, w.name, w.type
         ORDER BY w.id''',
    );
    
    // Umumiy statistika
    final stats = await db.execute(
      r'''SELECT 
         COUNT(*) as total_materials,
         COUNT(CASE WHEN current_stock <= 0 THEN 1 END) as critical_count,
         COUNT(CASE WHEN current_stock <= min_stock AND current_stock > 0 THEN 1 END) as low_count,
         SUM(current_stock) as total_stock
         FROM materials''',
    );
    
    return Response.json(body: {
      'report': 'Zaxira hisoboti',
      'generatedAt': DateTime.now().toIso8601String(),
      'statistics': {
        'totalMaterials': stats.first[0],
        'criticalCount': stats.first[1] ?? 0,
        'lowStockCount': stats.first[2] ?? 0,
        'totalStockQuantity': double.parse((stats.first[3] ?? 0).toString()),
      },
      'materials': materials.map((row) => {
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'unit': row[3],
        'currentStock': double.parse(row[4].toString()),
        'minStock': double.parse(row[5].toString()),
        'maxStock': double.parse(row[6].toString()),
        'status': row[7],
      }).toList(),
      'warehouseSummary': warehouseSummary.map((row) => {
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'totalTransactions': row[3],
        'totalIn': double.parse((row[4] ?? 0).toString()),
        'totalOut': double.parse((row[5] ?? 0).toString()),
        'currentBalance': double.parse((row[4] ?? 0).toString()) - double.parse((row[5] ?? 0).toString()),
      }).toList(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
