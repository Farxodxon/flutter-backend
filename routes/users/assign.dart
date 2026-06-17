import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  final payload = context.read<Map<String, dynamic>>();
  final role = payload['role'] as String? ?? 'employee';

  if (role == 'employee') {
    return Response.json(statusCode: 403, body: {'error': 'Ruxsat yoq'});
  }

  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Faqat POST'});
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final userId = body['user_id'] as int?;
    final departmentIds = (body['department_ids'] as List?)?.map((e) => e as int).toList() ?? [];
    final warehouseIds = (body['warehouse_ids'] as List?)?.map((e) => e as int).toList() ?? [];

    if (userId == null) {
      return Response.json(statusCode: 400, body: {'error': 'user_id majburiy'});
    }

    final db = await Database.connect();
    await db.execute('BEGIN');

    try {
      await db.execute(
        'DELETE FROM user_departments WHERE user_id = \$1',
        parameters: [userId],
      );
      for (final dId in departmentIds) {
        await db.execute(
          'INSERT INTO user_departments (user_id, department_id) VALUES (\$1, \$2) ON CONFLICT DO NOTHING',
          parameters: [userId, dId],
        );
      }

      await db.execute(
        'DELETE FROM user_warehouses WHERE user_id = \$1',
        parameters: [userId],
      );
      for (final wId in warehouseIds) {
        await db.execute(
          'INSERT INTO user_warehouses (user_id, warehouse_id) VALUES (\$1, \$2) ON CONFLICT DO NOTHING',
          parameters: [userId, wId],
        );
      }

      await db.execute('COMMIT');

      final deptResult = await db.execute(
        '''SELECT d.id, d.name FROM departments d
           JOIN user_departments ud ON ud.department_id = d.id
           WHERE ud.user_id = \$1''',
        parameters: [userId],
      );
      final wareResult = await db.execute(
        '''SELECT w.id, w.name FROM warehouses w
           JOIN user_warehouses uw ON uw.warehouse_id = w.id
           WHERE uw.user_id = \$1''',
        parameters: [userId],
      );

      return Response.json(body: {
        'message': 'Biriktirildi',
        'departments': deptResult.map((r) => {'id': r[0], 'name': r[1]}).toList(),
        'warehouses': wareResult.map((r) => {'id': r[0], 'name': r[1]}).toList(),
      });
    } catch (e) {
      await db.execute('ROLLBACK');
      rethrow;
    }
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
  }
}
