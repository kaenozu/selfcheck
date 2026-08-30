/// スキャン状態
enum ScanState {
  idle, // カメラ起動待ち
  scanning, // バーコード+価格を並列認識中
  waitingPrice, // バーコード確定済み、価格安定化待ち
  noProduct, // 価格確定済み、バーコード認識待ち
  comparing, // 過去履歴比較中
  result, // 結果表示
  error, // エラー発生（自動復帰可能）
}

/// スキャン結果（状態機械の出力）
class ScanResult {
  final ScanState state;
  final String? productId;
  final int? priceYen;
  final String? errorMessage;
  final bool isSaved;

  const ScanResult({
    required this.state,
    this.productId,
    this.priceYen,
    this.errorMessage,
    this.isSaved = false,
  });

  ScanResult copyWith({
    ScanState? state,
    String? productId,
    int? priceYen,
    String? errorMessage,
    bool? isSaved,
  }) {
    return ScanResult(
      state: state ?? this.state,
      productId: productId ?? this.productId,
      priceYen: priceYen ?? this.priceYen,
      errorMessage: errorMessage ?? this.errorMessage,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  @override
  String toString() =>
      'ScanResult(state: $state, productId: $productId, price: ¥$priceYen)';
}

/// バーコード候補
class BarcodeCandidate {
  final String barcode; // JAN/EAN-13文字列
  final BarcodeFormat format; // フォーマット
  final double confidence; // 信頼度（0.0〜1.0）
  final Rect region; // 画面上の位置

  const BarcodeCandidate({
    required this.barcode,
    required this.format,
    required this.confidence,
    required this.region,
  });

  @override
  String toString() => 'BarcodeCandidate($barcode, $format, conf: $confidence)';
}

/// バーコードフォーマット
enum BarcodeFormat { ean13, ean8, code128, qrCode, unknown }

/// 価格候補
class PriceCandidate {
  final int priceYen; // 1〜99,999
  final double confidence; // 0.0〜1.0
  final Rect region; // 画面上の位置
  final List<String> rawTexts; // OCR生文字列

  const PriceCandidate({
    required this.priceYen,
    required this.confidence,
    required this.region,
    required this.rawTexts,
  });

  @override
  String toString() => 'PriceCandidate(¥$priceYen, conf: $confidence)';
}

/// 位置矩形
class Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
}
