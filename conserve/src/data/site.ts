// Zentrale Firmen- und Kontaktdaten. Quelle: bestehende Website conserve.at
// (Kontakt/Impressum). Vor Go-live mit dem Kunden gegenprüfen.

export const site = {
  name: 'CONSERVE',
  legalName: 'CONSERVE Baudenkmalforschung OG',
  tagline: 'Bauforschung und Altbausanierung',
  description:
    'CONSERVE Baudenkmalforschung OG – Bauforschung, Sanierungsplanung, Energieberatung und örtliche Bauaufsicht für historische Gebäude. Seit 2001 in Graz.',
  founded: 2001,
  url: 'https://www.conserve.at',
  email: 'office@conserve.at',
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
    trade: 'Baumeister; Planungsbüro für historische Bauforschung',
    chamber: 'Wirtschaftskammer Steiermark',
  },
  // Kontaktformular: Ziel-URL eines Form-Endpoints (z. B. eigenes PHP-Skript,
  // Formspree, Netlify Forms). Leer lassen = Formular wird nicht angezeigt.
  formAction: '',
} as const;

export type Person = {
  name: string;
  role?: string;
  phone: string;
  email?: string;
};

export const team: Person[] = [
  { name: 'DI Edith Ottenbacher', phone: '+43 676 722 6347' },
  { name: 'DI Barbara Wonisch', phone: '+43 650 825 0528' },
  { name: 'Ing. Rebekka Brandstätter-Tritthart', phone: '+43 677 6248 0894' },
];

export const nav = [
  { href: '/', label: 'Start' },
  { href: '/ueber-uns', label: 'Über uns' },
  { href: '/leistungen', label: 'Leistungen' },
  { href: '/projekte', label: 'Projekte' },
  { href: '/kontakt', label: 'Kontakt' },
] as const;

export const legalNav = [
  { href: '/impressum', label: 'Impressum' },
  { href: '/datenschutz', label: 'Datenschutz' },
] as const;

export const telHref = (phone: string) => `tel:${phone.replace(/[^+\d]/g, '')}`;

export const fullAddress = `${site.address.street}, ${site.address.zip} ${site.address.city}`;
