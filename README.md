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
| `src/styles/global.css` | Design-Tokens (Dark + Teal) und Basis-Styles |
| `src/layouts/Layout.astro` | SEO-Head, Schema.org, Header/Footer/Schnellkontakt |
| `public/.htaccess` | 301-Redirects + Caching/Kompression für SiteGround |
| `referenz/` | Lokale Design-/Recherche-Vorlagen (nicht versioniert) |

## Deploy

`npm run build` und den Inhalt von `dist/` per FTP/SSH in den Webroot des
SiteGround Cloud Servers laden. Redirects pflegt `public/.htaccess`.

## Status & offene Punkte

- [x] Projekt-Setup: Astro, Tailwind, Design-Tokens, Layout, Header/Footer/Schnellkontakt
- [ ] Startseite aus dem Design-Entwurf portieren (Zips `ident-it-redesign` / `Web_ident-IT` → `referenz/`)
- [ ] Kontakt, Danke- und Rechtsseiten
- [ ] Pillar- und Leistungsseiten (Marketing / Grafik / Web)
- [ ] Referenzen, Über uns, Website-Kosten-Konfigurator, Blog-Migration
- [ ] OG-Default-Image (1200×630) unter `public/og-default.jpg` ablegen
- [ ] Finales Teal-Logo (SVG) in `src/components/Logo.astro` + Favicon einsetzen
- [ ] Hero-Video komprimieren (< 2 MB) und selbst hosten
- [ ] CCM19 + Consent Mode v2 + GTM-Events
- [ ] Redirect-Map aus Alt-Sitemap vervollständigen (`public/.htaccess`)
