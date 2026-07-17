# Relaunch ident-it.at – Technisches Briefing & Seitenstruktur

**Projekt:** Eigene Agentur-Website „ident-IT – Werbeagentur Graz"
**Ziel:** Top 3 für „Werbeagentur Graz" (SEO) + SEA-taugliche Landingpages
**Umsetzung:** auf Basis dieses Dokuments – es ist die verbindliche Grundlage für den kompletten Aufbau.

---

## 0. Projektziel & Kontext

- Relaunch der bestehenden WordPress/Divi-Website als statische Astro-Site.
- Primäres SEO-Ziel: **„Werbeagentur Graz" → Top 3** (Startseite als Money-Page). Konkurrenz aktuell: Rittler & Co (werbe-agentur-graz.at), Rubikon, Madison, allinone creative, Verzeichnis werbeagentur-graz.at.
- Sekundär: Leistungsseiten ranken für lokale Keywords (Webdesign Graz, SEO Agentur Graz, Videoproduktion Graz, …).
- **Design-Leitprinzip: Hingucker + userfriendly.** Die Seite muss visuell beeindrucken (Showcase der Agentur), darf aber nie auf Kosten von Bedienbarkeit, Klarheit oder Ladezeit gehen. Details in Abschnitt 11.
- Die Seite wird zusätzlich mit **Google Ads (SEA)** beworben → Conversion-Tracking und Consent Mode v2 von Anfang an einplanen.
- **Startseiten-Entwurf liegt vor:** Zwei Zips (`ident-it-redesign.zip` = React/Vite-Prototyp, `Web_ident-IT.zip` = flacher Export + Recherche-Dateien + Assets). Der Prototyp ist die verbindliche Design- und Content-Vorlage → wird in Astro portiert (siehe Abschnitte 5 und 11).
- **Keyword-Daten liegen in den Zips** (Ahrefs + SISTRIX, Stand Feb 2026, siehe Abschnitt 3a). Finale Keyword-Freigabe macht Philipp; ggf. kommen aktualisierte SISTRIX-Exporte nach.
- Entwurf für **Wartung** existiert separat bei Philipp → vor Umsetzung anfordern.
- Aufbau läuft über **GitHub** (bestätigt).

---

## 1. Tech-Stack & Setup

| Bereich | Vorgabe |
|---|---|
| Framework | Astro (neueste stabile Version), `output: 'static'` |
| Styling | Tailwind CSS; eigene Klassen/IDs immer mit Prefix `iIT_` |
| Repo | GitHub `motorgoat/ident-it` (privat), analog zu `motorgoat/zauninger` |
| Deployment | SiteGround Cloud Server, Upload von `dist/` per FTP/SSH |
| Redirects | `.htaccess` in `/public/` (landet im Webroot) |
| Sitemap | `@astrojs/sitemap` |
| Bilder | `astro:assets`, WebP/AVIF, Lazy Loading (außer Hero/LCP) |
| Fonts | **Lokal gehostet** (DSGVO – kein Google-Fonts-CDN), `font-display: swap` |
| Content | Blog + Referenzen als Astro Content Collections (Markdown) |
| Projektregeln | Konventionsdatei im Repo-Root anlegen (Prefix-Regel, Deploy-Ablauf, Ton, Redirect-Pflege) |
| Referenz | Prototyp (React/Vite/Tailwind 4/framer-motion) in `/referenz/` ablegen oder separat halten – dient als Design-/Text-Vorlage. **Nicht 1:1 übernehmen**, sondern in statisches Astro portieren: framer-motion & shadcn raus, Animationen mit CSS/`IntersectionObserver` (ScrollReveal, Counter, Typewriter sind ohne Library machbar) |

**Sprachregeln für alle Texte:** Deutsch (du-Form wie bisher), „Philipp" (nie „Phil") in Texten/Signaturen, niemals „kümmere ich mich um" → stattdessen „mache ich / erledige ich / schau ich mir an".

**Neutralitätsregel (verbindlich):** Keine Erwähnung von KI-Tools, Coding-Assistenten oder Website-Generatoren – nirgends: nicht im Quellcode, nicht in Kommentaren, nicht in Meta-Tags (kein `generator`-Tag), nicht in Commit-Messages, nicht in Doku oder README. Entsprechende Reste aus dem Prototyp (Debug-Komponenten, Kommentare, Ordner) beim Portieren entfernen.

---

## 2. IST-Analyse (Kurzfassung der aktuellen Website)

**Marke & Basisdaten (übernehmen):**
- Slogan: **BE A VOICE – NOT AN ECHO!**
- Claim Startseite: „Digitale Strategien, die verkaufen." / „FULLSERVICE"
- Markenfarbe ALT: `#cddb00` (Lime) – **Redesign wechselt auf Teal-Palette** (siehe Abschnitt 11); Logo-Frage siehe offene Punkte
- NAP: Mariahilferstraße 1, 8020 Graz · +43 660 94 49 688 · office@ident-it.at
- Öffnungszeiten: Mo–Do 08:00–17:00, Fr 08:00–12:00
- Google-Bewertung: 5,0 ★ (13 Rezensionen) – prominent im Footer
- Geo: 47.0711162, 15.4333155 (Google Maps Place vorhanden)
- Impressum: **ident-IT GmbH, FN 488011p, LG ZRS Graz, UID ATU73235545 – von Philipp bestätigt, so übernehmen**

**Aktuelle Seitenstruktur (WordPress):**

```
/                                    Werbeagentur Graz | ident-IT (H1: Werbeagentur Graz ident-IT)
/leistungen/                         Übersicht 6 Leistungen
/leistungen/webdesign/               „Webdesign Graz" – Website erstellen, Onlineshop ab 4.900 €, 3-Schritte-Prozess
/leistungen/grafikdesign/            Flyer, Visitenkarten, Folder, Editorial, Logo, Messe
/leistungen/social-media-marketing/  Kanäle, Vorteile, Tipps
/leistungen/seo-agentur-graz/        „SEO Agentur Graz" – SEO/SEA-Erklärung, Kosten
/leistungen/videoproduktion-graz/    „Videoproduktion Graz" – Image-/Erklärvideos
/leistungen/marketing-agentur/       Positionierung, Storytelling, Marketingbetreuung
/referenzen/                         Portfolio-Grid mit Filtern (Web/App, Grafik, Video)
/kunden/                             Kundenlogos (SAPRO, Delta, Stadt Graz, Bundesministerium, Zauninger, Cosmos, Genea, …)
/ueber-uns/                          Namensbedeutung, Philipp Golob (Geschäftsführung) + Foto
/termin/                             Terminvereinbarung
/aktuelles/                          Blog (neuere Posts: /aktuelles/[slug]/, alte: /JJJJ/MM/TT/[slug]/)
/pakete/                             Hub → Marketing- & SEO-Betreuung
/pakete/marketing-betreuung/         Pakete Small/Medium/Pro
/pakete/seo-betreuung/               Pakete Small/Medium/Pro (Potenzialanalyse, Keywords, OnPage …)
/pakete/website-wartung/             2026 neu gemacht: Hosting & Betreuung – Solo 14,99 €/Mo (Aktion, statt 29,99), Standard 69 €, Medium 99 €, Premium 199 € – EU-Server, DSGVO, Domain, 5 Mailadressen, SSL, Cloudflare, WP-Updates
/website-kosten/                     Angebots-Konfigurator (Formular: Seitenanzahl, Funktionen, Budget) + Newsletter-Opt-in
/kontakt/                            NAP, Formular, Maps-Embed
/impressum/ (noindex), /agb, /datenschutz, /jobs/
```

**Technik alt:** GTM `GTM-TX5RHLD`, CCM19 Cookie-Banner, OneTap-Accessibility-Overlay (wird NICHT übernommen – stattdessen native Barrierefreiheit), Visual-Portfolio-Plugin.

---

## 3. Neue Seitenstruktur (SOLL)

Drei Leistungs-Säulen laut Philipp: **Marketing / Grafik / Web**. URL-Schema übernimmt das Muster des Entwurfs: `/leistungen/{kategorie}/{leistung}/`. SEM wird gemäß Entwurf + Keyword-Daten in **SEO** und **Google Ads** gesplittet. Slugs final nach Keyword-Freigabe.

```
/                                   Startseite (Entwurf in Zips → portieren) – KW: Werbeagentur Graz
│
├── /leistungen/                    Übersicht aller Leistungen (im Entwurf vorhanden)
│
├── /leistungen/marketing/          Pillar „Marketing" – KW: Marketing Agentur Graz / Online Marketing Graz
│   ├── /leistungen/marketing/online-marketing/   Online Marketing (Strategie, Kampagnen) – alternativ in Pillar integrieren
│   ├── /leistungen/marketing/seo/                SEO – KW: SEO Agentur Graz, Suchmaschinenoptimierung Graz (Entwurfsseite vorhanden)
│   ├── /leistungen/marketing/google-ads/         Google Ads / SEA – KW: Google Ads Agentur Graz (Entwurfsseite vorhanden)
│   ├── /leistungen/marketing/social-media/       Social Media inkl. Contenterstellung – KW: Social Media Agentur Graz (Entwurfsseite vorhanden)
│   └── /leistungen/marketing/videoproduktion/    Werbespots & Videoproduktion – KW: Videoproduktion Graz (NEU, nicht im Entwurf)
│
├── /leistungen/grafik/             Pillar „Grafik" – KW: Grafikdesign Graz (Entwurfsseite „Grafikdesign" als Basis)
│   ├── /leistungen/grafik/branding/              Logo, Branding & Corporate Design – KW: Branding Agentur Graz, Logo Design Graz (Entwurfsseite vorhanden)
│   ├── /leistungen/grafik/drucksorten/           Visitenkarten, Flyer, Folder, Kataloge (NEU)
│   └── /leistungen/grafik/beschriftungen/        Schaufensterbeschriftung & Autobeklebung (NEU)
│
├── /leistungen/web/                Pillar „Web"
│   ├── /leistungen/web/webdesign/                Webdesign / Website erstellen lassen – KW: Webdesign Graz (Entwurfsseite vorhanden)
│   ├── /leistungen/web/onlineshop/               Onlineshop / WooCommerce – KW: Webshop Agentur Graz (Position 4–5 halten!)
│   └── /leistungen/web/wartung/                  Wartung & Hosting (Vorlage: Live-Seite /pakete/website-wartung/, siehe Referenzdatei)
│
├── /referenzen/                    Portfolio mit Filter (Marketing | Grafik | Web) + Kundenlogos integriert
├── /ueber-uns/                     Agentur, Philipp, Arbeitsweise, Google-Bewertungen
├── /website-kosten/                Angebots-Konfigurator (bleibt – Conversion- & SEA-Seite; rankt für „website erstellen lassen graz" Pos. 5 / „homepage erstellen graz" Pos. 2)
├── /aktuelles/                     Blog (Content Collection; ausgewählte Alt-Posts migrieren)
│   └── /aktuelles/[slug]/
├── /kontakt/                       Formular, NAP, Maps (Entwurfsseite vorhanden)
├── /danke/                         Danke-Seite nach Formular (noindex) → Google-Ads-Conversion
├── /impressum/ · /datenschutz/ · /agb/        (noindex, follow; Impressum & Datenschutz im Entwurf vorhanden)
└── 404-Seite (im Entwurf vorhanden)
```

**Aufteilung Webdesign vs. Grafikdesign:** Im Entwurf lag Webdesign unter „Design" – laut Philipps finaler Struktur gehört Webdesign in die Säule **Web**, Grafikdesign + Branding in die Säule **Grafik**. Entwurfsseiten entsprechend umhängen, Inhalte bleiben nutzbar.

**Pakete-Seiten:** Die alten `/pakete/*`-Preistabellen werden in die jeweiligen Leistungsseiten integriert (SEO-Pakete → SEO-Seite, Marketing-Pakete → Online-Marketing/Pillar, Wartungstarife → `/leistungen/web/wartung/`). Vorteil: stärkere Seiten, bessere Quality Scores für SEA. Alte URLs per 301 umleiten.

**Fällt weg (301 auf sinnvolles Ziel):** `/kunden/` (→ `/referenzen/`), `/termin/` (→ `/kontakt/`), `/pakete/` (→ `/website-kosten/`). `/jobs/` nur behalten, wenn Philipp aktiv sucht – sonst 301 auf `/ueber-uns/`.

---

## 3a. Keyword-Basis (Ahrefs + SISTRIX, Stand Feb 2026 – aus den Zips)

Quelle: `keyword_strategie_final.md`, `seo_keyword_mapping.md`, `sistrix_*.md`, `serp_*.md` im Zip `Web_ident-IT`. Ausgangslage: SISTRIX-Sichtbarkeit 0,0011 (sehr niedrig), nur ~13 organische Keywords. „werbeagentur graz" von Pos. 18 auf 28 gefallen. Wettbewerber: Rubikon (Pos. 1), Rittler & Co (überall Top 5, Keyword-Domain), FRIDA GRÜN (Webdesign Pos. 1), Crediso (Local Pack, 106 Bewertungen).

| Keyword | SV (AT) | KD | Ist-Pos. | Zielseite |
|---|---|---|---|---|
| werbeagentur graz | 600 (CPC 3,30 €) | 15–30 | 28 | Startseite |
| webdesign graz | 400–600 | 4–12 | 22 | /leistungen/web/webdesign/ |
| webdesign agentur graz | 400–600 | 13 | – | /leistungen/web/webdesign/ |
| seo agentur graz | 400 | 6–8 | – | /leistungen/marketing/seo/ |
| suchmaschinenoptimierung graz | 250 | **0** | 22 | /leistungen/marketing/seo/ |
| social media betreuung | 350 | 1 | **1 – halten!** | /leistungen/marketing/social-media/ |
| social media agentur graz | 150 | 1 | – | /leistungen/marketing/social-media/ |
| google ads agentur graz | 300 | – | – | /leistungen/marketing/google-ads/ |
| online marketing agentur graz | 200–300 | – | – | /leistungen/marketing/ bzw. online-marketing |
| marketing agentur graz | 200 | – | – | /leistungen/marketing/ |
| branding agentur graz | 150 | 31 | – | /leistungen/grafik/branding/ |
| grafikdesign graz | 90–200 | 6 | – | /leistungen/grafik/ |
| website erstellen lassen graz | 150 | – | **5 – halten!** | /website-kosten/ + Webdesign |
| homepage erstellen graz | 150 | 17 | **2 – halten!** | /website-kosten/ + Webdesign |
| webshop agentur graz | 10 | 7 | 4–5 | /leistungen/web/onlineshop/ |

**Quick Wins:** suchmaschinenoptimierung graz (KD 0!), social media agentur graz (KD 1), webdesign graz (KD 4). **Content-Regeln aus der Strategie:** DU-Ansprache, keine kopierten Alt-Texte, PAA-Fragen als FAQ, lokaler Bezug (Graz/Steiermark), Trust-Signale (seit 2018, 5,0 Google, 100+ Kunden), CTA „Kostenloses Erstgespräch" auf jeder Seite.

---

## 4. Navigation

**Header (sticky, Entwurf `Navigation.tsx` als Vorlage – Kategorien erweitern):**
Logo | **Marketing** ▾ (Online Marketing, SEO, Google Ads, Social Media, Videoproduktion) | **Grafik** ▾ (Grafikdesign, Branding & Logo, Drucksorten, Beschriftungen) | **Web** ▾ (Webdesign, Onlineshop, Wartung & Hosting) | Referenzen | Agentur ▾ (Über uns, Blog) | **Kontakt** bzw. Tel-CTA (im Entwurf: Telefon-Button rechts)

- Dropdowns zeigen die Unterseiten + je 1 Zeile Beschreibung.
- Mobil: Burger, Accordion-Untermenüs, Kontakt-CTA fix sichtbar.

**Footer:** Logo + Slogan | NAP + Öffnungszeiten | Google-Rating (5★, Link zum Profil) | Leistungs-Quicklinks (alle 10 Leistungsseiten – interne Verlinkung!) | Impressum · Datenschutz · AGB · Cookie-Einstellungen (CCM19-Widget-Trigger).

---

## 5. Seiten-Spezifikationen

Für **jede** Seite gilt: genau eine H1, individueller Title (≤ 60 Zeichen, Muster „{Leistung} Graz | ident-IT") + Meta-Description (≤ 155 Zeichen, mit CTA), Breadcrumb (UI + Schema), Abschluss-CTA-Sektion („Kostenloses Erstgespräch" → /kontakt/), 2–4 interne Links zu verwandten Leistungen/Referenzen.

### Startseite `/`
**Vorlage: `pages/Home.tsx` im Entwurf – Struktur, Texte und Look 1:1 nach Astro portieren.** Aufbau des Entwurfs:
1. **Hero:** Fullscreen-Hintergrundvideo (dunkel gefiltert, brightness 0.35) + Grain-Textur + Badge „Werbeagentur in Graz – seit 2018" → **H1: „Deine Werbeagentur in Graz für [Typewriter: Webdesign | Online Marketing | Branding | Social Media | SEO]"** → Subline (Fullservice, Keywords) → CTAs „Kostenloses Erstgespräch" + „Unsere Leistungen" → Trust-Zeile (5,0 Google · 13 Bewertungen · Graz, Steiermark · 100+ Kunden) → Scroll-Indikator.
   ⚠️ Video liegt als `hero-bg-video.mp4` (4,5 MB) im Zip → **selbst hosten** (die im Code hinterlegte externe CDN-URL läuft ab!), komprimieren (Ziel < 2 MB, 1080p, ohne Ton), `poster`-Bild für LCP, auf Mobil ggf. statisches Poster statt Video.
2. Intro-SEO-Text: H2 „Fullservice-Werbeagentur in Graz – alles aus einer Hand"
3. Leistungen (#leistungen): H2 „Was wir als Werbeagentur für dich tun" – Karten → Pillar-/Leistungsseiten (auf finale 3-Säulen-Struktur erweitern: Marketing / Grafik / Web)
4. Stats/Counter-Sektion (AnimatedCounter)
5. Prozess: H2 „In 3 Schritten zum Erfolg"
6. USPs: H2 „Was dich bei unserer Werbeagentur erwartet"
7. Zielgruppen/Branchen: H2 „Werbeagentur für Unternehmen in Graz"
8. FAQ: H2 „FAQ – Werbeagentur Graz" (FAQPage-Schema ergänzen)
9. Local: H2 „Werbeagentur in Graz – lokal verwurzelt, digital vernetzt"
10. CTA: H2 „Bereit, durchzustarten?" (heller Abschnitt, Noise-Textur)
Title lt. Keyword-Strategie: „Werbeagentur Graz | ident-IT – Webdesign, Marketing & Grafikdesign". „Werbeagentur Graz" 3–4× natürlich im Text. Zusätzlich einbauen: Referenz-Teaser + Kundenlogos (im Entwurf noch nicht enthalten, von Alt-Seite übernehmen).

### Pillar-Seiten `/leistungen/marketing/`, `/leistungen/grafik/`, `/leistungen/web/`
- Je: Hero mit Leistungsversprechen → Karten der Unterseiten → Referenzen der Kategorie → Prozess/Arbeitsweise → FAQ → CTA.
- 600–900 Wörter, Pillar verlinkt alle Kinder, Kinder verlinken zurück (Breadcrumb + Textlinks).

### Leistungs-Unterseiten
Vorhandene Entwurfsseiten (SEO, Google Ads, Social Media, Webdesign, Grafikdesign, Branding) portieren und an Title/H1-Vorgaben aus `keyword_strategie_final.md` halten. Neue Seiten (Videoproduktion, Drucksorten, Beschriftungen, Onlineshop, Wartung, Online Marketing) im selben Aufbau erstellen: Hero (H1 mit Keyword + Graz) → Problem/Nutzen → Leistungsumfang → ggf. Preise/Pakete → 2–3 Referenzbeispiele → Ablauf in Schritten → FAQ (PAA-Fragen) → CTA. Alt-Texte der WordPress-Seiten NICHT kopieren (Vorgabe aus Keyword-Strategie) – nur als Faktenquelle nutzen.

Besonderheiten:
- **/leistungen/web/webdesign/**: 1-2-3-Prozess (Erstgespräch → Konzept & Design → Launch) gehört laut Strategie HIERHER (nicht nur Startseite); Preisindikation + FAQ „Was kostet eine Website?"; Verweis auf /website-kosten/ und Wartung. Onlineshop-Preisanker „ab 4.900 €" auf /leistungen/web/onlineshop/.
- **/leistungen/web/wartung/**: Vorlage = Live-Seite `https://ident-it.at/pakete/website-wartung/` (bereits 2026 neu gestaltet). Kompletter Inhalt gesichert in `wartung-seite_inhalt-referenz.md` (Tarife Solo 14,99 € Aktion / 69 € / 99 € „Beliebt" / Premium 199 €, Add-ons, FAQ, Fußnote). 1:1 übernehmen, nur ins Teal-Designsystem portieren; Vergleichstabelle responsive; ⚠️ Paketnamen vereinheitlichen (Tabelle vs. Karten auf der Live-Seite widersprechen sich – siehe Referenzdatei).
- **/leistungen/marketing/videoproduktion/**: Referenzvideos (Hochwasserschutz, Marburgerhöfe) einbetten (YouTube nocookie + Consent).
- **/leistungen/grafik/beschriftungen/**: neues Thema, Keywords „Autobeklebung Graz / Fahrzeugbeschriftung Graz / Schaufensterbeschriftung"; bei getrenntem Suchvolumen später splitten.

### /referenzen/
- Grid mit JS-Filter (Alle | Marketing | Grafik | Web), Projekte als Content Collection (Titel, Kunde, Kategorie, Bild, 2–3 Sätze, optional Link).
- Kundenlogo-Leiste am Seitenende (ersetzt /kunden/).

### /website-kosten/
- Konfigurator-Formular 1:1 nachbauen (Seitenanzahl, Funktionen, Onlineshop-Größe, Budget, DSGVO-Checkbox, optional Newsletter). Absenden → /danke/.

### /kontakt/
- Kurzformular (Name, Mail, Telefon optional, Nachricht, DSGVO-Checkbox), NAP-Block, Öffnungszeiten, Maps (erst nach Consent laden oder statisches Bild mit Link), Klick-to-Call/Mail.

### /aktuelles/
- Blog-Index + Einzelseiten. Migrieren: Schulstart-Aktion 2026, Service-Quadrat-Case, Eisenwort-Case, Förderungen-Beitrag + weitere aus Sitemap. Alte Datums-URLs → 301 auf neue Slugs.

---

## 6. Globale Komponenten

1. `Layout.astro` – SEO-Head (Props: title, description, canonical, ogImage, noindex), Schema-Slots, Header, Footer, ContactButtons.
2. `Header.astro` / `Footer.astro`
3. `Breadcrumb.astro` (UI + BreadcrumbList-JSON-LD)
4. `CtaSection.astro` – wiederverwendbarer Abschluss-CTA
5. `FaqAccordion.astro` – mit FAQPage-Schema
6. `PriceTable.astro` – für Wartung/SEO/Marketing-Pakete
7. `ReferenceCard.astro` / `LogoWall.astro`
8. `ContactButtons.astro` – **siehe unten, fixe Vorgabe von Philipp**

### ContactButtons.astro (rechts unten: Tel, Mail & WhatsApp)

Ein fixes Element rechts unten mit **drei Icons** (Telefon, E-Mail, WhatsApp) als vertikale Pill. Basiert auf Philipps WhatsApp-Komponente – WhatsApp-SVG unverändert übernehmen. Vor `</body>` im Layout einbinden.

```astro
---
// src/components/ContactButtons.astro
interface Props { waText?: string }
const { waText = "Hallo, ich habe eine Frage zu " } = Astro.props;
const phone = "436609449688";
const mail = "office@ident-it.at";
const text = encodeURIComponent(waText);
---

<div class="iIT_contact-fab" aria-label="Schnellkontakt">
  <a href={`tel:+${phone}`} class="iIT_fab-btn iIT_fab-tel" aria-label="Jetzt anrufen">
    <svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor" aria-hidden="true">
      <path d="M6.62 10.79a15.05 15.05 0 0 0 6.59 6.59l2.2-2.2a1 1 0 0 1 1.02-.24c1.12.37 2.33.57 3.57.57a1 1 0 0 1 1 1V20a1 1 0 0 1-1 1C10.61 21 3 13.39 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.24.2 2.45.57 3.57a1 1 0 0 1-.25 1.02l-2.2 2.2Z"/>
    </svg>
  </a>
  <a href={`mailto:${mail}`} class="iIT_fab-btn iIT_fab-mail" aria-label="E-Mail schreiben">
    <svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor" aria-hidden="true">
      <path d="M20 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2Zm0 4-8 5-8-5V6l8 5 8-5v2Z"/>
    </svg>
  </a>
  <a
    href={`https://wa.me/${phone}?text=${text}`}
    target="_blank"
    rel="noopener noreferrer"
    class="iIT_fab-btn iIT_fab-wa"
    aria-label="Kontakt über WhatsApp"
  >
    <svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor" aria-hidden="true">
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.149-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884a9.82 9.82 0 0 1 6.988 2.896 9.82 9.82 0 0 1 2.892 6.994c-.003 5.45-4.437 9.885-9.884 9.885M20.52 3.449C18.24 1.245 15.24 0 12.045 0 5.463 0 .104 5.359.101 11.947c0 2.096.549 4.142 1.588 5.945L0 24l6.335-1.652a11.9 11.9 0 0 0 5.71 1.454h.006c6.585 0 11.946-5.359 11.949-11.948 0-3.192-1.24-6.192-3.495-8.445"/>
    </svg>
  </a>
</div>

<style>
  .iIT_contact-fab {
    position: fixed;
    right: 20px;
    bottom: 20px;
    z-index: 999;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .iIT_fab-btn {
    display: grid;
    place-items: center;
    width: 54px;
    height: 54px;
    border-radius: 50%;
    color: #fff;
    box-shadow: 0 4px 14px rgb(0 0 0 / 0.25);
    transition: transform .15s ease, box-shadow .15s ease;
  }
  .iIT_fab-btn:hover {
    transform: scale(1.07);
    box-shadow: 0 6px 18px rgb(0 0 0 / 0.3);
  }
  .iIT_fab-tel  { background: linear-gradient(135deg, #0ABAB5, #3DD6D0); color: #0d1117; }
  .iIT_fab-mail { background: #151b23; border: 1px solid rgba(149, 187, 204, 0.25); }
  .iIT_fab-wa   { background: #25D366; }
  @media (prefers-reduced-motion: reduce) {
    .iIT_fab-btn { transition: none; }
  }
</style>
```

Hinweise: Tel-/Mail-Klicks als GTM-Events taggen (Conversion, siehe Abschnitt 9). Auf sehr kleinen Screens Buttons ggf. auf 48 px reduzieren. Die Telefonnummer steht im Impressum – passt.

---

## 7. SEO-Technik (Pflichtenheft)

1. **Meta/Canonical/OG** pro Seite über zentrale Layout-Props; OG-Image 1200×630 neu erstellen.
2. **Strukturierte Daten (JSON-LD):**
   - Sitewide `ProfessionalService` (Werbeagentur): Name „ident-IT", address (Mariahilferstraße 1, 8020 Graz, AT), telephone +43 660 9449688, email, geo 47.0711162/15.4333155, openingHoursSpecification (Mo–Do 08–17, Fr 08–12), priceRange „€€", sameAs (Facebook identITsolutions, Instagram, Google-Maps-Profil), aggregateRating erst nach Prüfung der Richtlinien.
   - `Service` auf jeder Leistungsseite, `BreadcrumbList` überall, `FAQPage` bei FAQs, `Article` im Blog.
3. **Lokales SEO:** NAP exakt identisch auf Website, Google Business Profile und Verzeichnissen (WKO, Herold). Startseite verlinkt GBP; Bewertungen prominent.
4. **Interne Verlinkung (WICHTIG – explizite Anforderung von Philipp):**
   - Silo: Startseite → 3 Pillars → alle Unterseiten; jede Unterseite verlinkt zurück auf Pillar + 2–3 thematische Geschwister (z. B. Webdesign ↔ SEO ↔ Wartung; Branding ↔ Drucksorten; Social Media ↔ Videoproduktion ↔ Google Ads).
   - Jede Leistungsseite verlinkt: passende Referenzen, /website-kosten/ (wo Preisfrage naheliegt) und /kontakt/.
   - Footer: alle Leistungsseiten als Quicklinks (sitewide Linkjuice).
   - Blogposts verlinken kontextuell auf die passende Leistungsseite (Money-Page), Leistungsseiten zurück auf vertiefende Blogposts.
   - Breadcrumbs auf allen Unterseiten (UI + Schema).
   - Ankertexte: beschreibend mit Keyword-Bezug variieren („Webdesign aus Graz", „unsere SEO-Betreuung"), nicht immer identisch, kein Stuffing.
   - Regel: **keine verwaiste Seite** – jede indexierbare Seite hat mind. 3 eingehende interne Links; Prüfung vor Launch per Crawl.
5. **Performance-Budget:** LCP < 2,0 s, CLS < 0,1, INP < 200 ms. Keine Renderblocker, kritisches CSS inline, Hero-Bild `fetchpriority="high"`, Rest lazy. Kein externes Font-/Script-CDN außer notwendigem Tracking.
6. **robots.txt** + XML-Sitemap; `/danke/`, `/impressum/`, `/datenschutz/`, `/agb/` → `noindex, follow`.
7. **404-Seite** mit Suche/Quicklinks.
8. **Launch-Checkliste:** Redirects testen (Statuscodes!), Search Console Property + Sitemap einreichen, Crawl mit Screaming Frog o. ä., Web Vitals messen.

---

## 8. Redirects (301, `.htaccess`)

**Wichtig:** Vor dem Launch die komplette XML-Sitemap der Alt-Seite ziehen (`ident-it.at/sitemap_index.xml` bzw. WP-SEO-Plugin) und JEDE indexierte URL mappen – insbesondere alle Blog-Posts (alte Datums-Permalinks!). Basis-Mapping:

```
/leistungen/webdesign/                → /leistungen/web/webdesign/
/leistungen/grafikdesign/             → /leistungen/grafik/
/leistungen/social-media-marketing/   → /leistungen/marketing/social-media/
/leistungen/seo-agentur-graz/         → /leistungen/marketing/seo/
/leistungen/videoproduktion-graz/     → /leistungen/marketing/videoproduktion/
/leistungen/marketing-agentur/        → /leistungen/marketing/
/pakete/                              → /website-kosten/
/pakete/marketing-betreuung/          → /leistungen/marketing/
/pakete/seo-betreuung/                → /leistungen/marketing/seo/
/pakete/website-wartung/              → /leistungen/web/wartung/
/kunden/                              → /referenzen/
/termin/                              → /kontakt/
/home                                 → /
/jobs/                                → /ueber-uns/   (falls Jobs entfällt)
/aktuelles/category/*                 → /aktuelles/
/2021/03/31/foerderungen-fuer-digitalisierungsmassnahmen/ → /aktuelles/foerderungen-digitalisierung/
… (Rest aus Sitemap ergänzen)
```

Bleiben identisch: `/`, `/leistungen/`, `/referenzen/`, `/ueber-uns/`, `/kontakt/`, `/website-kosten/`, `/aktuelles/`, `/impressum/`, `/datenschutz/`, `/agb`.

---

## 9. Tracking, Formulare & SEA-Readiness

- **Cookie-Consent: CCM19** (Philipps Standard-Setup) mit **Google Consent Mode v2**.
- **GTM `GTM-TX5RHLD`** weiterverwenden (Container aufräumen). Events: Formular-Submit (→ /danke/), Tel-Klick, Mailto-Klick, WhatsApp-Klick – identisches Muster wie bei Service-Quadrat/Top Trock.
- **/danke/** als Conversion-Ziel für Google Ads; noindex.
- **Formular-Backend:** statische Site → kleines PHP-Mail-Script am SiteGround-Server (Honeypot + Zeitfalle als Spamschutz, danach Redirect auf /danke/). Kein externer Formulardienst nötig.
- SEA-Landingpage-Tauglichkeit: Leistungsseiten haben klare H1 = Anzeigenversprechen, CTA above the fold, Telefonnummer sichtbar → Quality Score.

---

## 10. Recht & Barrierefreiheit

- **Impressum/Datenschutz/AGB:** Impressumsdaten sind bestätigt (ident-IT GmbH, FN 488011p) – Entwurfsseiten `Impressum.tsx`/`Datenschutz.tsx` als Basis. Datenschutzerklärung auf neuen Stack anpassen (österr. Recht: § 165 TKG 2021, DSG; Behörde: Datenschutzbehörde, Barichgasse 40–42, 1030 Wien) – nur tatsächlich eingesetzte Dienste nennen (SiteGround-Hosting, GTM/Ads, CCM19, ggf. YouTube nocookie, Maps).
- **Barrierefreiheit (BaFG-Niveau, natives HTML statt Overlay-Plugin):** semantische Struktur, WCAG-AA-Kontraste (im Entwurf bereits umgesetzt – beibehalten; Teal `#0ABAB5` auf Weiß NICHT für Fließtext), Fokus-Styles, Alt-Texte, Tastaturbedienbarkeit, `prefers-reduced-motion` (Hero-Video pausieren/Poster zeigen).

---

## 11. Design-Richtung (fix durch Entwurf definiert)

**Leitprinzip (Vorgabe von Philipp): Ein Hingucker – und trotzdem einfach zu bedienen und userfriendly.** Konkret heißt das:

- **Wow konzentriert, nicht flächig:** Der Wow-Effekt sitzt im Hero (Video, Typewriter, Glow) und in wenigen gezielten Momenten. Der Rest der Seite ist ruhig, klar strukturiert und schnell erfassbar. Effekte sind Zugabe, nie Voraussetzung – Inhalte sind sofort lesbar, auch bevor/ohne Animation.
- **Nichts stört die Bedienung:** kein Scroll-Hijacking, kein Custom-Cursor, keine Auto-Sounds, keine Overlays, die Content blockieren, keine Animation länger als ~0,6 s auf dem kritischen Pfad. Hover-Effekte haben immer ein Touch-Äquivalent.
- **Klare Nutzerführung:** jede Leistung in max. 2 Klicks erreichbar, sticky Header, auf jeder Seite sichtbarer Kontaktweg (Header-Tel + ContactButtons + Abschluss-CTA). Eindeutige Button-Beschriftungen („Kostenloses Erstgespräch", nicht „Los geht's").
- **Lesbarkeit vor Effekt:** Fließtext nie auf bewegtem Hintergrund, WCAG-AA-Kontraste, Zeilenlänge ~60–80 Zeichen, großzügiger Weißraum (bzw. Dark-Raum), klare Hierarchie H1→H2→H3.
- **Mobile first:** Touch-Ziele ≥ 44 px, einfaches Burger-Menü, ContactButtons verdecken keine Inhalte/CTAs, Hero funktioniert auch als statisches Poster.
- **Performance ist Teil der UX:** Budget aus Abschnitt 7 gilt trotz Video und Effekten; Animationen GPU-freundlich (transform/opacity), `prefers-reduced-motion` respektieren.
- **Formulare kurz:** nur nötige Felder, klare Fehlermeldungen, ein Klick zum Absenden.

Der Prototyp definiert das Designsystem verbindlich – **„Neumorphismus Dark + Teal"**:

| Token | Wert |
|---|---|
| Teal (Primär/Akzent) | `#0ABAB5` · dunkel `#088F8C` · hell `#3DD6D0` |
| Petrol | `#1A6B6A` |
| Steel Blue (Sekundär/Text gedämpft) | `#95BBCC` |
| Charcoal | `#323131` |
| Hintergründe | `#0d1117` (Base) · `#151b23` (Cards) · `#111820`/`#1a2332` (Wechsel-Sektionen) |
| Brand-Gradient | `linear-gradient(135deg, #1A6B6A, #0ABAB5, #95BBCC)` |
| Typografie | **Raleway** (Display/Headlines, extrabold) + **Roboto** (Body) – lokal hosten |
| Stil-Elemente | Neumorphism-Cards (weiche Schatten auf Dark), Gradient-Borders, Grain/Noise-Textur, Glow-Buttons, Gradient-Text |

- Dark Theme ist Standard (Entwurf: `defaultTheme="dark"`).
- Animationen aus dem Entwurf schlank nachbauen: ScrollReveal (IntersectionObserver), TypewriterText, AnimatedCounter, Glow-Hover. **Ohne** framer-motion/GSAP – CSS + wenig Vanilla-JS, `prefers-reduced-motion` respektieren. Schwere Komponenten des Prototyps (ParticleCanvas, ParticleNetwork, Floating3DCards, MorphingBlob) nur übernehmen, wo sie im finalen Home.tsx tatsächlich verwendet werden – Performance vor Show.
- Alle Sektionshintergründe/Overlays wie im Entwurf (Video-Overlay-Gradients, Glow-Lines zwischen Sektionen).
- Referenz-Mockups/Bilder: bestehende Projektbilder von der Alt-Seite übernehmen (Uploads sichern!), fehlende Mockups erzeugt Philipp via Higgsfield/Adobe.
- ⚠️ **Logo-Thema:** Im Zip liegen nur die ALTEN Lime-Logos (`Ident-IT_Logo_dunkel_oH.png`) + ein Teal-**SVG-Nachbau** (`Logo.tsx`), der vom echten Logo abweicht (Pfeil-Symbol statt Original-Form). → Philipp liefert das finale Teal-Logo als SVG, sonst Original-Logoform in Teal nachbauen.

---

## 12. Offene Punkte – Input von Philipp VOR Umsetzung

| # | Punkt | Status |
|---|---|---|
| 1 | Finale Keyword-Freigabe (Basis liegt in Zips, ggf. neue SISTRIX-Exporte) → Slugs/Titles/H1 fixieren | mit Philipp |
| 2 | Entwurf **Startseite** | ✅ erhalten (Zips) |
| 3 | Entwurf **Wartung** | ✅ Live-Seite /pakete/website-wartung/ ist die Vorlage; Inhalt gesichert in `wartung-seite_inhalt-referenz.md` |
| 4 | Impressum ident-IT GmbH, FN 488011p | ✅ bestätigt |
| 5 | SEM-Split SEO + Google Ads | ✅ entschieden (lt. Entwurf) |
| 6 | Finales **Teal-Logo als SVG** | Philipp erstellt es – bis dahin Platzhalter, Logo-Slot vorbereiten |
| 7 | Hero-Video final: `hero-bg-video.mp4` aus Zip verwenden oder neues via Higgsfield? Komprimieren + selbst hosten | klären |
| 8 | /jobs/ behalten? | Default: entfällt |
| 9 | Referenzbilder, Kundenlogos, Portrait Philipp | sammeln (Alt-Site sichern) |
| 10 | Alte Blog-Posts: welche migrieren? | Sitemap-Liste vorlegen |
| 11 | Google Business Profile: Kategorie „Werbeagentur", Website-Link, Fotos, Bewertungen pushen (Crediso hat 106!) | nach Launch |

### Wichtige Dateien in den Zips (Referenz für die Umsetzung)

- **Design/Code-Vorlage:** `redesign/client/src/` – `pages/Home.tsx` (Startseite!), alle Leistungsseiten, `components/` (Navigation, Footer, GlowButton, NeuCard, ScrollReveal, TypewriterText, AnimatedCounter, SEOHead, PageHero …), `index.css` (Design-Tokens), `lib/constants.ts` (BRAND-Daten, NAV_LINKS, Farben)
- **Assets:** `hero-bg-video.mp4`, `Ident-IT_Logo_dunkel_oH.png`, `Ident-IT_Logo_Leistungen_dunkel_oH.png`, `favicon_120x120.png`
- **SEO-Recherche:** `keyword_strategie_final.md`, `seo_keyword_mapping.md`, `sistrix_data.md`, `sistrix_werbeagentur_graz.md`, `ahrefs_keywords.md`, `serp_*.md` (9 SERP-Analysen), `wettbewerber_*.md`
- Ignorieren: `visual_check_*.md`, `pasted_file_*`, generator-spezifische Debug-/Dialog-Komponenten (Dialog-Komponente in `components/`, Debug-Ordner mit doppelten Unterstrichen in `public/`) sowie alle externen, ablaufenden CDN-URLs

---

## 13. Arbeitsreihenfolge

**Übergabe/Setup:** Im Projektordner liegen: dieses Briefing (Repo-Root), `wartung-seite_inhalt-referenz.md`, und die beiden Zips entpackt unter `referenz/` (Prototyp-Code + Recherche-MDs + Assets). `referenz/` kommt in die `.gitignore` – der Prototyp-Code dient nur lokal als Vorlage und landet wegen der Neutralitätsregel (enthält Generator-Dateinamen) nicht in der Git-History. Assets daraus (Video, Favicon, Logos) werden bereinigt nach `src/assets/` bzw. `public/` übernommen.

1. Zips entpacken, Prototyp + Recherche-Dateien lesen (`Home.tsx`, `constants.ts`, `index.css`, `keyword_strategie_final.md`). Assets sichern (Video komprimieren, Logos, Favicon).
2. Repo + Astro-Setup, Konventionsdatei, Design-Tokens aus Entwurf, Header/Footer/ContactButtons.
3. Startseite aus `Home.tsx` portieren + /kontakt/ + /danke/ + rechtliche Seiten.
4. Pillar-Seiten Marketing/Grafik/Web; vorhandene Entwurfsseiten portieren, neue Unterseiten (Videoproduktion, Drucksorten, Beschriftungen, Onlineshop, Wartung) erstellen.
5. Referenzen (Collection) + Über uns + Website-Kosten-Konfigurator + Blog-Migration.
6. SEO-Technik: Schema, Sitemap, robots, `.htaccess`-Redirects (vollständige Map aus Alt-Sitemap), interne Verlinkung nach Abschnitt 7 prüfen.
7. Tracking: CCM19 + Consent Mode v2 + GTM-Events.
8. QA: Abnahmekriterien aus Abschnitt 14 abarbeiten, Redirect-Test, Mobile → Deploy auf SiteGround → Search Console.

---

## 14. Abnahmekriterien (Definition of Done – harte Anforderungen von Philipp)

Vor Launch muss jede der vier Anforderungen nachweisbar erfüllt sein:

### 1. Barrierefrei (WCAG 2.1 AA / BaFG-Niveau)
- Kontraste ≥ 4,5:1 für Text (≥ 3:1 für große Schrift/UI-Elemente) – Teal `#0ABAB5` und Steel Blue `#95BBCC` auf den Dark-Hintergründen gezielt gegenprüfen
- Volle Tastaturbedienung inkl. Dropdown-Navigation und Mobile-Menü; sichtbarer Fokus-Ring; Skip-Link zum Hauptinhalt
- Semantik: Landmarks (header/nav/main/footer), saubere Heading-Hierarchie, Formular-Labels + zugängliche Fehlermeldungen
- Alt-Texte für alle Inhaltsbilder (dekorative leer); Kontakt-FAB und alle Touch-Targets ≥ 44 px
- `prefers-reduced-motion`: sämtliche Animationen aus, Hero-Video pausiert → Poster; Video ohne Ton, keine Blitz-/Flackereffekte
- **KEIN Accessibility-Overlay** (OneTap fliegt raus) – nativ lösen; die eigene Seite ist Schaufenster für Philipps BaFG-Beratung
- Nachweis: Lighthouse Accessibility ≥ 95 + axe DevTools ohne Criticals + manueller Tastatur-Durchlauf

### 2. DSGVO-konform
- **Null Third-Party-Requests vor Consent**: Fonts, Video, Icons, alle Assets self-hosted; kein Google-Fonts-CDN, keine externen Skripte
- GTM/Google Ads laden erst nach CCM19-Einwilligung (Consent Mode v2); Google Maps & YouTube als 2-Klick-Lösung (nocookie)
- Formulare: Datenminimierung, DSGVO-Checkbox mit Link, Versand über eigenen SiteGround-Server (EU), TLS
- Datenschutzerklärung deckt exakt den realen Stack ab
- Nachweis: Inkognito-Test ohne Consent → Netzwerk-Tab zeigt 0 externe Requests

### 3. Performant
- Budgets: Lighthouse Performance ≥ 95 (mobil), LCP < 2,0 s, CLS < 0,1, INP < 200 ms, JS gesamt < 100 KB
- Hero-Video < 2 MB, `preload="metadata"` + Poster-Bild als LCP-Element (`fetchpriority="high"`); auf Mobil bzw. Datensparmodus nur Poster
- Bilder via `astro:assets` (AVIF/WebP), width/height gesetzt (kein CLS), lazy außer above the fold
- Fonts: WOFF2 subsetted, `font-display: swap`, Preload; kritisches CSS inline
- `.htaccess`: Kompression (Brotli/Gzip) + Cache-Header für Assets
- Animationen nur mit `transform`/`opacity` (GPU), keine Layout-Trigger

### 4. Cool & modern
- Look = Entwurf (Abschnitt 11): Dark-Teal-Neumorphismus, Video-Hero, Gradient-Akzente, Micro-Interactions, Typewriter-H1
- **Konfliktregel:** Wow-Effekt ja – aber niemals auf Kosten von Punkt 1–3. Jeder Effekt braucht einen Reduced-Motion-Fallback und darf die Budgets nicht reißen. Im Zweifel Effekt vereinfachen statt Performance/Barrierefreiheit opfern.
