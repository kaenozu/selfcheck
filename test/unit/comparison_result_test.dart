import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/comparison_result.dart' as domain;

void main() {
  group('ComparisonResult', () {
    test('firstPrice creates result with correct values', () {
      final result = domain.ComparisonResult.firstPrice(500);
      expect(result.status, domain.ComparisonStatus.firstPrice);
      expect(result.currentPrice, 500);
      expect(result.observationCount, 0);
    });

    test('historyShort creates result with correct values', () {
      final result = domain.ComparisonResult.historyShort(
        currentPrice: 550,
        lastPrice: 500,
        observationCount: 2,
      );
      expect(result.status, domain.ComparisonStatus.historyShort);
      expect(result.observationCount, 2);
      expect(result.baselineMedianYen, 500);
    });

    test('withBaseline creates result with correct values', () {
      final result = domain.ComparisonResult.withBaseline(
        currentPrice: 550,
        baselineMedianYen: 500,
        diffYen: 50,
        diffRate: 0.1,
        label: domain.ComparisonLabel.slightlyExpensive,
        observationCount: 5,
      );
      expect(result.status, domain.ComparisonStatus.withBaseline);
      expect(result.baselineMedianYen, 500);
      expect(result.label, domain.ComparisonLabel.slightlyExpensive);
    });
  });

  group('ComparisonPolicy', () {
    test('labelForDiffRate returns veryCheap for <= -10%', () {
      expect(domain.ComparisonPolicy.labelForDiffRate(-0.15), domain.ComparisonLabel.veryCheap);
      expect(domain.ComparisonPolicy.labelForDiffRate(-0.20), domain.ComparisonLabel.veryCheap);
    });

    test('labelForDiffRate returns cheap for -10% to -5%', () {
      expect(domain.ComparisonPolicy.labelForDiffRate(-0.10), domain.ComparisonLabel.veryCheap);
      expect(domain.ComparisonPolicy.labelForDiffRate(-0.07), domain.ComparisonLabel.cheap);
      expect(domain.ComparisonPolicy.labelForDiffRate(-0.05), domain.ComparisonLabel.cheap);
    });

    test('labelForDiffRate returns normal for -5% to +5%', () {
      expect(domain.ComparisonPolicy.labelForDiffRate(-0.04), domain.ComparisonLabel.normal);
      expect(domain.ComparisonPolicy.labelForDiffRate(0.0), domain.ComparisonLabel.normal);
      expect(domain.ComparisonPolicy.labelForDiffRate(0.04), domain.ComparisonLabel.normal);
    });

    test('labelForDiffRate returns slightlyExpensive for +5% to < +10%', () {
      expect(domain.ComparisonPolicy.labelForDiffRate(0.05), domain.ComparisonLabel.slightlyExpensive);
      expect(domain.ComparisonPolicy.labelForDiffRate(0.07), domain.ComparisonLabel.slightlyExpensive);
    });

    test('labelForDiffRate returns expensive for >= +10%', () {
      expect(domain.ComparisonPolicy.labelForDiffRate(0.10), domain.ComparisonLabel.expensive);
      expect(domain.ComparisonPolicy.labelForDiffRate(0.15), domain.ComparisonLabel.expensive);
    });

    test('labelText returns correct Japanese text', () {
      expect(domain.ComparisonPolicy.labelText(domain.ComparisonLabel.veryCheap), 'かなり安い');
      expect(domain.ComparisonPolicy.labelText(domain.ComparisonLabel.cheap), '安い');
      expect(domain.ComparisonPolicy.labelText(domain.ComparisonLabel.normal), 'いつも通り');
      expect(domain.ComparisonPolicy.labelText(domain.ComparisonLabel.slightlyExpensive), '少し高い');
      expect(domain.ComparisonPolicy.labelText(domain.ComparisonLabel.expensive), '高い');
    });
  });
}
