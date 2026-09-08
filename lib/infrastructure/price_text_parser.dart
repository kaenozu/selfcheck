import '../domain/scan_state.dart';

final RegExp _pricePattern = RegExp(
  r'(?<![0-9])(?:[¥￥]\s*)?([0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})(?:\s*円)?(?![0-9])',
);
final RegExp _barePriceLinePattern = RegExp(
  r'^\s*(?:[0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})\s*$',
);
final RegExp _unitPriceContextPattern = RegExp(
  r'(?:'
  r'(?:[0-9]+\s*(?:g|kg|ml|l|個|本|枚|袋|パック))\s*(?:当たり|あたり|当り|につき)'
  r'|[/／]\s*[0-9]+\s*(?:g|kg|ml|l|個|本|枚|袋|パック)'
  r')',
  caseSensitive: false,
);

/// Parses a plausible retail price from OCR text without guessing values.
///
/// Currency-marked candidates are preferred. A bare number is accepted only
/// when the whole OCR line is numeric, preventing text such as "在庫 12" from
/// being treated as a price. Explicit unit-price lines such as "100g当たり
/// ¥198" or "¥198/100g" are rejected rather than stored as a product price.
/// Among equally-ranked bare candidates, the larger OCR region wins because
/// shelf-label prices are typically the dominant text.
PriceCandidate? parsePriceText(Iterable<({String text, Rect region})> lines) {
  _ParsedPrice? best;

  for (final line in lines) {
    if (_unitPriceContextPattern.hasMatch(line.text)) continue;

    for (final match in _pricePattern.allMatches(line.text)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final normalized = raw.replaceAll(RegExp(r'[,，]'), '');
      final value = int.tryParse(normalized);
      if (value == null || value < 1 || value > 99999) continue;

      final matchedText = match.group(0) ?? raw;
      final hasCurrencyMarker =
          matchedText.contains('¥') ||
          matchedText.contains('￥') ||
          matchedText.contains('円');
      if (!hasCurrencyMarker && !_barePriceLinePattern.hasMatch(line.text)) {
        continue;
      }

      final candidate = _ParsedPrice(
        value: value,
        confidence: hasCurrencyMarker ? 0.90 : 0.70,
        region: line.region,
        rawText: line.text,
      );

      if (best == null ||
          candidate.confidence > best.confidence ||
          (candidate.confidence == best.confidence &&
              candidate.regionArea > best.regionArea)) {
        best = candidate;
      }
    }
  }

  if (best == null) return null;
  return PriceCandidate(
    priceYen: best.value,
    confidence: best.confidence,
    region: best.region,
    rawTexts: [best.rawText],
  );
}

class _ParsedPrice {
  const _ParsedPrice({
    required this.value,
    required this.confidence,
    required this.region,
    required this.rawText,
  });

  final int value;
  final double confidence;
  final Rect region;
  final String rawText;

  double get regionArea => region.width.abs() * region.height.abs();
}
