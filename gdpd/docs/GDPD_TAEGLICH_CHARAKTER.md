# gdpd – Täglich spielen und dein eigener Charakter (Spec v1)

This spec is for implementers, so it is written in English. Every text a player sees is in simple, warm German
(du-form) and is written here exactly as it should appear.

It builds on `GDPD_7_TAGE.md` (the 7 days, goal card, chip, success/fail, save section `[schoepfung]`) and
`GDPD_REGELN.md`. It implements the two requirement lists in `NAECHSTE_SCHRITTE.md`: „Ausrichtung wie Duolingo“
and „Eigener Charakter“. Everything not changed here stays as it is.

---

## 0. Key decisions (summary)

| topic | decision |
|---|---|
| game day | local time, **the day changes at 03:00** („Spieltag“ = local date of `now − 3 h`) |
| new levels | **one new level per Spieltag**: day n+1 opens on a later Spieltag than the first win of day n; missed days never pile up (always only one new level waiting) |
| after day 7 | every Spieltag a **„Welt des Tages“**: a validated pool board of one of days 2–7, chosen from the Spieltag number (same for everyone in the same time zone) |
| streak day | a Spieltag on which the player **wins one level** (the new day, a replay of an old day, or the Welt des Tages) |
| streak protection | „Serienschutz“: hold at most 2; +1 at every 7-day milestone; buy for 5 coins; used automatically for missed days, only if it saves the whole gap |
| after a win | **„Weiterbauen“** in the same level: no twist limit, no fail, the world keeps growing, wishes and faith continue, coins for growth; stars stay those of the winning attempt (more stars = „Nochmal“ on a fresh board) |
| locked level | tile shows „Morgen“; tap → „Morgen geht's weiter: Tag 3 · Tiere“; overview shows a countdown |
| reminders | at most one per day, ~23.5 h after the start of the last **winning** session, clamped to 08:00–21:30, only if the streak day is not done; ladder: +1, +2, +4 days, then a friendly final message on +7 and silence until the player returns |
| notification plugin | **own tiny Android v2 plugin „GdpdReminder“** (Kotlin, `AlarmManager.setAndAllowWhileIdle`, inexact, reboot-safe, large icon = the player's character). Built in CI with the Gradle wrapper of the Godot 4.3 Android build template. No maintained third-party plugin supports Godot 4.3 (section 6.1) |
| permission | Android 13+: `POST_NOTIFICATIONS` asked after the first win of day 1, by the character first („Soll ich dich morgen erinnern?“), then `OS.request_permission()`; no exact-alarm permission |
| character | created at first launch in **4 short steps** (< 1 min, „Würfeln“ button): 6 bases, palettes, face, 3 accessory slots, name, tone (lieb / frech / streng). 2D layered SVG parts, white fills tinted with `modulate`, untinted ink lines |
| character's job | all coach bubbles, card intros, praise, streak and comeback lines and the notifications come from it, with its face and expression |
| test | „Nächster Tag (Test)“ only when `OS.is_debug_build()` (editor runs and the `--export-debug` APK from CI) |

---

## 1. Daily model

### 1.1 Time source and the Spieltag

All daily logic reads the time from one function, so tests, the tour and the test button can move it:

```gdscript
## Game (game.gd)
var clock_override := -1        # tests/tour: fixed local unix time; -1 = system clock
var debug_day_offset := 0       # „Nächster Tag (Test)“: whole days added; only honoured in debug builds

## Local time as „unix seconds of the local wall clock“ (the local date/time read as if it were UTC).
func now_local() -> int:
	var t := clock_override
	if t < 0:
		t = int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system(false)))
	if OS.is_debug_build():
		t += debug_day_offset * 86400
	return t
```

Pure helpers in a new `scripts/daily.gd` (`class_name Daily`, static functions only, no nodes, fully testable):

```gdscript
const DAY_START_HOUR := 3                     # the Spieltag changes at 03:00 local time
static func day_key(local_unix: int) -> int:  # days since 1970-01-01 of (local time − 3 h)
	return floori(float(local_unix - DAY_START_HOUR * 3600) / 86400.0)
static func next_boundary(local_unix: int) -> int:   # local unix of the next 03:00
	return (day_key(local_unix) + 1) * 86400 + DAY_START_HOUR * 3600
static func weekday(key: int) -> int:         # 0 = Monday … 6 = Sunday (German week)
	return (int(Time.get_datetime_dict_from_unix_time(key * 86400 + 43200)["weekday"]) + 6) % 7
```

**Why 03:00 and not midnight.**
- Players who play around midnight (23:40–00:20) stay in one Spieltag: their win counts for „tonight“, the level they
  just finished is not suddenly „yesterday“, and the streak does not need a second win after midnight.
- A new level never appears at midnight, so the game never rewards staying up („noch 10 Minuten bis Tag 4“). The
  countdown (1.6) hides the exact time in the evening.
- Reminders are only sent between 08:00 and 21:30 (section 5), so they always fall inside one Spieltag.
- Daylight saving time in Europe switches between 02:00 and 03:00. With the boundary at 03:00 the doubled hour in
  autumn lies before the boundary and is handled by the „clock went back a little“ rule (1.7); the missing hour in
  spring does not touch the boundary.

### 1.2 How the 7 days unlock by date

New saved data (section 1.8): `won_key[n]` = Spieltag of the first win of day n (−1 = not won or unknown), and
`last_new_key` = Spieltag of the latest **first** win of any day.

```
day_unlocked(1)  = true
day_unlocked(n)  = won(n − 1)                                   # as before: the previous day is solved …
                   and (won(n) or n == next_new_day())          # … and n is either replayable or today's new one
next_new_day()   = the first n with not won(n) (8 = none left)
new_day_open()   = next_new_day() <= 7 and (today_key > last_new_key)
```

- A day that is won stays replayable forever (stars, practice).
- The next new day is **open** only on a Spieltag after the last first win. On the day of a first win it is
  **„morgen“** (locked until tomorrow).
- Missed Spieltage do not pile up: coming back after 5 days opens exactly one new day.
- `day_free` (old save) is kept for compatibility and set to `next_new_day()` when the new day is open, else to
  `next_new_day() − 1` (the overview reads the new functions, not `day_free`).
- „Freies Spiel“ stays unlocked by `world_done` (or `tutorial_done` for old players); it is never date-locked.

### 1.3 Welt des Tages (after day 7)

From the Spieltag after the first win of day 7, every Spieltag has one „Welt des Tages“ (WdT). It reuses a
**validated pool board** of the 7 days, so it is always solvable and uses exactly the day systems already tested:

```
template(key) = 2 + posmod(key, 6)                  # days 2..7 in turn: every type once in 6 days, never twice in a row
board(key)    = 1 + posmod(floori(key / 6.0), pool_size(t) − 1)   # skip board 0 (day 1 tutorial board; days 2–7 too)
```

- Config = `Days.config(template)` (goal, limit, stars, systems, choices) with the title replaced: card caps
  „Welt des Tages · Freitag“, title = the template's goal („Lass 5 Wälder wachsen“), intro line from the character
  (section 4.6). 6 × 19 = 114 different worlds before one repeats.
- The goal is the template's validated goal (short by construction: 12–18 twists). Do **not** shorten targets
  without re-running the model (`GDPD_7_TAGE.md` 8).
- Mercy (+2 twists per fail, max +6) works per Spieltag (`wdt_fails`, reset at the next Spieltag).
- Stars are stored per Spieltag (`wdt_stars`, last 14 keys) and in a counter `wdt_total` (worlds won).
- After a win: Weiterbauen (section 2) and „Morgen gibt es eine neue Welt.“
- The WdT does **not** use the day LCG seed of the pool board for anything new: replays are identical, which is
  wanted (a friend in the same time zone gets the same world; sharing later).

### 1.4 What completes a streak day

A Spieltag counts for the streak („Serientag“) the moment the player **wins one level** on it:
the new day, any replay of days 1–7, or the Welt des Tages. Free play does not count (it has no quick win).

- Only the first win of a Spieltag changes the streak; later wins only improve stars.
- A fail never counts and never costs anything.
- The win card shows the streak step (section 1.5) right after the stars.
- `session_anchor` (minute of day of the start of the session that completed the streak day) is stored for the
  reminder time (section 5).

### 1.5 Streak and Serienschutz (streak protection)

State: `streak`, `streak_best`, `streak_last` (Spieltag of the last streak day, −1 = none), `shields` (0–2),
`streak_days` (Spieltage of the last 21 streak days), `shield_days` (Spieltage bridged by a shield, last 21).

**Day check** – runs at app start, on resume, and when the Spieltag changes while the app is open (checked once per
second only while the overview is open, else at the next card):

```
missed = today_key − streak_last − 1          (only if streak > 0 and streak_last >= 0)
missed <= 0                 → nothing
1 <= missed <= shields      → shields −= missed; shield_days += those keys; streak_last = today_key − 1
                              (streak unchanged: protected days do not add); comeback = "saved"
missed >  shields           → streak = 0 (shields are NOT used: a shield never burns for nothing); comeback = "lost"
```

**On a streak day win** (Spieltag K):

```
streak_last == K       → nothing
otherwise              → streak += 1; streak_last = K; streak_days += K; streak_best = max(streak_best, streak)
streak % 7 == 0        → shields < 2 ? shields += 1 : credits += 3     (celebrate „+1 Serienschutz“ or „+3 Münzen“)
```

**Buying:** tap the shield in the overview header → card „Serienschutz“ with
„Schützt deine Serie, wenn du einen Tag verpasst. Du hast %d von 2.“ and the button „Kaufen · 5 Münzen“
(disabled with „Du hast genug Serienschutz.“ at 2, or „Dir fehlen %d Münzen.“).
Constants (`balance.gd`): `SHIELD_MAX = 2`, `SHIELD_PRICE = 5`, `STREAK_MILESTONE = 7`, `SHIELD_FULL_COINS = 3`.

**The flame.** The user asked for a flame counter. The game already uses red fire as danger (burning rows). So the
streak flame is a **separate icon** `icons/streak.svg`: a rounded, golden flame (`Style.SUN` with a `#FFD88A` core),
never red, never shown on the cube, always with a number next to it. The danger fire stays `fire.svg` in `Style.FIRE`.

**Streak celebration** (on the win card, after the stars fly in, 0.4 s later):
the header flame flies into the card, the number counts up (`2 → 3`, pop + `Style.HAPTIC_COMBO`), the week row
(1.6) lights today's circle, the character turns `proud` and says the streak line (4.4). Milestones (7, 14, 30, 50,
100, 365) get confetti and a full line „7 Tage in Folge!“ in big type. Streak 1 („Deine Serie beginnt“) is shown too,
but small.

### 1.6 Overview (day screen) – what it shows

Top to bottom (portrait, `Style.CONTENT_W`):

1. **Header row:** character portrait (72 px, idle animation) with its name below in caps; on the right three chips:
   streak flame + number, shield + number (hidden while 0 and never bought), coins.
2. **Character bubble** (one line, from the character, tone and state dependent, section 4.6).
3. **Heute card** (the main button of the screen), one of these states:
   - *new day open:* caps „Heute neu“, title „Tag 3 · Tiere“, goal line „Erschaffe 3 Tiere“, button „Los!“.
   - *today done, next is tomorrow:* a check tile, title „Heute geschafft!“, line „Morgen geht's weiter: Tag 4 ·
     Menschen“, countdown line, buttons „Weiterbauen“ (only while the won world is still in memory, section 2.4) and
     „Nochmal · mehr Sterne“ (only if the day has < 3 stars).
   - *after day 7, not done today:* caps „Welt des Tages · Freitag“, the goal, „Los!“. (Before day 7 „not done
     today“ always means a new day is open: a locked new day implies a first win today.)
   - *WdT done:* „Heute geschafft!“, „Morgen gibt es eine neue Welt.“, countdown.
   - *day 7 won today:* „Deine Welt ist vollendet!“, „Morgen: deine erste Welt des Tages“, countdown.
4. **Week row** („Diese Woche“): 7 circles Mo Di Mi Do Fr Sa So for the current week (Monday first):
   streak day = golden flame; shield day = blue shield (`Style.WATER`); missed = empty grey ring; today, not done =
   ring with a soft pulse; future = faint dot. Under the row: „Serie: 3 Tage · Rekord: 9“.
5. **The 7 day tiles** (as now, 4 + 3) and „Freies Spiel“. The tile of the next new day, when it is tomorrow, shows
   a small moon icon and the caption „Morgen“ instead of the lock. Tap → the tile wiggles and the character says
   the locked line (4.6); toast text: „Morgen geht's weiter: Tag 4 · Menschen“. Tiles after it keep the lock and
   „Erst Tag %d schaffen.“
6. Debug builds only: a small pill „Nächster Tag (Test)“ under the tiles (section 7).

**Countdown line** (seconds to `Daily.next_boundary()`):
- more than 8 h left: „Neuer Tag in 14 Std. 20 Min.“
- 8 h or less: „Morgen früh“ (no exact time in the evening: nobody should wait up for 03:00).
- Refreshed once per minute while visible.

### 1.7 Clock changes, time travel, time zones

`last_seen` = the largest `now_local()` ever seen (saved), `last_key` = its Spieltag.

| case | rule |
|---|---|
| normal (`now >= last_seen`) | `today_key = day_key(now)`; update `last_seen` |
| clock back < 36 h (DST in autumn, small correction, flying west) | `today_key = last_key` (the Spieltag never goes backwards); nothing unlocks, nothing is lost; `last_seen` unchanged |
| clock back ≥ 36 h (big correction after a wrong date) | **rebase:** `last_seen = now`, `last_key = today_key = day_key(now)`; every saved key moves back by the same number of days (`Daily.shift_keys`, as implemented): nothing lies in the future afterwards, „heute geschafft“ / „morgen geht's weiter“ stay as they were (nothing unlocks today), the streak is kept, no shield is used, the day check runs normally from the next Spieltag |
| clock forward (cheating or a wrong date) | accepted. It can open at most one new level per changed Spieltag and can break the streak (shields apply). A later correction backwards is the rebase above, so nobody gets stuck |
| time-zone travel east | a Spieltag can be shorter; at most it opens the next level a few hours earlier |

All keys are local-time keys. The save stores keys, never UTC times, except `session_anchor` (minutes of the day).

### 1.8 Save format v2 and migration

Still `user://rekord.cfg`, written by `Game._save_profile()`. `[schoepfung] version` becomes 2. New sections:

`[taeglich]`

| key | type | meaning |
|---|---|---|
| `version` | int | 1 (version of this section) |
| `gewonnen_am` | Array[int] (7) | Spieltag of the first win per day, −1 = none/unknown |
| `letzter_neuer` | int | `last_new_key`, −1 = none |
| `serie`, `serie_best`, `serie_letzter` | int | streak, best streak, `streak_last` |
| `serie_tage`, `schutz_tage` | Array[int] | last 21 streak days / shield days (keys) |
| `schutz` | int | shields 0–2 |
| `zuletzt` | int | `last_seen` (local unix) |
| `anker` | int | `session_anchor`, minute of the day (−1 = unknown) |
| `wdt_sterne` | Dictionary | key (as String) → stars, last 14 entries |
| `wdt_fehlversuche` | Array[int] | `[key, fails]` for the current Spieltag |
| `wdt_gesamt` | int | worlds of the day won |
| `bau_muenzen` | Array[int] | `[key, coins]` earned in Weiterbauen today (cap 3, section 2.2) |
| `test_tage` | int | `debug_day_offset` (ignored in release builds) |
| `zuletzt_tag`, `erster_tag`, `geoeffnet` | int | `last_key`; first Spieltag of the profile (week row: earlier days are empty, not „missed“); Spieltag of the latest session start (reminder ladder base) |
| `schutz_je` | bool | a shield was ever held (the shield chip stays visible) |
| `comeback` | String | "", "saved", "lost" – shown once, then cleared |

`[erinnerung]` – section 5.7. `[charakter]` – section 3.9.

**Migration from v1** (old save has `[schoepfung] version = 1` or no `[taeglich]`):
- `gewonnen_am[i] = -1` for every day with `sterne[i] > 0` („won before“ – counts as earlier than today), else −1.
- `letzter_neuer = -1` → the next new day (the old `frei`) is **open today**. Nobody loses a day they had.
- `serie = 0`, `schutz = 0`, `zuletzt = now`, `anker = -1`.
- `fertig == true` → the Welt des Tages starts today.
- No `[charakter]` → the character creator opens once at the next launch, before the overview, with the banner
  „Neu: Dein eigener Gott!“ (section 3.7). Old players skip nothing else.
- Brand-new players: creator → day 1 goal card (as today's first launch, without the overview).

---

## 2. Weiterbauen (continue after a win)

### 2.1 Entry

The win card (`day_ui._show_win`) changes:
- When the next new day is **tomorrow** (always after a first win, and after winning the WdT): primary button
  **„Weiterbauen“**, secondary „Nochmal · mehr Sterne“ (only < 3 stars) and the line
  „Morgen geht's weiter: Tag 2 · Pflanzen“ (WdT: „Morgen gibt es eine neue Welt.“). A small link „Zur Übersicht“.
- When a new day is still open today (the player won a replay first): primary stays „Weiter zu Tag 3 · Tiere“,
  secondary „Weiterbauen“.
- Day 7 first win: as now („Deine Welt ist vollendet!“, free play opens) with the primary button „Weiterbauen“ and
  „Freies Spiel“ as secondary.

### 2.2 Rules in Weiterbauen

`GameState.day_free_build = true` (new flag, part of `clone()`):

| thing | rule |
|---|---|
| twist limit | **off**: `twists_left()` returns −1, the ring in the chip is hidden, nothing fails on twists |
| fail | none: `check_day()` never sets `day_lost`; day 6 war is a normal war (churches fall, faith −, as in free play) |
| stars | frozen at the winning attempt (`day_won_at`). Better stars = „Nochmal · mehr Sterne“ (fresh pool board) |
| goal chip | shows a check and „Weiterbauen“; next to it a growth counter (grass icon + number of fields grown since the win: sum of `made` after the win) |
| growth, rows, cascades, rain refills, Regen gift, hint (free), wishes, Weltwaage, smog, Gewitter | exactly as the day config says |
| resting kinds | still rest; the pill says as now „Ruht heute · …“ and the character may add „Morgen wächst hier mehr.“ (once per session) |
| fire | the 3rd miss still burns the row (lesson stays), never a fail |
| faith | keeps counting (shown from day 6 as before); day 1–5 show only the growth counter |
| coins | +1 coin per 10 fields grown in Weiterbauen, at most 3 per Spieltag (`bau_muenzen`); toast „+1 Münze fürs Weiterbauen“ |
| streak / unlocks | nothing more (the win already counted) |
| undo | as in the day (no change) |

### 2.3 Leaving

- The menu's „Zur Übersicht“ (and Android back) leaves Weiterbauen without a question: nothing can be lost
  (the win and stars are saved at the win).
- A new day or a „Nochmal“ ends it.
- The character says the continue intro once per session when it starts (4.6).

### 2.4 Keeping the world

The continued `GameState` stays in memory (`Game.build_state`) while the app runs, so the overview's „Weiterbauen“
returns to it. It is **not** saved to disk in v1 (a day in progress is never saved, `GDPD_7_TAGE.md` 3.4). Persisting
it needs a `GameState` serializer – later.

---

## 3. Character system

### 3.1 Concept

The player creates their own god at the first launch. It is the companion: all coach texts come from it as a speech
bubble with its face; it praises, celebrates, worries before fire, is briefly sad when it was kept waiting, and it
signs the reminders. It is built from 2D layered vector parts: cheap, clean, extensible (later shop skins).

Design rules: round, friendly shapes, thick ink outline (`Style.INK`), big eyes; **no real religious symbols or
figures** (no crosses, crescents, stars of David, om signs, saints, prophets); halos and crowns are fairy-tale props.

### 3.2 Canvas and anchors

- Every part is an SVG on the same canvas `viewBox="0 0 256 256"` (`width="256" height="256"`), so layers stack
  without offsets. Feet/bottom at y ≈ 236, centre x = 128.
- Per base, data gives anchors (canvas pixels): `face` (centre between the eyes), `face_scale`, `eye_gap`, `mouth`,
  `head_top` (+ scale), `neck` (+ scale). Shared face and accessory parts are drawn centred at (128, 128) and moved
  and scaled to the anchor by the layer's `position`/`scale`.

### 3.3 Bases and their parts

Folder `icons/character/`. Per base a sub-folder; shared parts in `face/` and `acc/`. `*_f.svg` = fill (white with
grey shading, tinted), `*_l.svg` = ink lines and fixed details (never tinted).

| base (key, German name) | parts back → front (slot that tints it) | default name | special |
|---|---|---|---|
| `bart` Bart-Gott | `haar_hinten` (haar), `robe` (haupt), `haende` (haut), `kopf` (haut), `bart` (haar, gap for the mouth), `haar_vorne` (haar) | Barti | beard sways a little when it talks |
| `goettin` Göttin | `haar_lang` (haar), `kleid` (haupt), `haende` (haut), `kopf` (haut), `pony` (haar) | Lumi | long hair swings on hop |
| `sonne` Sonne | `strahlen` (haar = „Strahlen“), `scheibe` (haupt = „Kern“), `glanz` (fixed) | Sonni | rays turn slowly (6°/s) |
| `wolke` Wolke | `woelkchen` (haar = „Wölkchen“, small clouds behind), `wolke` (haupt), `bauch` (fixed white) | Wolki | drifts left/right ±4 px |
| `katze` Katzengott | `schwanz` (haupt = „Fell“), `koerper` (haupt), `kopf` (haupt), `ohren` (haupt) + `ohren_innen` (fixed pink), `muster` (haar = „Muster“, stripes), `schnauze` (fixed white), `schnurrhaare` (ink) | Miez | tail sways; ears twitch on blink |
| `nudel` Spaghettimonster | `nudeln_hinten` (haupt = „Nudeln“), `stiele` (haupt, eye stalks), `knaeuel` (haupt), `baellchen_l`, `baellchen_r` (haar = „Bällchen“) | Nudelchen | eyes sit on stalk tips (`eye_gap` 70); noodles wiggle |

Each tinted part has a matching `_l.svg`. Bases without hands/neck simply have no `neck` anchor (neck accessories
are then hidden; the creator greys them out).

### 3.4 Colour palettes

Stored as palette **keys** (stable if hex values are tuned later). Slots: `haupt`, `haut`, `haar`, `akzent`
(accessories), `augen` (iris).

| palette | keys → hex |
|---|---|
| `haupt` | sonne `#F2A93B`, himmel `#3B8EEA`, blatt `#3FA85F`, feuer `#EF5B4C`, lavendel `#C9B5F0`, nacht `#5B74D6`, wolke `#F4F1EA`, rosa `#F4A7B9` |
| `haut` | h1 `#FBE3CC`, h2 `#F1C7A0`, h3 `#D9A27A`, h4 `#B57A54`, h5 `#8A5636`, h6 `#5E3A24` |
| `haar` | weiss `#F4F1EA`, silber `#C9CCD3`, blond `#F2D27A`, rot `#B5592E`, braun `#6B4428`, schwarz `#2B2B33`, lila `#9B7AD8`, blau `#3B8EEA` |
| `akzent` | gold `#F2A93B`, silber `#C9CCD3`, rubin `#EF5B4C`, smaragd `#3FA85F`, saphir `#3B8EEA`, rosa `#F4A7B9` |
| `augen` | braun `#6B4428`, blau `#3B8EEA`, gruen `#3FA85F`, grau `#6E7480`, gold `#B5711A` |
| base overrides | sonne `haut` (Kern): `#FFD88A`, `#FFE9B8`, `#F7B9A8`; katze `haupt` (Fell): `#F2A93B`, `#C9CCD3`, `#6B4428`, `#2B2B33`, `#F4F1EA`; nudel `haupt` (Nudeln): `#F3D27A`, `#C99A5B`, `#7CB36B`, `#C85A7C`; nudel `haar` (Bällchen): `#8A4B2E`, `#B5592E`, `#6B4428` |

Defaults per base (also used by „Würfeln“ as a safe start): bart haupt=wolke haut=h2 haar=weiss; goettin haupt=lavendel
haut=h3 haar=braun; sonne haupt=sonne (Kern `#FFD88A`) haar=sonne; wolke haupt=wolke haar=himmel; katze haupt=`#F2A93B`
haar=braun; nudel haupt=`#F3D27A` haar=`#8A4B2E`. Accent gold, eyes braun.

### 3.5 Faces and expressions

Shared parts in `icons/character/face/` (ink unless noted):

- Eye styles (choice in the creator): `rund`, `oval`, `gross` (cute, big highlights), `schmal`. Each has
  `augen_<stil>_weiss.svg` (white, untinted), `augen_<stil>_iris.svg` (tinted `augen`), `augen_<stil>_l.svg`.
- Shared eye states: `augen_froh.svg` (^^ arcs), `augen_zu.svg` (closed lines, blink), `lid_muede.svg` (half lid,
  tinted `haut`; sun/cloud/cat/noodle use their body colour), `lid_traurig.svg` (drooping outer lids, tinted),
  `zwinker_r.svg` (right eye closed arc).
- Brows: `brauen_neutral`, `brauen_hoch`, `brauen_sorge`, `brauen_streng`, `brauen_frech` (one raised).
- Mouths: `mund_neutral`, `mund_laecheln`, `mund_lachen` (open, tongue), `mund_stolz` (smug smile), `mund_sorge`
  (wavy), `mund_traurig` (small down curve, never crying), `mund_o` (small „o“, yawn), `mund_frech` (side grin +
  tongue tip).
- Extras: `wangen.svg` (blush, tinted `#F4A7B9` at 60 %), `funkeln.svg` (sparkles), `schweiss.svg` (one drop),
  `zzz.svg`. No tears anywhere (no guilt).

| expression | eyes | brows | mouth | extras | used for |
|---|---|---|---|---|---|
| `neutral` | open | neutral | neutral (lieb: laecheln) | – | idle |
| `happy` | froh | hoch | lachen | wangen | growth, app open, Weiterbauen |
| `proud` | froh | neutral | stolz | funkeln | win, stars, streak |
| `worried` | open × 1.15, iris × 0.8 („big eyes“) | sorge | sorge | schweiss | 2nd flame (fire next), war risk, smog |
| `sad` | open + lid_traurig | sorge | traurig | – | comeback after missed days (max 1.5 s, then happy) |
| `sleepy` | lid_muede | neutral | o | zzz | app opened 21:30–08:00, final reminder icon |
| `cheeky` | left open + zwinker_r | frech | frech | – | tone frech idle, hints, the locked-tomorrow line |

Tone sets the resting face: lieb → `neutral` with smile, frech → `cheeky` every 3rd idle bubble, streng →
`neutral` with `brauen_streng`.

### 3.6 Accessories

`icons/character/acc/`, tinted `akzent` unless noted, placed at the base's anchors:

| slot | options |
|---|---|
| Kopf (`head_top`) | keins, `krone`, `heiligenschein` (fixed light gold `#FFD88A`, floats ±2 px), `blumenkranz` (fixed colours), `zauberhut` (tinted), `schleife` |
| Gesicht (`face`) | keins, `rundbrille`, `sonnenbrille` (fixed dark), `monokel` |
| Hals (`neck`) | keins, `fliege`, `schal`, `amulett` (a sun disk – no religious symbol) |

Later (shop): more of each slot and full base skins; a part is just new SVGs + one data row (3.8).

### 3.7 Creator flow (max 4 steps, under a minute)

Full-screen card over a soft sky. **Top 45 %:** the live preview (bobbing, reacts `happy` with a hop on every change),
the name under it. **Bottom:** the step. Header: caps „1 von 4“ and a dice button „Würfeln“ (randomizes the current
step; long-press randomizes everything). Footer: „Zurück“ (steps 2–4) and the primary button.

| step | title | content | primary |
|---|---|---|---|
| 1 | „Wer hilft dir beim Erschaffen?“ – line „Such dir deinen Gott aus. Du kannst ihn später ändern.“ | 6 big tiles (portraits with default colours): „Bart-Gott“, „Göttin“, „Sonne“, „Wolke“, „Katzengott“, „Spaghettimonster“ | „Weiter“; small link „Würfeln und los“ (random everything, default name, tone lieb → straight to step 4) |
| 2 | „Deine Farben“ | 3 swatch rows (labels per base: „Farbe“ / „Haut“ / „Haare“; Sonne: „Kern“, „Strahlen“; Katze: „Fell“, „Muster“; Nudel: „Nudeln“, „Bällchen“; Wolke: „Wolke“, „Wölkchen“) | „Weiter“ |
| 3 | „Gesicht und Schmuck“ | rows: „Augen“ (4 styles), „Augenfarbe“, „Auf dem Kopf“, „Im Gesicht“, „Am Hals“ (chips with small icons; „keins“ first) | „Weiter“ |
| 4 | „Wie heißt du?“ | name field (prefilled with the base's default name, max 12 characters) and „Wie soll %s reden?“ with 3 cards; tapping a card makes the preview say the sample in a bubble | „Fertig – los geht's!“ |

Tone cards (title, sample):
- „Lieb“ – „Schön, dass du da bist! Bauen wir zusammen eine Welt?“
- „Frech“ – „Na endlich! Ich dachte schon, ich muss die Welt allein würfeln.“
- „Streng“ – „Gut. Eine Welt baut sich nicht von selbst. Fangen wir an.“

Name rules: trim, remove line breaks and `{}`; empty → default name; at most 12 characters (Godot `String.length()`).
After „Fertig“: save, render the notification portraits (5.6), then day 1 (first launch) or the overview.
Edit later: Menü → „Dein Charakter“ opens the same 4 steps (title „Dein Charakter“, primary „Speichern“).

### 3.8 Godot implementation (layering and tinting)

**Chosen: neutral fills + `modulate`.** Every tinted part is drawn white (`#FFFFFF`) with light grey (`#D6D6D6`)
shading; `TextureRect.self_modulate = palette colour` multiplies it, so shading comes for free. Lines and fixed
details are separate `_l.svg` layers with `self_modulate = WHITE`. Pros: 1 file per part instead of 1 per colour;
new colours are data only. Limit: one colour per part (multi-colour skins → option B).

*Option B (later, for shop skins):* per-colour variants generated at runtime by replacing placeholder colours in the
SVG text and rasterizing with `Image.load_svg_from_string(svg, scale)`. Needs the raw SVGs in the export
(`include_filter` „icons/character/*.svg“). Not needed for v1.

Import: every `icons/character/**/*.svg` gets `svg/scale=2.0` in its `.import` (512 px textures: sharp at the largest
size, 200 logical px × content scale ≤ 2.5). About 15 textures are visible per character (≈ 15 MB VRAM worst case;
load only the used parts and cache them in `Style.icon`-like dictionary).

New files:
- `scripts/character.gd` (`class_name Character`, data only): `BASES` (per base: parts with slot, anchors, default
  name, labels for step 2), `PALETTES`, `EXPRESSIONS` (table 3.5), `ACCESSORIES`, `random(rng) -> Dictionary`,
  `sanitize_name()`, `default_look(base)`.
- `scripts/character_view.gd` (`class_name CharacterView extends Control`): builds one `TextureRect` per layer
  (`EXPAND_IGNORE_SIZE`, `STRETCH_KEEP_ASPECT_CENTERED`, full rect, **`mouse_filter = MOUSE_FILTER_IGNORE`**), API:
  `set_look(look: Dictionary)`, `set_expression(e: String, hold: float = 0.0)`, `react(kind: String)` ("hop",
  "shake", "spin", "nod"), `look_at_point(p: Vector2)`, `talking(on: bool)`, `portrait := false` (head-only crop for
  bubbles: a `clip_contents` parent with the head anchor centred). Works at 44 px (bubble), 72 px (header),
  200 px (creator, success card).
- `scripts/creator_ui.gd`: the 4 steps (built in code like `day_ui.gd`), owned by `GameUI`.

**Idle animation** (`_process`, only when `is_visible_in_tree()`):
- blink: random every 2.5–6 s, eyes → `augen_zu` for 0.12 s (double blink 15 %); not in `happy`/`sleepy`.
- bob: `position.y = sin(t · TAU / 2.4) · 3` px; breathe: `scale.y = 1 + 0.015 · sin(…)` (pivot at the feet).
- base extras: sun rays rotate, cloud drift, cat tail sway ±8°, noodles wiggle ±4°, halo float ±2 px.
- talking: while a bubble types/appears, mouth toggles `laecheln`/`lachen` every 0.14 s for the first 1.2 s.
- react: hop (squash 1.1/0.9 → stretch 0.92/1.08 → 1, 0.35 s, `TRANS_BACK`), shake (±6 px, 0.3 s), spin (360°
  0.6 s, proud with 3 stars), nod (rotation ±5°).
- look: pupils (iris layer) move up to 4 px toward a point (the tile that grew, the coach target).

### 3.9 Save `[charakter]`

| key | type | example |
|---|---|---|
| `version` | int | 1 |
| `basis` | String | "katze" |
| `farben` | Dictionary | {"haupt": "f1", "haut": "h2", "haar": "braun", "akzent": "gold", "augen": "gruen"} (base-override palettes use keys like "f1") |
| `augen` | String | "gross" |
| `kopf`, `gesicht`, `hals` | String | "krone", "", "fliege" |
| `name` | String | "Miez" |
| `ton` | String | "lieb" / "frech" / "streng" |
| `bilder` | int | version of the rendered notification portraits (5.6), re-render when it differs |

### 3.10 Where the character appears

| place | size | expression / behaviour |
|---|---|---|
| overview header + bubble | 72 px | state line (4.6); `sad` 1.5 s then `happy` on a comeback; `sleepy` at night |
| goal card | 56 px portrait at the top left; the intro line becomes its speech | `neutral`; day 1: „Hallo, ich bin %s!“ line first |
| coach bubbles (`ui._place_coach`) | 44 px portrait replaces `coach_tile`; the topic icon becomes a 22 px badge on the portrait's corner | per key (4.2) |
| „Schau zu!“ lane (day 1 demo) | 44 px | `happy`, looks at the hand |
| success card | 120 px above the stars | `proud`; `spin` at 3 stars; streak line under the stars |
| fail card | 96 px | `worried` → after 0.6 s `neutral` with the encouraging line (never sad at the player) |
| streak milestone | 200 px centre | `proud` + confetti |
| Weiterbauen | 44 px bubble once | `happy` |
| notifications | large icon 256 × 256 PNG | `happy` (A), `worried` (B), `neutral` with smile (C), `sleepy` waving (final) |
| menu | „Dein Charakter“ row with a 44 px portrait | – |

Rule for **who speaks**: speech bubbles, card intros/lines and notifications are the character. Pills, chips,
caps, button labels and card titles stay neutral system text (they are short facts, and the tour checks them).

---

## 4. Tone text banks (lieb / frech / streng)

New `scripts/voice.gd` (`class_name Voice`): `Voice.line(key: String, args: Dictionary = {}) -> String` picks the
variant for the current tone (and a random one where a key has a list, never the same twice in a row), fills
placeholders, and `Voice.face(key) -> String` returns the expression. Placeholders: `{name}` (character),
`{tag}` („Tag 3 · Tiere“, or „die Welt des Tages“ after day 7), `{streak}` (number). **Never start a sentence with
`{tag}`** (lowercase „die Welt des Tages“).

**Text rule (Philipp, overrides the longer texts below):** every player text is one short sentence, ideally 2–6
words, at most 8 (coach lines, cards, pills, banners, long-press, notifications, tone banks). The rule is explained
generically: „Bring 3 gleiche in eine Reihe.“ – never „Bring 3 Erden zusammen“. The texts quoted in this section are
the original long drafts; the shipped texts are in `scripts/character_texts.gd` (tone banks and notifications, one
source – `ReminderPlan` reads `CharacterTexts.NOTIFY`), `scripts/days.gd`, `scripts/ui.gd` and `scripts/day_ui.gd`.
`tests/test_models.gd` and `test_short_texts` in `tests/test_rules.gd` fail on a text longer than 8 words or one
that says „Erden“/„zusammen“.

Further rules: du-form, no guilt („du hast
mich enttäuscht“), no threats, no swearing, no religious jokes or real religious names; the rule content of a coach
line stays the same in all tones (only the voice changes). Dynamic coach lines that carry numbers (the wish line with
„in %d Drehungen“, the age line) keep their text in every tone – only the face changes – so tour checks stay valid.

### 4.1 Introduction (day 1 goal card, first line)

| lieb | frech | streng |
|---|---|---|
| Hallo, ich bin {name}! Heute erschaffen wir zusammen eine Welt. | Hi, ich bin {name}. Ich zeig dir, wie man eine Welt baut. Ist ganz leicht. Meistens. | Ich bin {name}. Ich zeige dir, wie man eine Welt erschafft. Pass gut auf. |

### 4.2 Coach lines (existing texts mapped to the character)

Day lines (`Days.DAYS[n].coach`, `coach_demo`, `coach_tool`); the data keeps the neutral text as the fallback and gets
`coach_frech`, `coach_streng` arrays (and `coach_lieb`), same order and length.

| key | lieb | frech | streng |
|---|---|---|---|
| d1 demo (`coach_demo`) | Schau zu: Ich dreh einmal für dich – drei Erden in einer geraden Reihe werden eine Wiese. | Pass auf, ich zeig's dir einmal: Drei Erden in einer geraden Reihe werden eine Wiese. | Schau genau hin: Drei Erden in einer geraden Reihe werden eine Wiese. |
| d1 c0 | Dreh mal eine Scheibe! Drei Erden in einer geraden Reihe werden eine Wiese. | Los, dreh! Drei Erden in einer geraden Reihe – zack, eine Wiese. | Dreh eine Scheibe. Drei Erden in einer geraden Reihe werden eine Wiese. |
| d1 c1 | Aus drei Erden wird eine Wiese. Wie schön! | Drei Erden, eine Wiese. Nicht schlecht für den Anfang! | Richtig. Aus drei Erden wird eine Wiese. |
| d1 c2 | Jetzt du! Wisch über die leuchtende Scheibe – oder finde selbst drei Erden. | Dein Zug! Wisch über die leuchtende Scheibe – oder such dir selbst drei Erden. | Jetzt du. Wisch über die leuchtende Scheibe – oder finde selbst drei Erden. |
| d1 c3 | Gut so! Das ist jetzt deine Welt. | Läuft! Ab jetzt bist du hier der Boss. | Gut. Diese Welt gehört jetzt dir. Pass gut auf sie auf. |
| d2 c0 | Heute wächst Wald: Drei Wiesen in einer Reihe werden ein Wald. | Wiesen sind langweilig. Drei in einer Reihe – und es wird ein Wald! | Heute: Wald. Drei Wiesen in einer Reihe werden ein Wald. |
| d2 c1 (fire warning) | Vorsicht: Wächst bei der nächsten Drehung wieder nichts, brennt es. Regen löscht Feuer. | Uff, gleich wird's heiß! Wächst beim nächsten Mal nichts, brennt es. Regen löscht Feuer. | Achtung. Wächst bei der nächsten Drehung nichts, brennt es. Regen löscht Feuer. |
| d2 tool | Probier den Regen: Tipp drauf und dann auf eine Wiese – sie wird sofort ein Wald. | Abkürzung gefällig? Tipp auf Regen, dann auf eine Wiese – schwupp, ein Wald. | Nutze den Regen: Tipp drauf, dann auf eine Wiese. Sie wird sofort ein Wald. |
| d3 | Drei Wälder werden ein großer Wald. Und drei große Wälder bringen Tiere! | Drei Wälder? Großer Wald. Drei große Wälder? Tiere! So einfach. | Drei Wälder werden ein großer Wald. Drei große Wälder bringen Tiere. Merk dir das. |
| d4 c0 | Drei Tiere in einer Reihe – und Menschen ziehen ein. Eine Hütte! | Drei Tiere in einer Reihe, und schon stehen Menschen vor der Tür. Eine Hütte! | Drei Tiere in einer Reihe: Menschen ziehen ein. Eine Hütte. |
| d4 c1 | Die Menschen wünschen sich etwas. Erfüll den Wunsch – dann wächst ihr Haus. | Die haben schon Wünsche! Erfüll den Wunsch – dann wächst ihr Haus. | Ein Wunsch. Erfüll ihn – dann wächst ihr Haus. |
| d5 | Jetzt entscheidest du: Aus drei Wiesen wird Wald oder Acker. Ein Acker macht die Menschen satt. | Du hast die Wahl: Wald oder Acker? Kleiner Tipp: Hungrige Menschen lieben Äcker. | Du entscheidest: Aus drei Wiesen wird Wald oder Acker. Ein Acker macht die Menschen satt. |
| d6 | Eine Kirche bringt jede Runde Glauben. Aber bitte nie zwei Kirchen zusammen – das gibt Krieg. | Kirchen bringen Glauben. Zwei Kirchen nebeneinander? Gibt Streit. Großen Streit. | Eine Kirche bringt jede Runde Glauben. Bring nie zwei Kirchen zusammen. Das gibt Krieg. |
| d7 | Industrie bringt viel Glauben – aber zu viel Stadt macht die Luft schmutzig. Bring die Waage ins Grüne: mit Wald oder einem Gewitter über einer Fabrik. | Fabriken sind fleißig, aber sie stinken. Halt die Waage im Grünen: mehr Wald – oder ein kleines Gewitter auf die Fabrik. | Industrie bringt viel Glauben, aber auch Smog. Halte die Waage im Grünen: mit Wald oder einem Gewitter über einer Fabrik. |

General coach keys (`ui.COACH`; used in days per `DAY_COACH` and in free play). Expression in brackets.

| key | lieb | frech | streng |
|---|---|---|---|
| `miss` (worried) | Hier ist nichts gewachsen. Bei 3 Flammen fängt die Reihe Feuer. | Nix gewachsen! Bei 3 Flammen wird's heiß – dann brennt die Reihe. | Hier ist nichts gewachsen. Bei 3 Flammen brennt die Reihe. |
| `fire` in days (worried) | Oh nein, Feuer! Gieß die brennenden Felder mit Regen – sonst schrumpfen sie. | Es brennt! Schnell Regen drauf – sonst schrumpfen die Felder. | Feuer. Gieß die brennenden Felder mit Regen, sonst schrumpfen sie. |
| `war` (worried) | Oh weh, Krieg! Zwei Kirchen haben sich getroffen. Halte sie auseinander. | Krach! Zwei Kirchen haben sich getroffen. Lass die mal schön getrennt. | Krieg. Zwei Kirchen haben sich getroffen. Halte sie auseinander. |
| `smog` (worried) | Die Luft ist schmutzig. Wälder welken, Tiere fliehen. Pflanz Wald oder schick ein Gewitter auf die Industrie. | Puh, Smog! Wälder welken, Tiere hauen ab. Mehr Wald – oder ein Gewitter auf die Fabrik. | Smog. Wälder welken, Tiere fliehen. Pflanz Wald oder strafe die Industrie. |
| `hint` in days (cheeky) | Kommst du nicht weiter? Tipp zeigt dir die beste Drehung – heute gratis. | Hängst du fest? Tipp verrät dir den besten Zug. Kostet heute nix. | Kommst du nicht weiter? Tipp zeigt die beste Drehung. Heute gratis. |
| `hold` (happy) | Halte ein Symbol gedrückt – dann erklär ich es dir. | Psst: Halte ein Symbol gedrückt, dann erklär ich's dir. | Halte ein Symbol gedrückt. Dann erkläre ich es dir. |
| `mini` (neutral) | Ab jetzt fragt eine kleine Pille über dem Feld. Tipp schnell das andere Bild – oder halte sie für die große Karte. | (same) | (same) |
| `wish` (happy) | dynamic text unchanged (see rule above) | (same) | (same) |
| rest in Weiterbauen (cheeky) | Das wächst erst an einem späteren Tag. Morgen wächst hier mehr! | Geduld, Geduld! Morgen wächst hier mehr. | Nicht heute. Morgen wächst hier mehr. |

The free-play-only keys (`rain`, `bolt`, `monsoon`, `undo`, `coins`, `scale`, `church`, `finished`, `industry`,
`nopeople`) keep their text in v1 and are spoken with the `neutral` face; tone variants are an easy follow-up.
`Game.PRAISE`/`GASP` (religious exclamations) are replaced in the character's mouth by 4.3; free play keeps them.

### 4.3 Praise, win and fail

| situation | lieb | frech | streng |
|---|---|---|---|
| growth (random, max one per 3 s) | Wie schön! · Toll gemacht! · Das wächst ja prima! · Hach, schön grün! · Super! | Zack! · Läuft bei dir! · Nicht übel! · Hui! · Das hab ich dir beigebracht! | Gut. · Ordentlich. · So ist es richtig. · Sauber gedreht. · Weiter so. |
| surprise (fire, war) | Oje! | Uiuiui! | Achtung! |
| win, 1 star | Geschafft! Ich bin stolz auf dich. | Geschafft! Knapp, aber wer zählt schon mit? | Geschafft. Mit weniger Drehungen gibt es mehr Sterne. |
| win, 2 stars | Zwei Sterne – richtig gut! | Zwei Sterne. Der dritte schaut schon neidisch. | Zwei Sterne. Gute Arbeit. |
| win, 3 stars | Drei Sterne! Du bist ein Naturtalent. | Drei Sterne?! Okay, du darfst ein bisschen angeben. | Drei Sterne. Ausgezeichnet. |
| fail | Nicht schlimm! Neue Welt, neues Glück. | Na, das war nix. Nochmal – diesmal mit Schwung! | Noch nicht. Versuch es nochmal – du bekommst mehr Drehungen. |
| fail by war (day 6) | Die Kirchen haben sich gestritten. Nochmal – halte sie auseinander. | Streit unter Kirchen, typisch. Nochmal, aber schön auseinander! | Krieg heißt: nochmal. Halte die Kirchen auseinander. |

### 4.4 Streak

| situation | lieb | frech | streng |
|---|---|---|---|
| streak 1 | Deine Serie beginnt: Tag 1! Morgen machen wir weiter. | Serie gestartet! Mal sehen, ob du morgen wiederkommst … | Tag 1 deiner Serie. Morgen geht es weiter. |
| 2–6 | {streak} Tage in Folge! Ich freu mich jeden Tag auf dich. | {streak} Tage am Stück! Du wirst ja richtig zuverlässig. | {streak} Tage in Folge. So wird eine Welt gebaut. |
| 7 (shield) | Eine ganze Woche! Dafür schenk ich dir einen Serienschutz. | 7 Tage! Eine Woche Schöpfung – kommt mir bekannt vor. Hier, ein Serienschutz. | Sieben Tage. Eine Woche Schöpfung. Dafür bekommst du einen Serienschutz. |
| 7 with 2 shields | Eine ganze Woche! Dein Serienschutz ist schon voll – hier sind 3 Münzen. | 7 Tage! Schutz hast du genug, also: 3 Münzen. Nicht alles auf einmal ausgeben! | Sieben Tage. Dein Schutz ist voll. Du bekommst 3 Münzen. |
| 14, 30, 50, 100, 365 | {streak} Tage! Unglaublich – danke, dass du immer wiederkommst. | {streak} Tage?! Ich brauche einen größeren Kalender. | {streak} Tage. Bemerkenswert. Weiter so. |
| shield bought | Gut aufgepasst! Jetzt ist deine Serie geschützt. | Schlau! Jetzt kann dir ein freier Tag nichts anhaben. | Vernünftig. Deine Serie ist geschützt. |

### 4.5 Comeback (first open after missed days; `comeback` flag, shown once)

| situation | lieb | frech | streng |
|---|---|---|---|
| saved by shield | Da bist du ja! Dein Serienschutz hat deine Serie gerettet. | Glück gehabt! Dein Serienschutz hat die Serie gerettet. Ich hab nichts gesehen. | Du warst weg. Dein Serienschutz hat die Serie gerettet. Heute spielen wir. |
| streak lost | Schön, dass du wieder da bist! Wir fangen einfach neu an – heute ist Tag 1. | Ah, da bist du ja! Ich hab schon Staub angesetzt. Neue Serie, los geht's! | Willkommen zurück. Die alte Serie ist vorbei. Die neue beginnt heute. |
| normal open | Hallo! Schön, dich zu sehen. | Na, auch wieder da? | Gut, dass du da bist. |
| opened 21:30–08:00 (sleepy) | Gähn … Schön, dass du da bist. Aber nicht zu lange, ja? | Gähn! Du bist ja eine richtige Nachteule. | Es ist spät. Eine kurze Runde, dann wird geschlafen. |

### 4.6 Overview and day-flow lines

| situation | lieb | frech | streng |
|---|---|---|---|
| new day open | Heute wartet {tag} auf dich. Ich freu mich schon! | Heute gibt's {tag}. Ich hab schon reingeschaut. Ein bisschen. | Heute steht {tag} an. Fangen wir an. |
| today done (locked line, tile tap) | Für heute ist alles geschafft. Morgen geht's weiter mit {tag}! | Hey, nicht vordrängeln! {tag} kommt morgen. | Geduld. Eine Welt entsteht Tag für Tag. Morgen: {tag}. |
| WdT open | Ich hab dir eine neue Welt gebaut. Magst du sie dir ansehen? | Neue Welt, frisch gewürfelt! Schaffst du sie? | Die Welt des Tages ist bereit. Zeig, was du kannst. |
| WdT done | Geschafft! Morgen bau ich dir eine neue Welt. | Erledigt! Morgen würfle ich dir was Neues. | Erledigt. Morgen gibt es eine neue Welt. |
| Weiterbauen start | Du kannst hier noch weiterbauen – ganz ohne Drehungs-Grenze. | Bonusrunde! Bau weiter, so lange du willst. Ohne Limit. | Das Ziel ist erreicht. Du darfst weiterbauen, ohne Grenze. |
| WdT intro on its goal card | Heute eine Welt mit {ziel}. Viel Spaß! | Heute: {ziel}. Das schaffst du locker. Wahrscheinlich. | Heute: {ziel}. Konzentrier dich. |

(`{ziel}` = the template's goal noun phrase, e.g. „5 Wäldern“ – keep it out of v1 if the grammar gets awkward and use
the goal line on the card instead.)

### 4.7 Notification texts

Notification **title** = `{name}`. **Body** = one template. Categories by slot of the reminder ladder (section 5.3):
**A** = 1st day after the last play, **B** = 2nd day, **C** = 4th day, **F** = final message (7th day).
Flag `S` = only if `streak >= 2`. 14 texts per tone + the final message.

**lieb**

| id | cat | text |
|---|---|---|
| l01 | A | Hallo! Heute wartet {tag} auf dich. |
| l02 | A | Deine Welt ist aufgewacht. Kommst du sie besuchen? |
| l03 | A | Ich hab Regen für dich aufgehoben. Spielen wir eine Runde? |
| l04 | A | Ein paar Drehungen, und deine Welt wird wieder ein Stück grüner. |
| l05 | A, S | Deine Serie: {streak} Tage! Machen wir heute weiter? |
| l06 | A | Die Wiesen fragen schon nach dir. Schaust du kurz vorbei? |
| l07 | A | Heute ist ein guter Tag für {tag}. Ich freu mich auf dich! |
| l08 | A | Nur fünf Minuten? Mehr braucht deine Welt heute nicht. |
| l09 | B | Ich hab dich gestern vermisst. Hast du heute ein bisschen Zeit? |
| l10 | B | Deine Welt ist ein bisschen still ohne dich. Kommst du heute? |
| l11 | B | Kein Stress! Wenn du Zeit hast: {tag} ist bereit. |
| l12 | C | Ich denk an dich! Deine Welt ist noch da – genau wie ich. |
| l13 | C | Wir können jederzeit neu anfangen. Ich warte gern auf dich. |
| l14 | C | Schau doch mal wieder rein. Ich hab dir viel zu zeigen! |
| lF | F | Ich erinnere dich jetzt nicht mehr. Deine Welt und ich sind da, wenn du wiederkommst. Alles Liebe! |

**frech**

| id | cat | text |
|---|---|---|
| f01 | A | Psst! {tag} ist da. Ich hab nicht reingeschaut. Fast nicht. |
| f02 | A | Deine Welt dreht sich nicht von allein. Hilfst du mir? |
| f03 | A | Mir ist langweilig. Rettest du mich mit ein paar Drehungen? |
| f04 | A | Die Wiesen wollen Wald werden. Ich kann das nicht – du schon. |
| f05 | A, S | {streak} Tage am Stück! Machen wir heute einen mehr draus? |
| f06 | A | Achtung, Durchsage: {name} sucht Gesellschaft. Belohnung: Spaß! |
| f07 | A | Ich hab ganz zufällig Regen übrig. Willst du? |
| f08 | A | Kurze Frage: Wer hat hier die Welt erschaffen? Genau, du. Weiter geht's! |
| f09 | B | Gestern keine Drehung? Ich hab's gesehen. Ich sag's aber keinem. |
| f10 | B | Huhu! Deine Welt hat ein kleines bisschen Staub angesetzt. Kommst du? |
| f11 | B | Ich hab Kekse. Okay, hab ich nicht. Aber {tag} hab ich! |
| f12 | C | Ich hab angefangen, mit den Wolken zu reden. Komm bitte zurück! |
| f13 | C | Lange nicht gesehen! Ich hab neue Witze. Und deine Welt. |
| f14 | C | Hallooo? Ist da wer? Deine Welt würde gern weiterwachsen. |
| fF | F | Okay, ich hab's kapiert: Pause! Ich bin jetzt still. Aber wenn du wiederkommst, freu ich mich riesig. |

**streng**

| id | cat | text |
|---|---|---|
| s01 | A | Die Welt wartet. Heute ist {tag} bereit. |
| s02 | A | Zeit für deine tägliche Schöpfung. Ein paar Minuten genügen. |
| s03 | A | Ordnung muss sein: heute eine Runde. Ich zähle auf dich. |
| s04 | A | Eine Welt baut sich nicht von selbst. Fangen wir an. |
| s05 | A, S | {streak} Tage in Folge. So eine Serie pflegt man. |
| s06 | A | Heute steht {tag} an. Pünktlich, bitte. |
| s07 | A | Die Wiesen stehen bereit. Es fehlt nur noch jemand, der dreht. |
| s08 | A | Eine Runde am Tag. Das ist der Plan. Bleib dabei. |
| s09 | B | Gestern war Pause. Heute geht es weiter. |
| s10 | B | Deine Welt hat heute noch nichts von dir gehört. Eine Runde? |
| s11 | B | Kurze Erinnerung: {tag} ist bereit. Mehr verlange ich nicht. |
| s12 | C | Es ist ruhig geworden. Wenn du bereit bist, machen wir weiter. |
| s13 | C | Deine Welt ist in Ordnung. Ich habe aufgepasst. Kommst du zurück? |
| s14 | C | Jede Welt verdient eine zweite Chance. Deine auch. |
| sF | F | Ich erinnere dich nicht mehr. Deine Welt bleibt, wie sie ist. Wenn du wiederkommst: Ich bin bereit. |

Category A texts may also be used for C when C has no unused text left; B/C never use `S` texts (the streak may
already be over). Final messages are fixed per tone.

---

## 5. Reminder policy

### 5.1 Principles

- At most **one** notification per Spieltag, only if the streak day is **not done**.
- Around the time the player last played successfully (≈ 23.5 h after the start of that session), never in quiet hours
  **21:30–08:00**, never a „last chance before midnight“ warning.
- The character sends it, in its tone, with its face; never the same text twice in a row.
- Ignored days → fewer reminders → after a week a friendly last message → silence until the player comes back.
- Settings: „Automatisch“ / „Feste Uhrzeit“ / „Aus“.

### 5.2 When the plan is made

The app cannot run in the background, so it **pre-plans the whole ladder** and re-plans on every visit:
`Reminders.replan()` runs at app start, on `NOTIFICATION_APPLICATION_RESUMED`, on `NOTIFICATION_APPLICATION_PAUSED`
(the most important one: the player may never come back), after every streak-day win and after every settings
change. It cancels all planned ids and schedules the new plan. Because of this, a reminder for a Spieltag on which the
player has already won is always cancelled before it fires.

### 5.3 Algorithm (pure function, `Reminders.plan(state: Dictionary, now: int) -> Array`)

```
inputs:  now (local unix), today = day_key(now), done_today (streak day done today),
         last_win_key (streak_last), last_open_key (Spieltag of the latest session start),
         anchor_min (session_anchor; −1 → 18:00), mode ("auto"|"fest"|"aus"), fixed_min,
         allowed (permission granted and notifications enabled), tone, streak, history (last 8 template ids)
if mode == "aus" or not allowed: return []

minute = (mode == "fest") ? fixed_min : anchor_min − 30          # ~23.5 h after the session start
minute = clamp(minute, 08:00 = 480, 21:30 = 1290)

base = max(last_win_key, last_open_key)        # opening the app counts as „came back“: the ladder restarts
slots = [(base + 1, "A"), (base + 2, "B"), (base + 4, "C"), (base + 7, "F")]
# the ladder: daily for 2 days, then skip 1, then skip 2, then the final message; nothing after it

for (key, cat) in slots:
    if key < today: continue                    # in the past
    if key == today and done_today: continue
    t = key * 86400 + minute * 60               # local wall-clock time on that Spieltag (03:00-based key: the
                                                #   calendar date of key is key itself because minute >= 08:00)
    if t < now + 2 * 3600: continue             # never right after a session (and never in the past)
    pick template (5.4), render title/body, add {id: 100 + (key − base), at: t, cat, tpl}
return list (at most 4 entries; ids 101, 102, 104, 107)
```

Notes:
- `base` uses the latest session start, so a player who only opens the app and leaves gets „A“ the next day again.
  The ladder („fewer after ignored days“) therefore only runs when the app is not opened at all.
- If the player won today, slot A is tomorrow; if the player opened the app today without winning, slot A is tomorrow
  as well (today's slot would come right after the visit).
- Fixed mode uses the same ladder and the fixed time.
- **„Played today“ check at fire time** is done by re-planning (5.2). The plugin also gets the Spieltag of each alarm
  and `mark_done(key)` (5.5), so even if the app was killed before `PAUSED`, an alarm for a done Spieltag is dropped.
- When the final message has been planned and its time passes without a visit, nothing more is planned (the next plan
  happens only on a visit, which restarts the ladder). This is „stop after a week, resume when the player returns“.

### 5.4 Template selection

```
pool = templates of tone with category == cat (C may borrow A when empty), excluding S-templates if streak < 2
       (B and C never use S)
if tone != "lieb": with probability 0.15 use the lieb pool of the same category instead (keeps it kind and varied)
remove ids in history[0..3] (the last 4 used) – if that empties the pool, remove only history[0]
weight = 1.0, × 0.25 if the id is in history[4..7]
rng.seed = hash([key, tone, history.size()])    # deterministic for tests; varies per day
pick weighted; render {name} {tag} {streak}
F slots always use the tone's final message (and never enter the history check)
```

History: when a plan is replaced, every entry of the old plan whose `at <= now` (it was shown) is appended to
`history` (max 8, newest first). So the same text never appears twice in a row, even across plans.

### 5.5 What the plan sends to the plugin

`schedule(id, year, month, day, hour, minute, title, body, icon_path, day_key)` – wall-clock fields (the plugin
converts them with the device's time zone, so DST and travel are handled by Android), the Spieltag for `mark_done`,
and the large-icon PNG of the right expression (5.6). `cancel_all()` before every new plan.
`mark_done(today_key)` after a streak-day win.

### 5.6 Large icon (the character's face)

After the creator (and when `[charakter] bilder` is outdated) render 4 PNGs, 256 × 256, transparent:
`user://erinnerung/gesicht_happy.png`, `_worried.png`, `_smile.png`, `_sleepy.png` (A, B, C, F). Use a
`SubViewport` (`transparent_bg = true`, size 256) with a `CharacterView` in portrait mode, wait for
`RenderingServer.frame_post_draw` twice, `get_texture().get_image().save_png(path)`. Pass
`ProjectSettings.globalize_path(path)` to the plugin. Headless (tests/CI smoke): skip rendering, pass "".

### 5.7 Settings and permission

Menu → section „Erinnerung“ (after „Dein Charakter“):
- segmented row: „Automatisch“ · „Feste Uhrzeit“ · „Aus“; sub line „Etwa zu der Zeit, zu der du sonst spielst.“ /
  a time stepper „18:00“ (± 15 min, 08:00–21:30) / „Keine Erinnerungen.“
- footnote: „Höchstens eine am Tag. Nie zwischen 21:30 und 8:00 Uhr.“
- permission denied or notifications off in Android: line „Benachrichtigungen sind am Handy ausgeschaltet.“ +
  button „Einstellungen öffnen“ (plugin `open_settings()`).
- no plugin (PC, CI): the section shows „Erinnerungen gibt es nur auf dem Handy.“ and is disabled.

Saved in `[erinnerung]`: `modus` ("auto" | "fest" | "aus", default "auto"), `uhrzeit` (minutes, default 1080),
`gefragt` (how often the in-game question was shown, 0–2), `verlauf` (Array[String], max 8), `geplant`
(Array of `{id, at, tpl}` of the current plan).

**Asking (Android 13+, `POST_NOTIFICATIONS` is a runtime permission):**
1. After the **first win of day 1** (after the streak line), the character asks in a small card:
   „Soll ich dich morgen erinnern, wenn {tag} bereit ist? Höchstens einmal am Tag – versprochen.“
   (frech: „Soll ich dir morgen Bescheid sagen, wenn {tag} da ist? Nur einmal am Tag, Ehrenwort.“;
   streng: „Ich erinnere dich morgen an {tag}. Einmal am Tag, nicht öfter. Einverstanden?“)
   Buttons „Ja, gern“ / „Lieber nicht“.
2. „Ja“ → `OS.request_permission("android.permission.POST_NOTIFICATIONS")`; result via
   `get_tree().on_request_permissions_result(permission, granted)`; then `replan()`.
   Below Android 13 the permission is granted at install (the call returns true at once).
3. „Lieber nicht“ → `modus` stays "auto" but nothing is planned until the permission exists; ask once more after the
   first 3-day streak (`gefragt < 2`), never again after that (Android itself blocks after two denials).
4. Check: `OS.get_granted_permissions().has("android.permission.POST_NOTIFICATIONS")` (API 33+) and the plugin's
   `notifications_enabled()` (the user can switch notifications off in Android settings on every version).
5. No `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`: reminders use inexact alarms (5.8), which need no permission.

### 5.8 Delivery limits (accepted)

`setAndAllowWhileIdle` is inexact: Android may deliver a few minutes late (Doze maintenance windows). That is fine for
a daily reminder. Some vendors (Xiaomi, Huawei, some Samsung modes) kill alarms of apps that were swiped away; we do
not ask for battery-optimization exceptions (that would be annoying). Alarms are restored after a reboot, an app
update and a time-zone change by the plugin's receiver.

---

## 6. Android notifications: plugin research and choice

### 6.1 Research (November 2026)

| candidate | Godot 4.3? | notes | verdict |
|---|---|---|---|
| **cengiz-pz/godot-android-notification-scheduler-plugin** v3.0 – https://github.com/cengiz-pz/godot-android-notification-scheduler-plugin/releases/tag/v3.0 (zip `NotificationSchedulerPlugin-3.0.zip`), MIT | **yes** („tested against and supports Godot version 4.3“) | Android v2 plugin (AAR + `EditorExportPlugin`, needs a Gradle build). API: node `NotificationScheduler` with `create_notification_channel(NotificationChannel)`, `schedule(NotificationData)` (`set_id`, `set_channel_id`, `set_title`, `set_content`, `set_small_icon_name`, `set_delay` seconds, `set_interval`, `set_deeplink`), `cancel(id)`, `get_notification_id()`, `has_post_notifications_permission()`, `request_post_notifications_permission()`; signals `notification_opened`, `notification_dismissed`, `permission_granted`, `permission_denied`. Uses `AlarmManager.set()` (inexact, good). **But:** repository archived (read-only since 8 Jan 2026); **no large icon** (commented out as „not working“ in `NotificationReceiver.java`); **alarms are lost on reboot** (no boot receiver in v3.0); delay in seconds only (no wall-clock/DST handling); the small icon must be copied into `res://android/build/res/drawable*`, which our CI re-creates on every run. v4.x targets 4.4.1 and states it does not work with Godot 4.4 | usable fallback, not chosen |
| **godot-mobile-plugins/godot-notification-scheduler** (the maintained successor, same author, Android + iOS) – https://github.com/godot-mobile-plugins/godot-notification-scheduler, latest v6.0 | **no** | v5.0/5.1 need Godot ≥ 4.5, v5.2 ≥ 4.6, v6.0 is built for 4.7 (`common/config/godot.properties: godotVersion=4.7`, links `godot-lib` 4.7). Has large icons, boot survival, exact/inexact | would need a Godot upgrade first |
| Godot asset library „Android Notification Scheduler Plugin“ | – | the same cengiz plugin, all versions | – |

So there is no maintained plugin for Godot 4.3 with large icons and reboot safety. **Decision: write a tiny custom
Android v2 plugin „GdpdReminder“** (≈ 250 lines Kotlin + manifest) and build it in CI. Its scope is exactly our
policy (wall-clock scheduling, large icon, boot/update/time-zone restore, `mark_done`). If Godot is later upgraded to
≥ 4.6, re-evaluate the maintained plugin (also for iOS).

### 6.2 Layout in the repository

```
gdpd/android_plugin/            Gradle library project (has a .gdignore, Godot never scans it)
  .gdignore
  settings.gradle  build.gradle  gradle.properties
  src/main/AndroidManifest.xml
  src/main/java/at/identit/gdpd/reminder/GdpdReminder.kt     (the GodotPlugin)
  src/main/java/at/identit/gdpd/reminder/Store.kt            (SharedPreferences: planned alarms as JSON)
  src/main/java/at/identit/gdpd/reminder/ReminderReceiver.kt (alarm → notification)
  src/main/java/at/identit/gdpd/reminder/RestoreReceiver.kt  (boot / update / time zone → set alarms again)
  src/main/res/drawable/ic_gdpd_notify.xml                   (small icon: white vector, a cube with a sun)
gdpd/addons/gdpd_reminder/
  plugin.cfg  export_plugin.gd
  bin/debug/gdpd_reminder-debug.aar  bin/release/gdpd_reminder-release.aar   (built in CI, git-ignored)
gdpd/scripts/reminders.gd       (class_name Reminders: plan() pure + the singleton wrapper)
gdpd/android/                   (Android build template, installed in CI, git-ignored)
```

`.gitignore` (in `gdpd/`): `android/`, `addons/gdpd_reminder/bin/`, `android_plugin/build/`, `android_plugin/.gradle/`.
`project.godot`: `[editor_plugins] enabled=PackedStringArray("res://addons/gdpd_reminder/plugin.cfg")`.

### 6.3 Plugin API (what GDScript calls)

Singleton name `GdpdReminder` (`Engine.has_singleton("GdpdReminder")`). Kotlin method names are snake_case so GDScript
calls them as written.

| method | does |
|---|---|
| `schedule(id: int, year: int, month: int, day: int, hour: int, minute: int, title: String, text: String, icon_path: String, day_key: int) -> bool` | stores the alarm (wall-clock fields) and sets `AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, …)`; false if the time is in the past |
| `cancel(id: int)` / `cancel_all()` | removes stored alarms, cancels the `PendingIntent`s and any shown notification of that id |
| `mark_done(day_key: int)` | stores the Spieltag; the receiver drops alarms with `day_key <= done` |
| `notifications_enabled() -> bool` | `NotificationManagerCompat.areNotificationsEnabled()` |
| `open_settings()` | opens Android's notification settings of the app (`Settings.ACTION_APP_NOTIFICATION_SETTINGS`, below API 26 the app details page) |
| `launch_notification_id() -> int` | the id if the app was opened by tapping a reminder (else −1; cleared after reading) – the character then says the normal comeback line with `happy` |

Permission is requested with Godot's own `OS.request_permission()` (Godot 4.3 `PermissionsUtil.requestPermission`
handles any dangerous permission that is in the manifest).

### 6.4 Plugin code (sketch, Kotlin, Godot 4.3)

```kotlin
package at.identit.gdpd.reminder

class GdpdReminder(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "GdpdReminder"
    private val ctx get() = activity!!.applicationContext

    @UsedByGodot
    fun schedule(id: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int,
                 title: String, text: String, icon_path: String, day_key: Int): Boolean {
        val p = Planned(id, year, month, day, hour, minute, title, text, icon_path, day_key)
        if (p.millis() <= System.currentTimeMillis()) return false
        Store.put(ctx, p); Alarms.set(ctx, p); return true
    }
    @UsedByGodot fun cancel(id: Int) { Alarms.cancel(ctx, id); Store.remove(ctx, id) }
    @UsedByGodot fun cancel_all() { Store.all(ctx).forEach { Alarms.cancel(ctx, it.id) }; Store.clear(ctx) }
    @UsedByGodot fun mark_done(day_key: Int) = Store.setDone(ctx, day_key)
    @UsedByGodot fun notifications_enabled() = NotificationManagerCompat.from(ctx).areNotificationsEnabled()
    @UsedByGodot fun open_settings() { /* ACTION_APP_NOTIFICATION_SETTINGS with EXTRA_APP_PACKAGE */ }
    @UsedByGodot fun launch_notification_id(): Int { /* read + remove extra "gdpd_reminder_id" of activity.intent */ }
}

// Planned.millis(): Calendar.getInstance() (device time zone), clear(), set(year, month - 1, day, hour, minute)
// Alarms.set(): AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, p.millis(),
//     PendingIntent.getBroadcast(ctx, p.id, Intent(ctx, ReminderReceiver::class.java).putExtra("id", p.id),
//         FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE))
// ReminderReceiver.onReceive: p = Store.get(id) ?: return; Store.remove(id); if (p.dayKey <= Store.done()) return
//     ensure channel "erinnerung" (name „Erinnerungen“, description „Höchstens eine Nachricht am Tag von deinem
//     Charakter.“, IMPORTANCE_DEFAULT); NotificationCompat.Builder(ctx, "erinnerung")
//     .setSmallIcon(R.drawable.ic_gdpd_notify).setLargeIcon(BitmapFactory.decodeFile(p.iconPath) /* null ok */)
//     .setContentTitle(p.title).setContentText(p.text).setStyle(BigTextStyle().bigText(p.text))
//     .setAutoCancel(true).setContentIntent(launch intent of the package + extra "gdpd_reminder_id", FLAG_IMMUTABLE)
//     post only if API < 33 or POST_NOTIFICATIONS is granted
// RestoreReceiver (BOOT_COMPLETED, MY_PACKAGE_REPLACED, TIMEZONE_CHANGED, TIME_SET): drop past entries, set the rest
```

`src/main/AndroidManifest.xml` (merged into the app by Gradle):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <application>
        <meta-data android:name="org.godotengine.plugin.v2.GdpdReminder"
            android:value="at.identit.gdpd.reminder.GdpdReminder" />
        <receiver android:name=".ReminderReceiver" android:exported="false" />
        <receiver android:name=".RestoreReceiver" android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.TIMEZONE_CHANGED" />
                <action android:name="android.intent.action.TIME_SET" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

`build.gradle` (versions pinned to the Godot 4.3 build template: Gradle 8.2, AGP 8.2.0, Kotlin 1.9.20, compile/target
SDK 34, min SDK 21, Java 17):

```groovy
plugins {
    id 'com.android.library' version '8.2.0'
    id 'org.jetbrains.kotlin.android' version '1.9.20'
}
android {
    namespace 'at.identit.gdpd.reminder'
    compileSdk 34
    defaultConfig { minSdk 21 }
    compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = '17' }
}
base { archivesName = 'gdpd_reminder' }          // → build/outputs/aar/gdpd_reminder-{debug,release}.aar
dependencies {
    compileOnly 'org.godotengine:godot:4.3.0.stable'   // Maven Central; provided by the app at runtime
    implementation 'androidx.core:core:1.12.0'
}
```

`settings.gradle`: `pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }`,
`dependencyResolutionManagement { repositories { google(); mavenCentral() } }`, `rootProject.name = 'gdpd_reminder'`.
`gradle.properties`: `android.useAndroidX=true`.

`addons/gdpd_reminder/plugin.cfg` + `export_plugin.gd` (paths in `_get_android_libraries` are relative to
`res://addons/`):

```gdscript
@tool
extends EditorPlugin

var _export: GdpdReminderExport


func _enter_tree() -> void:
	_export = GdpdReminderExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class GdpdReminderExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "GdpdReminder"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var kind := "debug" if debug else "release"
		return PackedStringArray(["gdpd_reminder/bin/%s/gdpd_reminder-%s.aar" % [kind, kind]])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["androidx.core:core:1.12.0"])
```

### 6.5 Export settings

`export_presets.cfg`, preset „Android“:

```
gradle_build/use_gradle_build=true
gradle_build/export_format=0          # APK (as now)
gradle_build/min_sdk=""               # template default 21
gradle_build/target_sdk=""            # template default 34
permissions/post_notifications=true   # also merged from the plugin manifest; listed for clarity
permissions/receive_boot_completed=true
```

A Gradle build needs the **Android build template** in `res://android/` (`android/.build_version` must contain
`4.3.stable`, `android/build/` = `android_source.zip` from the export templates, with an empty
`android/build/.gdignore`). Locally: Editor → Projekt → „Android-Build-Vorlage installieren…“. Godot 4.3 also has the
CLI flag `--install-android-build-template`, but only together with an export, so CI installs it by unzipping
(exactly what `ExportTemplateManager::install_android_template_from_file` does in 4.3).

### 6.6 CI (`.github/workflows/gdpd.yml`)

The image `barichello/godot-ci:4.3` has OpenJDK 17, the Android SDK at `/usr/lib/android-sdk` with
`platforms;android-33` + `build-tools;33.0.2`, and editor settings with `java_sdk_path`, `android_sdk_path` and the
debug keystore. The 4.3 template compiles against SDK 34 with build-tools 34.0.0 → install them. New step before
„Android-APK exportieren“ (Gradle needs network for Maven; GitHub runners have it):

```yaml
      - name: Gradle-Cache
        uses: actions/cache@v4
        with:
          path: |
            /github/home/.gradle/caches
            /github/home/.gradle/wrapper
          key: gradle-gdpd-${{ hashFiles('gdpd/android_plugin/**/*.gradle', 'gdpd/addons/gdpd_reminder/export_plugin.gd') }}

      - name: Android-Bauvorlage und Erinnerungs-Plugin
        run: |
          yes | sdkmanager --licenses >/dev/null || true
          sdkmanager "platforms;android-34" "build-tools;34.0.0" >/dev/null
          cd $PROJECT
          rm -rf android && mkdir -p android/build
          unzip -q ~/.local/share/godot/export_templates/4.3.stable/android_source.zip -d android/build
          echo "4.3.stable" > android/.build_version
          touch android/build/.gdignore
          chmod +x android/build/gradlew
          # Das Plugin mit dem Gradle-Wrapper der Vorlage bauen (Gradle 8.2 – passt zu AGP 8.2.0)
          android/build/gradlew --no-daemon -p android_plugin assembleDebug assembleRelease
          mkdir -p addons/gdpd_reminder/bin/debug addons/gdpd_reminder/bin/release
          cp android_plugin/build/outputs/aar/gdpd_reminder-debug.aar addons/gdpd_reminder/bin/debug/
          cp android_plugin/build/outputs/aar/gdpd_reminder-release.aar addons/gdpd_reminder/bin/release/
```

The existing export step stays (`godot --headless --verbose --export-debug "Android" build/gdpd.apk`); with
`use_gradle_build=true` it now runs Gradle (expect +3–6 min on a cold cache). Add a check after it:
`unzip -l build/gdpd.apk | grep -q "classes.dex"` and
`unzip -p build/gdpd.apk AndroidManifest.xml | strings | grep -q GdpdReminder || echo "Hinweis: Manifest ist binär"`
(the reliable check is on the device: `adb logcat | grep GdpdReminder`). Optional NDK warning („Unable to strip …“)
is harmless; if it fails the build, add `"ndk;23.2.8568313"` to the `sdkmanager` line.

PC exports are unaffected (the export plugin only supports Android). The import/test/tour steps run before the
template exists and do not need it.

### 6.7 Fallback without the singleton (PC, CI, editor)

`Reminders` keeps `_plugin: Object = Engine.get_singleton("GdpdReminder") if Engine.has_singleton("GdpdReminder") else null`.
Without it every call only logs one line per planned reminder, which the tour and tests read:

```
REMINDER plan id=101 at=2026-11-07 17:30 cat=A tpl=l03 title=Lumi text=Ich hab Regen für dich aufgehoben. Spielen wir eine Runde?
REMINDER cancel_all
```

and the settings show „Erinnerungen gibt es nur auf dem Handy.“ Nothing else changes.

### 6.8 As built (differences from the sketch above)

- **Java, no Gradle for the plugin.** The plugin is plain Java (`android_plugin/src/at/identit/gdpd/reminder/*.java`,
  framework APIs only, no androidx) and `android_plugin/build_aar.sh` builds the AAR with `javac --release 8` + `jar`
  against `android.jar` and the template's `godot-lib`. No AGP/Kotlin download, and it can be compiled where Google's
  Maven is not reachable. The app's Gradle build (Godot's template) dexes it and merges manifest and resources. The
  small icon is looked up by name (`getIdentifier("ic_gdpd_notify")`), so no `R` class is needed.
- **Extra methods:** `has_permission()`, `request_permission()` (POST_NOTIFICATIONS on API 33+, true below –
  Godot's own `OS.request_permission` returns false for it below 33) and `planned_count()`.
- **GDScript wrapper `scripts/notifier.gd`** (`class_name Notifier`, instead of `reminders.gd`):
  `Notifier.attach(Game)` connects `Game.reminders_planned` → `schedule_plan`, `streak_changed` → `mark_done`, keeps
  `Game.remind_permission` up to date; plus `schedule(at_unix, title, body, id, icon_path, day_key)`, `cancel_all()`,
  `request_permission()`, `notifications_enabled()`, `open_settings()`, `launch_notification_id()`,
  `Notifier.is_supported()`. Without the singleton every call only logs `REMINDER …`.
- **The editor plugin is not enabled in `project.godot`.** Godot 4.3 crashes on `--headless --editor --quit` when files
  still need importing and any editor plugin is enabled (reproduced with an empty plugin). CI enables it only for the
  Android export (`android_plugin/ci_android_export.sh`, restores `project.godot` afterwards); `--import` is safe.
- **CI:** `ci_android_export.sh` installs SDK 34 / build-tools 34.0.0, the build template
  (`prepare_gradle_export.sh`), builds the AAR, exports with Gradle and checks the APK (class in the dex, plugin
  meta-data in the manifest). If anything fails, the workflow exports the plain APK without Gradle and says so in the
  release text.

---

## 7. Test button „Nächster Tag“ and test hooks

Only when `OS.is_debug_build()` (true in the editor, in tour runs, and in the CI APK because it is exported with
`--export-debug`; a store build must use `--export-release`, where the button and `test_tage` do nothing):

- Overview: pill „Nächster Tag (Test)“ under the tiles; menu: row „Test“ with „Nächster Tag“, „Erinnerung in 10 s“,
  „Serie zurücksetzen“.
- „Nächster Tag“: `Game.debug_day_offset += 1`, save, run the day check (1.5), refresh the overview (unlock, week row,
  comeback line), `Reminders.replan()`; toast „Test: Jetzt ist %s.“ (weekday name).
- „Erinnerung in 10 s“: schedules id 199 in 10 s (wall clock now + 10 s; `setAndAllowWhileIdle` may add a little
  delay) with the next A template and the happy face.
- „Serie zurücksetzen“: streak 0, shields 0, history cleared.

Hooks for tests and the tour (all on `Game` / static, never used by the game itself):
- `Game.clock_override` (fixed `now_local()`), `Game.debug_day_offset`, `Game.debug_next_day()`.
- `Daily.*` pure functions; `Reminders.plan(state, now)` pure; `Reminders.last_log: Array` (the planned entries of the
  last `replan()`).
- `Game.reset_daily()` (fresh `[taeglich]`, `[erinnerung]`), `Game.set_character(look: Dictionary)`.
- `ui.creator` exposes `step`, `preview`, `next_btn`, `dice_btn`, `tiles`, `name_edit`, `tone_cards` for real taps.

---

## 8. Test plan

### 8.1 Rule tests (`tests/test_rules.gd`, must end with „ 0 Fehler“)

1. `Daily.day_key`: 02:59 belongs to the previous Spieltag, 03:00 to the new one; `next_boundary` is the next 03:00;
   `weekday` Monday = 0 (e.g. 2026-11-09 is a Monday).
2. Unlock by date: day 1 open; win day 1 at key K → day 2 locked („morgen“) at K, open at K+1 and still the only new
   day at K+5; replays of day 1 always open; day 3 never opens on the Spieltag day 2 was first won.
3. Migration v1 → v2: a v1 file with `sterne = [3,2,0,…]`, `frei = 3` → days 1–2 replayable, day 3 open today,
   `serie = 0`, no character → `needs_creator()`; a v1 file with `fertig = true` → WdT today.
4. Streak: wins on K, K+1, K+2 → 3; two wins on one key → +1 only; replay win counts; a fail does not.
5. Shields: streak 5, 1 shield, miss 1 day → kept, shield 0, `shield_days` has the key; miss 2 days with 1 shield →
   streak 0 and the shield is **kept**; milestone 7 → +1 shield; at 2 shields → +3 coins; buy: 5 coins → +1, refused
   at 2 or with too few coins.
6. Clock: back 1 h (DST) → same Spieltag, nothing changes; back 3 days → rebase, keys clamped, streak kept, nothing
   unlocks today; forward 1 day → next day opens once.
7. Welt des Tages: same key → same template/board/goal; 6 consecutive keys → 6 different templates; board index never
   0; a WdT win counts for the streak; replaying its solution from the pool JSON wins (cross-check with
   `GDPD_7_TAGE.md` 9.1/12).
8. Weiterbauen: after a win `twists_left() == -1`, 30 more twists → `day_lost == ""`; stars unchanged; day 6 war in
   Weiterbauen → not lost; growth counter = `made` delta; coins +1 per 10 growths, max 3 per key.
9. Reminder plan: anchor 18:10 → A at 17:40 next day; anchor 07:00 → 08:00; anchor 23:50 → 21:30; slots are
   base+1, +2, +4, +7 with categories A, B, C, F; won today → no slot today; `aus` or no permission → `[]`; fixed
   mode uses the fixed time; no entry within 2 h after `now`; every `at` is between 08:00 and 21:30 local.
10. Templates: each tone has ≥ 12 A–C texts and one F; only the placeholders `{name}`, `{tag}`, `{streak}`; no body
    starts with `{tag}`; rendered length ≤ 90 characters (final messages ≤ 110; they use `BigTextStyle`) with a 12-character name and „die Welt des Tages“; S texts
    never chosen with streak < 2 or in B/C; over 60 simulated plans with history the same id never appears twice in a
    row; F is the tone's final text.
11. Character: `Character.random()` always gives a valid look for every base; save → load round trip; `sanitize_name`
    („  {x}\n“ → „x“, 20 chars → 12, empty → default); every base × expression lists only part files that exist
    (`ResourceLoader.exists`).
12. Voice: every coach key used in days has lieb/frech/streng variants; the variants of `d4 c1` contain „Haus“ (tour
    check); no variant contains „Herrgott“, „Gottverdammt“, „Jesus“, „Allah“ or other names from a denylist.
13. Debug: with `OS.is_debug_build()` the offset moves `now_local()` by whole days (tests run in debug).

`tests/test_models.gd`: every SVG in `icons/character/**` loads; a `CharacterView` for every base builds its layers and
shows every expression without errors; prints „OK test_models“ as now.

### 8.2 Smoke

`--quit-after 6000` from a clean profile: the creator opens (no SCRIPT ERROR); with a profile that has a character, day 1
or the overview opens as before.

### 8.3 Screenshot tour (`main.gd`) – new CHECK names

The tour plays the 7 days back to back; with the date lock it calls `Game.debug_next_day()` after each win
(before tapping the next tile). Changed checks: `day_success` now expects the primary button „Weiterbauen“ and the line
„Morgen geht's weiter: Tag 2 · Pflanzen“; `day_next` taps „Nächster Tag (Test)“ first, then the day 2 tile.
Add to the tour and to the expected list in `.github/workflows/gdpd.yml`:

| name | what it checks |
|---|---|
| `creator_flow` | clean profile: the creator opens before day 1; 4 steps with real taps; „Würfeln“ changes the preview look; tone card „Frech“ shows its sample; „Fertig – los geht's!“ saves `[charakter]` and opens day 1 |
| `character_coach` | the day 1 coach bubble shows the character portrait (not the old tile) and the frech text of `d1 c0` |
| `day_locked_tomorrow` | after the day 1 win: overview tile 2 shows „Morgen“, tap → toast „Morgen geht's weiter: Tag 2 · Pflanzen“, Heute card „Heute geschafft!“ with a countdown line |
| `continue_mode` | „Weiterbauen“ on the win card: chip shows the check and no ring, 3 real twists later the day is still won, no fail card, growth counter moved |
| `streak_celebration` | first win: streak 1 line on the win card; after `debug_next_day` and the day 2 win: streak 2, flame number 2, week row with two flames |
| `next_day_button` | the pill exists (debug), tapping it opens day 2 („Heute neu“) |
| `streak_shield` | streak 7 milestone gives a shield (set state, win); then two `debug_next_day` without a win → streak kept, week row shows a shield circle, comeback line „… Serienschutz …“ |
| `daily_world` | after day 7 + `debug_next_day`: Heute card „Welt des Tages · <weekday>“, goal card opens with the template's goal, win counts for the streak |
| `reminder_plan` | after a win, the log has ≤ 4 `REMINDER plan` lines with ids 101/102/104/107, times within 08:00–21:30, four different templates, the last one is the tone's final text |
| `reminder_settings` | menu section „Erinnerung“: on PC it shows „Erinnerungen gibt es nur auf dem Handy.“ |
| `permission_ask` | after the first day 1 win the character card „Soll ich dich morgen erinnern …“ appears once; „Lieber nicht“ closes it and it does not come back on the next win |

Screenshots to add: `00_charakter_1.jpg` … `00_charakter_4.jpg`, `00u_morgen.jpg`, `00v_weiterbauen.jpg`,
`00w_serie.jpg`, `00x_welt_des_tages.jpg`, `00y_erinnerung.jpg`.

**As built (UI integration).** The tour runs with a fixed clock (Monday 2026-11-09, 17:40) from a clean profile and
prints these checks (all in the expected list of `.github/workflows/gdpd.yml`):

| name | what it checks (real input) |
|---|---|
| `creator_finish` | the creator opens before day 1; „Würfeln“ changes the look; Katzengott, a colour, the crown, tone „Frech“ (the preview says the sample); „Fertig – los geht's!“ saves `[charakter]` and opens the day 1 goal card with „Hi, ich bin Miez …“ |
| `character_coach` | the day 1 „Schau zu!“ line comes from the character: its portrait (the cat) and the frech text of `d1_demo` |
| `day_success` | win card: primary „Weiterbauen“, the line „Morgen geht's weiter: Tag 2 · Pflanzen“, the streak counted up to 1 |
| `permission_ask` | leaving the first win card, the character asks once (frech text with „Tag 2 · Pflanzen“); „Lieber nicht“ closes it (`gefragt` = 1). On PC only because the tour sets `debug_ask_on_pc` |
| `continue_mode_no_limit` | „Weiterbauen“: chip shows the check and „gewachsen“ instead of the ring, `twists_left() == -1`, 3 real twists later still won, no fail card, the growth counter moved |
| `day_locked_until_tomorrow` | overview: tile 2 shows the moon and „Morgen“, Heute card „Heute geschafft!“ with „Neuer Tag in 9 Std. 20 Min.“ and „Weiterbauen“; tapping tile 2: toast „Morgen geht's weiter: Tag 2 · Pflanzen“ and the character's frech `day_done` line |
| `next_day_debug_unlocks` | the pill „Nächster Tag (Test)“: day 2 open, Heute card „Heute neu · Tag 2 · Pflanzen“, Tuesday is today in the week row |
| `streak_increments` | day 2 won on the next Spieltag: the streak counts 1 → 2, two flames in the week row, the frech `streak_n` line |
| `reminder_scheduled` | the plan after that win: ids 101/102/104/107, categories A/B/C/F, A at 17:10 (session 17:40 − 30 min), all within 08:00–21:30, four different texts, the last one the frech final message, every entry logged by `Notifier` (`REMINDER plan …`); menu „Erinnerung“: on PC „Erinnerungen gibt es nur auf dem Handy.“, „Feste Uhrzeit“ plans at 18:00 |

Implementation: `scripts/voice.gd` (`class_name Voice`, the character's voice on top of `CharacterTexts`: tone, name,
never the same line twice per key, `day_coach(n, i, fallback)`); the creator is `scripts/character_creator.gd`
(hosted by `DayUI.open_creator`); coach bubbles, the lane, the goal card, win/fail cards, the overview and the
permission card use `GameUI._speaker()` (round portrait + topic badge); `GameUI.char_react()` changes the face of
every visible character (merge → happy, 2nd miss / fire / war → worried, wish → proud). In the test build the menu
also shows the time stepper on PC (it only plans log lines there).

### 8.4 On a phone (manual, with the CI APK)

1. Fresh install, Android 13+: create a character, win day 1, „Ja, gern“ → system dialog → allow.
2. Menu → Test → „Erinnerung in 10 s“, lock the phone: the notification shows the character's name, text and face.
3. Tap it: the app opens, the character greets.
4. Reboot with a planned reminder: win a day (the plan exists), reboot, then `adb shell dumpsys alarm | grep gdpd`
   must still list the alarms (restored by `RestoreReceiver`).
5. Settings → „Aus“: `dumpsys alarm` shows no gdpd alarms.

---

## 9. Implementation map

| file | change |
|---|---|
| `scripts/daily.gd` (new) | `class_name Daily`: day keys, unlock, streak, shields, WdT choice, clock rules – pure static |
| `scripts/game.gd` | `now_local()`, daily state + save `[taeglich]`, migration, `day_unlocked()`/`current_day()` via `Daily`, streak on `_finish_day`, WdT start (`start_daily_world()`), Weiterbauen (`continue_build()`), coins, debug hooks, signals `streak_changed(info)`, `daily_changed` |
| `scripts/game_state.gd` | `day_free_build` flag (no limit, no fail), part of `clone()` |
| `scripts/days.gd` | `coach_lieb/frech/streng` arrays per day, new `TEXT` keys (Morgen, Weiterbauen, Heute geschafft, Welt des Tages, countdown, Serie, Serienschutz) |
| `scripts/day_ui.gd` | overview header (character, chips), Heute card, week row, „Morgen“ tile, countdown, win card buttons, streak celebration, shield card, debug pill |
| `scripts/ui.gd` | coach bubble with portrait, menu sections „Dein Charakter“, „Erinnerung“, „Test“, `Voice` for coach text, permission card |
| `scripts/character.gd`, `character_view.gd`, `creator_ui.gd` (new) | section 3 |
| `scripts/voice.gd` (new, done) | section 4: `Voice.line/face/day_coach` on top of `CharacterTexts` |
| `scripts/reminder_plan.gd` (new, done) | `class_name ReminderPlan`: the pure plan (5.3), template selection with recency (5.4), the texts of 4.7, history, log line |
| `scripts/reminders.gd` (new) | plugin wrapper (6.3, 6.7): listens to `Game.reminders_planned(plan)`, sets `Game.remind_permission` |
| `scripts/balance.gd` | `SHIELD_MAX`, `SHIELD_PRICE`, `STREAK_MILESTONE`, `SHIELD_FULL_COINS`, `BUILD_COIN_EVERY = 10`, `BUILD_COIN_MAX = 3`, `REMIND_EARLIEST = 480`, `REMIND_LATEST = 1290`, `REMIND_LEAD = 30`, `REMIND_LADDER = [1, 2, 4, 7]` |
| `scripts/main.gd` | tour additions 8.3 |
| `icons/streak.svg`, `icons/shield.svg`, `icons/moon.svg`, `icons/dice.svg`, `icons/character/**` (new) | art |
| `addons/gdpd_reminder/`, `android_plugin/` (new) | section 6 |
| `export_presets.cfg`, `project.godot`, `.gitignore` | 6.2, 6.5 |
| `.github/workflows/gdpd.yml` | 6.6 + the new CHECK names |

Suggested order: (1) `Daily` + save/migration + tests, (2) unlock/overview/Weiterbauen/streak UI + tour,
(3) character data/view/creator + `Voice`, (4) `Reminders.plan` + tests, (5) plugin + CI + phone test.

---

## 10. Open points

- The streak flame next to the danger fire: watch the first player test; if it confuses, switch the streak symbol to a
  sun („Sonnen-Serie“) – only `icons/streak.svg` changes.
- Persisting Weiterbauen worlds needs a `GameState` serializer (later).
- iOS: the maintained `godot-notification-scheduler` covers iOS from Godot 4.5/4.6 on; revisit with an engine upgrade.
- Shop (more parts, skins, premium): parts are data rows + SVGs; prices and the coin economy need their own pass.
- WdT difficulty: the templates are the validated day boards; if players find them too easy after a month, add
  „Welt des Tages · schwer“ boards from the model (`days.py`) with shorter limits.

Sources: cengiz-pz plugin v3.0 source (`NotificationScheduler.gd`, `NotificationReceiver.java`,
`NotificationSchedulerPlugin.java`, `build.gradle.kts`) and releases page; godot-mobile-plugins/godot-notification-scheduler
README, releases and `common/config/godot.properties`; Godot 4.3-stable sources
(`platform/android/java/app/config.gradle`, `gradle-wrapper.properties`, `platform/android/export/export_plugin.cpp`,
`PermissionsUtil.java`, `editor/export/export_template_manager.cpp`); abarichello/godot-ci Dockerfile.
