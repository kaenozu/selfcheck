import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/recognition_failure_policy.dart';

void main() {
  group('RecognitionFailurePolicy', () {
    test('notifies only after consecutive frame failures', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isTrue);
      expect(policy.recordFailure(), isFalse);
      expect(policy.consecutiveFailures, 4);
    });

    test('a successful frame resets the failure streak', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(), isFalse);
      policy.recordSuccess();

      expect(policy.consecutiveFailures, 0);
      expect(policy.recordFailure(), isFalse);
    });

    test('fatal failures notify immediately', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(fatal: true), isTrue);
      expect(policy.consecutiveFailures, 1);
    });
  });
}
