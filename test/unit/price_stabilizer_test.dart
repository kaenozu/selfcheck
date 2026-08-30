import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_stabilizer.dart';

void main() {
  group('PriceStabilizer', () {
    late PriceStabilizer stabilizer;

    setUp(() {
      stabilizer = PriceStabilizer();
    });

    test('returns false with fewer than 3 readings', () {
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 100,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['100'],
          ),
        ),
        false,
      );
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 100,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['100'],
          ),
        ),
        false,
      );
    });

    test('returns true when 3 consecutive same prices', () {
      for (var i = 0; i < 3; i++) {
        final result = stabilizer.submit(
          const PriceCandidate(
            priceYen: 100,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['100'],
          ),
        );
        if (i < 2) {
          expect(result, false);
        } else {
          expect(result, true);
        }
      }
    });

    test('returns false when prices differ', () {
      stabilizer.submit(
        const PriceCandidate(
          priceYen: 100,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['100'],
        ),
      );
      stabilizer.submit(
        const PriceCandidate(
          priceYen: 100,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['100'],
        ),
      );
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 101,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['101'],
          ),
        ),
        false,
      );
    });

    test('reset clears history', () {
      stabilizer.submit(
        const PriceCandidate(
          priceYen: 100,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['100'],
        ),
      );
      stabilizer.reset();
      expect(stabilizer.currentPrice, null);
    });

    test('currentPrice returns latest price', () {
      stabilizer.submit(
        const PriceCandidate(
          priceYen: 100,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['100'],
        ),
      );
      expect(stabilizer.currentPrice, 100);
    });

    test('confidence returns latest confidence', () {
      stabilizer.submit(
        const PriceCandidate(
          priceYen: 100,
          confidence: 0.85,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['100'],
        ),
      );
      expect(stabilizer.confidence, 0.85);
    });
  });
}
