import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getDepartments(context);
    case HttpMethod.post:
      final parsed = await context.request.json();
      if (parsed is! Map<String, dynamic>) {
        return Response.json(statusCode: 400, body: {'error': 'JSON obyekt kutilgan'});
      }
      return _createDepartment(parsed);
    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}

Future<Response> _getDepartments(RequestContext context) async {
  final db = await Database.connect();
  final factoryId = context.request.uri.queryParameters['factory_id'];

  try {
    var query = 'SELECT d.id, d.factory_id, d.name, d.description, d.is_active, d.created_at FROM departments d';
    final params = <dynamic>[];

    if (factoryId != null) {
      query += ' WHERE d.factory_id = \$1';
      params.add(int.tryParse(factoryId));
    }

    query += ' ORDER BY d.id';

    final result = params.isEmpty
        ? await db.execute(query)
        : await db.execute(query, parameters: params);

    final departments = result.map((row) => {
      'id': row[0],
      'factoryId': row[1],
      'name': row[2],
      'description': row[3],
      'isActive': row[4],
      'createdAt': row[5]?.toString(),
    }).toList();

    return Response.json(body: {'departments': departments, 'total': departments.length});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}

Future<Response> _createDepartment(Map<String, dynamic> body) async {
  final db = await Database.connect();
  final name = body['name'] as String?;
  final factoryId = body['factory_id'] as int?;
  final description = body['description'] as String?;

  if (name == null || factoryId == null) {
    return Response.json(statusCode: 400, body: {'error': 'name va factory_id majburiy'});
  }

  try {
    final result = await db.execute(
      r'INSERT INTO departments (name, factory_id, description) VALUES ($1, $2, $3) RETURNING id, name, factory_id, description, is_active, created_at',
      parameters: [name, factoryId, description],
    );
    final row = result.first;
    return Response.json(statusCode: 201, body: {
      'message': 'Bo\'lim yaratildi',
      'department': {
        'id': row[0], 'name': row[1], 'factoryId': row[2],
        'description': row[3], 'isActive': row[4], 'createdAt': row[5]?.toString(),
      },
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
