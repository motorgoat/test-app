// Firmen- und Kontaktdaten – werden in Header, Footer, Kontakt und Impressum verwendet.

export const site = {
  name: 'CONSERVE',
  // Zwischen „Baudenkmalforschung“ und „OG“ steht ein geschütztes Leerzeichen (kein Zeilenumbruch)
  legalName: 'CONSERVE Baudenkmalforschung\u00A0OG',
  claim: 'Denkmalgerecht bewahren. Nachhaltig weiterbauen.',
  slogan: 'Fachbegleitung für historische Bausubstanz',
  seit: 'Erhalt des kulturellen Erbes seit 2001',
  taetigkeiten: ['Bauforschung', 'Denkmalpflege', 'Sanierungsplanung', 'Bauaufsicht'],
  description:
    'CONSERVE Baudenkmalforschung OG, Graz – Fachbegleitung für historische Bausubstanz: Bauforschung, Denkmalpflege, Sanierungsplanung und Bauaufsicht. Erhalt des kulturellen Erbes seit 2001.',
  founded: 2001,
  url: 'https://www.conserve.at',
  email: 'office@conserve.at',
  phone: '+43 677 6248 0894', // = Ing. Brandstätter-Tritthart
  address: {
    street: 'Färberplatz 1',
    zip: '8010',
    city: 'Graz',
    country: 'Österreich',
  },
  legal: {
    companyRegister: 'FN 360302 g',
    // TODO: Firmenbuchgericht mit Kunden bestätigen
    registerCourt: 'Landesgericht für ZRS Graz',
    vatId: 'ATU66456756',
    trade: 'Baumeistergewerbe; Planungsbüro für historische Bauforschung',
    // TODO: Berufsbezeichnung und Gewerbebehörde mit Kunden bestätigen
    jobTitle: 'Baumeister (verliehen in Österreich)',
    authority: 'Magistrat Graz',
    chamber: 'Wirtschaftskammer Steiermark',
  },
  // Kontaktformular: Ziel-URL eines Form-Endpoints (z. B. eigenes PHP-Skript,
  // Formspree, Netlify Forms). Leer lassen = Formular wird nicht angezeigt.
  formAction: '',
} as const;

export type Person = {
  name: string;
  role?: string;
  phone?: string;
  email?: string;
  foto?: string; // Dateiname in src/assets/bilder/ (Hochformat 4:5)
  werdegang: [string, string][]; // [Jahr, Text]
};

// Werdegang laut Firmenpräsentation (September 2026)
export const team: Person[] = [
  {
    name: 'DI Edith Ottenbacher',
    phone: '+43 676 722 6347',
    foto: 'team/ottenbacher.jpg',
    werdegang: [
      ['1992', 'Erste Bauforschungstätigkeiten'],
      ['1999', 'Diplomprüfung Architektur, TU Graz'],
      ['2001', 'Gründung CONSERVE GesbR'],
      ['2011', 'Gründungsmitglied CONSERVE OG'],
      ['2012–2014', 'Joanneum Research, Projektabwicklung im Facility Management'],
      ['2020–2022', 'Mitglied der Altstadt-Sachverständigenkommission (ASVK)'],
      ['2024–2026', 'Geschäftsführerin des Steirischen Volksbildungswerks'],
    ],
  },
  {
    name: 'DI Barbara Wonisch',
    phone: '+43 650 825 0528',
    foto: 'team/wonisch.jpg',
    werdegang: [
      ['1994', 'Erste Bauforschungstätigkeiten'],
      ['1995', 'Abschluss HTL-Kolleg für Restaurierung und Stadterneuerung, Krems/Donau'],
      ['2004', 'Diplomprüfung Architektur, TU Graz'],
      ['2009', 'Ziviltechniker-Prüfung'],
      ['2011', 'Gründungsmitglied CONSERVE OG'],
      ['2012', 'Baumeister-Prüfung'],
      ['2020–2022', 'Mitglied der Altstadt-Sachverständigenkommission (ASVK)'],
    ],
  },
  {
    name: 'Ing. Rebekka Brandstätter-Tritthart',
    phone: '+43 677 6248 0894',
    foto: 'team/brandstaetter-tritthart.jpg',
    werdegang: [
      ['1994', 'Erste Bauforschungstätigkeiten'],
      ['1995', 'Abschluss HTL-Kolleg für Restaurierung und Stadterneuerung, Krems/Donau'],
      ['1995–1999', 'Architekturbüro Tritthart (Umbau im Bestand, Restaurierung)'],
      ['1999–2001', 'Selbstständige Bauforscherin'],
      ['2001', 'Gründung CONSERVE GesbR'],
      ['2007–2017', 'Auslandsaufenthalt; Leitung einer lokalen Non-Profit-Organisation'],
      ['seit 2018', 'Gesellschafterin CONSERVE OG'],
    ],
  },
  {
    name: 'Ing. Mag. Eva Tangl',
    // TODO: Telefonnummer ergänzen
    foto: 'team/tangl.jpg',
    werdegang: [
      ['1998', 'Mag. Kunstgeschichte'],
      ['1999–2008', 'Kunsthistorische Dokumentationen, Restaurierung, ÖBA'],
      ['2008–2016', 'Diverse Bauforschungen, Projektabwicklungen, ÖBA'],
      ['2013', 'Abschluss HTL-Kolleg für Bautechnik Hochbau, HTBLA Ortwein'],
      ['2017–2024', 'Zechner Denkmal Consulting GmbH – Teamleitung ÖBA, Restaurierung im Parlament Wien'],
      ['seit 2022', 'Mitglied der Altstadt-Sachverständigenkommission (ASVK)'],
      ['seit 2024', 'Gerichtlich beeidete Sachverständige für Denkmalschutz, Stadt- und Ortsbild'],
      ['seit 2025', 'Energieberaterin; Netzwerk Energieberatung Steiermark'],
      ['seit 2026', 'Gesellschafterin CONSERVE OG'],
    ],
  },
];

// Interne Links immer mit Schrägstrich am Ende schreiben (z. B. '/kontakt/')
export const nav = [
  { href: '/ueber-uns/', label: 'Über uns' },
  { href: '/leistungen/', label: 'Leistungen' },
  { href: '/projekte/', label: 'Projekte' },
  { href: '/kontakt/', label: 'Kontakt' },
] as const;

export const legalNav = [
  { href: '/impressum/', label: 'Impressum' },
  { href: '/datenschutz/', label: 'Datenschutz' },
] as const;

export const telHref = (phone: string) => `tel:${phone.replace(/[^+\d]/g, '')}`;

export const fullAddress = `${site.address.street}, ${site.address.zip} ${site.address.city}`;
