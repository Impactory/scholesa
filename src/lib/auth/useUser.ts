import { useAuth } from '@/context/AuthContext';
import { doc, getDoc } from 'firebase/firestore';
import { firestore } from '@/firebase/client';
import { useEffect, useState } from 'react';
import { UserProfile } from '@/types/user';

export const useUser = () => {
  const { user } = useAuth();
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUserProfile = async () => {
      if (user) {
        const docRef = doc(firestore, 'users', user.uid);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          setUserProfile(docSnap.data() as UserProfile);
        }
      }
      setLoading(false);
    };

    fetchUserProfile();
  }, [user]);

  return { user, userProfile, loading };
};
