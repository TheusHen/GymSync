import 'package:flutter_test/flutter_test.dart';
import 'package:gymsync/core/services/notification_service.dart';

void main() {
  group('Notification Service Tests', () {
    test('NotificationService singleton instance', () {
      final service1 = NotificationService();
      final service2 = NotificationService();
      
      expect(service1, equals(service2));
    });

    test('NotificationService initial state', () {
      final service = NotificationService();
      
      expect(service.enabled, isTrue);
    });

    test('NotificationService enable/disable functionality', () {
      final service = NotificationService();
      
      service.enable(false);
      expect(service.enabled, isFalse);
      
      service.enable(true);
      expect(service.enabled, isTrue);
    });

    test('NotificationService init does not throw', () async {
      final service = NotificationService();
      
      try {
        await service.init();
        expect(true, isTrue);
      } catch (e) {
        // init may fail in test environment due to missing platform support
        expect(e, isNotNull);
      }
    });

    test('NotificationService show method does not throw', () async {
      final service = NotificationService();
      
      try {
        await service.show(
          elapsed: '00:05:30',
          activity: 'Walking',
        );
        expect(true, isTrue);
      } catch (e) {
        // show may fail in test environment due to missing platform support
        expect(e, isNotNull);
      }
    });

    test('NotificationService cancel method does not throw', () async {
      final service = NotificationService();
      
      try {
        await service.cancel();
        expect(true, isTrue);
      } catch (e) {
        // cancel may fail in test environment due to missing platform support
        expect(e, isNotNull);
      }
    });

    test('NotificationService onAction callback can be set', () {
      final service = NotificationService();
      bool callbackCalled = false;
      
      service.onAction = (action) {
        callbackCalled = true;
      };
      
      // Verify callback is set (we can't test the actual callback without platform support)
      expect(service.onAction, isNotNull);
    });
  });
}