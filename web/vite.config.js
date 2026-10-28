import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// The site is published from the repository albeasystems/amortix, so the base path is /amortix/.
export default defineConfig({
  base: process.env.BASE_PATH || '/amortix/',
  plugins: [react(), tailwindcss()],
  build: { rollupOptions: { input: 'index.html' } },
});
