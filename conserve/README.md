# CONSERVE – Website (Astro)

Website der CONSERVE Baudenkmalforschung OG, Graz. Statische Astro-Seite ohne CMS: Alle Inhalte stehen direkt im Code. Keine Cookies, keine externen Requests (Schriften lokal via Fontsource).

## Entwicklung

```bash
npm install
npm run dev       # http://localhost:4321
npm run build     # statischer Export nach dist/ – diesen Ordner auf den Webserver laden
npm run preview   # gebauten Stand lokal ansehen
npm run check     # prüft den Code auf Tippfehler (z. B. falsch geschriebene Feldnamen in src/data/*.ts)
```

Benötigt Node ≥ 22.12 (Astro 6). Nach Änderungen an `src/data/*.ts` am besten kurz `npm run check` laufen lassen.

## Wo ändere ich was?

| Inhalt | Datei |
| --- | --- |
| Adresse, Telefon, E-Mail, Team, Navigation, Impressumsdaten | `src/data/site.ts` |
| Leistungsbereiche (Startseite + Leistungen) | `src/data/leistungen.ts` |
| Projekte (Projektseite + Slider auf der Startseite) | `src/data/projekte.ts` |
| Texte der einzelnen Seiten | `src/pages/*.astro` (Text steht direkt im HTML) |
| Farben, Schriften, Abstände | `src/styles/global.css` (Variablen ganz oben) |
| Logo | `src/components/Logo.astro` |

Seiten: `/` · `/ueber-uns/` · `/leistungen/` · `/projekte/` · `/kontakt/` · `/impressum/` · `/datenschutz/` · 404

Interne Links immer mit Schrägstrich am Ende schreiben (`/kontakt/`, `/leistungen/#bauforschung`) – sonst leitet der Webserver jedes Mal um.

### Neues Projekt

In `src/data/projekte.ts` einen Eintrag ergänzen – die Reihenfolge in der Datei ist die Reihenfolge auf der Website:

```ts
{
  titel: 'Palais Welsersheimb',
  ort: 'Graz',
  jahr: 2023,                                   // optional
  leistungen: 'Fassadenuntersuchung & Maßnahmenkatalog',
  text: 'Kurzbeschreibung …',                   // optional
  auftraggeber: 'City Immobilien Invest GmbH', // optional
  bild: 'projekt-graz-palais-welsersheimb.jpg',
  bildAlt: 'Was auf dem Foto zu sehen ist',     // optional
  startseite: true,                             // im Slider auf der Startseite zeigen
},
```

### Bilder

Fotos einfach unter dem vorgesehenen Namen in **`src/assets/bilder/`** ablegen. Es zählt nur der Name – Endung (JPG, PNG, WebP, AVIF) und Groß-/Kleinschreibung sind egal: für `hero-startseite.jpg` passt also auch `Hero-Startseite.PNG`. Am besten mind. 2400 px breit. Astro erzeugt beim Build automatisch optimierte WebP-Größen. Solange ein Bild fehlt, zeigt die Seite einen gezeichneten Platzhalter, und der Build meldet `[Bild] … fehlt`.

Vorgesehene Dateinamen:

- Großbilder oben: `hero-startseite.jpg`, `hero-ueber-uns.jpg`, `hero-leistungen.jpg`, `hero-projekte.jpg`, `hero-kontakt.jpg`
- Über uns: `ueber-uns-arbeitsweise.jpg`
- Leistungen: `leistung-dokumentation-beratung.jpg`, `leistung-bauforschung.jpg`, `leistung-altbausanierung.jpg`
- Projekte: siehe Feld `bild` in `src/data/projekte.ts`

In einer Seite selbst: `<Bild src="dateiname.jpg" alt="Beschreibung" />` (Komponente `src/components/Bild.astro`). `alt=""` bei rein dekorativen Bildern, z. B. wenn die Überschrift daneben schon alles sagt.

Vorschaubild für Social Media/Messenger: `public/og-image.jpg` (1200 × 630 px) – wird automatisch verwendet, sobald die Datei existiert.

### Lange Wörter in Überschriften

Überschriften werden nicht automatisch getrennt. Bei sehr langen Wörtern eine weiche Trennstelle setzen – sie erscheint nur, wenn auf schmalen Bildschirmen tatsächlich getrennt wird:

- direkt im HTML einer Seite und im `title` des großen Bildes (`<Hero title="…">`): `&shy;`, z. B. `verantwortungs&shy;vollen`. Dort ist auch `<br />` für einen festen Zeilenumbruch erlaubt.
- in `src/data/*.ts` (Texte in Anführungszeichen): `\u00AD`, z. B. `title: 'Altbau\u00ADsanierung'`. `&shy;` würde dort wörtlich angezeigt.

### Kontaktformular

Ist vorbereitet, aber ausgeblendet. Zum Aktivieren in `src/data/site.ts` bei `formAction` die Adresse eines Formular-Dienstes eintragen (eigenes PHP-Skript, Formspree o. ä.) und die Datenschutzerklärung ergänzen.

## Offene Punkte

- [ ] Fotos liefern (siehe Dateinamen oben)
- [ ] Original-Logo als SVG einbauen (`src/components/Logo.astro`)
- [ ] Projektbeschreibungen und fehlende Jahreszahlen ergänzen
- [ ] Rollen der Ansprechpartnerinnen (`src/data/site.ts`, Feld `role`)
- [ ] Impressum bestätigen: Firmenbuchgericht, Berufsbezeichnung, Gewerbebehörde (`src/data/site.ts`)
- [ ] Vorschaubild `public/og-image.jpg` (1200 × 630 px)
- [ ] Datenschutzerklärung finalisieren (Hosting, ggf. Formular-Anbieter)
