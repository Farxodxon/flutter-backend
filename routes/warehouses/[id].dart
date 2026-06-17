import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final warehouseId = int.tryParse(id);
  if (warehouseId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Notogri ID'});
  }

  final db = await Database.connect();

  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  try {
    final whResult = await db.execute(
      'SELECT id, name, type, factory_id FROM warehouses WHERE id = \\$1',
      parameters: [warehouseId],
    );
    if (whResult.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Topilmadi'});
    }
    final wh = whResult.first;

    // Shu ombordagi har bir material boyicha jami kirim/chiqim
    final stockResult = await db.execute(
      '''SELECT
           m.id, m.name, m.unit,
           COALESCE(SUM(CASE WHEN wt.transaction_type = 'in' THEN wt.quantity ELSE 0 END), 0) as total_in,
           COALESCE(SUM(CASE WHEN wt.transaction_type = 'out' THEN wt.quantity ELSE 0 END), 0) as total_out
         FROM materials m
         LEFT JOIN warehouse_transactions wt ON wt.material_id = m.id AND wt.warehouse_id = \\$1
         WHERE m.id IN (SELECT DISTINCT material_id FROM warehouse_transactions WHERE warehouse_id = \\$1)
         GROUP BY m.id, m.name, m.unit
         ORDER BY m.name''',
      parameters: [warehouseId],
    );

    final materials = stockResult.map((row) {
      final totalIn = double.parse(row[3].toString());
      final totalOut = double.parse(row[4].toString());
      return {
        'materialId': row[0],
        'materialName': row[1],
        'unit': row[2],
        'totalIn': totalIn,
        'totalOut': totalOut,
        'balance': totalIn - totalOut,
      };
    }).toList();

    // Songgi 20 ta tranzaksiya
    final txResult = await db.execute(
      '''SELECT wt.id, wt.material_id, m.name, wt.transaction_type, wt.quantity, wt.unit, wt.notes, wt.created_at
         FROM warehouse_transactions wt
         JOIN materials m ON m.id = wt.material_id
         WHERE wt.warehouse_id = \\$1
         ORDER BY wt.created_at DESC
         LIMIT 20''',
      parameters: [warehouseId],
    );

    final transactions = txResult.map((row) => {
      'id': row[0],
      'materialId': row[1],
      'materialName': row[2],
      'type': row[3],
      'quantity': double.parse(row[4].toString()),
      'unit': row[5],
      'notes': row[6],
      'createdAt': row[7]?.toString(),
    }).toList();

    return Response.json(body: {
      'warehouse': {'id': wh[0], 'name': wh[1], 'type': wh[2], 'factoryId': wh[3]},
      'materials': materials,
      'transactions': transactions,
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
  }
}
