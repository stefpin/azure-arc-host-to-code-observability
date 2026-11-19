import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// base '/' because IIS serves the page from the site root (http://192.168.110.31:8080/).
// "npm run build" writes dist/, which is copied to C:\inetpub\minibank-api\wwwroot.
export default defineConfig({
  base: '/',
  plugins: [react()],
  server: {
    proxy: { '/api': 'http://localhost:8080' }, // "npm run dev" on APP-WIN: API calls go to the IIS site
  },
});
