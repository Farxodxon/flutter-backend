import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

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
    final lowStock = await db.execute(
      r'SELECT id, name, type, unit, current_stock, min_stock FROM materials WHERE current_stock <= min_stock AND min_stock > 0 ORDER BY current_stock ASC',
    );
    return Response.json(body: {
      'alerts': [],
      'lowStockMaterials': lowStock.map((row) => {
        'id': row[0], 'name': row[1], 'type': row[2], 'unit': row[3],
        'currentStock': double.parse(row[4].toString()), 'minStock': double.parse(row[5].toString()),
      }).toList(),
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _generateAlerts() async {
  return Response.json(body: {'message': 'Ogohlantirishlar yangilandi', 'alertsGenerated': 0});
}
