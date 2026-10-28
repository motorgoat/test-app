import type { ImageMetadata } from 'astro';

// Alle Bilder aus src/assets/bilder/ (auch Unterordner). Gesucht wird nach dem Pfad
// ohne Endung und ohne Groß-/Kleinschreibung: "hero-startseite.jpg" findet also auch
// "Hero-Startseite.PNG", "team/wonisch.jpg" die Datei "team/Wonisch.webp".
const dateien = import.meta.glob<{ default: ImageMetadata }>(
  '/src/assets/bilder/**/*.{[jJ][pP][gG],[jJ][pP][eE][gG],[pP][nN][gG],[wW][eE][bB][pP],[aA][vV][iI][fF]}',
  { eager: true },
);

const schluessel = (pfad: string) =>
  pfad
    .replace(/^\/?src\/assets\/bilder\//, '')
    .replace(/\.[^./]+$/, '')
    .toLowerCase();

const bilder = new Map<string, ImageMetadata>();
for (const [pfad, modul] of Object.entries(dateien)) {
  const key = schluessel(pfad);
  if (bilder.has(key)) {
    console.warn(`[Bild] "${key}" gibt es mehrfach (unterschiedliche Endung) – bitte die alte Datei löschen.`);
  }
  bilder.set(key, modul.default);
}

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

// Galerie: alle Bilder aus src/assets/bilder/projekte/<ordner>/, sortiert nach Dateiname
export function findeGalerie(ordner: string): ImageMetadata[] {
  const praefix = `projekte/${ordner.toLowerCase()}/`;
  const bilderImOrdner = [...bilder.entries()]
    .filter(([key]) => key.startsWith(praefix) && !key.slice(praefix.length).includes('/'))
    .sort(([a], [b]) => a.localeCompare(b, 'de', { numeric: true }))
    .map(([, bild]) => bild);
  if (!bilderImOrdner.length) console.warn(`[Galerie] src/assets/bilder/projekte/${ordner}/ ist leer oder fehlt.`);
  return bilderImOrdner;
}
