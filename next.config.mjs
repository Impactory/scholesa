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
