/**
 * Rubric Manager - Store Assessment Rubrics as Versioned Configs
 *
 * @deprecated Legacy rubric system reading from `assessmentRubrics` collection.
 * New rubrics are created by Admin-HQ via CapabilityFrameworkEditor and stored
 * in the `rubricTemplates` collection. The EducatorEvidenceReviewRenderer reads
 * HQ rubricTemplates first and falls back to this system for unmigrated sites.
 *
 * Migration path: once all sites have HQ rubric templates, remove this file,
 * the `assessmentRubrics` Firestore rules, and the seedFirestore.js seeding.
 *
 * CRITICAL: Rubrics are YOUR intelligence, not the model's.
 * Store them in your DB so you can:
 * - Iterate on quality without retraining
 * - Version track for experiments
 * - Audit which rubric version was used for each assessment
 * - Compare student performance across rubric versions
 *
 * Pattern: Store rich rubric in DB → Fetch in retrieval → Pass to model as context
 */

import { db } from '@/src/firebase/client-init';
import { collection, doc, getDoc, getDocs, addDoc, updateDoc, query, where, orderBy, limit, Timestamp } from 'firebase/firestore';

// Firestore collection
const RUBRICS_COLLECTION = 'assessmentRubrics';

/**
 * Assessment Rubric (YOUR knowledge, not the LLM's)
 */
export interface AssessmentRubric {
  id?: string;
  
  // Metadata
  name: string;
  description: string;
  version: number;
  status: 'draft' | 'active' | 'archived';
  
  // Scope
  siteId: string; // Site-specific or global ('*')
  grade?: number; // Grade-specific or all grades (undefined)
  skillId?: string; // Skill-specific or all skills (undefined)
  missionId?: string; // Mission-specific
  pillarId?: string; // Pillar-specific
  
  // Rubric structure
  criteria: RubricCriterion[];
  
  // Ownership & versioning
  createdBy: string; // Educator ID
  createdAt: Timestamp;
  updatedBy?: string;
  updatedAt?: Timestamp;
  
  // Tags for retrieval
  tags: string[];
}

/**
 * Rubric criterion (e.g., "Code Quality", "Critical Thinking")
 */
export interface RubricCriterion {
  name: string;
  description: string;
  weight: number; // 0-1 (all should sum to 1)
  levels: RubricLevel[];
}

/**
 * Performance level (e.g., "Emerging", "Proficient", "Advanced")
 */
export interface RubricLevel {
  name: string; // "Emerging" | "Proficient" | "Advanced"
  description: string; // What this level looks like
  exemplars?: string[]; // Example student work IDs
  commonMistakes?: string[]; // What NOT to do
  score: number; // Numeric score (e.g., 1, 2, 3)
}

/**
 * Service for managing assessment rubrics
 */
export class RubricManager {
  /**
   * Create a new rubric
   */
  static async createRubric(rubric: Omit<AssessmentRubric, 'id' | 'createdAt' | 'version'>): Promise<string> {
    const rubricData = {
      ...rubric,
      version: 1,
      createdAt: Timestamp.now()
    };
    
    const docRef = await addDoc(collection(db, RUBRICS_COLLECTION), rubricData);
    return docRef.id;
  }
  
  /**
   * Get a specific rubric by ID
   */
  static async getRubric(rubricId: string): Promise<AssessmentRubric | null> {
    const docRef = doc(db, RUBRICS_COLLECTION, rubricId);
    const docSnap = await getDoc(docRef);
    
    if (!docSnap.exists()) return null;
    
    return {
      id: docSnap.id,
      ...docSnap.data()
    } as AssessmentRubric;
  }
  
  /**
   * Get the active rubric for a specific context
   * Priority: mission > skill > pillar > grade > site > global
   */
  static async getActiveRubric(context: {
    siteId: string;
    grade?: number;
    skillId?: string;
    missionId?: string;
    pillarId?: string;
  }): Promise<AssessmentRubric | null> {
    const { siteId, grade, skillId, missionId, pillarId } = context;
    
    // Try mission-specific first (most specific)
    if (missionId) {
      const missionRubric = await this.findActiveRubric({ siteId, missionId });
      if (missionRubric) return missionRubric;
    }
    
    // Try skill-specific
    if (skillId) {
      const skillRubric = await this.findActiveRubric({ siteId, skillId });
      if (skillRubric) return skillRubric;
    }
    
    // Try pillar-specific
    if (pillarId) {
      const pillarRubric = await this.findActiveRubric({ siteId, pillarId });
      if (pillarRubric) return pillarRubric;
    }
    
    // Try grade-specific
    if (grade !== undefined) {
      const gradeRubric = await this.findActiveRubric({ siteId, grade });
      if (gradeRubric) return gradeRubric;
    }
    
    // Try site-specific
    const siteRubric = await this.findActiveRubric({ siteId });
    if (siteRubric) return siteRubric;
    
    // Fallback to global
    const globalRubric = await this.findActiveRubric({ siteId: '*' });
    return globalRubric;
  }
  
  /**
   * Find active rubric matching criteria
   */
  private static async findActiveRubric(filters: Partial<{
    siteId: string;
    grade: number;
    skillId: string;
    missionId: string;
    pillarId: string;
  }>): Promise<AssessmentRubric | null> {
    let q = query(
      collection(db, RUBRICS_COLLECTION),
      where('status', '==', 'active')
    );
    
    // Add filters
    if (filters.siteId) q = query(q, where('siteId', '==', filters.siteId));
    if (filters.grade !== undefined) q = query(q, where('grade', '==', filters.grade));
    if (filters.skillId) q = query(q, where('skillId', '==', filters.skillId));
    if (filters.missionId) q = query(q, where('missionId', '==', filters.missionId));
    if (filters.pillarId) q = query(q, where('pillarId', '==', filters.pillarId));
    
    // Get latest version
    q = query(q, orderBy('version', 'desc'), limit(1));
    
    const snapshot = await getDocs(q);
    if (snapshot.empty) return null;
    
    const doc = snapshot.docs[0];
    return {
      id: doc.id,
      ...doc.data()
    } as AssessmentRubric;
  }
  
  /**
   * Update rubric (creates new version)
   */
  static async updateRubric(
    rubricId: string,
    updates: Partial<Omit<AssessmentRubric, 'id' | 'version' | 'createdAt' | 'createdBy'>>,
    updatedBy: string
  ): Promise<void> {
    const existing = await this.getRubric(rubricId);
    if (!existing) throw new Error(`Rubric ${rubricId} not found`);
    
    const docRef = doc(db, RUBRICS_COLLECTION, rubricId);
    await updateDoc(docRef, {
      ...updates,
      version: existing.version + 1,
      updatedBy,
      updatedAt: Timestamp.now()
    });
  }
  
  /**
   * Archive a rubric (soft delete)
   */
  static async archiveRubric(rubricId: string, archivedBy: string): Promise<void> {
    const docRef = doc(db, RUBRICS_COLLECTION, rubricId);
    await updateDoc(docRef, {
      status: 'archived',
      updatedBy: archivedBy,
      updatedAt: Timestamp.now()
    });
  }
  
  /**
   * List all rubrics for a site
   */
  static async listRubrics(siteId: string, includeArchived = false): Promise<AssessmentRubric[]> {
    let q = query(collection(db, RUBRICS_COLLECTION), where('siteId', '==', siteId));
    
    if (!includeArchived) {
      q = query(q, where('status', 'in', ['draft', 'active']));
    }
    
    q = query(q, orderBy('createdAt', 'desc'));
    
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as AssessmentRubric));
  }
  
  /**
   * Format rubric for model context (what the LLM sees)
   */
  static formatForContext(rubric: AssessmentRubric): string {
    let formatted = `# ${rubric.name}\n\n`;
    formatted += `${rubric.description}\n\n`;
    
    rubric.criteria.forEach((criterion) => {
      formatted += `## ${criterion.name} (Weight: ${criterion.weight * 100}%)\n`;
      formatted += `${criterion.description}\n\n`;
      
      criterion.levels.forEach((level) => {
        formatted += `### ${level.name} (Score: ${level.score})\n`;
        formatted += `${level.description}\n`;
        
        if (level.commonMistakes && level.commonMistakes.length > 0) {
          formatted += `**Common mistakes at this level:**\n`;
          level.commonMistakes.forEach(mistake => {
            formatted += `- ${mistake}\n`;
          });
        }
        formatted += '\n';
      });
    });
    
    return formatted;
  }
}

/**
 * Convenience function: Get rubric for mission
 */
export async function getRubricForMission(
  siteId: string,
  missionId: string,
  grade: number,
  skillId?: string
): Promise<AssessmentRubric | null> {
  return RubricManager.getActiveRubric({
    siteId,
    missionId,
    grade,
    skillId
  });
}

/**
 * Convenience function: Format rubric as markdown for AI context
 */
export function formatRubricForAI(rubric: AssessmentRubric): string {
  return RubricManager.formatForContext(rubric);
}
