/**
 * Zentrale Marken- und Kontaktdaten (NAP) – einzige Quelle für Header, Footer,
 * Schema.org und Kontaktseiten. NAP muss exakt mit Google Business Profile
 * und Verzeichnissen (WKO, Herold) übereinstimmen.
 */
export const SITE = {
  name: 'ident-IT',
  legalName: 'ident-IT GmbH',
  slogan: 'BE A VOICE – NOT AN ECHO!',
  claim: 'Digitale Strategien, die verkaufen.',
  url: 'https://ident-it.at',
  phoneDisplay: '+43 660 94 49 688',
  phoneE164: '+436609449688',
  email: 'office@ident-it.at',
  address: {
    street: 'Mariahilferstraße 1',
    zip: '8020',
    city: 'Graz',
    country: 'AT',
  },
  geo: { lat: 47.0711162, lng: 15.4333155 },
  openingHours: [
    { label: 'Mo–Do', value: '08:00–17:00' },
    { label: 'Fr', value: '08:00–12:00' },
  ],
  rating: {
    value: '5,0',
    count: 13,
    // TODO: finale URL zum Google-Business-Profil eintragen
    url: 'https://www.google.com/maps/search/?api=1&query=ident-IT%20Werbeagentur%20Graz',
  },
  social: {
    facebook: 'https://www.facebook.com/identITsolutions',
    // TODO: Instagram-Profil-URL ergänzen (siehe BRIEFING.md, Abschnitt 7)
    instagram: '',
  },
  register: {
    firmenbuch: 'FN 488011p',
    gericht: 'Landesgericht für Zivilrechtssachen Graz',
    uid: 'ATU73235545',
    gegenstand: 'IT-Dienstleistungen, Werbeagentur',
    mitglied: 'Wirtschaftskammer Österreich (WKO)',
    aufsicht: 'Bezirkshauptmannschaft Graz',
  },
  foundedYear: 2018,
} as const;

/**
 * Autor für Blog & Fachinhalte (EEAT, siehe KONVENTIONEN.md Abschnitt 11):
 * sichtbarer Autor auf jedem Beitrag, Bio-Box, Person-Schema mit sameAs.
 */
export const AUTHOR = {
  name: 'Philipp Golob',
  shortName: 'Philipp',
  jobTitle: 'Geschäftsführung',
  /** Autorenseite – Bio-Boxen und Person-Schema verlinken hierher */
  url: '/ueber-uns/',
  bio: `Philipp führt ident-IT seit ${SITE.foundedYear} und setzt Webdesign-, SEO- und Marketing-Projekte für Unternehmen in Graz und der Steiermark um.`,
  // TODO: LinkedIn-/Fachprofil-URLs von Philipp ergänzen (sameAs im Person-Schema)
  sameAs: [] as string[],
  // TODO: Qualifikationen/Zertifikate von Philipp ergänzen (z. B. Google-Zertifizierungen)
  credentials: [] as string[],
} as const;

export interface NavChild {
  label: string;
  href: string;
  description: string;
}

export interface NavItem {
  label: string;
  href: string;
  children?: NavChild[];
}

/** Hauptnavigation laut BRIEFING.md, Abschnitt 4 (Drei Säulen: Marketing / Grafik / Web). */
export const NAV: NavItem[] = [
  {
    label: 'Marketing',
    href: '/leistungen/marketing/',
    children: [
      {
        label: 'Online Marketing',
        href: '/leistungen/marketing/online-marketing/',
        description: 'Strategie & Kampagnen, die messbar verkaufen',
      },
      {
        label: 'SEO',
        href: '/leistungen/marketing/seo/',
        description: 'Suchmaschinenoptimierung für Top-Rankings in Graz',
      },
      {
        label: 'Google Ads',
        href: '/leistungen/marketing/google-ads/',
        description: 'SEA-Kampagnen, die ab Tag 1 Anfragen bringen',
      },
      {
        label: 'Social Media',
        href: '/leistungen/marketing/social-media/',
        description: 'Kanäle, Content & Betreuung aus einer Hand',
      },
      {
        label: 'Videoproduktion',
        href: '/leistungen/marketing/videoproduktion/',
        description: 'Werbespots & Videos, die hängen bleiben',
      },
    ],
  },
  {
    label: 'Grafik',
    href: '/leistungen/grafik/',
    children: [
      {
        label: 'Grafikdesign',
        href: '/leistungen/grafik/',
        description: 'Design für Print & Digital – von Flyer bis Editorial',
      },
      {
        label: 'Branding & Logo',
        href: '/leistungen/grafik/branding/',
        description: 'Logo, Branding & Corporate Design',
      },
      {
        label: 'Drucksorten',
        href: '/leistungen/grafik/drucksorten/',
        description: 'Visitenkarten, Flyer, Folder & Kataloge',
      },
      {
        label: 'Beschriftungen',
        href: '/leistungen/grafik/beschriftungen/',
        description: 'Schaufenster- & Fahrzeugbeschriftung',
      },
    ],
  },
  {
    label: 'Web',
    href: '/leistungen/web/',
    children: [
      {
        label: 'Webdesign',
        href: '/leistungen/web/webdesign/',
        description: 'Websites, die verkaufen – modern, schnell, sichtbar',
      },
      {
        label: 'Onlineshop',
        href: '/leistungen/web/onlineshop/',
        description: 'Onlineshops mit WooCommerce – von Setup bis Betreuung',
      },
      {
        label: 'Wartung & Hosting',
        href: '/leistungen/web/wartung/',
        description: 'EU-Hosting, Updates & Backups – deine Website läuft',
      },
    ],
  },
  { label: 'Referenzen', href: '/referenzen/' },
  {
    label: 'Agentur',
    href: '/ueber-uns/',
    children: [
      {
        label: 'Über uns',
        href: '/ueber-uns/',
        description: 'Die Agentur hinter ident-IT',
      },
      {
        label: 'Blog',
        href: '/aktuelles/',
        description: 'Neuigkeiten & Praxiswissen aus der Agentur',
      },
    ],
  },
];

/** Alle Leistungsseiten – Footer-Quicklinks (sitewide interne Verlinkung). */
export const SERVICE_LINKS: { label: string; href: string }[] = [
  { label: 'Online Marketing Graz', href: '/leistungen/marketing/online-marketing/' },
  { label: 'SEO Agentur Graz', href: '/leistungen/marketing/seo/' },
  { label: 'Google Ads Agentur Graz', href: '/leistungen/marketing/google-ads/' },
  { label: 'Social Media Agentur Graz', href: '/leistungen/marketing/social-media/' },
  { label: 'Videoproduktion Graz', href: '/leistungen/marketing/videoproduktion/' },
  { label: 'Grafikdesign Graz', href: '/leistungen/grafik/' },
  { label: 'Branding & Logo Design Graz', href: '/leistungen/grafik/branding/' },
  { label: 'Drucksorten', href: '/leistungen/grafik/drucksorten/' },
  { label: 'Beschriftungen', href: '/leistungen/grafik/beschriftungen/' },
  { label: 'Webdesign Graz', href: '/leistungen/web/webdesign/' },
  { label: 'Onlineshop erstellen', href: '/leistungen/web/onlineshop/' },
  { label: 'Website-Wartung & Hosting', href: '/leistungen/web/wartung/' },
];
