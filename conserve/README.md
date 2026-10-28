# CONSERVE – Website (Astro)

Website der CONSERVE Baudenkmalforschung OG, Graz. Statische Astro-Seite ohne CMS: Alle Inhalte stehen direkt im Code. Keine Cookies, keine externen Requests (Schriften lokal via Fontsource).

## Entwicklung

```bash
npm install
npm run dev       # http://localhost:4321
npm run build     # statischer Export nach dist/ – diesen Ordner auf den Webserver laden
npm run preview   # gebauten Stand lokal ansehen
```

Benötigt Node ≥ 22.12 (Astro 6).

## Wo ändere ich was?

| Inhalt | Datei |
| --- | --- |
| Adresse, Telefon, E-Mail, Team, Navigation, Impressumsdaten | `src/data/site.ts` |
| Leistungsbereiche (Startseite + Leistungen) | `src/data/leistungen.ts` |
| Projekte (Projektseite + Slider auf der Startseite) | `src/data/projekte.ts` |
| Texte der einzelnen Seiten | `src/pages/*.astro` (Text steht direkt im HTML) |
| Farben, Schriften, Abstände | `src/styles/global.css` (Variablen ganz oben) |
| Logo | `src/components/Logo.astro` |

Seiten: `/` · `/ueber-uns` · `/leistungen` · `/projekte` · `/kontakt` · `/impressum` · `/datenschutz` · 404

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
  startseite: true,                             // im Slider auf der Startseite zeigen
},
```

### Bilder

Fotos einfach unter dem vorgesehenen Dateinamen in **`src/assets/bilder/`** ablegen (JPG, PNG, WebP oder AVIF; am besten mind. 2400 px breit). Astro erzeugt beim Build automatisch optimierte WebP-Größen. Solange ein Bild fehlt, zeigt die Seite einen gezeichneten Platzhalter, und der Build meldet `[Bild] … fehlt`.

Vorgesehene Dateinamen:

- Großbilder oben: `hero-startseite.jpg`, `hero-ueber-uns.jpg`, `hero-leistungen.jpg`, `hero-projekte.jpg`, `hero-kontakt.jpg`
- Über uns: `ueber-uns-arbeitsweise.jpg`
- Leistungen: `leistung-dokumentation-beratung.jpg`, `leistung-bauforschung.jpg`, `leistung-altbausanierung.jpg`
- Projekte: siehe Feld `bild` in `src/data/projekte.ts`

In einer Seite selbst: `<Bild src="dateiname.jpg" alt="Beschreibung" />` (Komponente `src/components/Bild.astro`).

### Lange Wörter in Überschriften

Überschriften werden nicht automatisch getrennt. Bei sehr langen Wörtern eine weiche Trennstelle mit `&shy;` setzen, z. B. `verantwortungs&shy;vollen` – sie erscheint nur, wenn auf schmalen Bildschirmen tatsächlich getrennt wird.

### Kontaktformular

Ist vorbereitet, aber ausgeblendet. Zum Aktivieren in `src/data/site.ts` bei `formAction` die Adresse eines Formular-Dienstes eintragen (eigenes PHP-Skript, Formspree o. ä.) und die Datenschutzerklärung ergänzen.

## Offene Punkte

- [ ] Fotos liefern (siehe Dateinamen oben)
- [ ] Original-Logo als SVG einbauen (`src/components/Logo.astro`)
- [ ] Projektbeschreibungen und fehlende Jahreszahlen ergänzen
- [ ] Rollen der Ansprechpartnerinnen (`src/data/site.ts`, Feld `role`)
- [ ] Firmenbuchgericht im Impressum bestätigen
- [ ] Datenschutzerklärung finalisieren (Hosting, ggf. Formular-Anbieter)
