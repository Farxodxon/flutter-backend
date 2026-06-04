import '../models/user.dart';

class UserStorage {
  static final List<User> _users = [];
  static int _nextId = 1;

  // Ro'yxatdan o'tish
  static User? register(String username, String email, String password) {
    // Email bandligini tekshirish
    if (_users.any((u) => u.email == email)) {
      return null; // Email allaqachon band
    }

    // Username bandligini tekshirish
    if (_users.any((u) => u.username == username)) {
      return null; // Username allaqachon band
    }

    final user = User(
      id: _nextId.toString(),
      username: username,
      email: email,
      password: password,
      createdAt: DateTime.now(),
    );

    _users.add(user);
    _nextId++;
    return user;
  }

  // Login
  static User? login(String email, String password) {
    try {
      return _users.firstWhere(
        (u) => u.email == email && u.password == password,
      );
    } catch (e) {
      return null;
    }
  }

  // Barcha foydalanuvchilarni olish
  static List<User> getAll() {
    return List.from(_users);
  }

  // ID bo'yicha foydalanuvchini topish
  static User? getById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (e) {
      return null;
    }
  }

  // Foydalanuvchini o'chirish
  static bool delete(String id) {
    final user = getById(id);
    if (user != null) {
      _users.remove(user);
      return true;
    }
    return false;
  }

  // Foydalanuvchini yangilash
  static User? update(String id, {String? username, String? email}) {
    final user = getById(id);
    if (user != null) {
      final updatedUser = User(
        id: user.id,
        username: username ?? user.username,
        email: email ?? user.email,
        password: user.password,
        createdAt: user.createdAt,
      );
      final index = _users.indexOf(user);
      _users[index] = updatedUser;
      return updatedUser;
    }
    return null;
  }
}
