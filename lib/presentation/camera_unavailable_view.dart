import 'package:flutter/material.dart';

class CameraUnavailableView extends StatefulWidget {
  const CameraUnavailableView({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<CameraUnavailableView> createState() => _CameraUnavailableViewState();
}

class _CameraUnavailableViewState extends State<CameraUnavailableView> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } on Object {
      // Keep the recovery UI visible so the user can retry after changing the
      // camera permission or after a transient camera failure.
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography,
                size: 72,
                color: Colors.white30,
              ),
              const SizedBox(height: 16),
              const Text(
                'カメラを利用できません。カメラ権限を確認してから再試行してください。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: _retrying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_retrying ? '再試行中…' : '再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
