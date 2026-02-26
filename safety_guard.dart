import '../telemetry/telemetry_models.dart';

/// D2 & D3) Safety, COPPA, Data Controls
class SafetyGuard {
  static const List<String> _piiPatterns = [
    r'\b\d{3}-\d{2}-\d{4}\b', // SSN-like
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', // Email
    r'\b\d{3}-\d{3}-\d{4}\b', // Phone
  ];

  bool _isSafeMode = false;
  bool get isSafeMode => _isSafeMode;

  /// Scans text for PII and returns redacted version.
  /// Returns tuple [redactedText, wasRedacted]
  (String, bool) redact(String text) {
    String redacted = text;
    bool found = false;
    
    for (final pattern in _piiPatterns) {
      final regex = RegExp(pattern);
      if (regex.hasMatch(redacted)) {
        found = true;
        redacted = redacted.replaceAll(regex, '[REDACTED]');
      }
    }
    return (redacted, found);
  }

  /// Checks if an action is allowed. Fails closed if in Safe Mode.
  bool canProceed(String actionType) {
    if (_isSafeMode) {
      // Only allow basic navigation or help in safe mode
      return actionType == 'navigation' || actionType == 'help';
    }
    return true;
  }

  void triggerSafeMode(String reason) {
    _isSafeMode = true;
    // In a real app, this would trigger a high-priority alert
    print('!!! SAFE MODE ACTIVATED: $reason !!!');
  }

  void resetSafeMode() {
    _isSafeMode = false;
  }
}