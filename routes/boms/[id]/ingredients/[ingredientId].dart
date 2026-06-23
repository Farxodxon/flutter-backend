import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context, String id, String ingredientId) async {
  if (context.request.method != HttpMethod.delete) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
  final ingId = int.tryParse(ingredientId);
  if (ingId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Noto\'g\'ri ID'});
  }
  final db = await Database.connect();
  try {
    await db.execute(r'DELETE FROM bom_ingredients WHERE id = $1', parameters: [ingId]);
    return Response.json(body: {'message': 'Ingredient o\'chirildi'});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
