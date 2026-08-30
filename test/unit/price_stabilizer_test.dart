import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_stabilizer.dart';

const _region = Rect(left: 0, top: 0, right: 100, bottom: 50);

PriceCandidate candidate(int price, {double confidence = 0.9}) {
  return PriceCandidate(
    priceYen: price,
    confidence: confidence,
    region: _region,
    rawTexts: ['$price'],
  );
}

void main() {
  group('PriceStabilizer', () {
    late PriceStabilizer stabilizer;

    setUp(() {
      stabilizer = PriceStabilizer();
    });

    test('does not expose stablePrice with fewer than 3 readings', () {
      expect(stabilizer.submit(candidate(100)), isFalse);
      expect(stabilizer.currentPrice, 100);
      expect(stabilizer.stablePrice, isNull);

      expect(stabilizer.submit(candidate(100)), isFalse);
      expect(stabilizer.stablePrice, isNull);
    });

    test('exposes stablePrice after 3 consecutive identical readings', () {
      expect(stabilizer.submit(candidate(100)), isFalse);
      expect(stabilizer.submit(candidate(100)), isFalse);
      expect(
        stabilizer.submit(candidate(100, confidence: 0.87)),
        isTrue,
      );

      expect(stabilizer.stablePrice, 100);
      expect(stabilizer.stableConfidence, 0.87);
    });

    test('clears stablePrice when the latest window is no longer stable', () {
      for (var i = 0; i < 3; i++) {
        stabilizer.submit(candidate(100));
      }
      expect(stabilizer.stablePrice, 100);

      expect(stabilizer.submit(candidate(101)), isFalse);
      expect(stabilizer.currentPrice, 101);
      expect(stabilizer.stablePrice, isNull);
      expect(stabilizer.stableConfidence, 0.0);
    });

    test('returns false when prices differ', () {
      stabilizer.submit(candidate(100));
      stabilizer.submit(candidate(100));
      expect(stabilizer.submit(candidate(101)), isFalse);
      expect(stabilizer.stablePrice, isNull);
    });

    test('reset clears latest and stable state', () {
      for (var i = 0; i < 3; i++) {
        stabilizer.submit(candidate(100));
      }
      expect(stabilizer.stablePrice, 100);

      stabilizer.reset();

      expect(stabilizer.currentPrice, isNull);
      expect(stabilizer.confidence, 0.0);
      expect(stabilizer.stablePrice, isNull);
      expect(stabilizer.stableConfidence, 0.0);
    });

    test('currentPrice and confidence still reflect latest OCR candidate', () {
      stabilizer.submit(candidate(100, confidence: 0.85));

      expect(stabilizer.currentPrice, 100);
      expect(stabilizer.confidence, 0.85);
      expect(stabilizer.stablePrice, isNull);
    });
  });
}
