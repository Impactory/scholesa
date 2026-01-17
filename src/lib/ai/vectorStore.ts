/**
 * Vector Database Integration for RAG
 * 
 * Provides semantic search over rubrics, exemplars, and student work.
 * Enables the AI coach to retrieve relevant context for better answers.
 * 
 * Architecture:
 * - **Firestore Vector Search** (primary choice - no extra service)
 * - Pinecone / Weaviate (alternatives if Firestore doesn't meet needs)
 * 
 * Implementation Status: STUB - Ready for Phase 2
 */

import { collection, addDoc, query, where, getDocs, Timestamp } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type { AgeBand } from '@/src/types/schema';

// ==================== TYPES ====================

export interface VectorDocument {
  id: string;
  content: string;
  embedding: number[]; // 1536-dim for OpenAI text-embedding-3-small
  metadata: {
    type: 'rubric' | 'exemplar' | 'misconception' | 'student_work' | 'feedback_pattern';
    gradeBand?: AgeBand;
    missionId?: string;
    learnerId?: string;
    skillIds?: string[];
    createdAt: Timestamp;
    updatedAt: Timestamp;
  };
}

export interface SearchResult {
  document: VectorDocument;
  score: number; // Cosine similarity 0-1
}

// ==================== EMBEDDING GENERATION ====================

export class EmbeddingService {
  /**
   * Generate embedding for text
   * 
   * Uses OpenAI text-embedding-3-small (1536 dimensions)
   * Cost: $0.02 / 1M tokens
   * 
   * TODO: Implement with OpenAI API or Vertex AI
   */
  static async generateEmbedding(text: string): Promise<number[]> {
    // STUB: Mock embedding generation
    // Production: Call OpenAI Embeddings API
    
    if (process.env.NODE_ENV === 'development') {
      // Return mock 1536-dim vector for development
      return Array(1536).fill(0).map(() => Math.random());
    }
    
    // Production implementation:
    // const response = await openai.embeddings.create({
    //   model: 'text-embedding-3-small',
    //   input: text,
    //   dimensions: 1536
    // });
    // return response.data[0].embedding;
    
    throw new Error('Embedding generation not implemented');
  }
  
  /**
   * Batch generate embeddings (more efficient)
   */
  static async generateEmbeddingsBatch(texts: string[]): Promise<number[][]> {
    // TODO: Implement batch embedding generation
    // OpenAI allows up to 2048 inputs per request
    
    return Promise.all(texts.map(text => this.generateEmbedding(text)));
  }
}

// ==================== VECTOR STORE ====================

export class VectorStore {
  /**
   * Store document with embedding
   */
  static async store(doc: Omit<VectorDocument, 'id'>): Promise<string> {
    // TODO: Implement Firestore Vector Search storage
    
    // For now, store in regular Firestore collection
    const docRef = await addDoc(collection(db, 'vectorDocuments'), {
      ...doc,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now()
    });
    
    return docRef.id;
  }
  
  /**
   * Semantic search using vector similarity
   * 
   * TODO: Implement with Firestore Vector Search or Pinecone
   */
  static async search(
    queryEmbedding: number[],
    topK: number = 5,
    filters?: {
      type?: VectorDocument['metadata']['type'];
      missionId?: string;
      gradeBand?: AgeBand;
    }
  ): Promise<SearchResult[]> {
    // STUB: Placeholder implementation
    // Production: Use Firestore Vector Search or Pinecone
    
    console.warn('Vector search not implemented - returning empty results');
    
    // Mock implementation for development:
    // 1. Fetch filtered documents from Firestore
    // 2. Calculate cosine similarity in-memory (inefficient but works for small datasets)
    // 3. Sort by score and return top K
    
    return [];
  }
  
  /**
   * Delete document from vector store
   */
  static async delete(documentId: string): Promise<void> {
    // TODO: Implement document deletion
    console.log('Deleting document:', documentId);
  }
  
  /**
   * Update document embedding (when content changes)
   */
  static async updateEmbedding(documentId: string, newEmbedding: number[]): Promise<void> {
    // TODO: Implement embedding update
    console.log('Updating embedding for:', documentId);
  }
}

// ==================== INDEXING UTILITIES ====================

export class VectorIndexer {
  /**
   * Index all rubrics into vector store
   */
  static async indexAllRubrics(): Promise<number> {
    console.log('Starting rubric indexing...');
    
    // TODO: Implement rubric indexing
    // 1. Fetch all rubrics from Firestore
    // 2. Generate embeddings for each rubric
    // 3. Store in vector DB
    // 4. Return count indexed
    
    return 0;
  }
  
  /**
   * Index all exemplars (good student work examples)
   */
  static async indexAllExemplars(): Promise<number> {
    console.log('Starting exemplar indexing...');
    
    // TODO: Implement exemplar indexing
    // Similar to rubrics
    
    return 0;
  }
  
  /**
   * Index common misconceptions library
   */
  static async indexMisconceptions(): Promise<number> {
    console.log('Starting misconception indexing...');
    
    // TODO: Implement misconception indexing
    
    return 0;
  }
  
  /**
   * Full reindex of all documents
   * Run this periodically or when rubrics/exemplars change
   */
  static async reindexAll(): Promise<{
    rubrics: number;
    exemplars: number;
    misconceptions: number;
  }> {
    const [rubrics, exemplars, misconceptions] = await Promise.all([
      this.indexAllRubrics(),
      this.indexAllExemplars(),
      this.indexMisconceptions()
    ]);
    
    return { rubrics, exemplars, misconceptions };
  }
}

// ==================== SIMILARITY UTILITIES ====================

/**
 * Calculate cosine similarity between two vectors
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error('Vectors must have same dimensions');
  }
  
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  
  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Find top K most similar documents by brute-force calculation
 * (Only use for small datasets < 1000 docs)
 */
export function findTopKSimilar(
  queryEmbedding: number[],
  documents: VectorDocument[],
  topK: number = 5
): SearchResult[] {
  const scored = documents.map(doc => ({
    document: doc,
    score: cosineSimilarity(queryEmbedding, doc.embedding)
  }));
  
  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

// ==================== CONFIGURATION ====================

export const VECTOR_CONFIG = {
  // Embedding model
  embeddingModel: 'text-embedding-3-small', // OpenAI
  embeddingDimensions: 1536,
  
  // Vector store
  vectorStore: 'firestore', // 'firestore' | 'pinecone' | 'weaviate'
  
  // Search params
  defaultTopK: 5,
  minSimilarity: 0.7, // Only return results with >70% similarity
  
  // Indexing
  batchSize: 100, // Batch size for embedding generation
  maxRetries: 3, // Retry failed embeddings
  
  // Caching
  cacheEmbeddings: true, // Cache frequently used embeddings
  cacheTTL: 3600000, // 1 hour in ms
};

// ==================== MIGRATION GUIDE ====================

/**
 * To fully implement vector search:
 * 
 * **Option 1: Firestore Vector Search** (Recommended)
 * - Pro: No extra service, integrated with existing Firestore
 * - Pro: Auto-scales, built-in filtering
 * - Con: Limited to 1000 dimensions (need to use OpenAI small model)
 * 
 * Steps:
 * 1. Enable Firestore Vector Search in Firebase Console
 * 2. Create vector index on `vectorDocuments` collection
 * 3. Implement `generateEmbedding()` using OpenAI API
 * 4. Implement `VectorStore.search()` using Firestore Vector Search
 * 5. Run `VectorIndexer.reindexAll()` to populate
 * 
 * **Option 2: Pinecone** (If need >1000 dims or advanced features)
 * - Pro: Purpose-built for vector search, very fast
 * - Pro: Supports larger embeddings (up to 20,000 dims)
 * - Con: Extra service to manage, costs ~$70/month for starter
 * 
 * Steps:
 * 1. Sign up for Pinecone, create index
 * 2. Install `@pinecone-database/pinecone` package
 * 3. Implement `VectorStore` methods using Pinecone SDK
 * 4. Run migration to copy existing rubrics/exemplars
 * 
 * **Option 3: Weaviate** (Open-source alternative)
 * - Pro: Self-hosted, full control
 * - Pro: Supports hybrid search (vector + keyword)
 * - Con: More ops overhead
 * 
 * Steps:
 * 1. Deploy Weaviate instance (Cloud Run, GKE, or Weaviate Cloud)
 * 2. Install `weaviate-ts-client` package
 * 3. Implement schema + VectorStore methods
 * 4. Migrate data
 */
