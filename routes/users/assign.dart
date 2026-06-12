import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Faqat POST ruxsat etilgan'},
    );
  }

  final parsed = await context.request.json();
  if (parsed is! Map<String, dynamic>) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'JSON obyekt kutilgan'},
    );
  }

  return _assignUser(parsed);
}

Future<Response> _assignUser(Map<String, dynamic> body) async {
  final db = await Database.connect();

  final userId = body['user_id'] as int?;
  final departmentId = body['department_id'] as int?;
  final warehouseId = body['warehouse_id'] as int?;

  if (userId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'user_id majburiy'},
    );
  }

  if (departmentId == null && warehouseId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'department_id yoki warehouse_id majburiy'},
    );
  }

  try {
    final results = <String, dynamic>{};

    // Bo'limga biriktirish
    if (departmentId != null) {
      await db.execute(
        r'INSERT INTO user_departments (user_id, department_id) VALUES ($1, $2) ON CONFLICT (user_id, department_id) DO NOTHING',
        parameters: [userId, departmentId],
      );
      results['department'] = 'Xodim bo\'limga biriktirildi';
    }

    // Omborxona'ga biriktirish
    if (warehouseId != null) {
      await db.execute(
        r'INSERT INTO user_warehouses (user_id, warehouse_id) VALUES ($1, $2) ON CONFLICT (user_id, warehouse_id) DO NOTHING',
        parameters: [userId, warehouseId],
      );
      results['warehouse'] = 'Xodim omborga biriktirildi';
    }

    return Response.json(statusCode: 201, body: {
      'message': 'Xodim muvaffaqiyatli biriktirildi',
      'details': results,
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Xatolik: $e'},
    );
  }
}
