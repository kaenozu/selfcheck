import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_text_parser.dart';

void main() {
  const region = Rect(left: 1, top: 2, right: 3, bottom: 4);

  test('prefers currency-marked price over bare numbers', () {
    final result = parsePriceText([
      (text: '在庫 12', region: region),
      (text: '税込 ￥1,980円', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 1980);
    expect(result.confidence, 0.90);
  });

  test('accepts a plausible bare price', () {
    final result = parsePriceText([(text: '398', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
    expect(result.confidence, 0.70);
  });

  test('does not reinterpret JAN/EAN-length text as a price', () {
    final result = parsePriceText([
      (text: '4901234567894', region: region),
    ]);

    expect(result, isNull);
  });

  test('rejects zero and values above 99,999 yen', () {
    expect(parsePriceText([(text: '￥0円', region: region)]), isNull);
    expect(parsePriceText([(text: '￥100,000円', region: region)]), isNull);
  });
}
