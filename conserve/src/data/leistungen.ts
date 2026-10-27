// Leistungsbereiche laut bestehender Website conserve.at.

export type Leistung = {
  id: string;
  title: string;
  short: string;
  points: string[];
};

export const leistungen: Leistung[] = [
  {
    id: 'bauforschung',
    title: 'Bauforschung',
    short:
      'Bauhistorische Untersuchungen als Grundlage für jeden verantwortungsvollen Umgang mit historischer Bausubstanz.',
    points: [
      'Bauhistorische Untersuchungen nach den Richtlinien des Bundesdenkmalamts',
      'Materialanalysen und Dendrochronologie',
      'Archiv- und Literaturrecherchen',
      'Fassadenuntersuchungen und Maßnahmenkataloge',
    ],
  },
  {
    id: 'bestandsaufnahme',
    title: 'Bestandsaufnahme',
    short:
      'Genaue Erfassung und Dokumentation des Bestands – vom Gesamtgebäude bis zum einzelnen Bauteil.',
    points: ['Bestandsaufnahmen', 'Fensterkataloge'],
  },
  {
    id: 'konzepte',
    title: 'Restaurier- & Sanierungskonzepte',
    short:
      'Konzepte, die Substanz erhalten und Nutzung ermöglichen – gemeinsam mit unabhängigen Fachpersonen erarbeitet.',
    points: [
      'Restaurierkonzepte',
      'Sanierungskonzepte für Altbauten',
      'Fensterrenovierung',
    ],
  },
  {
    id: 'energieberatung',
    title: 'Energieberatung',
    short:
      'Produktunabhängige Energieberatung, abgestimmt auf die Anforderungen historischer Gebäude.',
    points: ['Produktunabhängige Beratung', 'Energieberatung im Altbau und Denkmal'],
  },
  {
    id: 'planung',
    title: 'Planung & Ausschreibung',
    short:
      'Als Baumeisterunternehmen planen und kalkulieren wir Sanierungen und bereiten die Vergabe vor.',
    points: ['Planung', 'Ausschreibungen und Leistungsverzeichnisse', 'Angebotskontrolle'],
  },
  {
    id: 'oeba',
    title: 'Örtliche Bauaufsicht',
    short: 'Begleitung der Ausführung bis zur Fertigstellung – mit Blick auf Qualität und Kosten.',
    points: ['Örtliche Bauaufsicht (ÖBA)', 'Kostenverfolgung', 'Qualitätskontrolle', 'Rechnungsprüfung'],
  },
];
