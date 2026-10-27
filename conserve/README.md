# CONSERVE – Website (Astro)

Website der CONSERVE Baudenkmalforschung OG, Graz. Statische Astro-Seite, keine Cookies, keine externen Requests (Schriften lokal via Fontsource).

## Entwicklung

```bash
npm install
npm run dev       # http://localhost:4321
npm run build     # statischer Export nach dist/
npm run preview
```

Astro 6.x – benötigt Node ≥ 22.12.

## Struktur

```
src/
  data/site.ts          Firmendaten, Kontakte, Navigation, Impressumsdaten
  data/leistungen.ts    Leistungsbereiche (Startseite + /leistungen)
  content/projekte/     Ein Markdown-File pro Projekt (Content Collection)
  content.config.ts     Schema der Projekte
  styles/global.css     Design-Tokens (Farben, Schriften, Abstände) + Basis-Styles
  layouts/BaseLayout    <head>, SEO-Meta, Header, Footer
  components/           Header, Footer, Logo, PageHero, ProjectCard, ContactCta, ImagePlaceholder
  pages/                /, /ueber-uns, /leistungen, /projekte, /projekte/[slug], /kontakt,
                        /impressum, /datenschutz, 404
```

## Projekt anlegen

Neue Datei `src/content/projekte/<slug>.md`:

```md
---
title: Palais Welsersheimb
ort: Graz
jahr: 2023
leistung: Fassadenuntersuchung & Maßnahmenkatalog
kategorie: Bauforschung        # Bauforschung | Sanierung | ÖBA | Energieberatung
auftraggeber: City Immobilien Invest GmbH
bild: ./bilder/welsersheimb.jpg  # optional, relativ zur .md-Datei
bildAlt: Fassade zum Eisernen Tor
featured: true                 # auf Startseite zeigen
---

Projektbeschreibung in Markdown …
```

Ohne `bild` wird ein neutraler Platzhalter angezeigt.

## Offene Punkte

- [ ] Design an den Designvorschlag (conserve.at/wordpress) angleichen – Tokens in `src/styles/global.css`
- [ ] Original-Logo als SVG einbauen (`src/components/Logo.astro`)
- [ ] Projektbilder und -beschreibungen aus der bestehenden Website übernehmen
- [ ] Jahreszahlen für Projekte ohne `jahr` ergänzen
- [ ] Rollen/Fotos der Ansprechpartnerinnen (`src/data/site.ts`)
- [ ] Firmenbuchgericht im Impressum bestätigen
- [ ] Datenschutzerklärung finalisieren (Hosting, ggf. Formular-Anbieter)
- [ ] Kontaktformular: Endpoint in `site.formAction` setzen (leer = kein Formular)
