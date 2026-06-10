import 'package:bcrypt/bcrypt.dart';
import 'package:my_server/database.dart';
import 'package:my_server/models/user.dart';

class UserStorage {
  static const String _select =
      'SELECT id, username, email, COALESCE(role, \'employee\'), factory_id, COALESCE(is_active, true), created_at FROM users';

  // ========== LOGIN ==========
  static Future<User?> login(String email, String password) async {
    final db = await Database.connect();
    try {
      final result = await db.execute(
        'SELECT id, username, email, COALESCE(role, \'employee\'), factory_id, COALESCE(is_active, true), created_at, password FROM users WHERE email = \$1',
        parameters: [email],
      );
      if (result.isEmpty) return null;

      final storedPassword = result.first[7] as String;
      bool passwordMatch = false;
      if (storedPassword.startsWith('\$2')) {
        passwordMatch = BCrypt.checkpw(password, storedPassword);
      } else {
        passwordMatch = storedPassword == password;
        if (passwordMatch) {
          final hashed = BCrypt.hashpw(password, BCrypt.gensalt());
          await db.execute(
            'UPDATE users SET password = \$1 WHERE email = \$2',
            parameters: [hashed, email],
          );
        }
      }

      if (!passwordMatch) return null;
      return _rowToUser(result.first);
    } catch (e) {
      print('Login xatosi: $e');
      return null;
    }
  }

  // ========== SUPER ADMIN ==========
  static Future<User?> createSuperAdmin(
      String username, String email, String password) async {
    final db = await Database.connect();
    try {
      final existing =
          await db.execute('SELECT id FROM users WHERE role = \'super_admin\'');
      if (existing.isNotEmpty) return null;

      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
      final result = await db.execute(
        'INSERT INTO users (username, email, password, role) VALUES (\$1, \$2, \$3, \'super_admin\') RETURNING id, username, email, role, factory_id, COALESCE(is_active, true), created_at',
        parameters: [username, email, hashedPassword],
      );
      return _rowToUser(result.first);
    } catch (e) {
      print('Super admin xatosi: $e');
      return null;
    }
  }

  // ========== CREATE USER ==========
  static Future<User?> createUser({
    required String username,
    required String email,
    required String password,
    required String role,
    int? factoryId,
  }) async {
    final db = await Database.connect();
    try {
      final existing = await db.execute(
        'SELECT id FROM users WHERE email = \$1',
        parameters: [email],
      );
      if (existing.isNotEmpty) return null;

      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
      final result = await db.execute(
        'INSERT INTO users (username, email, password, role, factory_id) VALUES (\$1, \$2, \$3, \$4, \$5) RETURNING id, username, email, role, factory_id, COALESCE(is_active, true), created_at',
        parameters: [username, email, hashedPassword, role, factoryId],
      );
      return _rowToUser(result.first);
    } catch (e) {
      print('createUser xatosi: $e');
      return null;
    }
  }

  // ========== GET ALL ==========
  static Future<List<User>> getAll({String? role, int? factoryId}) async {
    final db = await Database.connect();
    try {
      String query = '$_select WHERE 1=1';
      final params = <dynamic>[];
      var idx = 1;

      if (role != null) {
        query += ' AND role = \$$idx';
        params.add(role);
        idx++;
      }
      if (factoryId != null) {
        query += ' AND factory_id = \$$idx';
        params.add(factoryId);
        idx++;
      }
      query += ' ORDER BY id';

      final result = params.isEmpty
          ? await db.execute(query)
          : await db.execute(query, parameters: params);

      return result.map(_rowToUser).toList();
    } catch (e) {
      print('getAll xatosi: $e');
      return [];
    }
  }

  // ========== GET BY ID ==========
  static Future<User?> getById(int id) async {
    final db = await Database.connect();
    try {
      final result = await db.execute(
        '$_select WHERE id = \$1',
        parameters: [id],
      );
      if (result.isEmpty) return null;
      return _rowToUser(result.first);
    } catch (e) {
      return null;
    }
  }

  // ========== UPDATE ==========
  static Future<User?> update(
    int id, {
    String? username,
    String? email,
    String? password,
    String? role,
    int? factoryId,
    bool? isActive,
  }) async {
    final db = await Database.connect();
    try {
      final setParts = <String>[];
      final params = <dynamic>[];
      var idx = 1;

      if (username != null) {
        setParts.add('username = \$$idx');
        params.add(username);
        idx++;
      }
      if (email != null) {
        setParts.add('email = \$$idx');
        params.add(email);
        idx++;
      }
      if (password != null) {
        final hashed = BCrypt.hashpw(password, BCrypt.gensalt());
        setParts.add('password = \$$idx');
        params.add(hashed);
        idx++;
      }
      if (role != null) {
        setParts.add('role = \$$idx');
        params.add(role);
        idx++;
      }
      if (factoryId != null) {
        setParts.add('factory_id = \$$idx');
        params.add(factoryId);
        idx++;
      }
      if (isActive != null) {
        setParts.add('is_active = \$$idx');
        params.add(isActive);
        idx++;
      }

      if (setParts.isEmpty) return null;
      params.add(id);

      final result = await db.execute(
        'UPDATE users SET ${setParts.join(', ')} WHERE id = \$$idx RETURNING id, username, email, COALESCE(role, \'employee\'), factory_id, COALESCE(is_active, true), created_at',
        parameters: params,
      );

      if (result.isEmpty) return null;
      return _rowToUser(result.first);
    } catch (e) {
      return null;
    }
  }

  // ========== HELPER ==========
  static User _rowToUser(dynamic row) {
    return User(
      id: int.parse(row[0].toString()),
      username: row[1] as String,
      email: row[2] as String,
      role: row[3] as String,
      factoryId: row[4] != null ? int.parse(row[4].toString()) : null,
      isActive: row[5] as bool? ?? true,
      createdAt: row[6] as DateTime,
    );
  }
}
