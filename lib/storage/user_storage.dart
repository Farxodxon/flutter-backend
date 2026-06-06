import 'package:my_server/database.dart';
import 'package:my_server/models/user.dart';

class UserStorage {
  // ========== LOGIN ==========
  static Future<User?> login(String email, String password) async {
    final db = await Database.connect();
    try {
      final result = await db.execute(
        r'SELECT id, username, email, password, COALESCE(role, $$employee$$), factory_id, created_at FROM users WHERE email = $1 AND password = $2',
        parameters: [email, password],
      );
      if (result.isEmpty) return null;
      return _rowToUser(result.first);
    } catch (e) {
      print('Login xatosi: $e');
      return null;
    }
  }

  // ========== SUPER ADMIN ==========
  static Future<User?> createSuperAdmin(String username, String email, String password) async {
    final db = await Database.connect();
    try {
      final existing = await db.execute(r"SELECT id FROM users WHERE role = 'super_admin'");
      if (existing.affectedRows > 0) return null;
      final result = await db.execute(
        r"INSERT INTO users (username, email, password, role) VALUES ($1, $2, $3, 'super_admin') RETURNING id, username, email, password, role, factory_id, created_at",
        parameters: [username, email, password],
      );
      return _rowToUser(result.first);
    } catch (e) {
      print('Super admin xatosi: $e');
      return null;
    }
  }

  // ========== CREATE USER ==========
  static Future<User?> createUser({
    required String username, required String email, required String password,
    required String role, int? factoryId, required int createdBy,
  }) async {
    final db = await Database.connect();
    try {
      final existing = await db.execute(
        r'SELECT id FROM users WHERE email = $1 OR username = $2',
        parameters: [email, username],
      );
      if (existing.affectedRows > 0) return null;
      final result = await db.execute(
        r'INSERT INTO users (username, email, password, role, factory_id) VALUES ($1, $2, $3, $4, $5) RETURNING id, username, email, password, role, factory_id, created_at',
        parameters: [username, email, password, role, factoryId],
      );
      return _rowToUser(result.first);
    } catch (e) {
      print('Create user xatosi: $e');
      return null;
    }
  }

  // ========== REGISTER ==========
  static Future<User?> register(String username, String email, String password) async {
    return createUser(username: username, email: email, password: password, role: 'employee', factoryId: null, createdBy: 0);
  }

  // ========== GET ALL ==========
  static Future<List<User>> getAll() async {
    final db = await Database.connect();
    try {
      final result = await db.execute(
        r'SELECT id, username, email, password, COALESCE(role, $$employee$$), factory_id, created_at FROM users ORDER BY id',
      );
      return result.map((row) => _rowToUser(row)).toList();
    } catch (e) {
      print('GetAll xatosi: $e');
      return [];
    }
  }

  // ========== GET BY ID ==========
  static Future<User?> getById(String id) async {
    final db = await Database.connect();
    try {
      final result = await db.execute(
        r'SELECT id, username, email, password, COALESCE(role, $$employee$$), factory_id, created_at FROM users WHERE id = $1',
        parameters: [int.tryParse(id) ?? 0],
      );
      if (result.isEmpty) return null;
      return _rowToUser(result.first);
    } catch (e) {
      print('GetById xatosi: $e');
      return null;
    }
  }

  // ========== UPDATE ==========
  static Future<User?> update(String id, {String? username, String? email}) async {
    final db = await Database.connect();
    try {
      final updates = <String>[];
      final params = <dynamic>[];
      var idx = 1;
      if (username != null) { updates.add('username = \$${idx++}'); params.add(username); }
      if (email != null) { updates.add('email = \$${idx++}'); params.add(email); }
      if (updates.isEmpty) return null;
      params.add(int.tryParse(id) ?? 0);
      final result = await db.execute(
        'UPDATE users SET ${updates.join(', ')} WHERE id = \$${idx} RETURNING id, username, email, password, COALESCE(role, \'employee\'), factory_id, created_at',
        parameters: params,
      );
      if (result.isEmpty) return null;
      return _rowToUser(result.first);
    } catch (e) {
      print('Update xatosi: $e');
      return null;
    }
  }

  // ========== DELETE ==========
  static Future<bool> delete(String id) async {
    final db = await Database.connect();
    try {
      final result = await db.execute(
        r'DELETE FROM users WHERE id = $1 AND role != $$super_admin$$',
        parameters: [int.tryParse(id) ?? 0],
      );
      return result.affectedRows > 0;
    } catch (e) {
      print('Delete xatosi: $e');
      return false;
    }
  }

  static User _rowToUser(dynamic row) {
    return User(
      id: row[0].toString(),
      username: row[1] as String,
      email: row[2] as String,
      password: row[3] as String,
      role: row[4] as String? ?? 'employee',
      factoryId: row[5]?.toString(),
      createdAt: row[6] as DateTime,
    );
  }
}
