import 'package:flutter/material.dart';
import '../../domain/scan_state.dart';

/// Overlay that displays state-appropriate messages during scanning
class ScanOverlay extends StatelessWidget {
  final ScanState scanState;

  const ScanOverlay({super.key, required this.scanState});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildOverlay(context),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    switch (scanState) {
      case ScanState.idle:
        return _IdleOverlay(key: const ValueKey('idle'));
      case ScanState.scanning:
        return _ScanningOverlay(key: const ValueKey('scanning'));
      case ScanState.waitingPrice:
        return _WaitingPriceOverlay(key: const ValueKey('waitingPrice'));
      case ScanState.noProduct:
        return _NoProductOverlay(key: const ValueKey('noProduct'));
      case ScanState.comparing:
        return _ComparingOverlay(key: const ValueKey('comparing'));
      case ScanState.result:
        return const SizedBox.shrink(key: ValueKey('result'));
      case ScanState.error:
        return const _ErrorOverlay(key: ValueKey('error'));
    }
  }
}

/// Idle state - tap to start
class _IdleOverlay extends StatelessWidget {
  const _IdleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, size: 64, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'タップしてスキャン開始',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'バーコードと価格を同時に認識します',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scanning state - show scan animation
class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '認識中...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'バーコードまたは価格を認識しています',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Waiting for price - barcode found, price stabilizing
class _WaitingPriceOverlay extends StatelessWidget {
  const _WaitingPriceOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.greenAccent,
            ),
            SizedBox(height: 12),
            Text(
              'バーコード認識済み',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '価格を安定させています...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// No product found - price found but no barcode
class _NoProductOverlay extends StatelessWidget {
  const _NoProductOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orangeAccent,
            ),
            SizedBox(height: 12),
            Text(
              'バーコードが見つかりません',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'バーコードが見える位置にカメラを向けてください',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comparing - fetching historical data
class _ComparingOverlay extends StatelessWidget {
  const _ComparingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '履歴を比較中...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state - shows error message with retry
/// (error message is passed via ScanScreen, not the overlay itself)
class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            SizedBox(height: 12),
            Text(
              'エラーが発生しました',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'タップして再試行',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
