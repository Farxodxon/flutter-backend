import 'package:dart_frog/dart_frog.dart';
import 'package:my_server/storage/user_storage.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final userId = int.tryParse(id);
  if (userId == null) {
    return Response.json(statusCode: 400, body: {"error": "Notogri ID"});
  }

  final payload = context.read<Map<String, dynamic>>();
  final callerRole = payload["role"] as String? ?? "employee";
  final callerId = payload["user_id"] as int?;

  if (callerRole == "employee" && callerId != userId) {
    return Response.json(statusCode: 403, body: {"error": "Ruxsat yoq"});
  }

  switch (context.request.method) {
    case HttpMethod.get:
      final user = await UserStorage.getById(userId);
      if (user == null) {
        return Response.json(statusCode: 404, body: {"error": "Topilmadi"});
      }
      return Response.json(body: {"user": user.toJson()});

    case HttpMethod.put:
      try {
        final body = await context.request.json() as Map<String, dynamic>;
        final user = await UserStorage.update(
          userId,
          username: body["username"] as String?,
          email: body["email"] as String?,
          password: body["password"] as String?,
          role: callerRole == "super_admin" ? body["role"] as String? : null,
          factoryId: callerRole == "super_admin" ? body["factory_id"] as int? : null,
        );
        if (user == null) {
          return Response.json(statusCode: 404, body: {"error": "Topilmadi"});
        }
        return Response.json(body: {"message": "Yangilandi", "user": user.toJson()});
      } catch (e) {
        return Response.json(statusCode: 400, body: {"error": "$e"});
      }

    case HttpMethod.delete:
      if (callerRole != "super_admin") {
        return Response.json(statusCode: 403, body: {"error": "Faqat super_admin"});
      }
      final user = await UserStorage.update(userId, isActive: false);
      if (user == null) {
        return Response.json(statusCode: 404, body: {"error": "Topilmadi"});
      }
      return Response.json(body: {"message": "Ochirildi"});

    default:
      return Response.json(statusCode: 405, body: {"error": "Method not allowed"});
  }
}
