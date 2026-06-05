import 'package:dart_frog/dart_frog.dart';
import '../../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
  
  final db = await Database.connect();
  
  try {
    final materialsCount = await db.execute(r'SELECT COUNT(*) FROM materials');
    final totalMaterials = materialsCount.first[0] as int;
    
    final lowStock = await db.execute(
      r'SELECT COUNT(*) FROM materials WHERE current_stock <= min_stock AND min_stock > 0',
    );
    final lowStockCount = lowStock.first[0] as int;
    
    final activeBatches = await db.execute(
      r"SELECT COUNT(*) FROM production_batches WHERE status IN ('planned', 'in_progress')",
    );
    final activeBatchCount = activeBatches.first[0] as int;
    
    final todayCompleted = await db.execute(
      r"SELECT COUNT(*) FROM production_batches WHERE status = 'completed' AND completed_at::date = CURRENT_DATE",
    );
    final todayCompletedCount = todayCompleted.first[0] as int;
    
    final monthlyProduction = await db.execute(
      r"SELECT COALESCE(SUM(actual_quantity), 0) FROM production_batches WHERE status = 'completed' AND completed_at >= date_trunc('month', CURRENT_DATE)",
    );
    final monthlyTotal = double.parse(monthlyProduction.first[0].toString());
    
    final warehousesCount = await db.execute(r'SELECT COUNT(*) FROM warehouses');
    final totalWarehouses = warehousesCount.first[0] as int;
    
    final recentTransactions = await db.execute(
      r'''SELECT wt.id, w.name as warehouse_name, m.name as material_name, 
         wt.transaction_type, wt.quantity, wt.unit, wt.created_at
         FROM warehouse_transactions wt
         LEFT JOIN warehouses w ON wt.warehouse_id = w.id
         LEFT JOIN materials m ON wt.material_id = m.id
         ORDER BY wt.created_at DESC
         LIMIT 5''',
    );
    
    return Response.json(body: {
      'summary': {
        'totalMaterials': totalMaterials,
        'lowStockCount': lowStockCount,
        'activeBatches': activeBatchCount,
        'todayCompleted': todayCompletedCount,
        'monthlyProduction': monthlyTotal,
        'totalWarehouses': totalWarehouses,
      },
      'recentTransactions': recentTransactions.map((row) => {
        'id': row[0],
        'warehouseName': row[1],
        'materialName': row[2],
        'type': row[3],
        'quantity': double.parse(row[4].toString()),
        'unit': row[5],
        'createdAt': row[6]?.toString(),
      }).toList(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
