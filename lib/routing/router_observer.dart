import 'package:flutter/material.dart';
import 'package:hands_app/core/logging/logger.dart';

// Observer for GoRouter navigation events
class GoRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    logger.d('[ROUTER_OBSERVER] didPush: ${route.settings.name} from ${previousRoute?.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    logger.d('[ROUTER_OBSERVER] didPop: ${route.settings.name} to ${previousRoute?.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    logger.d('[ROUTER_OBSERVER] didReplace: ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    logger.d('[ROUTER_OBSERVER] didRemove: ${route.settings.name} from ${previousRoute?.settings.name}');
  }
}
