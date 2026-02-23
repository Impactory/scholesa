/**
 * Model Adapter Layer
 * 
 * Vendor-agnostic AI interface - your app is the system of record,
 * AI providers are stateless reasoning services.
 * 
 * Architecture:
 * - Student data stays in your vault
 * - Send only minimum context needed for current task
 * - All intelligence (rubrics, policies, memory) owned by you
 * - Swap Gemini/OpenAI/Claude without losing "smartness"
 */

import type { AgeBand } from '@/src/types/schema';
import type { SupportedLocale } from '@/src/lib/i18n/config';
import type { Role } from '@/schema';

// ==================== YOUR SCHEMA (vendor-agnostic) ====================

export type TaskType =
  | 'hint_generation'
  | 'rubric_check'
  | 'debug_assistance'
  | 'critique_feedback'
  | 'explain_concept'
  | 'reflection_prompt';

export type PolicyMode =
  | 'k3_safe'       // K-3: Teacher guidance, no PII, simple language
  | 'grades_4_6'    // 4-6: Structured scaffolding
  | 'grades_7_9'    // 7-9: Metacognition, identity-focused
  | 'grades_10_12'; // 10-12: Professional, critique-level

export interface ContextBlock {
  type: 'rubric' | 'artifact' | 'feedback' | 'exemplar' | 'misconception' | 'mission_goal';
  content: string;
  id?: string; // Reference to source (for citations)
  relevance?: number; // 0-1, from retrieval
  metadata?: Record<string, unknown>; // Optional metadata for logging/debugging
}

export interface SafetyConstraints {
  blockHarmfulContent: boolean;
  requireChildSafe: boolean;
  noDirectAnswers: boolean;
  explainBackRequired: boolean;
  maxTokens: number;
}

export interface ModelRequest {
  taskType: TaskType;
  gradeBand: AgeBand;
  targetLocale: SupportedLocale;
  role: Role;
  siteId: string;
  learnerId: string;
  traceId: string;
  promptTemplateId: string;
  policyVersion: string;
  policyMode: PolicyMode;
  missionAttemptId?: string;
  
  // Student context (redacted, minimal)
  studentLevel: 'emerging' | 'proficient' | 'advanced';
  studentQuestion: string;
  
  // Retrieved context (from your vector store)
  contextBlocks: ContextBlock[];
  
  // Your rules
  rubricId?: string;
  safetyConstraints: SafetyConstraints;
  
  // Response format
  responseFormat: {
    type: 'hint' | 'steps' | 'explanation' | 'questions' | 'feedback';
    includeFollowUp: boolean;
    includeCitations: boolean;
  };
}

export interface ModelResponse {
  answer: string;
  
  // Structured outputs
  steps?: string[];
  hints?: string[];
  followUpQuestions?: string[];
  
  // Citations to YOUR artifacts (not model's training data)
  citations?: {
    contextBlockId: string;
    snippet: string;
  }[];
  
  // Model metadata
  modelVersion: string;
  promptTemplateId: string;
  policyVersion: string;
  safetyOutcome: 'allowed' | 'blocked' | 'modified' | 'escalated';
  safetyReasonCode: string;
  toolCallIds: string[];
  targetLocale: SupportedLocale;
  gradeBand: AgeBand;
  traceId: string;
  missionAttemptId?: string;
  confidence?: number; // 0-1
  safetyFlags?: string[];
  
  // For your logging
  modelUsed: string;
  tokensUsed: number;
  latencyMs: number;
}

// ==================== ADAPTER INTERFACE ====================

export interface ModelAdapter {
  name: string;
  
  /**
   * Convert your ModelRequest → vendor API call
   */
  complete(request: ModelRequest): Promise<ModelResponse>;
  
  /**
   * Health check
   */
  isAvailable(): Promise<boolean>;
}

// ==================== GEMINI ADAPTER ====================

export class GeminiAdapter implements ModelAdapter {
  name = 'gemini';
  private apiKey: string;
  private baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  
  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }
  
  async complete(request: ModelRequest): Promise<ModelResponse> {
    const startTime = Date.now();
    
    try {
      // Build system prompt from YOUR rules
      const systemPrompt = this.buildSystemPrompt(request);
      
      // Build user message with context blocks
      const userMessage = this.buildUserMessage(request);
      
      // Call Gemini API
      const response = await fetch(
        `${this.baseUrl}/models/gemini-1.5-flash:generateContent?key=${this.apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{
              parts: [{ text: userMessage }]
            }],
            systemInstruction: {
              parts: [{ text: systemPrompt }]
            },
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens: request.safetyConstraints.maxTokens,
              candidateCount: 1
            },
            safetySettings: this.buildSafetySettings(request)
          })
        }
      );
      
      if (!response.ok) {
        throw new Error(`Gemini API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      const latencyMs = Date.now() - startTime;
      
      // Parse response into YOUR schema
      return this.parseGeminiResponse(data, request, latencyMs);
      
    } catch (error) {
      console.error('Gemini adapter error:', error);
      throw error;
    }
  }
  
  async isAvailable(): Promise<boolean> {
    try {
      const response = await fetch(
        `${this.baseUrl}/models/gemini-1.5-flash?key=${this.apiKey}`
      );
      return response.ok;
    } catch {
      return false;
    }
  }
  
  // ===== PRIVATE HELPERS =====
  
  private buildSystemPrompt(request: ModelRequest): string {
    const { taskType, policyMode, safetyConstraints, targetLocale } = request;
    
    let prompt = `You are an AI learning coach for K-12 students.\n\n`;
    
    // Task-specific instructions
    const taskInstructions = {
      hint_generation: 'Provide hints that guide thinking, never direct answers. Ask questions that scaffold understanding.',
      rubric_check: 'Compare student work against rubric criteria. Point out strengths and specific gaps with examples.',
      debug_assistance: 'Help debug by asking diagnostic questions. Guide the debugging process, don\'t fix it for them.',
      critique_feedback: 'Provide constructive, growth-oriented feedback. Focus on specific improvements with reasoning.',
      explain_concept: 'Explain concepts using analogies and examples appropriate for the grade level.',
      reflection_prompt: 'Ask reflective questions that promote metacognition and identity development.'
    };
    
    prompt += `Task: ${taskInstructions[taskType]}\n\n`;
    prompt += `Language: Respond strictly in locale "${targetLocale}".\n\n`;
    
    // Age-appropriate policies
    const policyInstructions = {
      k3_safe: 'Use simple language (2nd grade reading level). Be encouraging and concrete. No abstract concepts.',
      grades_4_6: 'Use clear language with examples. Introduce growth mindset. Normalize mistakes as learning.',
      grades_7_9: 'Connect to identity and relevance. Ask "why this matters to you". Encourage metacognition.',
      grades_10_12: 'Professional tone. Challenge thinking. Connect to real-world applications and careers.'
    };
    
    prompt += `Age Band: ${policyInstructions[policyMode]}\n\n`;
    
    // Safety rules
    if (safetyConstraints.noDirectAnswers) {
      prompt += `CRITICAL: Never provide direct answers. Always scaffold with questions and hints.\n`;
    }
    
    if (safetyConstraints.explainBackRequired) {
      prompt += `IMPORTANT: After helping, ask the student to explain back what they learned.\n`;
    }
    
    prompt += `\nResponse Guidelines:
- Be encouraging and growth-oriented
- Use concrete examples
- Cite context blocks when relevant (use [Context #N])
- Keep responses concise (2-3 sentences for hints, 1 paragraph max for explanations)
- End with a follow-up question to check understanding`;
    
    return prompt;
  }
  
  private buildUserMessage(request: ModelRequest): string {
    let message = '';
    
    // Add context blocks (retrieved from YOUR store)
    if (request.contextBlocks.length > 0) {
      message += `Context:\n\n`;
      request.contextBlocks.forEach((block, idx) => {
        message += `[Context #${idx + 1}] (${block.type}):\n${block.content}\n\n`;
      });
    }
    
    // Student info (minimal, redacted)
    message += `Student Level: ${request.studentLevel}\n\n`;
    
    // The actual question
    message += `Student Question:\n${request.studentQuestion}`;
    
    return message;
  }
  
  private buildSafetySettings(request: ModelRequest) {
    // Gemini safety settings
    const baseSettings = [
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' }
    ];
    
    // Stricter for K-3
    if (request.safetyConstraints.requireChildSafe) {
      return baseSettings.map(s => ({ ...s, threshold: 'BLOCK_LOW_AND_ABOVE' }));
    }
    
    return baseSettings;
  }
  
  private parseGeminiResponse(
    data: any,
    request: ModelRequest,
    latencyMs: number
  ): ModelResponse {
    const candidate = data.candidates?.[0];
    if (!candidate) {
      throw new Error('No response from Gemini');
    }
    
    const text = candidate.content?.parts?.[0]?.text || '';
    
    // Extract citations (references to [Context #N])
    const citations: ModelResponse['citations'] = [];
    const citationRegex = /\[Context #(\d+)\]/g;
    let match;
    
    while ((match = citationRegex.exec(text)) !== null) {
      const contextIdx = parseInt(match[1]) - 1;
      const contextBlock = request.contextBlocks[contextIdx];
      
      if (contextBlock?.id) {
        citations.push({
          contextBlockId: contextBlock.id,
          snippet: contextBlock.content.substring(0, 100)
        });
      }
    }
    
    // Check safety flags
    const safetyFlags: string[] = [];
    if (candidate.safetyRatings) {
      candidate.safetyRatings.forEach((rating: any) => {
        if (rating.probability !== 'NEGLIGIBLE') {
          safetyFlags.push(`${rating.category}: ${rating.probability}`);
        }
      });
    }
    
    // Parse structured outputs based on format
    const response: ModelResponse = {
      answer: text.trim(),
      citations: citations.length > 0 ? citations : undefined,
      safetyFlags: safetyFlags.length > 0 ? safetyFlags : undefined,
      modelUsed: 'gemini-1.5-flash',
      modelVersion: 'gemini-1.5-flash',
      promptTemplateId: request.promptTemplateId,
      policyVersion: request.policyVersion,
      safetyOutcome: 'allowed',
      safetyReasonCode: 'none',
      toolCallIds: [],
      targetLocale: request.targetLocale,
      gradeBand: request.gradeBand,
      traceId: request.traceId,
      missionAttemptId: request.missionAttemptId,
      tokensUsed: data.usageMetadata?.totalTokenCount || 0,
      latencyMs
    };
    
    // Extract follow-up questions if requested
    if (request.responseFormat.includeFollowUp) {
      const questionMatches = text.match(/\?[^\n]*$/gm);
      if (questionMatches) {
        response.followUpQuestions = questionMatches.map((q: string) => q.trim());
      }
    }
    
    return response;
  }
}

// ==================== OPENAI ADAPTER ====================

export class OpenAIAdapter implements ModelAdapter {
  name = 'openai';
  private apiKey: string;
  private baseUrl = 'https://api.openai.com/v1';
  
  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }
  
  async complete(request: ModelRequest): Promise<ModelResponse> {
    const startTime = Date.now();
    
    try {
      const systemPrompt = this.buildSystemPrompt(request);
      const userMessage = this.buildUserMessage(request);
      
      const response = await fetch(`${this.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userMessage }
          ],
          temperature: 0.7,
          max_tokens: request.safetyConstraints.maxTokens
        })
      });
      
      if (!response.ok) {
        throw new Error(`OpenAI API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      const latencyMs = Date.now() - startTime;
      
      return {
        answer: data.choices[0].message.content.trim(),
        modelUsed: 'gpt-4o-mini',
        modelVersion: 'gpt-4o-mini',
        promptTemplateId: request.promptTemplateId,
        policyVersion: request.policyVersion,
        safetyOutcome: 'allowed',
        safetyReasonCode: 'none',
        toolCallIds: [],
        targetLocale: request.targetLocale,
        gradeBand: request.gradeBand,
        traceId: request.traceId,
        missionAttemptId: request.missionAttemptId,
        tokensUsed: data.usage.total_tokens,
        latencyMs
      };
      
    } catch (error) {
      console.error('OpenAI adapter error:', error);
      throw error;
    }
  }
  
  async isAvailable(): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/models`, {
        headers: { 'Authorization': `Bearer ${this.apiKey}` }
      });
      return response.ok;
    } catch {
      return false;
    }
  }
  
  private buildSystemPrompt(request: ModelRequest): string {
    return [
      'You are an AI learning coach for K-12 students.',
      `Respond strictly in locale "${request.targetLocale}".`,
      `Task type: ${request.taskType}.`,
      request.safetyConstraints.noDirectAnswers
        ? 'Never provide direct answers. Guide the learner with hints and questions.'
        : 'Provide concise educational support.',
      request.safetyConstraints.explainBackRequired
        ? 'End with a question asking the learner to explain back what they learned.'
        : 'End with a clear next step.'
    ].join('\n');
  }
  
  private buildUserMessage(request: ModelRequest): string {
    const context = request.contextBlocks
      .map((block, index) => `[Context #${index + 1}] (${block.type})\n${block.content}`)
      .join('\n\n');
    return [context, `Student level: ${request.studentLevel}`, `Question: ${request.studentQuestion}`]
      .filter(Boolean)
      .join('\n\n');
  }
}

// ==================== MODEL ROUTER ====================

export class ModelRouter {
  private adapters: Map<string, ModelAdapter> = new Map();
  private defaultAdapter: string = 'gemini';
  
  registerAdapter(adapter: ModelAdapter) {
    this.adapters.set(adapter.name, adapter);
  }
  
  setDefault(adapterName: string) {
    if (!this.adapters.has(adapterName)) {
      throw new Error(`Adapter ${adapterName} not registered`);
    }
    this.defaultAdapter = adapterName;
  }
  
  async complete(
    request: ModelRequest,
    preferredAdapter?: string
  ): Promise<ModelResponse> {
    const adapterName = preferredAdapter || this.defaultAdapter;
    const adapter = this.adapters.get(adapterName);
    
    if (!adapter) {
      throw new Error(`Adapter ${adapterName} not found`);
    }
    
    // Fallback to default if preferred unavailable
    if (preferredAdapter && !(await adapter.isAvailable())) {
      console.warn(`${adapterName} unavailable, falling back to ${this.defaultAdapter}`);
      const fallback = this.adapters.get(this.defaultAdapter);
      if (!fallback) {
        throw new Error('No available adapters');
      }
      return fallback.complete(request);
    }
    
    return adapter.complete(request);
  }
}

// ==================== SINGLETON INSTANCE ====================

export const modelRouter = new ModelRouter();

// Initialize with Gemini (from env)
if (process.env.NEXT_PUBLIC_GEMINI_API_KEY) {
  modelRouter.registerAdapter(
    new GeminiAdapter(process.env.NEXT_PUBLIC_GEMINI_API_KEY)
  );
  modelRouter.setDefault('gemini');
}

// Add OpenAI if available
if (process.env.OPENAI_API_KEY) {
  modelRouter.registerAdapter(
    new OpenAIAdapter(process.env.OPENAI_API_KEY)
  );
}
