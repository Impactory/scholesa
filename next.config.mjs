import { createRequire } from 'module';
const require = createRequire(import.meta.url);

const withPWA = require('next-pwa');

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  eslint: {
    ignoreDuringBuilds: true,
  },
  pwa: {
    dest: 'public',
    disable: process.env.NODE_ENV === 'development',
    register: false,
    skipWaiting: true,
  },

  // Add other Next.js configurations here
};

export default withPWA(nextConfig);
