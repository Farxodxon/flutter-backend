import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat GET'});
  }

  try {
    final db = await Database.connect();
    final result = await db.execute(
      'SELECT id, name, description FROM product_types ORDER BY id',
    );

    final types = result.map((row) => {
      'id': row[0],
      'name': row[1],
      'description': row[2],
    }).toList();

    return Response.json(body: {'product_types': types, 'total': types.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Server xatosi: $e'});
  }
}
