import { collection } from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';

// Define the collections
export const usersCollection = collection(firestore, 'users');

// Add other collections as needed
