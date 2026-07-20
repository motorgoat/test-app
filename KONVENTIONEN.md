# Projektkonventionen – ident-it.at

Verbindliche Regeln für alle Arbeiten in diesem Repo. Grundlage: `BRIEFING.md`.

## 1. Code & Struktur

- **Astro, statisch** (`output: 'static'`) – kein SSR, keine UI-Frameworks, keine Animations-Libraries (kein framer-motion, kein GSAP). Animationen mit CSS + wenig Vanilla-JS (`IntersectionObserver`).
- **Prefix-Regel:** Eigene Klassen/IDs immer mit Prefix `iIT_` (z. B. `iIT_contact-fab`). Tailwind-Utilities brauchen keinen Prefix.
- Design-Tokens liegen zentral in `src/styles/global.css` (`@theme`). Keine Hex-Werte in Komponenten hartcodieren.
- Marken-/Kontaktdaten (NAP, Telefon, Öffnungszeiten, Social) kommen **ausschließlich** aus `src/lib/site.ts`.
- Bilder über `astro:assets` (AVIF/WebP, width/height gesetzt), lazy außer above the fold.
- Fonts nur lokal (Fontsource-Pakete) – **kein externes Font-/Script-CDN**.
- `referenz/` (Prototyp-Code + Recherche) bleibt lokal und steht in `.gitignore` – dient nur als Vorlage, landet nie in der Git-History.

## 2. Sprache & Ton (alle Texte)

- Deutsch, **du-Form** (wie bisherige Website).
- **„Philipp"**, nie „Phil" – in Texten und Signaturen.
- Niemals „kümmere ich mich um" → stattdessen „mache ich / erledige ich / schau ich mir an".
- Button-Beschriftungen eindeutig: „Kostenloses Erstgespräch", nicht „Los geht's".

## 3. Neutralität (verbindlich)

Keine Erwähnung von KI-Tools, Coding-Assistenten oder Website-Generatoren – nirgends:
nicht im Quellcode, nicht in Kommentaren, nicht in Meta-Tags (kein `generator`-Tag),
nicht in Commit-Messages, nicht in Doku oder README.

## 4. SEO-Basics (jede Seite)

- Genau **eine H1**; Title ≤ 60 Zeichen, Muster „{Leistung} Graz | ident-IT"; Description ≤ 155 Zeichen mit CTA.
- Breadcrumb (UI + Schema) auf allen Unterseiten; Abschluss-CTA-Sektion; 2–4 interne Links zu verwandten Leistungen/Referenzen.
- **Keine verwaiste Seite:** jede indexierbare Seite hat mind. 3 eingehende interne Links (vor Launch per Crawl prüfen).
- `noindex, follow` für: `/danke/`, `/impressum/`, `/datenschutz/`, `/agb/` (auch im Sitemap-Filter in `astro.config.mjs` eingetragen).
- Alt-Texte der alten WordPress-Seiten nie kopieren – nur als Faktenquelle nutzen.

## 5. Performance-Budget (Abnahmekriterium)

- Lighthouse Performance ≥ 95 (mobil), LCP < 2,0 s, CLS < 0,1, INP < 200 ms, JS gesamt < 100 KB.
- Animationen nur mit `transform`/`opacity`; `prefers-reduced-motion` immer respektieren.
- Hero-Video < 2 MB, selbst gehostet, `preload="metadata"` + Poster als LCP-Element.

## 6. Barrierefreiheit (Abnahmekriterium, WCAG 2.1 AA)

- Kontraste ≥ 4,5:1 für Text; Akzent-Türkis `#00b4a8` und `#00cca8` sind auf den Dark-Hintergründen textsicher. Logo-Blau `#0078a8` ist rein dekorativ (Verläufe/Glows) – nie für Fließtext.
- Volle Tastaturbedienung (inkl. Dropdowns/Mobile-Menü), sichtbarer Fokus-Ring, Skip-Link.
- Touch-Targets ≥ 44 px; Alt-Texte für Inhaltsbilder (dekorative leer).
- **Kein Accessibility-Overlay** – nativ lösen.

## 7. DSGVO (Abnahmekriterium)

- **Null Third-Party-Requests vor Consent.** GTM/Ads erst nach CCM19-Einwilligung (Consent Mode v2).
- Google Maps & YouTube nur als 2-Klick-Lösung (nocookie).
- Formulare: Datenminimierung, DSGVO-Checkbox, Versand über eigenen SiteGround-Server.

## 8. Redirect-Pflege

- Jede URL-Änderung sofort in `public/.htaccess` als 301 nachziehen.
- Vor Launch: komplette Alt-Sitemap mappen, Statuscodes testen.

## 9. Deploy

- `npm run build` → Inhalt von `dist/` per FTP/SSH auf den SiteGround Cloud Server (Webroot) hochladen.
- `.htaccess` liegt in `public/` und landet automatisch im Build.

## 10. Git

- Commit-Messages auf Deutsch, präzise, im Imperativ („Ergänze Wartungsseite", nicht „WIP").
- Regel aus Punkt 3 gilt auch hier.

## 11. EEAT – Autoren-Expertise (Blog & Fachseiten)

Google (und Leser) müssen erkennen können, dass hinter jedem Text eine echte,
qualifizierte Person steht. Verbindlich für alle Blog-Posts und Fachinhalte:

- **Sichtbarer Autor:** Jeder Beitrag nennt „Philipp Golob" als Autor – nie „admin",
  „Redaktion" oder anonym. Autor-Daten kommen zentral aus `AUTHOR` in `src/lib/site.ts`.
- **Autoren-Bio am Artikel:** Kurze Bio-Box direkt am Beitrag (Rolle, Jahre Erfahrung,
  relevante Qualifikationen/Zertifikate) mit Foto und Link zur Autorenseite.
- **Autorenseite:** `/ueber-uns/` dient als Autorenprofil (Gründer-Block laut
  Über-uns-Brief); Blog-Bios verlinken dorthin.
- **Fachprofile verlinken:** LinkedIn bzw. weitere Fachprofile als `sameAs` im
  Person-Schema und sichtbar in der Bio (URLs liefert Philipp).
- **Erst-Hand-Erfahrung statt Allgemeinplätze:** Konkrete Praxisbeispiele schreiben
  („bei einem Kundenprojekt haben wir X getestet …") – keine austauschbaren Ratgebertexte.
- **Identity-/Security-Themen:** Besonders hier nachweisbare Fach-Referenzen und
  Zertifizierungen nennen.
- **Schema:** `Article` mit `author` → `Person` (Name, jobTitle, url auf /ueber-uns/,
  sameAs) auf jedem Blog-Post; die Autorenseite bekommt ein eigenes Person-Schema.
- Es zählt nicht das Meta-Tag, sondern dass die Kompetenz auf der Seite erkennbar ist.
