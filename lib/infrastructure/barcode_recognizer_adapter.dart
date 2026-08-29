import '../domain/scan_state.dart';

/// バーコード認識アダプターインターフェース
/// フレームからJAN/EANバーコード候補を返す
/// v0.2ではこれが主要な商品識別手段
abstract interface class BarcodeRecognizerAdapter {
  /// フレームからバーコード候補を返す
  Future<List<BarcodeCandidate>> detectBarcodes(CameraFrame frame);
  
  /// アダプターを解放する
  void dispose();
}

/// カメラフレーム（Domain層で定義）
class CameraFrame {
  final int width;
  final int height;
  final List<int> bytes;      // フレームバイト列
  final int rotationDegrees;  // 回転角度
  final DateTime timestamp;

  const CameraFrame({
    required this.width,
    required this.height,
    required this.bytes,
    required this.rotationDegrees,
    required this.timestamp,
  });
}

/// テスト用のモック実装
class MockBarcodeRecognizerAdapter implements BarcodeRecognizerAdapter {
  final List<BarcodeCandidate> _mockResults;
  int _callCount = 0;

  MockBarcodeRecognizerAdapter(this._mockResults);

  @override
  Future<List<BarcodeCandidate>> detectBarcodes(CameraFrame frame) async {
    _callCount++;
    // 3フレーム目以降で検出
    if (_callCount >= 3 && _mockResults.isNotEmpty) {
      return _mockResults;
    }
    return [];
  }

  @override
  void dispose() {}

  int get callCount => _callCount;
}
