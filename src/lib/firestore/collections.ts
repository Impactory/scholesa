import { collection } from 'firebase/firestore';
import { firestore } from '@/firebase/client';

export const usersCollection = collection(firestore, 'users');
export const programsCollection = collection(firestore, 'programs');
export const coursesCollection = collection(firestore, 'courses');
export const missionsCollection = collection(firestore, 'missions');
export const enrolmentsCollection = collection(firestore, 'enrolments');
export const attendanceCollection = collection(firestore, 'attendance');
export const reflectionsCollection = collection(firestore, 'reflections');
export const alertsCollection = collection(firestore, 'alerts');
export const announcementsCollection = collection(firestore, 'announcements');
