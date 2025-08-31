import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(ref);
});
