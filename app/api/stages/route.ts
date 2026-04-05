import { NextResponse } from 'next/server';
import { getAdminDb } from '@/src/firebase/admin-init';

/**
 * GET /api/stages — returns the 4 seeded learning stages.
 * Public read (all authenticated users).
 */
export async function GET() {
  try {
    const db = getAdminDb();
    const snapshot = await db.collection('stages').orderBy('gradeRange').get();

    if (snapshot.empty) {
      return NextResponse.json({ stages: [], seeded: false });
    }

    const stages = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return NextResponse.json({ stages, seeded: true });
  } catch (error) {
    console.error('GET /api/stages error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch stages' },
      { status: 500 }
    );
  }
}
