import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig, loadEnv } from 'vite'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const configDirectory = dirname(fileURLToPath(import.meta.url))

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, configDirectory, 'VITE_')
  const apiBaseUrl = new URL(env.VITE_FINANCE_AI_API_BASE_URL || 'http://127.0.0.1:8000')
  if (!['http:', 'https:'].includes(apiBaseUrl.protocol) || apiBaseUrl.username || apiBaseUrl.password) {
    throw new Error('VITE_FINANCE_AI_API_BASE_URL must be an HTTP(S) origin without credentials.')
  }
  if (apiBaseUrl.pathname !== '/' || apiBaseUrl.search || apiBaseUrl.hash) {
    throw new Error('VITE_FINANCE_AI_API_BASE_URL must contain only the backend origin.')
  }

  return {
    plugins: [react(), tailwindcss()],
    server: {
      watch: {
        ignored: [resolve(configDirectory, 'staff-web')],
      },
      proxy: {
        '/api': {
          target: apiBaseUrl.origin,
          changeOrigin: true,
        },
      },
    },
  }
})
