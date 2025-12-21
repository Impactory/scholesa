import { addDoc, writeBatch, doc, Timestamp } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import { sessionsCollection, sessionOccurrencesCollection } from '@/src/firebase/firestore/collections';
import { Session, SessionOccurrence } from '@/src/types/schema';

/**
 * Creates a Session and generates weekly occurrences for a set duration.
 */
export async function createSessionWithOccurrences(
  sessionData: Omit<Session, 'id'>,
  weeksToGenerate: number = 10
) {
  // 1. Create the parent Session document
  // We cast to any here because addDoc expects the raw data, but our collection is typed.
  // The type safety comes from the input parameter.
  const sessionRef = await addDoc(sessionsCollection, sessionData as any);
  const sessionId = sessionRef.id;

  // 2. Generate Occurrences in a Batch
  const batch = writeBatch(db);
  const startDate = sessionData.startTime.toDate();
  
  for (let i = 0; i < weeksToGenerate; i++) {
    const occurrenceDate = new Date(startDate);
    occurrenceDate.setDate(startDate.getDate() + (i * 7));
    
    const occurrence: Omit<SessionOccurrence, 'id'> = {
      sessionId,
      date: Timestamp.fromDate(occurrenceDate),
      siteId: sessionData.siteId,
      roomId: sessionData.roomId || '',
      educatorId: sessionData.educatorId,
    };

    const occRef = doc(sessionOccurrencesCollection);
    batch.set(occRef, occurrence);
  }

  await batch.commit();
  return sessionId;
}