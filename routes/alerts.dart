import 'package:dart_frog/dart_frog.dart';
import '../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getAlerts();
    case HttpMethod.post:
      return _generateAlerts();
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getAlerts() async {
  final db = await Database.connect();
  
  try {
    // Oxirgi 50 ta ogohlantirish
    final alerts = await db.execute(
      r'''SELECT sa.id, m.name as material_name, sa.alert_type, sa.current_stock, 
         sa.min_required, sa.daily_usage, sa.days_until_empty, sa.suggested_order_date,
         sa.suggested_order_quantity, sa.is_read, sa.created_at
         FROM stock_alerts sa
         LEFT JOIN materials m ON sa.material_id = m.id
         ORDER BY sa.created_at DESC
         LIMIT 50''',
    );
    
    // Joriy zaxira holati
    final lowStock = await db.execute(
      r'''SELECT id, name, type, unit, current_stock, min_stock, lead_time_days
         FROM materials
         WHERE current_stock <= min_stock AND min_stock > 0
         ORDER BY current_stock ASC''',
    );
    
    return Response.json(body: {
      'alerts': alerts.map((row) => {
        'id': row[0],
        'materialName': row[1],
        'alertType': row[2],
        'currentStock': double.parse(row[3].toString()),
        'minRequired': double.parse(row[4].toString()),
        'dailyUsage': double.parse(row[5].toString()),
        'daysUntilEmpty': row[6],
        'suggestedOrderDate': row[7]?.toString(),
        'suggestedOrderQuantity': double.parse(row[8].toString()),
        'isRead': row[9],
        'createdAt': row[10]?.toString(),
      }).toList(),
      'lowStockMaterials': lowStock.map((row) => {
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'unit': row[3],
        'currentStock': double.parse(row[4].toString()),
        'minStock': double.parse(row[5].toString()),
        'leadTimeDays': row[6],
      }).toList(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _generateAlerts() async {
  final db = await Database.connect();
  
  try {
    // Kam qolgan materiallarni topish
    final lowMaterials = await db.execute(
      r'''SELECT id, name, current_stock, min_stock, lead_time_days
         FROM materials
         WHERE current_stock <= min_stock AND min_stock > 0''',
    );
    
    int alertsGenerated = 0;
    
    for (final material in lowMaterials) {
      final materialId = material[0] as int;
      final currentStock = double.parse(material[2].toString());
      final minStock = double.parse(material[3].toString());
      final leadTimeDays = material[4] as int;
      
      // Kunlik ishlatish (taxminiy)
      final dailyUsage = minStock / 30;
      final daysUntilEmpty = dailyUsage > 0 ? (currentStock / dailyUsage).ceil() : 0;
      
      final alertType = currentStock <= 0 ? 'critical' : 'low_stock';
      final suggestedOrderQty = (minStock * 2) - currentStock;
      
      // Ogohlantirish qo'shish
      await db.execute(
        r'''INSERT INTO stock_alerts (material_id, alert_type, current_stock, min_required, daily_usage, days_until_empty, suggested_order_quantity, suggested_order_date) 
           VALUES ($1, $2, $3, $4, $5, $6, $7, NOW() + ($8 || ' days')::INTERVAL)''',
        parameters: [materialId, alertType, currentStock, minStock, dailyUsage, daysUntilEmpty, suggestedOrderQty, leadTimeDays.toString()],
      );
      
      alertsGenerated++;
    }
    
    return Response.json(body: {
      'message': 'Ogohlantirishlar yangilandi',
      'alertsGenerated': alertsGenerated,
      'timestamp': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
