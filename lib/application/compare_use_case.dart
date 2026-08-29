import '../domain/comparison_result.dart';
import '../infrastructure/price_repository.dart';

/// CompareUseCase - compares current price against historical median
class CompareUseCase {
  final PriceRepository _repository;

  CompareUseCase(this._repository);

  /// Compare current price against stored observations
  ///
  /// When [skipInsert] is true, the current observation is NOT saved to the
  /// database. Use this when the caller already determined this is a duplicate
  /// and wants to show the comparison without inflating the observation count.
  Future<ComparisonResult> compare({
    required int currentPriceYen,
    required String productId,
    required double currentConfidence,
    bool skipInsert = false,
  }) async {
    // Fetch historical observations first (before inserting current)
    final since = DateTime.now().subtract(
      const Duration(days: ComparisonPolicy.validObservationDays),
    );
    final observations = await _repository.getValidObservations(
      productId: productId,
      since: since,
      limit: ComparisonPolicy.maxObservationsForMedian,
    );

    // Save current observation (unless caller says it's a duplicate)
    if (!skipInsert) {
      await _repository.insertObservation(
        productId: productId,
        priceYen: currentPriceYen,
        priceConfidence: currentConfidence,
      );
    }

    if (observations.isEmpty) {
      return ComparisonResult.firstPrice(currentPriceYen);
    }

    // Calculate median
    final prices = observations.map((o) => o.priceYen).toList()..sort();
    final median = prices[prices.length ~/ 2];

    if (observations.length < 3) {
      return ComparisonResult.historyShort(
        currentPrice: currentPriceYen,
        lastPrice: median,
        observationCount: observations.length,
      );
    }

    // Calculate diff
    final diffYen = currentPriceYen - median;
    final diffRate = median > 0 ? diffYen / median : 0.0;
    final label = ComparisonPolicy.labelForDiffRate(diffRate);

    return ComparisonResult.withBaseline(
      currentPrice: currentPriceYen,
      baselineMedianYen: median,
      diffYen: diffYen,
      diffRate: diffRate,
      label: label,
      observationCount: observations.length,
    );
  }
}
