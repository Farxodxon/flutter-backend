import 'dart:io';
import 'package:postgres/postgres.dart';

class Database {
  static Connection? _connection;

  static Future<Connection> connect() async {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }

    final databaseUrl = Platform.environment['DATABASE_URL'];
    
    if (databaseUrl == null || databaseUrl.isEmpty) {
      throw Exception('DATABASE_URL environment variable is not set');
    }

    final uri = Uri.parse(databaseUrl);
    
    // Neon default port 5432
    final port = uri.port != 0 ? uri.port : 5432;
    
    final endpoint = Endpoint(
      host: uri.host,
      port: port,
      database: uri.pathSegments.first,
      username: uri.userInfo.split(':').first,
      password: uri.userInfo.split(':').last,
      isUnixSocket: false,
    );

    _connection = await Connection.open(endpoint);

    if (!_connection!.isOpen) {
      throw Exception('PostgreSQLga ulanish muvaffaqiyatsiz');
    }
    
    print('✅ PostgreSQLga ulandi');
    return _connection!;
  }

  static Future<void> close() async {
    if (_connection != null && _connection!.isOpen) {
      await _connection!.close();
      print('🔌 PostgreSQL yopildi');
    }
  }
}
