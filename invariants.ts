import { doc, getDoc } from 'firebase/firestore';
import {
  sessionsCollection,
  missionsCollection,
  usersCollection,
  programsCollection,
  coursesCollection,
  sitesCollection
} from '@/src/firebase/firestore/collections';
import { UserRole } from '@/src/types/schema';

/**
 * Verifies that a referenced Session exists.
 */
export async function verifySessionId(sessionId: string): Promise<void> {
  const snap = await getDoc(doc(sessionsCollection, sessionId));
  if (!snap.exists()) {
    throw new Error(`Invariant Violation: Session ${sessionId} does not exist.`);
  }
}

/**
 * Verifies that a referenced Mission exists.
 */
export async function verifyMissionId(missionId: string): Promise<void> {
  const snap = await getDoc(doc(missionsCollection, missionId));
  if (!snap.exists()) {
    throw new Error(`Invariant Violation: Mission ${missionId} does not exist.`);
  }
}

/**
 * Verifies that a referenced User exists and optionally checks their role.
 */
export async function verifyUserId(userId: string, requiredRole?: UserRole): Promise<void> {
  const snap = await getDoc(doc(usersCollection, userId));
  if (!snap.exists()) {
    throw new Error(`Invariant Violation: User ${userId} does not exist.`);
  }
  if (requiredRole) {
    const data = snap.data();
    if (data?.role !== requiredRole) {
      throw new Error(`Invariant Violation: User ${userId} is not a ${requiredRole}.`);
    }
  }
}

/**
 * Verifies hierarchy for Enrollment: Program -> Course
 */
export async function verifyProgramAndCourse(programId: string, courseId: string): Promise<void> {
  const pSnap = await getDoc(doc(programsCollection, programId));
  if (!pSnap.exists()) throw new Error(`Invariant Violation: Program ${programId} does not exist.`);
  
  const cSnap = await getDoc(doc(coursesCollection, courseId));
  if (!cSnap.exists()) throw new Error(`Invariant Violation: Course ${courseId} does not exist.`);
  
  if (cSnap.data()?.programId !== programId) {
    throw new Error(`Invariant Violation: Course ${courseId} does not belong to Program ${programId}.`);
  }
}

/**
 * Verifies Site existence.
 */
export async function verifySiteId(siteId: string): Promise<void> {
  const snap = await getDoc(doc(sitesCollection, siteId));
  if (!snap.exists()) {
    throw new Error(`Invariant Violation: Site ${siteId} does not exist.`);
  }
}