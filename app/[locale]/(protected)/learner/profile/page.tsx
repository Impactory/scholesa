import { Metadata } from 'next';
import { StudentMotivationProfile } from '@/src/components/motivation/StudentMotivationProfile';

export const metadata: Metadata = {
  title: 'My Learning Profile | Scholesa',
  description: 'Your motivation, skills, and learning journey'
};

export default function LearnerProfilePage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <StudentMotivationProfile />
    </div>
  );
}
