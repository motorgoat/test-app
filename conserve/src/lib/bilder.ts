import type { ImageMetadata } from 'astro';

// Alle Bilder aus src/assets/bilder/ – Zugriff über den Dateinamen.
const bilder = import.meta.glob<{ default: ImageMetadata }>('/src/assets/bilder/*.{jpg,jpeg,png,webp,avif}', {
  eager: true,
});

const gemeldet = new Set<string>();

export function findeBild(datei?: string): ImageMetadata | undefined {
  if (!datei) return undefined;
  const bild = bilder[`/src/assets/bilder/${datei}`]?.default;
  if (!bild && !gemeldet.has(datei)) {
    gemeldet.add(datei);
    console.warn(`[Bild] src/assets/bilder/${datei} fehlt – Platzhalter wird angezeigt.`);
  }
  return bild;
}
