import type { ImageMetadata } from 'astro';

// Alle Bilder aus src/assets/bilder/. Gesucht wird nur nach dem Dateinamen ohne
// Endung und ohne Groß-/Kleinschreibung: "hero-startseite.jpg" findet also auch
// "Hero-Startseite.PNG" oder "hero-startseite.webp".
const dateien = import.meta.glob<{ default: ImageMetadata }>(
  '/src/assets/bilder/*.{[jJ][pP][gG],[jJ][pP][eE][gG],[pP][nN][gG],[wW][eE][bB][pP],[aA][vV][iI][fF]}',
  { eager: true },
);

const schluessel = (pfad: string) =>
  (pfad.split('/').pop() ?? '').replace(/\.[^.]+$/, '').toLowerCase();

const bilder = new Map(Object.entries(dateien).map(([pfad, modul]) => [schluessel(pfad), modul.default]));

const gemeldet = new Set<string>();

export function findeBild(datei?: string, optional = false): ImageMetadata | undefined {
  if (!datei) return undefined;
  const bild = bilder.get(schluessel(datei));
  if (!bild && !optional && !gemeldet.has(datei)) {
    gemeldet.add(datei);
    console.warn(`[Bild] src/assets/bilder/${datei} fehlt – Platzhalter wird angezeigt.`);
  }
  return bild;
}
