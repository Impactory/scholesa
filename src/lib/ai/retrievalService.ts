/**
 * Retrieval & Memory Service
 * 
 * Your "smartness" comes from retrieving relevant context from YOUR data:
 * - Student's past work
 * - Teacher feedback
 * - Unit standards + exemplars
 * - Common misconceptions library
 * 
 * This keeps long-term memory portable (not locked in vendor)
 */

import type { ContextBlock } from './modelAdapter';
import type { AgeBand } from '@/src/types/schema';
import { getRubricForMission, formatRubricForAI, type AssessmentRubric } from './rubricManager';
import { EmbeddingService, VectorStore, type SearchResult } from './vectorStore';
import { Timestamp } from 'firebase/firestore';

// ==================== TYPES ====================

export interface RetrievalQuery {
  query: string;
  gradeBand: AgeBand;
  missionId?: string;
  learnerId?: string;
  topK?: number; // How many results to return
  filters?: {
    types?: ContextBlock['type'][];
    minRelevance?: number; // 0-1
  };
}

export interface StoredDocument {
  id: string;
  type: ContextBlock['type'];
  content: string;
  metadata: {
    gradeBand?: AgeBand;
    missionId?: string;
    learnerId?: string;
    rubricId?: string;
    skillId?: string;
    createdAt: number;
    version?: number;
  };
  embedding?: number[]; // Vector for semantic search
}

// ==================== RETRIEVAL SERVICE ====================

export class RetrievalService {
  /**
   * Retrieve relevant context for a student question
   * 
   * Uses hybrid approach:
   * 1. Vector search for semantic similarity (when available)
   * 2. Keyword filtering for specific metadata (mission, grade)
   * 3. Re-ranking by relevance
   */
  static async retrieve(query: RetrievalQuery): Promise<ContextBlock[]> {
    const contextBlocks: ContextBlock[] = [];
    
    // 1. Retrieve rubric criteria (if mission provided) - Always high priority
    if (query.missionId) {
      const rubric = await this.getRubricForMission(query.missionId, query.gradeBand);
      if (rubric) {
        contextBlocks.push({
          type: 'rubric',
          content: rubric.content,
          id: rubric.id,
          relevance: 0.9 // High relevance - always include rubric
        });
      }
    }
    
    // 2. Vector search for semantic similarity ✅ ENABLED
    const useVectorSearch = true; // Vector store with indexing now implemented
    
    if (useVectorSearch) {
      try {
        // Generate embedding for query
        const queryEmbedding = await EmbeddingService.generateEmbedding(query.query);
        
        // Search vector store
        const searchResults = await VectorStore.search(queryEmbedding, query.topK || 5, {
          missionId: query.missionId,
          gradeBand: query.gradeBand
        });
        
        // Convert search results to context blocks (map vector types to context types)
        for (const result of searchResults) {
          const contextType: ContextBlock['type'] = 
            result.document.metadata.type === 'student_work' ? 'artifact' :
            result.document.metadata.type === 'feedback_pattern' ? 'feedback' :
            result.document.metadata.type;
          
          contextBlocks.push({
            type: contextType,
            content: result.document.content,
            id: result.document.id,
            relevance: result.score
          });
        }
      } catch (err) {
        console.warn('Vector search failed, falling back to keyword search:', err);
      }
    }
    
    // 3. Fallback: Keyword-based retrieval (used until vector search is implemented)
    if (!useVectorSearch || contextBlocks.length === 0) {
      // Retrieve exemplars (good examples)
      const exemplars = await this.getExemplars(query);
      contextBlocks.push(...exemplars);
      
      // Retrieve common misconceptions
      const misconceptions = await this.getMisconceptions(query);
      contextBlocks.push(...misconceptions);
      
      // Retrieve student's past work (if learner provided)
      if (query.learnerId) {
        const pastWork = await this.getStudentPastWork(query.learnerId, query.missionId);
        contextBlocks.push(...pastWork);
      }
      
      // Retrieve teacher feedback patterns
      const feedbackPatterns = await this.getTeacherFeedback(query);
      contextBlocks.push(...feedbackPatterns);
    }
    
    // Filter by relevance threshold
    const filtered = contextBlocks.filter(
      block => !query.filters?.minRelevance || (block.relevance || 0) >= query.filters.minRelevance
    );
    
    // Sort by relevance, take top-K
    const topK = query.topK || 5;
    return filtered
      .sort((a, b) => (b.relevance || 0) - (a.relevance || 0))
      .slice(0, topK);
  }
  
  /**
   * Store a document for future retrieval
   * 
   * Phase 2: Will store in vector DB for semantic search
   */
  static async store(document: StoredDocument): Promise<void> {
    // Convert to vector document and store
    try {
      const embedding = await EmbeddingService.generateEmbedding(document.content);
      
      await VectorStore.store({
        content: document.content,
        embedding,
        metadata: {
          type: document.type === 'artifact' ? 'student_work' :
                document.type === 'feedback' ? 'feedback_pattern' :
                document.type === 'mission_goal' ? 'misconception' : // Map mission_goal to misconception
                document.type,
          gradeBand: document.metadata.gradeBand,
          missionId: document.metadata.missionId,
          learnerId: document.metadata.learnerId,
          skillIds: document.metadata.skillId ? [document.metadata.skillId] : undefined,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now()
        }
      });
      
      console.log('Stored document in vector store:', document.id, document.type);
    } catch (err) {
      console.warn('Vector store not available, skipping storage:', err);
    }
  }
  
  /**
   * Update embeddings for a document (when content changes)
   * 
   * Phase 2: Will regenerate embedding and update vector DB
   */
  static async updateEmbedding(documentId: string, content: string): Promise<void> {
    try {
      const newEmbedding = await EmbeddingService.generateEmbedding(content);
      await VectorStore.updateEmbedding(documentId, newEmbedding);
      
      console.log('Updated embedding for:', documentId);
    } catch (err) {
      console.warn('Vector store not available, skipping embedding update:', err);
    }
  }
  
  // ===== PRIVATE RETRIEVAL METHODS =====
  
  private static async getRubricForMission(
    missionId: string,
    gradeBand: AgeBand
  ): Promise<ContextBlock | null> {
    // Fetch from YOUR Firestore (rubrics collection)
    // REAL implementation using RubricManager
    
    try {
      const gradeNumber = this.gradeBandToNumber(gradeBand);
      const rubric = await getRubricForMission('*', missionId, gradeNumber);
      
      if (!rubric) return null;
      
      // Format rubric as markdown
      const formattedRubric = formatRubricForAI(rubric);
      
      return {
        type: 'rubric',
        content: formattedRubric,
        id: rubric.id || `rubric_${missionId}`,
        metadata: {
          rubricId: rubric.id,
          rubricVersion: rubric.version,
          rubricName: rubric.name
        },
        relevance: 0.95 // Rubrics are highly relevant
      };
    } catch (err) {
      console.error('Error fetching rubric:', err);
      return null;
    }
  }
  
  /**
   * Helper: Convert age band to grade number for rubric lookup
   */
  private static gradeBandToNumber(ageBand: AgeBand): number {
    const mapping: Record<AgeBand, number> = {
      grades_1_3: 2,
      grades_4_6: 5,
      grades_7_9: 8,
      grades_10_12: 11
    };
    return mapping[ageBand] || 5;
  }
  
  private static async getExemplars(query: RetrievalQuery): Promise<ContextBlock[]> {
    // Fetch exemplar artifacts from YOUR collection
    // Already filtered by grade band
    
    // Mock for now
    if (query.missionId) {
      return [{
        type: 'exemplar',
        content: 'Example of proficient work: [student showed clear variable naming, step-by-step logic, tested edge cases]',
        id: `exemplar_${query.missionId}_1`,
        relevance: 0.7
      }];
    }
    
    return [];
  }
  
  private static async getMisconceptions(query: RetrievalQuery): Promise<ContextBlock[]> {
    // Fetch from YOUR misconceptions library
    // Curated by educators, tagged by skill/grade
    
    // Mock for now
    return [{
      type: 'misconception',
      content: 'Common mistake: Students often forget to initialize variables before using them in loops.',
      id: 'misconception_loop_init',
      relevance: 0.6
    }];
  }
  
  private static async getStudentPastWork(
    learnerId: string,
    missionId?: string
  ): Promise<ContextBlock[]> {
    // Fetch student's previous artifacts, reflections
    // Helps AI understand their level and patterns
    
    // Mock for now
    return [{
      type: 'artifact',
      content: 'Student previously completed similar mission with Bronze level. Showed strong effort but needed hints on debugging.',
      id: `past_work_${learnerId}`,
      relevance: 0.5
    }];
  }
  
  private static async getTeacherFeedback(query: RetrievalQuery): Promise<ContextBlock[]> {
    // Fetch teacher feedback patterns for similar questions
    // "What worked" from YOUR educator feedback vault
    
    // Mock for now
    return [{
      type: 'feedback',
      content: 'Teachers found success by asking students to explain their code line-by-line before debugging.',
      id: 'feedback_pattern_debug',
      relevance: 0.6
    }];
  }
}

// ==================== CONVENIENCE FUNCTIONS ====================

/**
 * Get context for AI Coach hint request
 */
export async function getHintContext(
  studentQuestion: string,
  learnerId: string,
  missionId: string,
  gradeBand: AgeBand
): Promise<ContextBlock[]> {
  return RetrievalService.retrieve({
    query: studentQuestion,
    gradeBand,
    missionId,
    learnerId,
    topK: 5,
    filters: {
      types: ['rubric', 'exemplar', 'misconception'],
      minRelevance: 0.5
    }
  });
}

/**
 * Get context for rubric check
 */
export async function getRubricCheckContext(
  studentWork: string,
  missionId: string,
  gradeBand: AgeBand
): Promise<ContextBlock[]> {
  return RetrievalService.retrieve({
    query: studentWork,
    gradeBand,
    missionId,
    topK: 3,
    filters: {
      types: ['rubric', 'exemplar'],
      minRelevance: 0.7 // Higher threshold for rubric checks
    }
  });
}

/**
 * Store a new exemplar
 */
export async function storeExemplar(
  content: string,
  missionId: string,
  gradeBand: AgeBand,
  skillIds: string[]
): Promise<void> {
  const doc: StoredDocument = {
    id: `exemplar_${missionId}_${Date.now()}`,
    type: 'exemplar',
    content,
    metadata: {
      gradeBand,
      missionId,
      createdAt: Date.now(),
      version: 1
    }
  };
  
  await RetrievalService.store(doc);
}

/**
 * Store a misconception
 */
export async function storeMisconception(
  description: string,
  skillId: string,
  gradeBand: AgeBand
): Promise<void> {
  const doc: StoredDocument = {
    id: `misconception_${skillId}_${Date.now()}`,
    type: 'misconception',
    content: description,
    metadata: {
      gradeBand,
      skillId,
      createdAt: Date.now()
    }
  };
  
  await RetrievalService.store(doc);
}
