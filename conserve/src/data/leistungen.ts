// Leistungsbereiche laut Firmenpräsentation (September 2026) – erscheinen auf der
// Startseite (jeweils die ersten `startseite` Punkte) und vollständig auf /leistungen/.
// `bild`: Dateiname in src/assets/bilder/.

export type Leistungsbereich = {
  id: string;
  title: string;
  intro: string;
  items: string[];
  startseite?: number; // wie viele Punkte auf der Startseite (Standard: 4)
  bild?: string;
  bildAlt?: string; // was auf dem Foto zu sehen ist (leer = dekorativ)
};

export const leistungen: Leistungsbereich[] = [
  {
    id: 'bauforschung',
    title: 'Bauforschung',
    bild: 'leistung-bauforschung.jpg',
    intro:
      'Die Bauforschung macht die Geschichte eines Gebäudes lesbar – und schafft so die Grundlage für jede denkmalgerechte Entscheidung.',
    items: [
      'Bauhistorische Untersuchungen gemäß den aktuellen Richtlinien des Bundesdenkmalamtes',
      'Bauhistorische Bestandsaufnahme, Sondierungen, Erfassung von Oberflächenschichten (Fassungstreppen, Putzschichten etc.)',
      'Kooperation mit Fachfirmen für Materialanalysen, mikroskopische Untersuchungen, Feinschliffe, Dendrochronologie',
      'Archiv- und Literaturrecherchen',
      'Raumbuch, Fassadenbuch, Gespärrebuch',
      'Gesamtauswertung',
      'Befunddokumentation',
      'Berichterstellung',
      'Baualterpläne',
    ],
  },
  {
    id: 'gebaeudedokumentation',
    title: 'Gebäude\u00ADdokumentation & Gutachten', // \u00AD = Trennstelle
    bild: 'leistung-gebaeudedokumentation.jpg',
    intro:
      'Wir erfassen und bewerten den Bestand – von der Schutzwürdigkeit des Gesamtobjekts bis zum einzelnen Bauteil und seinen Schäden.',
    items: [
      'Bestandsaufnahmen',
      'Raumbücher',
      'Bewertung der Schutzwürdigkeit des Gesamtobjekts',
      'Entwicklungsgeschichtliche Einordnung hochwertiger Bauteile',
      'Dokumentation gestalterischer Details der Altbausubstanz',
      'Zustandsdokumentation mit Schadensanalysen (Feuchtigkeit, Materialverfall, Risse und andere Gebrechen)',
      'Ursachenanalysen (z. B. Feuchteeintrag, statische Probleme)',
      'Abbruchdokumentation',
      'Fensterkataloge',
    ],
  },
  {
    id: 'fachbegleitung',
    title: 'Fachbegleitung im Denkmalschutz',
    bild: 'leistung-fachbegleitung.jpg',
    intro:
      'Von der Musterfläche bis zur Einreichung: Wir entwickeln Konzepte und Planungen, die Substanz erhalten und Nutzung ermöglichen.',
    items: [
      'Restaurierungs- und Sanierungskonzepte (gemeinsam mit qualifizierten und produktunabhängigen Fachpersonen)',
      'Sanierungsplanung (Fassaden, Fenster, thermische Sanierung etc.)',
      'Maßnahmenkonzepte',
      'Einreichung bei Baubehörde, ASVK, BDA, Förderungen',
      'Fachbegleitung Musterflächenerstellung',
      'Bauteilsicherungen (vor Absturz oder Verlust)',
      'Kostenschätzungen für Altbausanierungen',
      'Leistungsverzeichnisse für besondere handwerkliche Anforderungen',
      'Angebotsvergleiche',
      'Individuelle Energieberatung',
    ],
  },
  {
    id: 'altbausanierung',
    title: 'Altbausanierung (ÖBA)',
    bild: 'leistung-altbausanierung.jpg',
    intro:
      'Wir begleiten die Ausführung auf der Baustelle – mit Blick auf historische Bautechniken, Materialien und Kosten.',
    items: [
      'Örtliche Bauaufsicht und fachliche Beratung bei denkmalgeschützten Objekten und hochwertigen Altbausanierungen',
      'Begleitung der Maßnahmen unter Berücksichtigung von Bauwerkstechniken, Materialien und deren spezifischer Verarbeitung',
      'Qualitätskontrolle bei der baulichen Umsetzung mit Fokus auf denkmalgerechte Materialanwendungen',
      'Kostenverfolgung, Rechnungsprüfung',
    ],
  },
];
