import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/auth/jwt_service.dart';

Handler middleware(Handler handler) {
  return (context) async {
    // CORS uchun OPTIONS so'rovlar
    if (context.request.method == HttpMethod.options) {
      return Response(
        statusCode: 200,
        headers: _corsHeaders(),
      );
    }

    // Ochiq endpoint'lar (auth kerak emas)
    final path = context.request.uri.path;
    final openPaths = ['/login', '/setup'];
    
    if (openPaths.contains(path)) {
      final response = await handler(context);
      return _addCors(response);
    }

    // Token tekshirish
    final authHeader = context.request.headers['Authorization'] ?? 
                       context.request.headers['authorization'];
    final user = JwtService.getUserFromToken(authHeader);

    if (user == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'Avtorizatsiya talab qilinadi. Iltimos, qayta kiring.'},
        headers: _corsHeaders(),
      );
    }

    // User ma'lumotini request context'ga qo'shish
    final updatedContext = context.provide<Map<String, dynamic>>(() => user);
    final response = await handler(updatedContext);
    return _addCors(response);
  };
}

Map<String, String> _corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

Response _addCors(Response response) {
  return response.copyWith(headers: {
    ...response.headers,
    ..._corsHeaders(),
  });
}
