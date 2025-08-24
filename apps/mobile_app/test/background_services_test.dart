import 'package:flutter_test/flutter_test.dart';
import 'package:gymsync/core/services/background_location_service.dart';
import 'package:gymsync/core/services/foreground_workout_service.dart';

void main() {
  group('Background Services Tests', () {
    test('BackgroundLocationService singleton instance', () {
      final service1 = BackgroundLocationService();
      final service2 = BackgroundLocationService();
      
      expect(service1, equals(service2));
    });

    test('ForegroundWorkoutService singleton instance', () {
      final service1 = ForegroundWorkoutService();
      final service2 = ForegroundWorkoutService();
      
      expect(service1, equals(service2));
    });

    test('ForegroundWorkoutService initial state', () {
      final service = ForegroundWorkoutService();
      
      expect(service.isRunning, isFalse);
    });
  });
}