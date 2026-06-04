import 'package:dart_frog/dart_frog.dart';
import '../lib/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context) async {
  print('📥 Register so\'rovi keldi');
  
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Faqat POST so\'rov ruxsat etilgan'},
    );
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    print('📦 Body: $body');
    
    final username = body['username'] as String?;
    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (username == null || email == null || password == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'username, email va password majburiy'},
      );
    }

    final user = await UserStorage.register(username, email, password);

    if (user == null) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'Bu email yoki username allaqachon band'},
      );
    }

    return Response.json(
      statusCode: 201,
      body: {
        'message': 'Ro\'yxatdan o\'tish muvaffaqiyatli',
        'user': user.toJson(),
      },
    );
  } catch (e, stackTrace) {
    print('❌ Xatolik: $e');
    print('📍 Stack trace: $stackTrace');
    return Response.json(
      statusCode: 400,
      body: {'error': 'Noto\'g\'ri JSON format: $e'},
    );
  }
}
