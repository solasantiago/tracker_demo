import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Se publica en https://solasantiago.github.io/tracker/
export default defineConfig({
  base: '/tracker/',
  plugins: [react()],
});
