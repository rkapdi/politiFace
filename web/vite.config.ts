/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// base './' + hash routing: the app works unchanged under
// rkapdi.github.io/politiFace/app/ today and politiface.app/app/ later.
export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  define: {
    __APP_BUILD__: JSON.stringify(`web-${new Date().toISOString().slice(0, 10)}`),
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test-setup.ts'],
  },
})
