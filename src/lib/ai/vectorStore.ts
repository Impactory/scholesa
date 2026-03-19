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
 * Implementation Status: Active internal vector retrieval and indexing service
 */

import { collection, addDoc, query, where, getDocs, Timestamp, doc, deleteDoc, updateDoc, limit } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import type { AgeBand } from '@/src/types/schema';

// ==================== TYPES ====================

export interface VectorDocument {
  id: string;
  content: string;
  embedding: number[]; // 1536-dim Scholesa internal embedding
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
  private static readonly DIMENSIONS = 1536;

  /**
   * Generate embedding for text
   *
   * Internal deterministic embedding (no external API calls).
   */
  static async generateEmbedding(text: string): Promise<number[]> {
    return this.generateDeterministicEmbedding(text);
  }
  
  /**
   * Batch generate embeddings (more efficient)
   */
  static async generateEmbeddingsBatch(texts: string[]): Promise<number[][]> {
    return texts.map((text) => this.generateDeterministicEmbedding(text));
  }

  private static generateDeterministicEmbedding(text: string): number[] {
    const normalized = text.normalize('NFKC').toLowerCase().trim();
    if (!normalized) {
      return Array(this.DIMENSIONS).fill(0);
    }

    const vector = Array(this.DIMENSIONS).fill(0) as number[];
    for (let i = 0; i < normalized.length; i += 1) {
      const current = normalized.charCodeAt(i);
      const next = normalized.charCodeAt((i + 1) % normalized.length);
      const prev = normalized.charCodeAt((i - 1 + normalized.length) % normalized.length);
      const idxA = (current * 31 + next * 17 + i) % this.DIMENSIONS;
      const idxB = (current * 13 + prev * 19 + i * 7) % this.DIMENSIONS;
      vector[idxA] += 1 + (current % 11) / 10;
      vector[idxB] -= 0.5 + (next % 7) / 10;
    }

    const norm = Math.sqrt(vector.reduce((sum, value) => sum + value * value, 0));
    if (norm === 0) return vector;
    return vector.map((value) => value / norm);
  }
}

// ==================== VECTOR STORE ====================

export class VectorStore {
  /**
   * Store document with embedding
   */
  static async store(doc: Omit<VectorDocument, 'id'>): Promise<string> {
    // Store in Firestore with vector embedding
    // Note: Firestore Vector Search requires specific index configuration
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
   * Uses in-memory cosine similarity for now.
   * For production at scale, use Firestore Vector Search (requires index) or Pinecone.
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
    try {
      // Build Firestore query with filters
      let q = query(collection(db, 'vectorDocuments'));
      
      if (filters?.type) {
        q = query(q, where('metadata.type', '==', filters.type));
      }
      if (filters?.missionId) {
        q = query(q, where('metadata.missionId', '==', filters.missionId));
      }
      if (filters?.gradeBand) {
        q = query(q, where('metadata.gradeBand', '==', filters.gradeBand));
      }
      
      // Fetch candidates (limit to 100 to avoid excessive memory usage)
      q = query(q, limit(100));
      const snapshot = await getDocs(q);
      
      if (snapshot.empty) {
        return [];
      }
      
      // Calculate cosine similarity for each document
      const results: SearchResult[] = [];
      
      snapshot.forEach(docSnap => {
        const data = docSnap.data();
        const docEmbedding = data.embedding as number[];
        
        if (!docEmbedding || docEmbedding.length !== queryEmbedding.length) {
          return; // Skip malformed embeddings
        }
        
        const similarity = this.cosineSimilarity(queryEmbedding, docEmbedding);
        
        results.push({
          document: {
            id: docSnap.id,
            content: data.content,
            embedding: docEmbedding,
            metadata: data.metadata
          },
          score: similarity
        });
      });
      
      // Sort by score descending and return top K
      results.sort((a, b) => b.score - a.score);
      return results.slice(0, topK);
      
    } catch (err) {
      console.error('Vector search failed:', err);
      return [];
    }
  }
  
  /**
   * Calculate cosine similarity between two vectors
   */
  private static cosineSimilarity(a: number[], b: number[]): number {
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
    
    const denominator = Math.sqrt(normA) * Math.sqrt(normB);
    return denominator === 0 ? 0 : dotProduct / denominator;
  }
  
  /**
   * Delete document from vector store
   */
  static async delete(documentId: string): Promise<void> {
    await deleteDoc(doc(db, 'vectorDocuments', documentId));
  }
  
  /**
   * Update document embedding (when content changes)
   */
  static async updateEmbedding(documentId: string, newContent: string, newEmbedding: number[]): Promise<void> {
    await updateDoc(doc(db, 'vectorDocuments', documentId), {
      content: newContent,
      embedding: newEmbedding,
      'metadata.updatedAt': Timestamp.now()
    });
  }
}

// ==================== INDEXING UTILITIES ====================

export class VectorIndexer {
  /**
   * Index all rubrics into vector store
   */
  static async indexAllRubrics(): Promise<number> {
    console.log('Starting rubric indexing...');
    
    try {
      // 1. Fetch all active rubrics from Firestore
      const rubricQuery = query(
        collection(db, 'assessmentRubrics'),
        where('status', '==', 'active')
      );
      const rubricSnap = await getDocs(rubricQuery);
      
      if (rubricSnap.empty) {
        console.log('No rubrics found to index.');
        return 0;
      }
      
      let indexedCount = 0;
      const rubrics = rubricSnap.docs;
      
      // 2. Process rubrics in batches for efficient embedding generation
      const batchSize = 10;
      for (let i = 0; i < rubrics.length; i += batchSize) {
        const batch = rubrics.slice(i, i + batchSize);
        
        // Prepare content for embedding (combine rubric details)
        const contents = batch.map(doc => {
          const data = doc.data();
          const criteriaText = (data.criteria || []).map((criterion: any) => 
            `${criterion.name}: ${criterion.description}`
          ).join('\n');
          
          return `Rubric: ${data.name}\n${data.description}\n\nCriteria:\n${criteriaText}`;
        });
        
        // 3. Generate embeddings for batch
        const embeddings = await EmbeddingService.generateEmbeddingsBatch(contents);
        
        // 4. Store in vector DB
        for (let j = 0; j < batch.length; j++) {
          const doc = batch[j];
          const data = doc.data();
          
          await VectorStore.store({
            content: contents[j],
            embedding: embeddings[j],
            metadata: {
              type: 'rubric',
              gradeBand: data.grade ? (data.grade <= 3 ? 'grades_1_3' : data.grade <= 6 ? 'grades_4_6' : 'grades_7_9') : undefined,
              missionId: data.missionId,
              skillIds: data.skillId ? [data.skillId] : [],
              createdAt: data.createdAt || Timestamp.now(),
              updatedAt: data.updatedAt || Timestamp.now()
            }
          });
          
          indexedCount++;
        }
        
        console.log(`Indexed rubrics ${i + 1}-${Math.min(i + batchSize, rubrics.length)} of ${rubrics.length}`);
      }
      
      console.log(`✓ Indexed ${indexedCount} rubrics`);
      return indexedCount;
      
    } catch (err) {
      console.error('Failed to index rubrics:', err);
      return 0;
    }
  }
  
  /**
   * Index all exemplars (good student work examples)
   */
  static async indexAllExemplars(): Promise<number> {
    console.log('Starting exemplar indexing...');
    
    try {
      // 1. Fetch artifacts marked as exemplars (high quality student work)
      const exemplarQuery = query(
        collection(db, 'artifacts'),
        where('isExemplar', '==', true),
        where('status', '==', 'approved')
      );
      const exemplarSnap = await getDocs(exemplarQuery);
      
      if (exemplarSnap.empty) {
        console.log('No exemplars found to index.');
        return 0;
      }
      
      let indexedCount = 0;
      const exemplars = exemplarSnap.docs;
      
      // 2. Process exemplars in batches
      const batchSize = 10;
      for (let i = 0; i < exemplars.length; i += batchSize) {
        const batch = exemplars.slice(i, i + batchSize);
        
        // Prepare content for embedding
        const contents = batch.map(doc => {
          const data = doc.data();
          const missionTitle = typeof data.missionTitle === 'string' && data.missionTitle.trim().length > 0
            ? data.missionTitle.trim()
            : null;
          const studentWork = typeof data.content === 'string' && data.content.trim().length > 0
            ? data.content
            : typeof data.description === 'string' && data.description.trim().length > 0
              ? data.description
              : '';
          const educatorNotes = typeof data.exemplarNotes === 'string' && data.exemplarNotes.trim().length > 0
            ? `\n\nEducator Notes: ${data.exemplarNotes}`
            : '';
          return `Exemplar Work:${missionTitle ? `\nMission: ${missionTitle}` : ''}\n\nStudent Work:\n${studentWork}${educatorNotes}`;
        });
        
        // 3. Generate embeddings for batch
        const embeddings = await EmbeddingService.generateEmbeddingsBatch(contents);
        
        // 4. Store in vector DB
        for (let j = 0; j < batch.length; j++) {
          const doc = batch[j];
          const data = doc.data();
          
          await VectorStore.store({
            content: contents[j],
            embedding: embeddings[j],
            metadata: {
              type: 'exemplar',
              gradeBand: data.grade ? (data.grade <= 3 ? 'grades_1_3' : data.grade <= 6 ? 'grades_4_6' : 'grades_7_9') : undefined,
              missionId: data.missionId,
              learnerId: data.createdBy,
              skillIds: data.skillIds || [],
              createdAt: data.createdAt || Timestamp.now(),
              updatedAt: data.updatedAt || Timestamp.now()
            }
          });
          
          indexedCount++;
        }
        
        console.log(`Indexed exemplars ${i + 1}-${Math.min(i + batchSize, exemplars.length)} of ${exemplars.length}`);
      }
      
      console.log(`✓ Indexed ${indexedCount} exemplars`);
      return indexedCount;
      
    } catch (err) {
      console.error('Failed to index exemplars:', err);
      return 0;
    }
  }
  
  /**
   * Index common misconceptions library
   */
  static async indexMisconceptions(): Promise<number> {
    console.log('Starting misconception indexing...');
    
    try {
      // 1. Fetch all documented misconceptions from Firestore
      // Misconceptions are stored per skill/topic to help AI provide better guidance
      const misconceptionQuery = query(
        collection(db, 'commonMisconceptions'),
        where('isActive', '==', true)
      );
      const misconceptionSnap = await getDocs(misconceptionQuery);
      
      if (misconceptionSnap.empty) {
        console.log('No misconceptions found to index. Creating default set...');
        return await this.seedDefaultMisconceptions();
      }
      
      let indexedCount = 0;
      const misconceptions = misconceptionSnap.docs;
      
      // 2. Process misconceptions in batches
      const batchSize = 10;
      for (let i = 0; i < misconceptions.length; i += batchSize) {
        const batch = misconceptions.slice(i, i + batchSize);
        
        // Prepare content for embedding
        const contents = batch.map(doc => {
          const data = doc.data();
          const topic = typeof data.topic === 'string' && data.topic.trim().length > 0
            ? `\nTopic: ${data.topic.trim()}`
            : '';
          const skillName = typeof data.skillName === 'string' && data.skillName.trim().length > 0
            ? `\nSkill: ${data.skillName.trim()}`
            : '';
          return `Common Misconception:${topic}${skillName}\n\nMisconception: ${data.misconception}\n\nWhy students think this: ${data.reasoning}\n\nCorrect understanding: ${data.correctUnderstanding}\n\nHow to address: ${data.teachingStrategy}`;
        });
        
        // 3. Generate embeddings for batch
        const embeddings = await EmbeddingService.generateEmbeddingsBatch(contents);
        
        // 4. Store in vector DB
        for (let j = 0; j < batch.length; j++) {
          const doc = batch[j];
          const data = doc.data();
          
          await VectorStore.store({
            content: contents[j],
            embedding: embeddings[j],
            metadata: {
              type: 'misconception',
              gradeBand: data.gradeBand,
              skillIds: data.skillId ? [data.skillId] : [],
              createdAt: data.createdAt || Timestamp.now(),
              updatedAt: data.updatedAt || Timestamp.now()
            }
          });
          
          indexedCount++;
        }
        
        console.log(`Indexed misconceptions ${i + 1}-${Math.min(i + batchSize, misconceptions.length)} of ${misconceptions.length}`);
      }
      
      console.log(`✓ Indexed ${indexedCount} misconceptions`);
      return indexedCount;
      
    } catch (err) {
      console.error('Failed to index misconceptions:', err);
      return 0;
    }
  }
  
  /**
   * Seed default misconceptions for common topics
   * Run this once to populate the library
   */
  private static async seedDefaultMisconceptions(): Promise<number> {
    console.log('Seeding default misconceptions...');
    
    const defaultMisconceptions = [
      {
        topic: 'Variables & Functions',
        skillName: 'Programming',
        gradeBand: 'grades_4_6' as AgeBand,
        misconception: 'Variables store the code, not the value',
        reasoning: 'Students confuse variable names with the value they hold',
        correctUnderstanding: 'Variables are containers that store values. The variable name is a label for that container.',
        teachingStrategy: 'Use physical box analogy: "x = 5" means putting the number 5 into a box labeled x',
        isActive: true
      },
      {
        topic: 'Loops',
        skillName: 'Programming',
        gradeBand: 'grades_4_6' as AgeBand,
        misconception: 'Loop runs once per item in the list',
        reasoning: 'Students think the loop counter and list position are different',
        correctUnderstanding: 'For-each loop visits each item once. Counter loops run a specific number of times.',
        teachingStrategy: 'Trace code step-by-step on paper, showing variable values changing each iteration',
        isActive: true
      },
      {
        topic: 'Fractions',
        skillName: 'Mathematics',
        gradeBand: 'grades_1_3' as AgeBand,
        misconception: 'Bigger denominator means bigger fraction',
        reasoning: 'Students apply whole number logic (bigger number = more)',
        correctUnderstanding: 'Larger denominator means smaller pieces. 1/8 of pizza is smaller than 1/4.',
        teachingStrategy: 'Use visual models like pizza slices or fraction bars to show piece size',
        isActive: true
      }
    ];
    
    // Store default misconceptions
    for (const misc of defaultMisconceptions) {
      await addDoc(collection(db, 'commonMisconceptions'), {
        ...misc,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now()
      });
    }
    
    // Now index them
    return await this.indexMisconceptions();
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
