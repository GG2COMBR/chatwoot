import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';
import { aliases, vueOptions } from './vite.shared';
import yaml from '@rollup/plugin-yaml';

export default defineConfig({
  plugins: [ruby(), vue(vueOptions), yaml()],
  server: {
    // Local Docker dev: Rails proxies to the `vite` service, so the dev
    // server receives Host: vite:3036. Vite 6 blocks unknown hosts by
    // default (DNS-rebinding protection). Allow it only in development.
    allowedHosts: true,
  },
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
      },
    },
  },
  resolve: { alias: aliases },
});
