import '../domain/scan_state.dart';

/// PriceStabilizer - detects stable price readings
class PriceStabilizer {
  final List<int> _history = [];
  int? _currentPrice;
  double _confidence = 0.0;

  /// Submit a price candidate and return true if stable
  bool submit(PriceCandidate candidate) {
    _currentPrice = candidate.priceYen;
    _confidence = candidate.confidence;
    _history.add(candidate.priceYen);

    // Keep only last 5 readings
    if (_history.length > 5) {
      _history.removeAt(0);
    }

    // Need at least 3 readings
    if (_history.length < 3) return false;

    // Check if last 3 are the same
    final last3 = _history.sublist(_history.length - 3);
    return last3.every((p) => p == last3.first);
  }

  int? get currentPrice => _currentPrice;
  double get confidence => _confidence;

  void reset() {
    _history.clear();
    _currentPrice = null;
    _confidence = 0.0;
  }
}
