import { collection } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';

// Define the collections
export const usersCollection = collection(db, 'users');

// Add other collections as needed
export const programsCollection = collection(db, 'programs');
export const enrolmentsCollection = collection(db, 'enrolments');
export const attendanceCollection = collection(db, 'attendance');
