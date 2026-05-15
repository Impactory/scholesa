import { dirname } from 'path';
import { fileURLToPath } from 'url';

const rootDir = dirname(fileURLToPath(import.meta.url));

// Safety: never allow E2E test mode in production builds
if (
  process.env.NODE_ENV === 'production' &&
  process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1'
) {
  throw new Error(
    'FATAL: NEXT_PUBLIC_E2E_TEST_MODE=1 must not be set in production builds. ' +
    'This would route all data through the in-memory fake backend.'
  );
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  outputFileTracingRoot: rootDir,
  turbopack: {},
};

export default nextConfig;
