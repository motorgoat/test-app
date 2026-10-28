# CONSERVE – Website (Astro)

Website der CONSERVE Baudenkmalforschung OG, Graz. Statische Astro-Seite ohne CMS: Alle Inhalte stehen direkt im Code. Keine Cookies, keine externen Requests (Schriften lokal via Fontsource).

## Entwicklung

```bash
npm install
npm run dev       # http://localhost:4321
npm run build     # prüft den Code und erstellt den statischen Export in dist/ – diesen Ordner auf den Webserver laden
npm run preview   # gebauten Stand lokal ansehen
npm run check     # prüft den Code auf Tippfehler (z. B. falsch geschriebene Feldnamen in src/data/*.ts)
```

Benötigt Node ≥ 22.12 (Astro 6). `npm run build` bricht mit einer Fehlermeldung ab, wenn z. B. in `src/data/*.ts` ein Feldname falsch geschrieben ist.

## Wo ändere ich was?

| Inhalt | Datei |
| --- | --- |
| Adresse, Telefon, E-Mail, Navigation, Impressumsdaten | `src/data/site.ts` |
| Team (Name, Telefon, Foto, Werdegang) | `src/data/site.ts` → `team` |
| Leistungsbereiche (Startseite + Leistungen) | `src/data/leistungen.ts` |
| Projekte (Projektübersicht, Projektseiten, Slider auf der Startseite) | `src/data/projekte.ts` |
| Texte der einzelnen Seiten | `src/pages/*.astro` (Text steht direkt im HTML) |
| Farben, Schriften, Abstände | `src/styles/global.css` (Variablen ganz oben) |
| Logo | `public/logo/*.svg` (Monogramm „CO“ und Wortmarke, jeweils weiß und dunkel) |

Seiten: `/` · `/ueber-uns/` · `/leistungen/` · `/projekte/` · `/projekte/<projekt>/` (nur Projekte mit Galerie) · `/kontakt/` · `/impressum/` · `/datenschutz/` · 404

Interne Links immer mit Schrägstrich am Ende schreiben (`/kontakt/`, `/leistungen/#bauforschung`) – sonst leitet der Webserver jedes Mal um.

### Neues Projekt

In `src/data/projekte.ts` einen Eintrag ergänzen – die Reihenfolge in der Datei ist die Reihenfolge auf der Website:

```ts
{
  titel: 'Palais Welsersheimb',
  ort: 'Graz',                                  // optional
  jahr: 2023,                                   // optional
  leistungen: 'Fassadenuntersuchung & Maßnahmenkatalog',
  text: 'Kurzbeschreibung …',                   // optional
  auftraggeber: 'City Immobilien Invest GmbH', // optional
  bild: 'projekt-graz-palais-welsersheimb.jpg', // ohne Bild → Liste „Weitere Projekte“
  bildAlt: 'Was auf dem Foto zu sehen ist',     // optional
  bildText: 'Foto: …',                          // optional, Bildunterschrift
  galerie: 'palais-welsersheimb',               // optional → eigene Projektseite mit Bildergalerie
  startseite: true,                             // im Slider auf der Startseite zeigen
},
```

**Galerie:** Fotos in den Ordner `src/assets/bilder/projekte/<galerie>/` legen (z. B. `01.jpg`, `02.jpg` …, Reihenfolge nach Dateiname). Die Projektseite mit Großansicht (Lightbox) entsteht automatisch.

### Bilder

Fotos einfach unter dem vorgesehenen Namen in **`src/assets/bilder/`** ablegen. Es zählt nur der Name – Endung (JPG, PNG, WebP, AVIF) und Groß-/Kleinschreibung sind egal: für `hero-startseite.jpg` passt also auch `Hero-Startseite.PNG`. Am besten mind. 2400 px breit. Astro erzeugt beim Build automatisch optimierte WebP-Größen. Solange ein Bild fehlt, zeigt die Seite einen gezeichneten Platzhalter, und der Build meldet `[Bild] … fehlt`.

Aktuelle Bilder (Fotos vom Kunden, Oktober 2026 – auf max. 2400 px verkleinert, Metadaten/GPS entfernt):

- Großbilder oben: `hero-startseite.jpg`, `hero-ueber-uns.jpg`, `hero-leistungen.jpg`, `hero-projekte.jpg`, `hero-kontakt.jpg`
- Über uns: `ueber-uns-arbeitsweise.jpg`, Teamfotos in `team/` (Hochformat 4:5)
- Leistungen: `leistung-bauforschung.jpg`, `leistung-gebaeudedokumentation.jpg`, `leistung-fachbegleitung.jpg`, `leistung-altbausanierung.jpg`
- Projekte: Titelbilder siehe Feld `bild` in `src/data/projekte.ts`, Galerien in `projekte/<ordner>/`
- Vorschaubild für Social Media: `og-image.jpg`

Ein Bild tauschen = neue Datei unter demselben Namen ablegen. Hat die neue Datei eine andere Endung (z. B. `.png` statt `.jpg`), die alte Datei löschen – sonst meldet der Build `[Bild] … gibt es mehrfach`.

Bildausschnitt: Große Bilder füllen ihre Fläche und werden dabei beschnitten. Ist das Wichtige abgeschnitten, den Ausschnitt verschieben – im `<Hero>` mit `bildPosition="center top"` (und `bildPositionMobil` für Handys), bei Projekten und Leistungen mit dem Feld `bildPosition`.

In einer Seite selbst: `<Bild src="dateiname.jpg" alt="Beschreibung" />` (Komponente `src/components/Bild.astro`). `alt=""` bei rein dekorativen Bildern, z. B. wenn die Überschrift daneben schon alles sagt.

Vorschaubild für Social Media/Messenger: `src/assets/bilder/og-image.jpg` – beliebige Größe, wird automatisch auf 1200 × 630 px zugeschnitten und verwendet, sobald die Datei existiert.

### Lange Wörter in Überschriften

Überschriften werden nicht automatisch getrennt. Bei sehr langen Wörtern eine weiche Trennstelle setzen – sie erscheint nur, wenn auf schmalen Bildschirmen tatsächlich getrennt wird:

- direkt im HTML einer Seite und im `title` des großen Bildes (`<Hero title="…">`): `&shy;`, z. B. `verantwortungs&shy;vollen`. Dort ist auch `<br />` für einen festen Zeilenumbruch erlaubt.
- in `src/data/*.ts` (Texte in Anführungszeichen): `\u00AD`, z. B. `title: 'Altbau\u00ADsanierung'`. `&shy;` würde dort wörtlich angezeigt.

### Kontaktformular

Ist vorbereitet, aber ausgeblendet. Zum Aktivieren in `src/data/site.ts` bei `formAction` die Adresse eines Formular-Dienstes eintragen (eigenes PHP-Skript, Formspree o. ä.) und die Datenschutzerklärung ergänzen.

## Offene Punkte

- [ ] Telefonnummer Ing. Mag. Eva Tangl (`src/data/site.ts`)
- [ ] Logo: aus JPG/PNG vektorisiert – falls vorhanden, Original-SVG/PDF vom Grafiker einsetzen (`public/logo/`)
- [ ] Projektbeschreibungen und fehlende Jahreszahlen ergänzen; Ort der Wöllbachmühle
- [ ] Höher aufgelöste Fotos für die Großbilder, falls vorhanden (aktuell teils nur 1000–1400 px breit)
- [ ] Impressum bestätigen: Firmenbuchgericht, Berufsbezeichnung, Gewerbebehörde (`src/data/site.ts`)
- [ ] Datenschutzerklärung finalisieren (Hosting, ggf. Formular-Anbieter)
