// Projektliste – Reihenfolge hier = Reihenfolge auf der Website.
// `startseite: true` zeigt das Projekt im Slider auf der Startseite.
// `bild`: Dateiname in src/assets/bilder/ (leer = Platzhalter).

export type Projekt = {
  titel: string;
  ort: string;
  jahr?: number;
  leistungen: string;
  text?: string;
  auftraggeber?: string;
  bild?: string;
  bildAlt?: string;
  startseite?: boolean;
};

export const projekte: Projekt[] = [
  {
    titel: 'Stadtparkbrunnen',
    ort: 'Graz',
    bild: 'projekt-graz-stadtparkbrunnen.jpg',
    leistungen: 'Befundung, Planung, ÖBA',
    text: 'Dem Restaurierungsvorhaben ging eine umfassende interdisziplinäre Bestandsaufnahme voraus.',
    startseite: true,
  },
  {
    titel: 'Schloss Sauerbrunn und Sternschanze',
    ort: 'Pöls',
    bild: 'projekt-poels-schloss-sauerbrunn-und-sternschanze.jpg',
    leistungen: 'Bauhistorische Untersuchung, Archiv- und Literaturrecherche',
    startseite: true,
  },
  {
    titel: 'Stadtplatz 38',
    ort: 'Vöcklabruck',
    bild: 'projekt-voecklabruck-stadtplatz-38.jpg',
    jahr: 2026,
    leistungen: 'Bauhistorische Untersuchung',
    auftraggeber: 's_arquitex Schreder & Partner ZT GmbH',
    startseite: true,
  },
  {
    titel: 'Palais Welsersheimb',
    ort: 'Graz',
    bild: 'projekt-graz-palais-welsersheimb.jpg',
    jahr: 2023,
    leistungen: 'Fassadenuntersuchung & Maßnahmenkatalog',
    auftraggeber: 'City Immobilien Invest GmbH',
    startseite: true,
  },
  {
    titel: 'Schloss Admontbichl',
    ort: 'Obdach',
    bild: 'projekt-obdach-schloss-admontbichl.jpg',
    leistungen: 'Bauforschung',
    startseite: true,
  },
  {
    titel: 'Palais Herberstein',
    ort: 'Graz',
    bild: 'projekt-graz-palais-herberstein.jpg',
    leistungen: 'Fensterrenovierung, örtliche Bauaufsicht',
    startseite: true,
  },
  {
    titel: 'Waagplatz 2',
    ort: 'Klagenfurt',
    bild: 'projekt-klagenfurt-waagplatz-2.jpg',
    leistungen: 'Bauhistorische Untersuchung',
  },
  {
    titel: 'Kreuzkapelle',
    ort: 'Gamlitz',
    bild: 'projekt-gamlitz-kreuzkapelle.jpg',
    leistungen: 'Bauhistorische Untersuchung',
  },
  {
    titel: 'Heinrichstraße 61',
    ort: 'Graz',
    bild: 'projekt-graz-heinrichstrasse-61.jpg',
    leistungen: 'Bauforschung',
  },
  {
    titel: 'Buchhaus',
    ort: 'Geistthal',
    bild: 'projekt-geistthal-buchhaus.jpg',
    leistungen: 'Bauforschung',
  },
  {
    titel: 'Murgasse 12',
    ort: 'Bad Radkersburg',
    bild: 'projekt-bad-radkersburg-murgasse-12.jpg',
    leistungen: 'Bauforschung',
  },
];
