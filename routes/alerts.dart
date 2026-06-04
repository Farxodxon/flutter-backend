import 'package:dart_frog/dart_frog.dart';
import '../lib/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
  
  final db = await Database.connect();
  
  try {
    // Joriy zaxira holati
    final lowStock = await db.execute(
      r'''SELECT id, name, type, unit, current_stock, min_stock, max_stock, lead_time_days
         FROM materials
         WHERE current_stock <= min_stock AND min_stock > 0
         ORDER BY current_stock ASC''',
    );
    
    // Barcha materiallar va ularning holati
    final allMaterials = await db.execute(
      r'''SELECT id, name, type, unit, current_stock, min_stock, max_stock, lead_time_days,
         CASE 
           WHEN current_stock <= 0 THEN 'critical'
           WHEN current_stock <= min_stock THEN 'low_stock'
           WHEN current_stock <= (min_stock * 1.5) THEN 'reorder'
           ELSE 'ok'
         END as status
         FROM materials
         ORDER BY 
           CASE 
             WHEN current_stock <= 0 THEN 0
             WHEN current_stock <= min_stock THEN 1
             WHEN current_stock <= (min_stock * 1.5) THEN 2
             ELSE 3
           END''',
    );
    
    final summary = {
      'critical': 0,
      'lowStock': 0,
      'reorder': 0,
      'ok': 0,
    };
    
    for (final row in allMaterials) {
      final status = row[9] as String;
      if (status == 'critical') summary['critical'] = (summary['critical'] as int) + 1;
      else if (status == 'low_stock') summary['lowStock'] = (summary['lowStock'] as int) + 1;
      else if (status == 'reorder') summary['reorder'] = (summary['reorder'] as int) + 1;
      else summary['ok'] = (summary['ok'] as int) + 1;
    }
    
    return Response.json(body: {
      'summary': summary,
      'alerts': lowStock.map((row) => {
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'unit': row[3],
        'currentStock': double.parse(row[4].toString()),
        'minStock': double.parse(row[5].toString()),
        'maxStock': double.parse(row[6].toString()),
        'leadTimeDays': row[7],
        'status': 'low_stock',
      }).toList(),
      'allMaterials': allMaterials.map((row) => {
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'unit': row[3],
        'currentStock': double.parse(row[4].toString()),
        'minStock': double.parse(row[5].toString()),
        'maxStock': double.parse(row[6].toString()),
        'leadTimeDays': row[7],
        'status': row[9],
      }).toList(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
