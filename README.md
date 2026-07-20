# ident-it.at

Website der **ident-IT GmbH – Werbeagentur Graz**. Statische Site auf Basis von
[Astro](https://astro.build) und Tailwind CSS, Deployment auf SiteGround.

## Entwicklung

```bash
npm install
npm run dev       # Dev-Server auf localhost:4321
npm run build     # Statischer Build nach dist/
npm run preview   # Build lokal testen
```

## Struktur

| Pfad | Inhalt |
|---|---|
| `BRIEFING.md` | Verbindliches Projekt-Briefing (Seitenstruktur, SEO, Design) |
| `KONVENTIONEN.md` | Projektregeln: Prefix, Ton, Budgets, Deploy, Redirects |
| `wartung-seite_inhalt-referenz.md` | Inhaltsvorlage für `/leistungen/web/wartung/` |
| `docs/websitebrief_ueber-uns.md` | Positionierungs-Brief für die Über-uns-Seite |
| `src/lib/site.ts` | Zentrale Marken- & Kontaktdaten (NAP), Navigation |
| `src/styles/global.css` | Design-Tokens (Dark + Blau/Türkis aus dem Logo) und Basis-Styles |
| `src/layouts/Layout.astro` | SEO-Head, Schema.org, Header/Footer/Schnellkontakt |
| `public/.htaccess` | 301-Redirects + Caching/Kompression für SiteGround |
| `referenz/` | Lokale Design-/Recherche-Vorlagen (nicht versioniert) |

## Deploy

`npm run build` und den Inhalt von `dist/` per FTP/SSH in den Webroot des
SiteGround Cloud Servers laden. Redirects pflegt `public/.htaccess`.

## Status & offene Punkte

- [x] Projekt-Setup: Astro, Tailwind, Design-Tokens, Layout, Header/Footer/Schnellkontakt
- [x] Startseite aus dem Design-Entwurf portiert (alle Sektionen, Animationen als CSS/Vanilla-JS)
- [x] Hero-Video komprimiert (0,8 MB) & selbst gehostet, Poster als LCP-Element
- [x] Kontakt (Formular + PHP-Mail-Script mit Honeypot/Zeitfalle), Danke-, Impressum-, Datenschutz-, AGB-Seite
- [x] Finales Logo (Blau→Türkis) eingebaut: Symbol in Header/Footer, Favicon, Palette exakt aus dem Logo abgeleitet
- [ ] Logo als SVG ablegen, sobald verfügbar (aktuell freigestelltes PNG aus der Vorlage)
- [ ] Pillar- und Leistungsseiten (Marketing / Grafik / Web) portieren bzw. neu erstellen
- [ ] Referenzen, Über uns, Website-Kosten-Konfigurator, Blog-Migration
- [ ] Card-Mockups & Team-/Bürofoto einsetzen (Platzhalter-Visuals aktiv; Bilder liefert Philipp)
- [x] OG-Default-Image (1200×630) aus dem Logo erzeugt (`public/og-default.jpg`)
- [ ] AGB-Text von der bestehenden Website übernehmen
- [ ] EEAT (KONVENTIONEN.md, Abschnitt 11): Autoren-Bio-Box + Person-Schema beim Blog-Aufbau umsetzen; von Philipp benötigt: LinkedIn-/Fachprofil-URLs, Qualifikationen/Zertifikate, Portrait-Foto
- [ ] CCM19 + Consent Mode v2 + GTM-Events
- [ ] Redirect-Map aus Alt-Sitemap vervollständigen (`public/.htaccess`)
