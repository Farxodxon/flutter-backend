import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final materialId = int.tryParse(id);
  if (materialId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Notogri ID'});
  }

  final payload = context.read<Map<String, dynamic>>();
  final role = payload['role'] as String? ?? 'employee';

  if (role == 'employee' && context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 403, body: {'error': 'Ruxsat yoq'});
  }

  final db = await Database.connect();

  switch (context.request.method) {
    case HttpMethod.get:
      try {
        final result = await db.execute(
          '''SELECT id, name, type, unit, current_stock, min_stock, max_stock,
             supplier_id, lead_time_days, factory_id, assigned_to, created_at
             FROM materials WHERE id = \$1''',
          parameters: [materialId],
        );
        if (result.isEmpty) {
          return Response.json(statusCode: 404, body: {'error': 'Topilmadi'});
        }
        final row = result.first;
        return Response.json(body: {
          'material': {
            'id': row[0], 'name': row[1], 'type': row[2], 'unit': row[3],
            'currentStock': double.parse(row[4].toString()),
            'minStock': double.parse(row[5].toString()),
            'maxStock': double.parse(row[6].toString()),
            'supplierId': row[7], 'leadTimeDays': row[8],
            'factoryId': row[9], 'assignedTo': row[10],
            'createdAt': row[11]?.toString(),
          },
        });
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
      }

    case HttpMethod.put:
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final setParts = <String>[];
        final params = <dynamic>[];
        var idx = 1;

        void addField(String column, dynamic value) {
          if (value != null) {
            setParts.add('$column = \$$idx');
            params.add(value);
            idx++;
          }
        }

        addField('name', body['name']);
        addField('type', body['type']);
        addField('unit', body['unit']);
        addField('min_stock', body['min_stock']);
        addField('max_stock', body['max_stock']);
        addField('lead_time_days', body['lead_time_days']);
        addField('assigned_to', body['assigned_to']);

        if (setParts.isEmpty) {
          return Response.json(statusCode: 400, body: {'error': 'Yangilanadigan maydon yoq'});
        }

        params.add(materialId);
        final result = await db.execute(
          'UPDATE materials SET ${setParts.join(', ')} WHERE id = \$$idx RETURNING id, name, type, unit, current_stock, min_stock, max_stock, factory_id, assigned_to',
          parameters: params,
        );

        if (result.isEmpty) {
          return Response.json(statusCode: 404, body: {'error': 'Topilmadi'});
        }
        final row = result.first;
        return Response.json(body: {
          'message': 'Yangilandi',
          'material': {
            'id': row[0], 'name': row[1], 'type': row[2], 'unit': row[3],
            'currentStock': double.parse(row[4].toString()),
            'minStock': double.parse(row[5].toString()),
            'maxStock': double.parse(row[6].toString()),
            'factoryId': row[7], 'assignedTo': row[8],
          },
        });
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Server xatosi'});
      }

    case HttpMethod.delete:
      if (role != 'super_admin' && role != 'admin') {
        return Response.json(statusCode: 403, body: {'error': 'Ruxsat yoq'});
      }
      try {
        final result = await db.execute(
          'DELETE FROM materials WHERE id = \$1 RETURNING id',
          parameters: [materialId],
        );
        if (result.isEmpty) {
          return Response.json(statusCode: 404, body: {'error': 'Topilmadi'});
        }
        return Response.json(body: {'message': 'Ochirildi'});
      } catch (e) {
        return Response.json(statusCode: 500, body: {'error': 'Material ishlatilgan, ochirib bolmaydi'});
      }

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
