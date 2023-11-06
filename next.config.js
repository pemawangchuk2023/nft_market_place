/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  env: {
    ALCHEMY_API_KEY: process.env.ALCHEMY_API_KEY,
    WEB_3_STORAGE_KEY: process.env.WEB_3_STORAGE_KEY,
  },
  images: {
    domains: ['ipfs.dweb.link', 'ipfs.w3s.link'],
  },
};

module.exports = nextConfig;
