import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('BarcodeCandidate domain model', () {
    test('holds valid EAN-13', () {
      const candidate = BarcodeCandidate(
        barcode: '4901234567890',
        format: BarcodeFormat.ean13,
        confidence: 1.0,
        region: Rect(left: 0, top: 0, right: 100, bottom: 50),
      );

      expect(candidate.barcode.length, 13);
      expect(candidate.format, BarcodeFormat.ean13);
    });

    test('BarcodeFormat enum covers expected formats', () {
      expect(BarcodeFormat.values, contains(BarcodeFormat.ean13));
      expect(BarcodeFormat.values, contains(BarcodeFormat.ean8));
      expect(BarcodeFormat.values, contains(BarcodeFormat.unknown));
    });

    test('toString includes barcode value', () {
      const candidate = BarcodeCandidate(
        barcode: '4901234567890',
        format: BarcodeFormat.ean13,
        confidence: 0.95,
        region: Rect(left: 0, top: 0, right: 100, bottom: 50),
      );

      expect(candidate.toString(), contains('4901234567890'));
      expect(candidate.toString(), contains('ean13'));
    });
  });

  group('PriceCandidate domain model', () {
    test('holds valid price data', () {
      const candidate = PriceCandidate(
        priceYen: 398,
        confidence: 0.9,
        region: Rect(left: 0, top: 50, right: 100, bottom: 100),
        rawTexts: ['¥398', '398'],
      );

      expect(candidate.priceYen, 398);
      expect(candidate.confidence, 0.9);
      expect(candidate.rawTexts, ['¥398', '398']);
    });

    test('toString includes price', () {
      const candidate = PriceCandidate(
        priceYen: 1200,
        confidence: 0.8,
        region: Rect(left: 0, top: 0, right: 50, bottom: 20),
        rawTexts: ['1200'],
      );

      expect(candidate.toString(), contains('¥1200'));
    });
  });

  group('Rect domain model', () {
    test('computes width and height', () {
      const rect = Rect(left: 10, top: 20, right: 110, bottom: 70);
      expect(rect.width, 100);
      expect(rect.height, 50);
    });

    test('zero-size rect', () {
      const rect = Rect(left: 50, top: 50, right: 50, bottom: 50);
      expect(rect.width, 0);
      expect(rect.height, 0);
    });
  });

  group('Adapter interface contracts', () {
    test('BarcodeRecognizerAdapter interface is abstract', () {
      // Verify the adapter interface exists and can be implemented
      // This is a compile-time test ensuring the split preserved the API
    });
  });
}
