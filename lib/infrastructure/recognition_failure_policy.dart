/// Decides when repeated frame-level recognition failures are actionable.
///
/// A single failed frame is expected on a live camera stream. Callers should
/// publish the underlying error only when [recordFailure] returns true, or
/// when the failure is known to be fatal. Any successfully completed frame
/// resets the streak so transient camera/ML Kit failures can recover.
class RecognitionFailurePolicy {
  RecognitionFailurePolicy({this.threshold = 3})
    : assert(threshold > 0, 'threshold must be positive');

  final int threshold;
  int consecutiveFailures = 0;

  bool recordFailure({bool fatal = false}) {
    consecutiveFailures++;
    return fatal || consecutiveFailures == threshold;
  }

  void recordSuccess() {
    consecutiveFailures = 0;
  }
}
