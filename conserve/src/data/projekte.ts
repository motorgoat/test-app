// Projektliste – Reihenfolge hier = Reihenfolge auf der Website.
// Projekte mit `bild` erscheinen groß mit Foto, Projekte ohne Bild in der Liste „Weitere Projekte“.
// `startseite: true`  → im Slider auf der Startseite
// `galerie: 'ordner'` → eigene Projektseite mit allen Fotos aus src/assets/bilder/projekte/ordner/
//                        (Reihenfolge nach Dateiname, z. B. 01.jpg, 02.jpg …)
// `bild`: Dateiname in src/assets/bilder/

export type Projekt = {
  titel: string;
  ort?: string;
  jahr?: number;
  leistungen: string;
  text?: string;
  auftraggeber?: string;
  bild?: string;
  bildAlt?: string;
  bildText?: string; // Bildunterschrift, z. B. „Foto: Metahofschlössl, Graz“
  galerie?: string;
  startseite?: boolean;
};

export const projekte: Projekt[] = [
  {
    titel: 'Stadtpark­brunnen', // ­ = Trennstelle für schmale Karten
    ort: 'Graz',
    leistungen: 'Bauhistorische und restauratorische Untersuchung, Sanierungsplanung, ÖBA',
    text: 'Dem Restaurierungsvorhaben ging eine umfassende interdisziplinäre Bestandsaufnahme voraus.',
    bild: 'projekt-graz-stadtparkbrunnen.jpg',
    galerie: 'stadtparkbrunnen',
    startseite: true,
  },
  {
    titel: 'Pädagogische Hochschule der Diözese',
    ort: 'Linz',
    leistungen: 'Bauhistorische Untersuchung',
    bild: 'projekt-linz-paedagogische-hochschule.jpg',
    galerie: 'paedagogische-hochschule-linz',
    startseite: true,
  },
  {
    titel: 'Schloss Admontbichl',
    ort: 'Obdach',
    leistungen: 'Bauhistorische Untersuchung',
    bild: 'projekt-obdach-schloss-admontbichl.jpg',
    startseite: true,
  },
  {
    titel: 'Schloss Sauerbrunn und Sternschanze',
    ort: 'Pöls',
    leistungen: 'Bauhistorische Untersuchung',
    bild: 'projekt-poels-schloss-sauerbrunn-und-sternschanze.jpg',
    startseite: true,
  },
  {
    titel: 'Buchhaus',
    ort: 'Geistthal',
    leistungen: 'Oberflächenuntersuchung, Restaurierkonzept, Planung & ÖBA',
    bild: 'projekt-geistthal-buchhaus.jpg',
    startseite: true,
  },
  {
    titel: 'Schutzzonen von Graz – Fassaden- und Fenster\u00ADsanierungen',
    ort: 'Graz',
    leistungen: 'Dokumentation, Konzepterstellung, ÖBA',
    bild: 'projekt-graz-schutzzonen-metahofschloessl.jpg',
    bildText: 'Foto: Metahofschlössl, Graz',
    startseite: true,
  },
  {
    titel: 'NS-Siedlung Münichholz',
    ort: 'Steyr',
    leistungen: 'Ortsbildanalyse nach bauhistorischen Kriterien',
    bild: 'projekt-steyr-ns-siedlung-muenichholz.jpg',
  },
  {
    titel: 'Hauptplatz 9',
    ort: 'Bad Radkersburg',
    leistungen: 'Bauhistorische Untersuchung',
    bild: 'projekt-bad-radkersburg-hauptplatz-9.jpg',
  },
  {
    titel: 'Wöllbachmühle',
    leistungen: 'Abbruchdokumentation',
    bild: 'projekt-woellbachmuehle.jpg',
    galerie: 'woellbachmuehle',
  },

  // --- Weitere Projekte (ohne Foto) ---
  {
    titel: 'Stadtplatz 38',
    ort: 'Vöcklabruck',
    jahr: 2026,
    leistungen: 'Bauhistorische Untersuchung',
    auftraggeber: 's_arquitex Schreder & Partner ZT GmbH',
  },
  {
    titel: 'Palais Welsersheimb',
    ort: 'Graz',
    jahr: 2023,
    leistungen: 'Fassadenuntersuchung & Maßnahmenkatalog',
    auftraggeber: 'City Immobilien Invest GmbH',
  },
  { titel: 'Palais Herberstein', ort: 'Graz', leistungen: 'Fensterrenovierung, örtliche Bauaufsicht' },
  { titel: 'Waagplatz 2', ort: 'Klagenfurt', leistungen: 'Bauhistorische Untersuchung' },
  { titel: 'Kreuzkapelle', ort: 'Gamlitz', leistungen: 'Bauhistorische Untersuchung' },
  { titel: 'Heinrichstraße 61', ort: 'Graz', leistungen: 'Bauforschung' },
  { titel: 'Murgasse 12', ort: 'Bad Radkersburg', leistungen: 'Bauforschung' },
];

// Adresse der Projektseite, z. B. /projekte/stadtparkbrunnen-graz/
export const projektSlug = (p: Projekt) =>
  [p.titel, p.ort]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()
    .replace(/­/g, '')
    .replace(/ä/g, 'ae')
    .replace(/ö/g, 'oe')
    .replace(/ü/g, 'ue')
    .replace(/ß/g, 'ss')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

export const projektLink = (p: Projekt) => (p.galerie ? `/projekte/${projektSlug(p)}/` : undefined);
