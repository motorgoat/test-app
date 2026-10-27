import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const projekte = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projekte' }),
  schema: ({ image }) =>
    z.object({
      title: z.string(),
      ort: z.string(),
      jahr: z.number().int().optional(),
      leistung: z.string(),
      kategorie: z.enum(['Bauforschung', 'Sanierung', 'ÖBA', 'Energieberatung']),
      auftraggeber: z.string().optional(),
      bild: image().optional(),
      bildAlt: z.string().optional(),
      featured: z.boolean().default(false),
      // Reihenfolge innerhalb gleicher Jahre (kleiner = weiter oben)
      order: z.number().default(100),
    }),
});

export const collections = { projekte };
