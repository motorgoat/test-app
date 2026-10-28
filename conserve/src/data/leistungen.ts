// Leistungsbereiche – erscheinen auf der Startseite und auf /leistungen.
// `bild`: Dateiname in src/assets/bilder/ (leer = Platzhalter).

export type Leistungsbereich = {
  id: string;
  title: string;
  intro: string;
  items: string[];
  bild?: string;
  bildAlt?: string; // was auf dem Foto zu sehen ist (leer = dekorativ)
};

export const leistungen: Leistungsbereich[] = [
  {
    id: 'dokumentation-beratung',
    bild: 'leistung-dokumentation-beratung.jpg',
    title: 'Dokumentation & Beratung',
    intro:
      'Am Anfang steht ein genaues Bild des Bestands. Wir dokumentieren, beraten unabhängig und entwickeln Konzepte, die Substanz und Nutzung zusammenbringen.',
    items: [
      'Individuelle Energieberatung',
      'Restaurierungs- und Sanierungskonzepte (gemeinsam mit qualifizierten und produktunabhängigen Fachpersonen)',
      'Fensterkataloge, Bestandsaufnahme, Raumbücher',
      'Unterstützung bei Förderanträgen',
    ],
  },
  {
    id: 'bauforschung',
    bild: 'leistung-bauforschung.jpg',
    title: 'Bauforschung',
    intro:
      'Die Bauforschung macht die Geschichte eines Gebäudes lesbar – und schafft so die Grundlage für jede denkmalgerechte Entscheidung.',
    items: [
      'Bauhistorische Untersuchungen gemäß den aktuellen Richtlinien des Bundesdenkmalamtes',
      'Bauhistorische Bestandsaufnahme, Sondierungen, Erfassung von Oberflächenschichten (Fassungstreppen, Putze etc.)',
      'Materialanalysen, mikroskopische Untersuchungen, Feinschliffe, begleitende Dendrochronologie',
      'Archiv- und Literaturrecherchen',
      'Raumbücher, Fassadenbuch, Gespärrebuch',
      'Gesamtauswertung, Befunddokumentationen, Berichterstellung',
      'Baualterpläne',
    ],
  },
  {
    id: 'altbausanierung',
    bild: 'leistung-altbausanierung.jpg',
    title: 'Altbausanierung',
    intro:
      'Als Baumeister- und Planungsbüro begleiten wir Sanierungen von der Planung über die Einreichung bis zur örtlichen Bauaufsicht.',
    items: [
      'Sanierungsplanung (Fassaden, Fenster, thermische Sanierung etc.)',
      'Einreichung bei Baubehörde, ASVK und BDA',
      'Ausschreibungen, Leistungsverzeichnisse, Angebotskontrolle',
      'Örtliche Bauaufsicht, Kostenverfolgung, Qualitätskontrolle, Rechnungsprüfung',
    ],
  },
];
