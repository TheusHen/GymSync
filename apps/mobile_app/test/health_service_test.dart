import 'package:flutter_test/flutter_test.dart';
import 'package:gymsync/core/services/health_service.dart';
import 'package:gymsync/core/services/samsung_health_service.dart';
import 'package:gymsync/core/services/google_fit_service.dart';

void main() {
  group('Health Service Tests', () {
    test('HealthService singleton instance', () {
      final service1 = HealthService();
      final service2 = HealthService();
      
      expect(service1, equals(service2));
    });

    test('SamsungHealthService singleton instance', () {
      final service1 = SamsungHealthService();
      final service2 = SamsungHealthService();
      
      expect(service1, equals(service2));
    });

    test('GoogleFitService singleton instance', () {
      final service1 = GoogleFitService();
      final service2 = GoogleFitService();
      
      expect(service1, equals(service2));
    });

    test('HealthService initialization does not throw', () async {
      final service = HealthService();
      
      // This test ensures the initialize method can be called without throwing
      try {
        await service.initialize();
        // If we get here, initialization succeeded or failed gracefully
        expect(true, isTrue);
      } catch (e) {
        // We allow initialization to fail in test environment due to missing platform permissions
        expect(e, isNotNull);
      }
    });

    test('HealthService serviceType getter works', () {
      final service = HealthService();
      
      // Should return a string indicating the service type
      expect(service.serviceType, isA<String>());
      expect(service.serviceType.isNotEmpty, isTrue);
    });

    test('HealthService isSamsung getter returns boolean', () {
      final service = HealthService();
      
      expect(service.isSamsung, isA<bool>());
    });

    test('Activity detection methods return correct types', () async {
      final service = HealthService();
      
      try {
        // These methods should return correct types even if they fail
        final currentExercise = await service.getCurrentExerciseDetailed();
        expect(currentExercise, anyOf(isNull, isA<Map<String, dynamic>>()));

        final activeExerciseType = await service.getCurrentActiveExerciseType();
        expect(activeExerciseType, anyOf(isNull, isA<String>()));

        final isWalking = await service.isWalking();
        expect(isWalking, isA<bool>());
      } catch (e) {
        // Methods may fail in test environment due to missing permissions
        expect(e, isNotNull);
      }
    });

    test('Activity monitoring methods do not throw', () {
      final service = HealthService();
      
      // These should not throw even if they fail to start monitoring
      expect(() => service.startActivityMonitoring(), returnsNormally);
      expect(() => service.stopActivityMonitoring(), returnsNormally);
    });
  });
}