// src/safety/pii_detector.ts
export class PiiDetector {
  // Simple regex-based PII detection
  static detect(text: string): string[] {
    const patterns = [
      /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, // Email
      /\b\d{3}-\d{2}-\d{4}\b/, // SSN
      /\b\d{10}\b/, // Phone
      /\b[A-Za-z]+\s+[A-Za-z]+\b/ // Name (basic)
    ];

    const detected: string[] = [];
    patterns.forEach((pattern, index) => {
      const matches = text.match(pattern);
      if (matches) {
        detected.push(`Pattern ${index + 1}: ${matches[0]}`);
      }
    });

    return detected;
  }

  // Redact PII from text
  static redact(text: string): string {
    // Replace detected PII with placeholders
    let redacted = text;
    const patterns = [
      /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
      /\b\d{3}-\d{2}-\d{4}\b/g,
      /\b\d{10}\b/g,
      /\b[A-Za-z]+\s+[A-Za-z]+\b/g
    ];

    patterns.forEach(pattern => {
      redacted = redacted.replace(pattern, '[REDACTED]');
    });

    return redacted;
  }
}