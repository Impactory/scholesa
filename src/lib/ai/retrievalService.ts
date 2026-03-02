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
import { EmbeddingService, VectorStore, type VectorDocument } from './vectorStore';
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
   * In production, this would:
   * 1. Generate embedding for query
   * 2. Vector search in your store (Pinecone, Weaviate, or Firestore vector search)
   * 3. Re-rank by relevance
   * 4. Return top-K
   * 
   * For now, simplified with keyword matching
   */
  static async retrieve(query: RetrievalQuery): Promise<ContextBlock[]> {
    const topK = query.topK || 5;
    const minRelevance = query.filters?.minRelevance ?? 0;
    const allowedTypes = query.filters?.types;

    try {
      const queryEmbedding = await EmbeddingService.generateEmbedding(query.query);
      const vectorTypes = this.resolveVectorTypes(allowedTypes);

      const searches = vectorTypes.map((type) =>
        VectorStore.search(queryEmbedding, topK * 2, {
          type,
          missionId: query.missionId,
          gradeBand: query.gradeBand,
        })
      );

      const resultsByType = await Promise.all(searches);

      const contextBlocks = resultsByType
        .flat()
        .map((result) => this.mapSearchResultToContext(result.document, result.score))
        .filter((block): block is ContextBlock => Boolean(block))
        .filter((block) => {
          if (allowedTypes && !allowedTypes.includes(block.type)) return false;
          return (block.relevance ?? 0) >= minRelevance;
        })
        .sort((a, b) => (b.relevance ?? 0) - (a.relevance ?? 0));

      const deduped: ContextBlock[] = [];
      const seen = new Set<string>();
      for (const block of contextBlocks) {
        const key = block.id || `${block.type}:${block.content.slice(0, 64)}`;
        if (seen.has(key)) continue;
        seen.add(key);
        deduped.push(block);
        if (deduped.length >= topK) break;
      }

      return deduped;
    } catch (error) {
      console.error('Retrieval failed:', error);
      return [];
    }
  }
  
  /**
   * Store a document for future retrieval
   */
  static async store(document: StoredDocument): Promise<void> {
    const embedding = document.embedding ?? await EmbeddingService.generateEmbedding(document.content);

    await VectorStore.store({
      content: document.content,
      embedding,
      metadata: {
        type: this.mapStoredToVectorType(document.type),
        gradeBand: document.metadata.gradeBand,
        missionId: document.metadata.missionId,
        learnerId: document.metadata.learnerId,
        skillIds: document.metadata.skillId ? [document.metadata.skillId] : undefined,
        createdAt: Timestamp.fromMillis(document.metadata.createdAt),
        updatedAt: Timestamp.now(),
      },
    });
  }
  
  /**
   * Update embeddings for a document (when content changes)
   */
  static async updateEmbedding(documentId: string, content: string): Promise<void> {
    const embedding = await EmbeddingService.generateEmbedding(content);
    await VectorStore.updateEmbedding(documentId, content, embedding);
  }
  
  // ===== PRIVATE RETRIEVAL METHODS =====
  
  private static async getRubricForMission(
    missionId: string,
    gradeBand: AgeBand
  ): Promise<ContextBlock | null> {
    const seed = await EmbeddingService.generateEmbedding(`rubric ${missionId}`);
    const [best] = await VectorStore.search(seed, 1, {
      type: 'rubric',
      missionId,
      gradeBand,
    });
    if (!best) return null;
    return this.mapSearchResultToContext(best.document, best.score);
  }
  
  private static async getExemplars(query: RetrievalQuery): Promise<ContextBlock[]> {
    const seed = await EmbeddingService.generateEmbedding(query.query || `exemplar ${query.missionId || ''}`);
    const results = await VectorStore.search(seed, query.topK || 5, {
      type: 'exemplar',
      missionId: query.missionId,
      gradeBand: query.gradeBand,
    });
    return results
      .map((result) => this.mapSearchResultToContext(result.document, result.score))
      .filter((block): block is ContextBlock => Boolean(block));
  }
  
  private static async getMisconceptions(query: RetrievalQuery): Promise<ContextBlock[]> {
    const seed = await EmbeddingService.generateEmbedding(query.query || 'common misconception');
    const results = await VectorStore.search(seed, query.topK || 5, {
      type: 'misconception',
      gradeBand: query.gradeBand,
    });
    return results
      .map((result) => this.mapSearchResultToContext(result.document, result.score))
      .filter((block): block is ContextBlock => Boolean(block));
  }
  
  private static async getStudentPastWork(
    learnerId: string,
    missionId?: string
  ): Promise<ContextBlock[]> {
    const seed = await EmbeddingService.generateEmbedding(`student work ${learnerId} ${missionId || ''}`);
    const results = await VectorStore.search(seed, 3, {
      type: 'student_work',
      missionId,
    });

    return results
      .filter((result) => result.document.metadata.learnerId === learnerId)
      .map((result) => this.mapSearchResultToContext(result.document, result.score))
      .filter((block): block is ContextBlock => Boolean(block));
  }
  
  private static async getTeacherFeedback(query: RetrievalQuery): Promise<ContextBlock[]> {
    const seed = await EmbeddingService.generateEmbedding(query.query || 'teacher feedback pattern');
    const results = await VectorStore.search(seed, query.topK || 5, {
      type: 'feedback_pattern',
      missionId: query.missionId,
      gradeBand: query.gradeBand,
    });
    return results
      .map((result) => this.mapSearchResultToContext(result.document, result.score))
      .filter((block): block is ContextBlock => Boolean(block));
  }

  private static resolveVectorTypes(types?: ContextBlock['type'][]): VectorDocument['metadata']['type'][] {
    if (!types || types.length === 0) {
      return ['rubric', 'exemplar', 'misconception', 'student_work', 'feedback_pattern'];
    }

    const mapped = types.map((type) => this.mapContextToVectorType(type)).filter((type): type is VectorDocument['metadata']['type'] => Boolean(type));
    return mapped.length > 0 ? Array.from(new Set(mapped)) : ['rubric', 'exemplar', 'misconception', 'student_work', 'feedback_pattern'];
  }

  private static mapSearchResultToContext(document: VectorDocument, score: number): ContextBlock | null {
    const typeMap: Record<VectorDocument['metadata']['type'], ContextBlock['type']> = {
      rubric: 'rubric',
      exemplar: 'exemplar',
      misconception: 'misconception',
      student_work: 'artifact',
      feedback_pattern: 'feedback',
    };

    const type = typeMap[document.metadata.type];
    if (!type) return null;

    return {
      type,
      content: document.content,
      id: document.id,
      relevance: score,
      metadata: {
        ...document.metadata,
      },
    };
  }

  private static mapStoredToVectorType(type: StoredDocument['type']): VectorDocument['metadata']['type'] {
    switch (type) {
      case 'artifact':
        return 'student_work';
      case 'feedback':
        return 'feedback_pattern';
      case 'rubric':
      case 'exemplar':
      case 'misconception':
        return type;
      default:
        return 'feedback_pattern';
    }
  }

  private static mapContextToVectorType(type: ContextBlock['type']): VectorDocument['metadata']['type'] | null {
    switch (type) {
      case 'artifact':
        return 'student_work';
      case 'feedback':
        return 'feedback_pattern';
      case 'rubric':
      case 'exemplar':
      case 'misconception':
        return type;
      case 'mission_goal':
        return null;
      default:
        return null;
    }
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
