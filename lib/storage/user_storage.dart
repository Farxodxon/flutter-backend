import '../database.dart';
import '../models/user.dart';

class UserStorage {
  // Ro'yxatdan o'tish
  static Future<User?> register(String username, String email, String password) async {
    final db = await Database.connect();

    try {
      // Email bandligini tekshirish
      final existing = await db.execute(
        r'SELECT id FROM users WHERE email = $1 OR username = $2',
        parameters: [email, username],
      );

      if (existing.affectedRows > 0) {
        return null;
      }

      // Yangi foydalanuvchi qo'shish
      final result = await db.execute(
        r'''INSERT INTO users (username, email, password) 
           VALUES ($1, $2, $3) 
           RETURNING id, username, email, password, created_at''',
        parameters: [username, email, password],
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return User(
        id: row[0].toString(),
        username: row[1] as String,
        email: row[2] as String,
        password: row[3] as String,
        createdAt: row[4] as DateTime,
      );
    } catch (e) {
      print('❌ Register xatolik: $e');
      return null;
    }
  }

  // Login
  static Future<User?> login(String email, String password) async {
    final db = await Database.connect();

    try {
      final result = await db.execute(
        r'SELECT id, username, email, password, created_at FROM users WHERE email = $1 AND password = $2',
        parameters: [email, password],
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return User(
        id: row[0].toString(),
        username: row[1] as String,
        email: row[2] as String,
        password: row[3] as String,
        createdAt: row[4] as DateTime,
      );
    } catch (e) {
      print('❌ Login xatolik: $e');
      return null;
    }
  }

  // Barcha foydalanuvchilar
  static Future<List<User>> getAll() async {
    final db = await Database.connect();

    try {
      final result = await db.execute(
        r'SELECT id, username, email, password, created_at FROM users ORDER BY id',
      );

      return result.map((row) => User(
        id: row[0].toString(),
        username: row[1] as String,
        email: row[2] as String,
        password: row[3] as String,
        createdAt: row[4] as DateTime,
      )).toList();
    } catch (e) {
      print('❌ GetAll xatolik: $e');
      return [];
    }
  }

  // ID bo'yicha
  static Future<User?> getById(String id) async {
    final db = await Database.connect();

    try {
      final result = await db.execute(
        r'SELECT id, username, email, password, created_at FROM users WHERE id = $1',
        parameters: [int.tryParse(id) ?? 0],
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return User(
        id: row[0].toString(),
        username: row[1] as String,
        email: row[2] as String,
        password: row[3] as String,
        createdAt: row[4] as DateTime,
      );
    } catch (e) {
      print('❌ GetById xatolik: $e');
      return null;
    }
  }

  // O'chirish
  static Future<bool> delete(String id) async {
    final db = await Database.connect();

    try {
      final result = await db.execute(
        r'DELETE FROM users WHERE id = $1',
        parameters: [int.tryParse(id) ?? 0],
      );
      return result.affectedRows > 0;
    } catch (e) {
      print('❌ Delete xatolik: $e');
      return false;
    }
  }

  // Yangilash
  static Future<User?> update(String id, {String? username, String? email}) async {
    final db = await Database.connect();

    try {
      final params = <dynamic>[];
      final setParts = <String>[];
      var paramCount = 1;

      if (username != null) {
        setParts.add('username = \$${paramCount++}');
        params.add(username);
      }
      if (email != null) {
        setParts.add('email = \$${paramCount++}');
        params.add(email);
      }

      if (setParts.isEmpty) return null;

      params.add(int.tryParse(id) ?? 0);
      final whereParam = paramCount;

      final result = await db.execute(
        'UPDATE users SET ${setParts.join(', ')} WHERE id = \$$whereParam RETURNING id, username, email, password, created_at',
        parameters: params,
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return User(
        id: row[0].toString(),
        username: row[1] as String,
        email: row[2] as String,
        password: row[3] as String,
        createdAt: row[4] as DateTime,
      );
    } catch (e) {
      print('❌ Update xatolik: $e');
      return null;
    }
  }
}
