// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://www.conserve.at',
  // alle Seiten liegen als ordner/index.html vor – interne Links daher mit / am Ende
  trailingSlash: 'always',
  integrations: [sitemap()],
});
