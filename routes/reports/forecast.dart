import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
  
  final db = await Database.connect();
  
  try {
    // O'rtacha kunlik sotuv
    final avgSalesResult = await db.execute(
      r"SELECT COALESCE(AVG(daily_qty), 0) FROM (SELECT DATE(created_at) as date, SUM(quantity) as daily_qty FROM sales WHERE created_at >= CURRENT_DATE - INTERVAL '30 days' GROUP BY DATE(created_at)) t",
    );
    final dailyAvgSales = double.parse(avgSalesResult.first[0].toString());
    
    // Materiallar
    final materials = await db.execute(
      r"SELECT m.id, m.name, m.type, m.unit, m.current_stock, m.min_stock, m.lead_time_days, COALESCE(s.name, 'Nomalum') as supplier_name FROM materials m LEFT JOIN suppliers s ON m.supplier_id = s.id ORDER BY m.id",
    );
    
    final forecasts = <Map<String, dynamic>>[];
    double totalDaysReserve = double.infinity;
    
    for (final row in materials) {
      final currentStock = double.parse(row[4].toString());
      final minStock = double.parse(row[5].toString());
      final leadTimeDays = row[6] as int;
      
      final dailyUsage = dailyAvgSales > 0 ? dailyAvgSales : (minStock / 30.0);
      final daysRemaining = dailyUsage > 0 ? (currentStock / dailyUsage) : 999.0;
      
      String? suggestedOrderDate;
      String status = 'ok';
      
      if (daysRemaining <= leadTimeDays) {
        status = 'critical';
        suggestedOrderDate = 'HOZIR buyurtma bering!';
      } else if (daysRemaining <= leadTimeDays * 1.5) {
        status = 'warning';
        final orderDays = (daysRemaining - leadTimeDays).ceil();
        suggestedOrderDate = '$orderDays kun ichida buyurtma bering';
      }
      
      if (daysRemaining < totalDaysReserve) {
        totalDaysReserve = daysRemaining;
      }
      
      forecasts.add({
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'unit': row[3],
        'currentStock': currentStock,
        'minStock': minStock,
        'leadTimeDays': leadTimeDays,
        'supplierName': row[7],
        'dailyUsage': double.parse(dailyUsage.toStringAsFixed(2)),
        'daysRemaining': daysRemaining.ceil(),
        'status': status,
        'suggestedOrder': suggestedOrderDate,
      });
    }
    
    // Tayyor mahsulot
    final finishedResult = await db.execute(
      r"SELECT COALESCE(SUM(quantity), 0) FROM finished_products WHERE status = 'in_stock'",
    );
    final totalFinished = double.parse(finishedResult.first[0].toString());
    final finishedDays = dailyAvgSales > 0 ? (totalFinished / dailyAvgSales) : 999.0;
    
    return Response.json(body: {
      'report': 'Prognoz hisoboti',
      'generatedAt': DateTime.now().toIso8601String(),
      'summary': {
        'avgDailySales': double.parse(dailyAvgSales.toStringAsFixed(2)),
        'totalFinishedProducts': totalFinished,
        'finishedDaysReserve': finishedDays.ceil(),
        'minMaterialDaysReserve': totalDaysReserve == double.infinity ? 0 : totalDaysReserve.ceil(),
        'totalReserveDays': (finishedDays + (totalDaysReserve == double.infinity ? 0 : totalDaysReserve)).ceil(),
      },
      'forecasts': forecasts,
      'alerts': {
        'critical': forecasts.where((f) => f['status'] == 'critical').length,
        'warning': forecasts.where((f) => f['status'] == 'warning').length,
        'ok': forecasts.where((f) => f['status'] == 'ok').length,
      }
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
