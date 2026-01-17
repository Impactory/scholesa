/**
 * Redaction Service
 * 
 * Strip PII before sending to AI providers
 * - Replace names with STUDENT_A, TEACHER_B
 * - Remove emails, phone numbers, addresses
 * - Sanitize file paths, URLs
 * - Age-specific redaction policies
 */

import type { PolicyMode } from './modelAdapter';

export interface RedactionConfig {
  redactNames: boolean;
  redactEmails: boolean;
  redactPhones: boolean;
  redactLocations: boolean;
  redactIds: boolean;
  preserveCodeSnippets: boolean;
}

export interface RedactionResult {
  redacted: string;
  replacements: Map<string, string>; // Original → Placeholder
  flagged: string[]; // Patterns that might need review
}

export class RedactionService {
  /**
   * Get redaction config based on policy mode
   */
  static getConfigForPolicy(policyMode: PolicyMode): RedactionConfig {
    const baseConfig: RedactionConfig = {
      redactNames: true,
      redactEmails: true,
      redactPhones: true,
      redactLocations: true,
      redactIds: true,
      preserveCodeSnippets: true
    };
    
    // K-3: strictest redaction
    if (policyMode === 'k3_safe') {
      return {
        ...baseConfig,
        preserveCodeSnippets: false // Even safer
      };
    }
    
    return baseConfig;
  }
  
  /**
   * Redact PII from text
   */
  static redact(
    text: string,
    config: RedactionConfig,
    knownEntities?: {
      studentNames?: string[];
      educatorNames?: string[];
      siteNames?: string[];
    }
  ): RedactionResult {
    let redacted = text;
    const replacements = new Map<string, string>();
    const flagged: string[] = [];
    
    // 1. Redact known entities first (most accurate)
    if (knownEntities) {
      if (knownEntities.studentNames && config.redactNames) {
        knownEntities.studentNames.forEach((name, idx) => {
          const placeholder = `STUDENT_${String.fromCharCode(65 + idx)}`; // A, B, C...
          const regex = new RegExp(`\\b${this.escapeRegex(name)}\\b`, 'gi');
          if (regex.test(redacted)) {
            redacted = redacted.replace(regex, placeholder);
            replacements.set(name, placeholder);
          }
        });
      }
      
      if (knownEntities.educatorNames && config.redactNames) {
        knownEntities.educatorNames.forEach((name, idx) => {
          const placeholder = `TEACHER_${String.fromCharCode(65 + idx)}`;
          const regex = new RegExp(`\\b${this.escapeRegex(name)}\\b`, 'gi');
          if (regex.test(redacted)) {
            redacted = redacted.replace(regex, placeholder);
            replacements.set(name, placeholder);
          }
        });
      }
      
      if (knownEntities.siteNames && config.redactLocations) {
        knownEntities.siteNames.forEach((name, idx) => {
          const placeholder = `SCHOOL_${idx + 1}`;
          const regex = new RegExp(`\\b${this.escapeRegex(name)}\\b`, 'gi');
          if (regex.test(redacted)) {
            redacted = redacted.replace(regex, placeholder);
            replacements.set(name, placeholder);
          }
        });
      }
    }
    
    // 2. Redact emails
    if (config.redactEmails) {
      const emailRegex = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g;
      const emails = redacted.match(emailRegex) || [];
      emails.forEach((email, idx) => {
        const placeholder = `EMAIL_${idx + 1}`;
        redacted = redacted.replace(email, placeholder);
        replacements.set(email, placeholder);
      });
    }
    
    // 3. Redact phone numbers
    if (config.redactPhones) {
      const phoneRegex = /(\+\d{1,3}[-.]?)?\(?\d{3}\)?[-.]?\d{3}[-.]?\d{4}/g;
      const phones = redacted.match(phoneRegex) || [];
      phones.forEach((phone, idx) => {
        const placeholder = `PHONE_${idx + 1}`;
        redacted = redacted.replace(phone, placeholder);
        replacements.set(phone, placeholder);
      });
    }
    
    // 4. Redact Firestore IDs (long alphanumeric strings)
    if (config.redactIds) {
      const idRegex = /\b[A-Za-z0-9]{20,}\b/g;
      const ids = redacted.match(idRegex) || [];
      ids.forEach((id, idx) => {
        // Don't redact if it looks like code (has underscores, mixed case pattern)
        if (config.preserveCodeSnippets && this.looksLikeCode(id)) {
          return;
        }
        const placeholder = `ID_${idx + 1}`;
        redacted = redacted.replace(id, placeholder);
        replacements.set(id, placeholder);
      });
    }
    
    // 5. Redact addresses (simplified - just street patterns)
    if (config.redactLocations) {
      const addressRegex = /\b\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln)\b/gi;
      const addresses = redacted.match(addressRegex) || [];
      addresses.forEach((address, idx) => {
        const placeholder = `ADDRESS_${idx + 1}`;
        redacted = redacted.replace(address, placeholder);
        replacements.set(address, placeholder);
      });
    }
    
    // 6. Flag potential PII that we might have missed
    const flagPatterns = [
      { pattern: /\b(?:my|their|his|her)\s+(?:name|email|phone|address)\s+is\b/gi, type: 'explicit_pii' },
      { pattern: /\b(?:SSN|social\s+security)\b/gi, type: 'ssn_mention' },
      { pattern: /\b(?:password|passwd|pwd)\s*[:=]/gi, type: 'password_mention' }
    ];
    
    flagPatterns.forEach(({ pattern, type }) => {
      if (pattern.test(text)) {
        flagged.push(type);
      }
    });
    
    return {
      redacted,
      replacements,
      flagged
    };
  }
  
  /**
   * Restore redacted text (for logging, not for sending to model)
   */
  static restore(
    redacted: string,
    replacements: Map<string, string>
  ): string {
    let restored = redacted;
    
    // Reverse the map: placeholder → original
    const reverseMap = new Map<string, string>();
    replacements.forEach((placeholder, original) => {
      reverseMap.set(placeholder, original);
    });
    
    // Replace placeholders with originals
    reverseMap.forEach((original, placeholder) => {
      const regex = new RegExp(`\\b${this.escapeRegex(placeholder)}\\b`, 'g');
      restored = restored.replace(regex, original);
    });
    
    return restored;
  }
  
  /**
   * Check if string looks like code (preserve variable names, etc.)
   */
  private static looksLikeCode(str: string): boolean {
    // Has underscores or camelCase
    return /_/.test(str) || /[a-z][A-Z]/.test(str);
  }
  
  /**
   * Escape special regex characters
   */
  private static escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}

// ==================== CONVENIENCE FUNCTIONS ====================

/**
 * Quick redact for student questions
 */
export function redactStudentQuestion(
  question: string,
  studentName: string,
  policyMode: PolicyMode
): RedactionResult {
  const config = RedactionService.getConfigForPolicy(policyMode);
  return RedactionService.redact(question, config, {
    studentNames: [studentName]
  });
}

/**
 * Redact artifact content
 */
export function redactArtifact(
  content: string,
  metadata: {
    studentName: string;
    educatorName?: string;
    siteName?: string;
  },
  policyMode: PolicyMode
): RedactionResult {
  const config = RedactionService.getConfigForPolicy(policyMode);
  return RedactionService.redact(content, config, {
    studentNames: [metadata.studentName],
    educatorNames: metadata.educatorName ? [metadata.educatorName] : undefined,
    siteNames: metadata.siteName ? [metadata.siteName] : undefined
  });
}
