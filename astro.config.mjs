// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

// Seiten, die per noindex ausgenommen sind, gehören nicht in die Sitemap.
const NOINDEX = ['/danke/', '/impressum/', '/datenschutz/', '/agb/'];

export default defineConfig({
  site: 'https://ident-it.at',
  output: 'static',
  trailingSlash: 'always',
  integrations: [
    sitemap({
      filter: (page) => !NOINDEX.some((path) => page.endsWith(path)),
    }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
});
