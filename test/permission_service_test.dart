import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/services/app_permission_service.dart';

void main() {
  group('AppPermissionService', () {
    late AppPermissionService service;

    setUp(() {
      service = AppPermissionService();
    });

    group('Permission Names and Rationales', () {
      test('should provide user-friendly permission names', () {
        expect(service.getPermissionName(AppPermission.photos), equals('Photo Library'));
        expect(service.getPermissionName(AppPermission.calendar), equals('Calendar'));
        expect(service.getPermissionName(AppPermission.notifications), equals('Notifications'));
      });

      test('should provide meaningful rationales', () {
        final photoRationale = service.getPermissionRationale(AppPermission.photos);
        expect(photoRationale, contains('document'));
        expect(photoRationale, contains('tasks'));

        final calendarRationale = service.getPermissionRationale(AppPermission.calendar);
        expect(calendarRationale, contains('schedule'));
        expect(calendarRationale, contains('calendar'));

        final notificationRationale = service.getPermissionRationale(AppPermission.notifications);
        expect(notificationRationale, contains('Notifications'));
        expect(notificationRationale, contains('schedule'));
      });
    });

    group('Service Instance', () {
      test('should return same instance (singleton)', () {
        final service1 = AppPermissionService();
        final service2 = AppPermissionService();
        expect(identical(service1, service2), isTrue);
      });
    });

    group('Permission Rationale Content', () {
      test('photo permission rationale should mention task documentation', () {
        final rationale = service.getPermissionRationale(AppPermission.photos);
        expect(rationale, contains('Photos'));
        expect(rationale, contains('document'));
        expect(rationale, contains('proof'));
      });

      test('calendar permission rationale should mention schedule sync', () {
        final rationale = service.getPermissionRationale(AppPermission.calendar);
        expect(rationale, contains('Calendar'));
        expect(rationale, contains('sync'));
        expect(rationale, contains('schedule'));
      });

      test('notification permission rationale should mention updates', () {
        final rationale = service.getPermissionRationale(AppPermission.notifications);
        expect(rationale, contains('Notifications'));
        expect(rationale, contains('schedule'));
        expect(rationale, contains('announcements'));
      });
    });
  });

  group('AppPermission enum', () {
    test('should contain all required permissions', () {
      const permissions = AppPermission.values;
      expect(permissions, contains(AppPermission.photos));
      expect(permissions, contains(AppPermission.calendar));
      expect(permissions, contains(AppPermission.notifications));
      expect(permissions.length, equals(3));
    });
  });
}
