// Stub bindings for non-web platforms; does nothing.
class ActivityTrackerPlatformBindings {
  static void installGlobalWebListeners({void Function()? onUserActivity, void Function()? onVisibilityGained}) {}
  static void removeGlobalWebListeners() {}
}
