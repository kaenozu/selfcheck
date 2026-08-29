import 'package:flutter/material.dart';
import '../domain/scan_state.dart';
import 'scan_screen_controller.dart';
import 'widgets/scan_overlay.dart';
import 'widgets/result_card.dart';
import 'widgets/price_context_badges.dart';

/// Main scan screen - camera preview with state-driven overlay and result card
class ScanScreen extends StatefulWidget {
  final ScanScreenController controller;

  const ScanScreen({super.key, required this.controller});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    widget.controller.addListener(_onStateChanged);
    widget.controller.init();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.uiState;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (placeholder)
          _buildCameraPlaceholder(),

          // Scan frame guide
          if (state.isScanning) _buildScanGuide(),

          // State-driven overlay
          ScanOverlay(scanState: state.scanState),

          // Result card (bottom sheet style)
          if (state.isShowingResult && state.comparisonResult != null)
            _buildResultOverlay(state),

          // Top bar
          _buildTopBar(state),

          // Bottom controls
          _buildBottomControls(state),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(
          Icons.videocam_off,
          size: 80,
          color: Colors.white12,
        ),
      ),
    );
  }

  Widget _buildScanGuide() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.3 + (_pulseController.value * 0.3);
        return Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: opacity),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(ScanScreenUiState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (state.isScanning)
                IconButton(
                  onPressed: () => widget.controller.cancelScan(),
                  icon: const Icon(Icons.close, color: Colors.white),
                )
              else
                const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  '自分値スキャン',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(ScanScreenUiState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error message
              if (state.isError && state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Status text
              if (state.scanState == ScanState.waitingPrice)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'バーコード認識済み ▶ 価格安定化待ち',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),

              // Scan button (also shown in error state for retry)
              if (state.canStartScan) _buildScanButton(),

              if (state.isShowingResult) ...[
                const SizedBox(height: 8),
                Text(
                  'スキャン完了',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: () => widget.controller.startScan(),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: const Icon(
          Icons.qr_code_scanner,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildResultOverlay(ScanScreenUiState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(top: 8),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Price context badges
                if (state.comparisonResult != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PriceContextBadges(
                      isSaleVisible: false,
                      isMemberPriceVisible: false,
                    ),
                  ),

                // Result card
                ResultCard(
                  result: state.comparisonResult!,
                  janCode: state.janCode,
                  onDismiss: () => widget.controller.dismissResult(),
                  onScanAgain: () {
                    widget.controller.dismissResult();
                    widget.controller.startScan();
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
