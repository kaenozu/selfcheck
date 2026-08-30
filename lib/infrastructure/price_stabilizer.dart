import '../domain/scan_state.dart';

/// PriceStabilizer - detects stable price readings
class PriceStabilizer {
  final List<int> _history = [];
  int? _currentPrice;
  double _confidence = 0.0;
  int? _stablePrice;
  double _stableConfidence = 0.0;

  /// Submit a price candidate and return true if stable.
  ///
  /// [currentPrice] always reflects the latest OCR candidate, while
  /// [stablePrice] is populated only after three consecutive identical
  /// readings. Callers that persist or compare prices must use [stablePrice].
  bool submit(PriceCandidate candidate) {
    _currentPrice = candidate.priceYen;
    _confidence = candidate.confidence;
    _history.add(candidate.priceYen);

    // Keep only last 5 readings
    if (_history.length > 5) {
      _history.removeAt(0);
    }

    // Need at least 3 readings before a value can be considered stable.
    if (_history.length < 3) {
      _stablePrice = null;
      _stableConfidence = 0.0;
      return false;
    }

    final last3 = _history.sublist(_history.length - 3);
    final isStable = last3.every((price) => price == last3.first);

    if (isStable) {
      _stablePrice = last3.first;
      _stableConfidence = candidate.confidence;
    } else {
      _stablePrice = null;
      _stableConfidence = 0.0;
    }

    return isStable;
  }

  /// Latest OCR candidate, regardless of stability.
  int? get currentPrice => _currentPrice;

  /// Confidence of the latest OCR candidate.
  double get confidence => _confidence;

  /// Price that passed the three-consecutive-readings stability requirement.
  int? get stablePrice => _stablePrice;

  /// Confidence associated with [stablePrice].
  double get stableConfidence => _stableConfidence;

  void reset() {
    _history.clear();
    _currentPrice = null;
    _confidence = 0.0;
    _stablePrice = null;
    _stableConfidence = 0.0;
  }
}
