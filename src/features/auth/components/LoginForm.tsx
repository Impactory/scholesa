'use client';

import { useState } from 'react';
import { Button } from '@/src/components/ui/Button';
import { Input } from '@/src/components/ui/Input';
import { useAuth } from '@/src/firebase/auth/useAuth';
import { useRouter, useParams } from 'next/navigation';

export function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { signInWithGoogle } = useAuth();
  const router = useRouter();
  const params = useParams();
  const locale = params.locale as string || 'en';

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    console.log('Email/password login not fully implemented yet, use Google Sign-In');
  };

  const handleGoogleSignIn = async () => {
    try {
      await signInWithGoogle();
      router.push(`/${locale}/dashboard`);
    } catch (error) {
      console.error('Login failed', error);
    }
  };

  return (
    <div className='flex min-h-screen flex-col justify-center bg-gray-50 py-12 sm:px-6 lg:px-8'>
      <div className='sm:mx-auto sm:w-full sm:max-w-md'>
        <h2 className='mt-6 text-center text-3xl font-extrabold text-gray-900'>Sign in to your account</h2>
      </div>

      <div className='mt-8 sm:mx-auto sm:w-full sm:max-w-md'>
        <div className='bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10'>
          <form className='space-y-6' onSubmit={handleSubmit}>
            <Input
              id='email'
              label='Email address'
              type='email'
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
            <Input
              id='password'
              label='Password'
              type='password'
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />

            <div>
              <Button type='submit' className='w-full'>
                Sign in
              </Button>
            </div>
          </form>

          <div className='mt-6'>
            <div className='relative'>
              <div className='absolute inset-0 flex items-center'>
                <div className='w-full border-t border-gray-300' />
              </div>
              <div className='relative flex justify-center text-sm'>
                <span className='bg-white px-2 text-gray-500'>Or continue with</span>
              </div>
            </div>

            <div className='mt-6'>
               <Button onClick={handleGoogleSignIn} className='w-full' variant='outline'>
                Google
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
