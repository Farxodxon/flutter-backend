import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: {
      'message': 'Salom, Flutter!',
      'time': DateTime.now().toIso8601String(),
    },
  );
}