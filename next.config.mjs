import { createRequire } from 'module';
import { dirname } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const rootDir = dirname(fileURLToPath(import.meta.url));

const withPWA = require('next-pwa');
const pwaConfig = {
  dest: 'public',
  disable: process.env.NODE_ENV === 'development',
  register: false,
  skipWaiting: true,
};

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
const nextConfig = withPWA({
  reactStrictMode: true,
  outputFileTracingRoot: rootDir,
  pwa: pwaConfig,
  turbopack: {},
});

const pwaWebpack = nextConfig.webpack;
delete nextConfig.pwa;

nextConfig.webpack = (config, options) => {
  if (!pwaWebpack) {
    return config;
  }

  return pwaWebpack(config, {
    ...options,
    config: {
      ...options.config,
      pwa: pwaConfig,
    },
  });
};

export default nextConfig;
