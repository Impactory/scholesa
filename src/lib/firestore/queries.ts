import { query, where, getDocs, orderBy, limit } from 'firebase/firestore';
import { 
  usersCollection, 
  programsCollection, 
  enrolmentsCollection, 
  attendanceCollection 
} from './collections';

export const getUsersByRole = async (role: string) => {
  const q = query(usersCollection, where('role', '==', role));
  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const getActivePrograms = async (studioId: string) => {
  const q = query(
    programsCollection, 
    where('studioId', '==', studioId), 
    where('active', '==', true)
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const getStudentEnrolments = async (userId: string) => {
  const q = query(enrolmentsCollection, where('userId', '==', userId));
  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const getRecentAttendance = async (studioId: string, limitCount = 10) => {
  const q = query(
    attendanceCollection, 
    where('studioId', '==', studioId),
    orderBy('date', 'desc'),
    limit(limitCount)
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};
