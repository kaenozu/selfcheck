import '../domain/scan_state.dart';
import 'barcode_recognizer_adapter.dart';

/// 価格OCRアダプターインターフェース
/// フレームから価格候補のみを抽出する
/// 商品名・数量の抽出は行わない（v0.2の変更点）
abstract interface class PriceOCRAdapter {
  /// フレームから価格候補リストを返す
  Future<List<PriceCandidate>> extractPrices(CameraFrame frame);
  
  /// アダプターを解放する
  void dispose();
}

/// テスト用のモック実装
class MockPriceOCRAdapter implements PriceOCRAdapter {
  final List<PriceCandidate> _mockResults;
  int _callCount = 0;

  MockPriceOCRAdapter(this._mockResults);

  @override
  Future<List<PriceCandidate>> extractPrices(CameraFrame frame) async {
    _callCount++;
    // 2フレーム目以降で検出
    if (_callCount >= 2 && _mockResults.isNotEmpty) {
      return _mockResults;
    }
    return [];
  }

  @override
  void dispose() {}

  int get callCount => _callCount;
}
