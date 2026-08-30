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
final RegExp _taxInclusiveAfterPattern = RegExp(
  r'(?:税込(?:価格)?|総額|支払総額)\s*[:：]?\s*(?:[¥￥]\s*)?'
  r'([0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})(?:\s*円)?',
);
final RegExp _taxInclusiveBeforePattern = RegExp(
  r'(?:[¥￥]\s*)?([0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})'
  r'(?:\s*円)?\s*[（(]?\s*(?:税込(?:価格)?|総額|支払総額)\s*[）)]?',
);
final RegExp _taxExclusiveContextPattern = RegExp(
  r'(?:税抜(?:き|価格)?|税別|本体価格)',
);

/// Parses a plausible retail price from OCR text without guessing values.
///
/// Explicit tax-inclusive totals are preferred because they represent the
/// consumer-facing amount paid. Explicit tax-exclusive-only lines fail closed.
/// Currency-marked candidates are otherwise preferred. A bare number is
/// accepted only when the whole OCR line is numeric, preventing text such as
/// "在庫 12" from being treated as a price. Explicit unit-price lines such as
/// "100g当たり ¥198" or "¥198/100g" are rejected rather than stored as a
/// product price. Among equally ranked candidates, the larger OCR region wins.
PriceCandidate? parsePriceText(Iterable<({String text, Rect region})> lines) {
  _ParsedPrice? best;

  for (final line in lines) {
    if (_unitPriceContextPattern.hasMatch(line.text)) continue;

    final taxInclusive = _parseTaxInclusiveCandidate(line);
    if (taxInclusive != null) {
      if (_isBetterCandidate(taxInclusive, best)) {
        best = taxInclusive;
      }
      continue;
    }

    if (_taxExclusiveContextPattern.hasMatch(line.text)) continue;

    for (final match in _pricePattern.allMatches(line.text)) {
      final value = _parsePriceValue(match.group(1));
      if (value == null) continue;

      final matchedText = match.group(0) ?? '';
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
        priority: hasCurrencyMarker ? 2 : 1,
        region: line.region,
        rawText: line.text,
      );

      if (_isBetterCandidate(candidate, best)) {
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

_ParsedPrice? _parseTaxInclusiveCandidate(
  ({String text, Rect region}) line,
) {
  for (final pattern in [_taxInclusiveAfterPattern, _taxInclusiveBeforePattern]) {
    final match = pattern.firstMatch(line.text);
    final value = _parsePriceValue(match?.group(1));
    if (value == null) continue;

    return _ParsedPrice(
      value: value,
      confidence: 0.90,
      priority: 3,
      region: line.region,
      rawText: line.text,
    );
  }
  return null;
}

int? _parsePriceValue(String? raw) {
  if (raw == null) return null;
  final normalized = raw.replaceAll(RegExp(r'[,，]'), '');
  final value = int.tryParse(normalized);
  if (value == null || value < 1 || value > 99999) return null;
  return value;
}

bool _isBetterCandidate(_ParsedPrice candidate, _ParsedPrice? best) {
  if (best == null) return true;
  if (candidate.priority != best.priority) {
    return candidate.priority > best.priority;
  }
  if (candidate.confidence != best.confidence) {
    return candidate.confidence > best.confidence;
  }
  return candidate.regionArea > best.regionArea;
}

class _ParsedPrice {
  const _ParsedPrice({
    required this.value,
    required this.confidence,
    required this.priority,
    required this.region,
    required this.rawText,
  });

  final int value;
  final double confidence;
  final int priority;
  final Rect region;
  final String rawText;

  double get regionArea => region.width.abs() * region.height.abs();
}
