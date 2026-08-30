import '../domain/scan_state.dart';

final RegExp _pricePattern = RegExp(
  r'(?:[¥￥]\s*)?([0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})(?:\s*円)?',
);

/// Parses a plausible retail price from OCR text without guessing values.
///
/// Currency-marked candidates are preferred. Bare numbers are accepted only in
/// the 1..99,999 yen range; JAN/EAN-length values are therefore never treated
/// as prices.
PriceCandidate? parsePriceText(
  Iterable<({String text, Rect region})> lines,
) {
  _ParsedPrice? best;

  for (final line in lines) {
    for (final match in _pricePattern.allMatches(line.text)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final normalized = raw.replaceAll(RegExp(r'[,，]'), '');
      final value = int.tryParse(normalized);
      if (value == null || value < 1 || value > 99999) continue;

      final matchedText = match.group(0) ?? raw;
      final hasCurrencyMarker = matchedText.contains('¥') ||
          matchedText.contains('￥') ||
          matchedText.contains('円');
      final candidate = _ParsedPrice(
        value: value,
        confidence: hasCurrencyMarker ? 0.90 : 0.70,
        region: line.region,
        rawText: line.text,
      );

      if (best == null || candidate.confidence > best.confidence) {
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
}
