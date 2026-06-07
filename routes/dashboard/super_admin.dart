import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/database.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  // Faqat super_admin
  final payload = context.read<Map<String, dynamic>>();
  final role = payload['role'] as String? ?? '';
  if (role != 'super_admin') {
    return Response.json(statusCode: 403, body: {'error': 'Faqat super_admin uchun'});
  }

  final db = await Database.connect();

  try {
    // Zavodlar soni
    final factoriesRes = await db.execute('SELECT COUNT(*) FROM factories');
    final totalFactories = factoriesRes.first[0] as int;

    // Foydalanuvchilar soni (rol bo'yicha)
    final usersRes = await db.execute('''
      SELECT role, COUNT(*) as cnt FROM users GROUP BY role
    ''');
    final usersByRole = <String, int>{};
    for (final row in usersRes) {
      usersByRole[row[0] as String] = row[1] as int;
    }
    final totalUsers = usersByRole.values.fold(0, (a, b) => a + b);

    // Materiallar
    final materialsRes = await db.execute('SELECT COUNT(*) FROM materials');
    final totalMaterials = materialsRes.first[0] as int;

    final lowStockRes = await db.execute(
      'SELECT COUNT(*) FROM materials WHERE current_stock <= min_stock AND min_stock > 0',
    );
    final lowStockCount = lowStockRes.first[0] as int;

    // Ishlab chiqarish — bu oy
    final monthProdRes = await db.execute('''
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'completed') as completed,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress,
        COUNT(*) FILTER (WHERE status = 'planned') as planned,
        COALESCE(SUM(actual_quantity) FILTER (WHERE status = 'completed'), 0) as total_qty
      FROM production_batches 
      WHERE created_at >= date_trunc('month', CURRENT_DATE)
    ''');
    final mp = monthProdRes.first;
    final monthlyBatches = {
      'total': mp[0] as int,
      'completed': mp[1] as int,
      'inProgress': mp[2] as int,
      'planned': mp[3] as int,
      'totalQuantity': double.parse(mp[4].toString()),
    };

    // So'ngi 6 oy ishlab chiqarish trend
    final trendRes = await db.execute('''
      SELECT 
        TO_CHAR(date_trunc('month', created_at), 'Mon') as month,
        COALESCE(SUM(actual_quantity) FILTER (WHERE status = 'completed'), 0) as qty,
        COUNT(*) as batches
      FROM production_batches
      WHERE created_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '5 months'
      GROUP BY date_trunc('month', created_at), TO_CHAR(date_trunc('month', created_at), 'Mon')
      ORDER BY date_trunc('month', created_at)
    ''');
    final trend = trendRes.map((row) => {
      'month': row[0],
      'quantity': double.parse(row[1].toString()),
      'batches': row[2] as int,
    }).toList();

    // Omborlar
    final warehousesRes = await db.execute('SELECT COUNT(*) FROM warehouses');
    final totalWarehouses = warehousesRes.first[0] as int;

    // Zavodlar ro'yxati
    final factoriesListRes = await db.execute('''
      SELECT f.id, f.name, 
        COUNT(DISTINCT u.id) as user_count,
        COUNT(DISTINCT m.id) as material_count
      FROM factories f
      LEFT JOIN users u ON u.factory_id = f.id
      LEFT JOIN materials m ON m.factory_id = f.id
      GROUP BY f.id, f.name
      ORDER BY f.id
    ''');
    final factories = factoriesListRes.map((row) => {
      'id': row[0],
      'name': row[1],
      'userCount': row[2] as int,
      'materialCount': row[3] as int,
    }).toList();

    // So'ngi faoliyat
    final activityRes = await db.execute('''
      SELECT pb.id, pb.status, pb.planned_quantity, pb.unit,
             pb.created_at, u.username, f.name as factory_name
      FROM production_batches pb
      LEFT JOIN users u ON pb.operator_id = u.id
      LEFT JOIN factories f ON pb.factory_id = f.id
      ORDER BY pb.created_at DESC
      LIMIT 8
    ''');
    final recentActivity = activityRes.map((row) => {
      'id': row[0],
      'status': row[1],
      'quantity': double.parse(row[2]?.toString() ?? '0'),
      'unit': row[3],
      'createdAt': row[4]?.toString(),
      'operator': row[5],
      'factory': row[6],
    }).toList();

    return Response.json(body: {
      'overview': {
        'totalFactories': totalFactories,
        'totalUsers': totalUsers,
        'totalMaterials': totalMaterials,
        'lowStockCount': lowStockCount,
        'totalWarehouses': totalWarehouses,
        'usersByRole': usersByRole,
      },
      'monthlyBatches': monthlyBatches,
      'trend': trend,
      'factories': factories,
      'recentActivity': recentActivity,
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Xatolik: $e'});
  }
}
