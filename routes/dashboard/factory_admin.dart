import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final payload = context.read<Map<String, dynamic>>();
  final role = payload['role'] as String? ?? '';
  final factoryId = payload['factory_id'] as int?;

  if (role != 'admin') {
    return Response.json(statusCode: 403, body: {'error': 'Faqat zavod admin uchun'});
  }
  if (factoryId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Factory ID topilmadi'});
  }

  final db = await Database.connect();

  try {
    // Zavod ma'lumotlari
    final factoryRes = await db.execute(
      'SELECT id, name, address, is_active FROM factories WHERE id = \$1',
      parameters: [factoryId],
    );
    if (factoryRes.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Zavod topilmadi'});
    }
    final factory = {
      'id': factoryRes.first[0],
      'name': factoryRes.first[1],
      'address': factoryRes.first[2],
      'isActive': factoryRes.first[3],
    };

    // Xodimlar soni
    final usersRes = await db.execute(
      'SELECT COUNT(*) FROM users WHERE factory_id = \$1 AND is_active = TRUE',
      parameters: [factoryId],
    );
    final totalUsers = usersRes.first[0] as int;

    // Materiallar
    final materialsRes = await db.execute(
      'SELECT COUNT(*) FROM materials WHERE factory_id = \$1',
      parameters: [factoryId],
    );
    final totalMaterials = materialsRes.first[0] as int;

    final lowStockRes = await db.execute(
      'SELECT COUNT(*) FROM materials WHERE factory_id = \$1 AND current_stock <= min_stock AND min_stock > 0',
      parameters: [factoryId],
    );
    final lowStockCount = lowStockRes.first[0] as int;

    // Omborlar
    final warehousesRes = await db.execute(
      'SELECT COUNT(*) FROM warehouses WHERE factory_id = \$1',
      parameters: [factoryId],
    );
    final totalWarehouses = warehousesRes.first[0] as int;

    // Bu oygi ishlab chiqarish
    final monthRes = await db.execute(
      '''SELECT
          COUNT(*) as total,
          COUNT(*) FILTER (WHERE status = 'completed') as completed,
          COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress,
          COUNT(*) FILTER (WHERE status = 'planned') as planned,
          COALESCE(SUM(actual_quantity) FILTER (WHERE status = 'completed'), 0) as total_qty
        FROM production_batches
        WHERE factory_id = \$1
        AND created_at >= date_trunc('month', CURRENT_DATE)''',
      parameters: [factoryId],
    );
    final mp = monthRes.first;
    final monthly = {
      'total': mp[0] as int,
      'completed': mp[1] as int,
      'inProgress': mp[2] as int,
      'planned': mp[3] as int,
      'totalQuantity': double.parse(mp[4].toString()),
    };

    // Bugungi ishlab chiqarish
    final todayRes = await db.execute(
      '''SELECT COUNT(*), COALESCE(SUM(actual_quantity), 0)
        FROM production_batches
        WHERE factory_id = \$1
        AND DATE(created_at) = CURRENT_DATE''',
      parameters: [factoryId],
    );
    final today = {
      'batches': todayRes.first[0] as int,
      'quantity': double.parse(todayRes.first[1].toString()),
    };

    // 6 oylik trend
    final trendRes = await db.execute(
      '''SELECT
          TO_CHAR(date_trunc('month', created_at), 'Mon') as month,
          COALESCE(SUM(actual_quantity) FILTER (WHERE status = 'completed'), 0) as qty,
          COUNT(*) as batches
        FROM production_batches
        WHERE factory_id = \$1
        AND created_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '5 months'
        GROUP BY date_trunc('month', created_at), TO_CHAR(date_trunc('month', created_at), 'Mon')
        ORDER BY date_trunc('month', created_at)''',
      parameters: [factoryId],
    );
    final trend = trendRes.map((row) => {
      'month': row[0],
      'quantity': double.parse(row[1].toString()),
      'batches': row[2] as int,
    }).toList();

    // So'ngi faoliyat
    final activityRes = await db.execute(
      '''SELECT pb.id, pb.status, pb.planned_quantity, pb.actual_quantity,
               pb.unit, pb.created_at, u.username
        FROM production_batches pb
        LEFT JOIN users u ON pb.operator_id = u.id
        WHERE pb.factory_id = \$1
        ORDER BY pb.created_at DESC
        LIMIT 8''',
      parameters: [factoryId],
    );
    final activity = activityRes.map((row) => {
      'id': row[0],
      'status': row[1],
      'plannedQty': double.parse(row[2]?.toString() ?? '0'),
      'actualQty': double.parse(row[3]?.toString() ?? '0'),
      'unit': row[4],
      'createdAt': row[5]?.toString(),
      'operator': row[6],
    }).toList();

    // Kam qolgan materiallar
    final lowMaterialsRes = await db.execute(
      '''SELECT name, current_stock, min_stock, unit
        FROM materials
        WHERE factory_id = \$1 AND current_stock <= min_stock AND min_stock > 0
        ORDER BY (current_stock / NULLIF(min_stock, 0)) ASC
        LIMIT 5''',
      parameters: [factoryId],
    );
    final lowMaterials = lowMaterialsRes.map((row) => {
      'name': row[0],
      'currentStock': double.parse(row[1].toString()),
      'minStock': double.parse(row[2].toString()),
      'unit': row[3],
    }).toList();

    return Response.json(body: {
      'factory': factory,
      'overview': {
        'totalUsers': totalUsers,
        'totalMaterials': totalMaterials,
        'lowStockCount': lowStockCount,
        'totalWarehouses': totalWarehouses,
      },
      'monthly': monthly,
      'today': today,
      'trend': trend,
      'recentActivity': activity,
      'lowMaterials': lowMaterials,
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
