# gdpd – Balance 2: Erschaffen und Gedeihen, kein Farmen, wenige Arten (Spec v2)

This spec is for implementers, so it is written in English. Every text a player sees is in simple German (du-form),
as short as possible (2–6 words), and is written here exactly as it should appear.

It replaces Spec v1 of this file (v1 only removed farming and thinned the old day boards). v2 adds the **new core
concept approved by the user** and rebuilds the 7 days on it. Where it conflicts with `GDPD_7_TAGE.md`,
`GDPD_REGELN.md` or `GDPD_TAEGLICH_CHARAKTER.md`, this spec wins for the 7 days; free play keeps its rules
(section 3) until it gets its own pass.

**Player feedback this answers (verbatim):**
- „Teilweise ist es aber auch viel zu leicht, weil ich einfach immer die gleiche Scheibe hin und her drehen kann,
  damit es immer gleich Upgrades gibt.“
- „Sollten nicht zu viele verschiedene Felder auf einmal aktiv sein? Wenn der nächste Tag erreicht wird, könnten sich
  ja die niedrigeren Upgraden, damit man nicht zu viel verschiedene hat und es zu unübersichtlich wird. Es kann ja
  dann von Tag zu Tag schwerer werden.“
- „Ok, und der Spieler bekommt immer die Tagesaufgabe, damit er weiß was er tun bzw verbinden muss. Wenn er seine
  Aufgabe erledigt hat, kann er noch weiter farmen oder so.“

**The concept in one line:** „Zuerst schützt du die Menschen vor der Natur, später die Natur vor den Menschen.“

**Validated with:** the real GDScript (`game_state.gd`, headless, all 140 current pool boards) for the exploit; the
Python rules model `engine8.py` for the new days (300 generated boards per day and bot, 20-board pools); and a
GDScript reference port of the new rules (`rules8.gd`, scratch) that matches the model step by step
(700 cases, 11 359 steps, 0 mismatches; all 140 pool solutions win at exactly `solved_in` in GDScript). Files:
section 13.

---

## 0. Decisions (summary)

| # | decision | why (one line) |
|---|---|---|
| 1 | **Two kinds of growth.** ERSCHAFFEN: nature grows by „Bring 3 gleiche in eine Reihe“ (Erde → Wiese → Wald → Tiere → Hütte). GEDEIHEN: people (Hütte → Dorf → Stadt) never form rows; they grow when their **neighbours** meet their needs. | The approved concept; people become a puzzle of neighbourhoods, not of rows. |
| 2 | **Needs:** Hütte 🍞 · Dorf 🍞🔨 · Stadt 🍞🔨🙏. Sources: 🍞 Tiere, Acker · 🔨 Wald, Stein, Industrie · 🙏 Kirche. | One new need per day (4, 5, 6); at most 3 icons on a field. |
| 3 | **Satt 2 Runden → wächst; 4 Runden Hunger → schrumpft.** | Short enough to see, long enough to plan; shrinking is a warning, not a punishment loop. |
| 4 | **3 Tiere → 1 Hütte**; the other 2 Tiere become Wiese („Die Tiere ziehen ein“). | Otherwise every new Hütte is fed at birth and day 4 has no puzzle. |
| 5 | **Every danger warns one twist ahead:** Blitz (field), Krieg (churches touch), Flut (crowded face). Smog acts every twist next to Industrie. | The player can always react; nothing comes out of nowhere. |
| 6 | **„Jede Reihe wächst nur einmal“** (rule `once`, from Spec v1) stays for all rows, days and free play. | Kills every repeat loop; zero cost for honest play. |
| 7 | **No more „3 Fehlversuche → Feuer“ on the days.** Fire is now a nature event (Blitz) from day 3. | It was the engine of the farming loop (section 1.3) and the concept puts fire on day 3. |
| 8 | **At most 3 growable kinds per day**; yesterday's lower kinds have **grown overnight** („Über Nacht gewachsen“). | Fewer different fields at once; each day continues yesterday's world. |
| 9 | **Rising difficulty:** good bot 100 → 100 → 97 → 90 → 89 → 76 → 71 % (300 boards); greedy and weak fall off from day 3; ★★★ 22–45 %. | „Es kann ja dann von Tag zu Tag schwerer werden.“ |
| 10 | **The task is always on screen** with what to connect (icons), during play and after the win (**Extra-Aufgaben** in Weiterbauen). Farming after the win is allowed, but only real new growth pays. | „Damit er weiß, was er tun bzw. verbinden muss … kann er noch weiter farmen.“ |
| 11 | New pools (20 per day, solutions), every board farm-proof (ping-pong, cycle and single-slice farmers never win). | Shipped boards cannot be beaten by farming, even by an oracle. |

---

## 1. The exploit, reproduced with the real GDScript

### 1.1 Method

Scratch copy of the current `gdpd/` (unchanged scripts, current pools), headless (`farm.gd`): on all 140 pool boards,
honest play = the hint (`best_day_action`, rain included) vs. pure cycles, each played for the day limit (after a win
it continues in Weiterbauen): `pp` = one slice back and forth (m, m′, m, m′ …), `rot4` = same slice same direction,
`rot3` = m, m, m2, `pp2` = half turn twice, `comm` = A B A′ B′, `dbl` = A A′ B B′ (two-slice cycles from the 4 best
slices). For every board the **best** move/pair is kept (oracle farmer). Also `strike_farm.gd` (day 7 Gewitter) and
`farm_free.gd` (free play, 12 seeds, 30 twists). Re-run on 7 November 2026 on the current repo: identical numbers.

### 1.2 Results (current rules, current pools; growth = fields that grew per twist)

| day | honest g/tw (won) | pp | rot4 | rot3 | pp2 | comm | dbl | farmers won |
|---|---|---|---|---|---|---|---|---|
| 1 | 1.56 (20/20) | 0.14 | 0.27 | 0.22 | 0.13 | 0.39 | 0.24 | comm 3/20 |
| 2 | 1.30 (20/20) | 0.28 | 0.37 | 0.25 | 0.22 | 0.45 | 0.31 | 0 |
| 3 | 1.23 (19/20) | 0.27 | 0.39 | 0.30 | 0.25 | 0.45 | 0.33 | 0 |
| 4 | 1.05 (19/20) | 0.20 | 0.24 | 0.14 | 0.17 | 0.24 | 0.19 | 0 |
| 5 | 0.90 (19/20) | 0.28 | 0.31 | 0.22 | 0.23 | 0.32 | 0.28 | 0 |
| 6 | 0.78 (20/20) | 0.20 | 0.24 | 0.19 | 0.15 | 0.27 | 0.23 | 0 |
| 7 | 0.85 (19/20) | 0.21 | 0.28 | 0.19 | 0.16 | 0.26 | 0.25 | 0 |

Growth per twist index for `pp` (share of boards where twist t grew), day 5: `0.85 0 0 0 0.65 0.20 0 0 0.80 0.20 0 0
0.80 …` – a strict **period of 4**: grow, miss, miss, miss (fire), grow again. Day 1 (no fire): growth only at t0.
That period is exactly what the player felt: the same slice back and forth „gibt immer gleich Upgrades“.

Day 7 Gewitter (20 boards): hint 2.6 Gewitter per day, 0 regrowths; „Gewitter on any field“: **148 Gewitter per day,
148 regrowths** – an endless faith fountain without a single twist.

Free play (30 twists, 12 seeds): Mittel, any slice back and forth (median slice) grows something on **66 %** of the
twists (Schwer 66 %, Einfach 27 %); Einfach `rot4` out-earns the eval bot (faith 7419 vs. 4828).

### 1.3 Why the current rules let it through (traced event by event)

1. **Fire reset (days 2–7, free play).** Twist A makes the row (a, b, c) of kind k grow: c → k+1. Twisting back and
   forth then misses three times; the 3rd miss burns the last swiped row (it contains c). Next twist c falls back to
   k, the trio (a, b, c, k) stands again, and the late merge makes it grow **again**. `broken` only remembers the rows
   of the *last* twist, `standing` only the rows at turn start, `spent` exists only for Einfach groups – nothing
   remembers that this exact row already grew. Growth changes the kind of c, so the trio key differs while c is
   grown, and becomes the old key again after the fall.
2. **Gewitter reset (day 7, free play).** Gewitter lets a field fall one step. If it was the target of a row, the old
   trio is complete again and grows in the same round. Gewitter is no twist, so it costs neither twists nor misses.
3. **Passive regrowth (free play).** Each twist one Erde with ≥ 2 nature neighbours becomes Wiese and joins the late
   merges; with many Wiesen around it completes a Wiese row almost every twist, whatever slice is turned.
4. **Einfach groups (free play).** A completing row makes the whole connected group grow; rotating one slice in one
   direction keeps bringing new group contacts (real growth, but faster than thinking).
5. **Not the cause:** straight rows on the side faces of the slice (they keep their key when the face rotates,
   `standing` blocks them) and quarter turns that bring new stickers (honest new rows, bounded – without falls the
   total growth of a board is finite).

---

## 2. The anti-farming rule: „Jede Reihe wächst nur einmal“

### 2.1 Exact rule

- `spent` (exists today for Einfach) becomes the memory of **every** row that has grown, in all modes:
  key = `line_key(line)` = the 3 field ids (sorted) + the kind **before** growing.
- When a row grows (straight or diagonal, Einfach group or not, first pass or cascade, normal or late, by twist or by
  rain), its key goes into `spent` **before** the target changes kind. When a whole face grows, all lines of that face
  go into `spent`.
- A row whose key is in `spent` never counts again: in the first pass via `counts()` (as now), and **also in cascade
  passes** (`pass_i > 0`; today cascades skip `counts()`).
- `spent` is kept for the whole game (day attempt, Weiterbauen, free-play game), copied by `clone()`, part of undo
  and the save. Size: one entry per growth (a day < 40, a 300-twist free game < 600).
- A field that fell can still grow in a **new** row (another trio, or the same fields with another kind).

### 2.2 Why this rule and not a pause

| variant (current pools, 20 boards/day) | good won / ★★★ (days 1–7) | farmers | verdict |
|---|---|---|---|
| current rules | 100 % all days / 60 20 55 45 50 30 70 | slice farmer wins day 2 55 %; day-7 Gewitter farmer 3.35 growths/twist | exploit |
| **once** | **identical** (100 % / 60 20 55 45 50 30 65) | pp growth halved, slice farmer day 2 55 → 5 %, Gewitter farmer 0.95 growths/twist (= honest) | **chosen** |
| pause 1 twist („ruht kurz“) | 95–100 % / 60 15 40 35 50 35 70 | pp unchanged, Gewitter farmer 2.60 | hurts honest, not farmers |
| pause 2 twists | 95–100 % / 60 10 30 25 55 35 70 | pp unchanged, Gewitter farmer 2.15 | worse |

The pause blocks the honest follow-up row (a field that just grew is the natural centre of the next row) and does not
stop the loop (the loop period is 4, longer than any short pause). „Once“ only ever blocks a row that already grew,
which honest play never needs.

### 2.3 Feedback (existing `spent` path)

- badge `check` on the 3 fields, pill caps **„Schon gewachsen“**, big line **„Bring ein anderes Feld rein“**
  (already in `ui.gd`; keep). Help (Regeln) gets one line: **„Jede Reihe wächst nur einmal.“**
- Coach (once per profile, the first time a `spent` row is shown): **„Diese Reihe ist schon gewachsen.“**

### 2.4 In the new days

The new days have no miss-fire, so the classic loop cannot start there at all; `once` still matters where something
can fall back (Blitz fire on days 3–5, smog, war) and in free play. Best ping-pong of any slice on the new pools
(model, growth in twists 3–20, i.e. after the first two honest rows): day 3 **3** with `once` vs. **8** without,
day 4 1 vs. 2, all other days 0.

---

## 3. Free play (unchanged concept, rule 2.1 plus regrowth fix)

- Rule 2.1 is on.
- **„Nachwachsen schließt keine Reihe.“** Regrowth (one Erde → Wiese per twist, ≥ 2 nature neighbours, not in smog)
  skips every Erde field that would complete a row of 3 Wiesen as Wiese (straight, or diagonal where diagonals count).
- Free play keeps miss-fire, Gewitter, wishes and the Waage until its own pass. Gedeihen comes to free play later
  (proposal: same needs; Großstadt needs 💧 Wasser as a 4th source).

### 3.1 Free play before / after (real GDScript, 12 seeds × 30 twists, `farm_free.gd`)

| level | strategy | before: made/tw · faith · twists that grew | after (once + regrow_safe) |
|---|---|---|---|
| Einfach | eval bot | 11.82 · 4828 · – | 11.04 · 4642 · – |
| Einfach | best ping-pong | 10.15 · 4412 · 45 % | 9.56 · 3835 · 41 % |
| Einfach | same slice, same direction (rot4) | 12.23 · 7419 · 56 % | 12.37 · 8375 · 56 % |
| Einfach | median slice back and forth | 5.49 · 270 · 27 % | 4.57 · 194 · 21 % |
| Mittel | eval bot | 3.21 · 724 | 3.39 · 802 |
| Mittel | best ping-pong | 1.04 · 73 · 65 % | **0.68 · 24 · 43 %** |
| Mittel | rot4 | 1.31 · 127 · 68 % | 1.05 · 76 · 55 % |
| Mittel | median slice back and forth | 0.80 · 49 · 66 % | **0.45 · 10 · 35 %** |
| Schwer | eval bot | 3.06 · 550 | 3.16 · 571 |
| Schwer | best ping-pong | 0.99 · 62 · 65 % | 0.68 · 24 · 43 % |
| Schwer | median slice back and forth | 0.75 · 39 · 66 % | 0.45 · 10 · 35 % |

Mittel/Schwer: farming income falls to 3 % (ping-pong) and 1 % (median slice) of honest play. **Open:** Einfach
`rot4` still out-earns the eval bot, because whole groups grow on every new contact (section 12).

---

## 4. The new core rules (days)

### 4.1 Kinds

| kind | id | role | grows by | gives (to its 4 neighbours) |
|---|---|---|---|---|
| Erde | 0 | land | row (days 1–2) → Wiese | – |
| Wiese | 1 | nature | row (days 2–4) → Wald; rain → Wald / Acker | – |
| Wald | 2 | nature, burns | row (days 3–5) → Tiere | 🔨 Arbeit |
| Acker | 3 | food | – (rain on a Wiese next to people) | 🍞 Nahrung |
| Tiere | 5 | nature, burns | row (days 4–7) → Hütte | 🍞 Nahrung |
| Hütte | 6 | people, burns | Gedeihen → Dorf (from day 5) | – |
| Dorf | 8 | people, burns | Gedeihen → Stadt (from day 6) | – |
| Stadt | 9 | people | – | – |
| Kirche | 10 | finished | – | 🙏 Glaube |
| Industrie | 12 | finished (day 7) | – | 🔨 Arbeit, Smog |
| Wasser | 15 | background | – | (💧 free play) · makes neighbours „nass“ |
| **Stein** | **16, new** | background (day 5+) | – | 🔨 Arbeit |

Großer Wald, Haus, Großstadt, Metropole, Paradies are not used on the days (they stay in free play). Stein is new:
an inert grey rock field like Wasser (`FieldData.KIND_COUNT` 17, icon `stone`, board code `R`).

Neighbours = the 4 stickers next to a field on the cube, **across edges too** (`GameState.neighbors`).

### 4.2 Erschaffen (rows)

- Rows as today: 3 equal fields in a new straight row on one face; no diagonals on the days. `standing`, `broken`
  and **`once`** apply. Only the kinds in the day's `rows` set form rows; every other kind is silent.
- Next kind (days): Erde → Wiese → Wald → Tiere → Hütte.
- **Consume:** when a row of Tiere grows, the target becomes a Hütte and the **other two Tiere become Wiese**
  (they are locked for the rest of the round, no cascade from them). Event `grow` with `others`.
- Rain (tool, no twist): on the warned Blitz field → the Blitz is cancelled; on a burning field → all fire on that
  face goes out; on Erde → Wiese (day 2); on Wiese → **Acker if a people field is next to it** (days 5–7), else Wald.
  A field made by rain may complete a row (counts as usual).

### 4.3 Gedeihen (people)

- **Needs** (by level): Hütte `[food]`, Dorf `[food, work]`, Stadt `[food, work, faith]`. A need is met if **any**
  neighbour is a source of it (4.1). Sources are not used up: one Tiere field feeds every Hütte around it.
- A people field is **satt** when all its needs are met, it is not burning and it is not in a war front.
- At the end of every twist (step 9 in 4.5), for every people field:
  - satt → `hungry = 0`, `fed += 1`; if `fed ≥ 2` and the next level is allowed today (`top`), it grows
    (Hütte → Dorf → Stadt), `fed = 0`. Event `thrive`.
  - not satt → `fed = 0`, `hungry += 1`; if `hungry ≥ 4` and it is above Hütte, it shrinks one level, `hungry = 0`.
    Event `starve`. A Hütte never shrinks by hunger (it only shows „Hunger“).
  - `fed`/`hungry` belong to the field and move with it; they reset when the field changes kind by anything else
    (row, fire, war, flood, meteor).
- `made[k]` counts a thriving growth only the **first time this field reaches level k** (`maxlvl`), so shrink and
  regrow never count twice (anti-farming for Gedeihen).
- Tasks of the Gedeihen days count a **state** at the end of a twist („3 Dörfer satt“), never events.
- Start boards: nothing is satt („Über Nacht hungrig geworden“), no ready row, no two churches touching.

### 4.4 Dangers and Glaube

All dangers are deterministic; the only random choice (Blitz tie-break) uses the model's LCG
(`rng = (rng · 1103515245 + 12345) & 0x7fffffff`, value `(rng >> 8) % n`, seed `(seed · 7919 + 17) & 0x7fffffff`),
so pools replay exactly.

**Blitz und Feuer (days 3–5):**
- `lightning = E`, `lightning_from = F`: at the end of twist t with t ≥ F and (t − F) mod E = 0, a **warning** is set
  on one field: among Wald/Tiere that are not burning and not fresh, the one with the most flammable neighbours
  (ties: LCG). Event `bolt_warn`.
- At the end of the **next** twist the warned field catches fire if it is still Wald/Tiere (event `bolt`; else
  `bolt_miss`). Rain on it before that cancels it (`bolt_cancel`).
- Fire step (end of every twist, before the Blitz): every field that was already burning spreads to each neighbour
  that is flammable (Wald, Tiere, Hütte, Dorf), not burning, not fresh and **not nass** (no Wasser neighbour), then
  burns down: Wald → Wiese, Tiere → Wiese, Hütte → Wiese, Dorf → Hütte. Burnt fields are fresh (cannot catch fire)
  for the next 2 fire steps. Events `ignite`, `burnt`.
- So the player always has one twist: move the forest away from huts, put water next to them, or rain.

**Krieg (days 6–7):** churches that touch another church at the end of a twist start a war: event `war_start`
(„Krieg droht!“), the **front** = all people next to those churches; no damage yet. At the end of every following
twist with churches still touching: every front field falls one level (Stadt → Dorf → Hütte → Wiese, event
`war_hit`), then the front spreads to all people next to it. Front fields are never satt. When no churches touch at
the end of a twist: `war_end` („Frieden“), front cleared. Churches themselves are never damaged.

**Meteor (days 6–7):** Glaube (Rev. 9, anti-farming): a people field pays **+3 Glauben once per level** – when it
stands next to a Kirche at the end of a twist with a level it has not been paid for yet (first time faith, or it grew
Hütte → Dorf → Stadt). Fields already next to a church in the morning pay only after they grow (`flvl` per field,
`FieldData.flvl` / `engine8.flvl`). Twisting one slice back and forth therefore brings nothing (before: +1 per people
field next to a church on **every** twist, a meteor after a median of 6 back-and-forth twists). With **12 Glauben** a
Meteor can be thrown (tool, no twist) on any non-Wasser field: it becomes Erde (crater). On a church it usually ends
the war at the end of the next twist. A good game earns about one meteor (good bot, faith at the win: day 6 9–15,
day 7 3–12); back and forth on any slice never reaches 12 within 40 twists on any day-6/7 pool board.

**Smog (day 7):** at the end of every twist, every Industrie lets its best nature neighbour fall one step
(Tiere → Wald → Wiese → Erde; ties: neighbour order). Event `smog`.

**Flut (day 7):** city weight of a face = Dorf 1, Stadt 2, Industrie 2. A face with weight ≥ 5 at the end of a twist is
**warned** (`flood_warn`, „Das Meer steigt!“). If it is still ≥ 5 at the end of the next twist, every Erde, Wiese,
Acker and Hütte **on that face with a Wasser neighbour** becomes Wasser (event `flood`), and the face stays warned.
Half of the day-7 pool boards start with one crowded face (the cities grew overnight): the first warning comes after
twist 1 – the day's new thing shows at once.

### 4.5 Order of a twist round (exact)

1. Rows (creation, `once`, consume). 2. `twists += 1`; `fresh −= 1`. 3. Fire spreads and burns down.
4. Blitz strikes / new warning. 5. Smog. 6. Flut. 7. Krieg. 8. *(nothing else changes kinds after this)*
9. Gedeihen (satt / grow / hunger / shrink). 10. Glaube. 11. Rain every N twists (max 3). 12. Task check.

Rows only grow from twists and rain: kinds changed by fire, smog, flood, war or meteor never trigger a row in the same
round (they can form one with a later twist). Rain and Meteor are no twist: no round, no counters.

### 4.6 Preview while twisting (contract)

While the finger drags a slice (before release), the game computes the state after the rotation and compares
supply. Rev. 9: `satt_new` / `satt_lost` come from the state **after the whole round** (the same clone
`Game.preview` resolves: merges, 3 Tiere → Hütte, war hits, thriving), so a hut made satt by the twist is marked and a
field that loses food because its Tiere move into a new hut is marked red; a field that grows a level and then lacks
the next need is not a loss. The need-icon diff (`need_met`, `need_lost`) stays rotation-only. `test_preview8` checks
preview = real events for every move on boards 0–2 of days 4–7. While dragging, the goal chip shows the change as a
ghost value („1→2/3“ green, „2→1/3“ red), also when the field is out of view:

```
preview(move) -> {
  "satt_new":  [field ids],          # will be satt after this twist (were not)
  "satt_lost": [field ids],          # are satt now, will not be
  "need_met":  {id: ["food", …]},    # needs that become met for each people field
  "need_lost": {id: ["work", …]},
  "rows":      [[a, b, c, kind], …], # rows that will count (as today)
  "war_risk":  bool,                 # churches would touch
  "flood_risk":[face, …],            # faces that would reach weight 5
  "fire_risk": [field ids]           # flammable, dry fields next to a burning field after the move
}
```

Model: `GS8.preview(m)` returns `(satt_new, satt_lost)`; the rest is the same pattern. Cost: one clone + 54 need
checks (cheap enough per drag frame; cache per move).

---

## 5. The 7 days

### 5.1 Arc and kinds per day

| day | new thing | start board (rest Wasser) | growable today (≤ 3) | made today, rests | overnight (presentation) |
|---|---|---|---|---|---|
| 1 Land | 3 gleiche → Wiese | Erde 22 | Erde | Wiese | – |
| 2 Pflanzen | Wald, Regen | Wiese 10, Erde 16 | Erde, Wiese | Wald | Erde → Wiese |
| 3 Tiere | **Blitz, Feuer** (nature is danger) | Wiese 18, Wald 7 | Wiese, Wald | Tiere | Erde → Wiese |
| 4 Menschen | 3 Tiere → Hütte; 🍞 Nahrung | Wald 10, Tiere 13, Wiese 2 | Wald, Tiere (Wiese from consume) | Hütte | Wiesen → Wald |
| 5 Arbeit | 🔨 Arbeit, Stein, Acker (by rain); Hütte → Dorf | Hütte 5, Wald 7, Tiere 5, Stein 3, Wiese 7 | Wald, Tiere, Hütte | Dorf | Tiere → Hütten |
| 6 Glaube | 🙏 Kirche, **Krieg**, Meteor; Dorf → Stadt | Dorf 8, Kirche 3, Wald 7, Tiere 5, Acker 4, Stein 3 | Tiere, Dorf | Stadt | Hütten → Dörfer |
| 7 Gleichgewicht | **Smog, Flut** (people are danger) | Stadt 5, Kirche 3, Industrie 2, Wald 9, Tiere 5, Acker 4 | Tiere | Stadt | Dörfer → Städte |

„Growable“ = a row kind with ≥ 3 fields on the board, or a people level below today's top. Checked on all 140 pool
boards: max growable kinds at start = 1, 2, 2, 2, 3, 2, 1 (before Rev. 8: 1, 2, 4, 5, 7, 8, 9).

**Visible kinds (Rev. 9):** the user's complaint was about *different fields on screen*, not only growing ones. The
pool boards now show at most **1, 2, 2, 3, 5, 6, 6 kinds besides Wasser** (`Days.VISIBLE_MAX`, checked in
`test_day_boards` and in the tour check `kinds_per_day`; before: 1, 2, 2, 3, 6, 8, 9). Leftover lower kinds became
their overnight upgrade (day 6: the 3 Hütten are Dörfer, day 7: the 5 Dörfer are Städte), inert Wiesen are gone from
days 6–7 (day 5 keeps 7 Wiesen: rain next to huts makes the Acker), day 5 gets its Acker from rain instead of the
start board, day 7 lost Stein (Wald and Industrie give Arbeit). Wasser fell from 61 % to 50 % of the fields on day 5
(and 44–48 % on days 6–7), so people fields dominate the later faces.

### 5.2 Day table (config)

| day | task (chip) | limit | ★★★ ≤ | ★★ ≤ | `rows` | `top` | systems |
|---|---|---|---|---|---|---|---|
| 1 | Lass 8 Wiesen wachsen | 15 | 4 | 6 | Erde | – | no rain |
| 2 | Lass 5 Wälder wachsen | 14 | 5 | 7 | Erde, Wiese | – | Regen start 1, +1 every 6; rain makes Wiese/Wald |
| 3 | Erschaffe 4 Tiere | 10 | 4 | 6 | Wiese, Wald | – | Regen 1, every 4; Blitz E 2, F 1 |
| 4 | Versorge 3 Hütten | 14 | 6 | 9 | Wiese, Wald, Tiere | Hütte | Regen 1, every 5; Blitz E 4, F 3; needs Hütte 🍞 |
| 5 | Mach 3 Dörfer satt | 13 | 4 | 7 | Wald, Tiere | Dorf | as 4 + rain Acker; needs Hütte 🍞, Dorf 🍞🔨 |
| 6 | Mach 3 Städte satt | 12 | 4 | 6 | Tiere | Stadt | Regen 1, every 5, rain Acker; Krieg; Meteor; + Stadt 🍞🔨🙏 |
| 7 | Mach 3 Städte satt | 11 | 4 | 6 | Tiere | Stadt | as 6 + Smog + Flut |

Rev. 9: day 3 had only 8 twists (a spike: the hint never got ★★★, the weak bot 0/6 against 4/6 on day 2); now 10.
Day 6 was easier than day 5 (hint ★★★ 2/6 against 0/6); now 12 twists and ★★ ≤ 6, day 7 ★★ ≤ 6 too.

Config keys (new, per day, in `Days`): `rows`, `next8`, `consume`, `top`, `needs`, `lightning`, `lightning_from`,
`war8`, `meteor`, `smog8`, `flood8`, `rain_acker`, `rain_kinds`, `grow_after` (2), `shrink_after` (4),
`flood_at` (5), `goal = ["make", [kinds], n] | ["satt", kind, n]`, `overnight`. The exact values are
`DAY8` in `gdpd_sim/b3/days8.py`; the JSON form the GDScript port reads is `cfg_json()` in `xcheck8.py`.

### 5.3 What makes each day harder than the one before

- 2: two steps from Erde to Wald, rain as a tool. 3: fire every 2 twists, 10 twists, 4 Tiere.
- 4: first Gedeihen task; every Hütte costs 3 Tiere and must end next to other Tiere; fire can burn huts.
- 5: two needs; huts must first grow (2 satt twists), then the Dorf needs Arbeit too; sources are scarce
  (no Acker in the morning, 5 Tiere); rain makes Acker only next to people.
- 6: three needs, 3 churches that must not touch (war spreads), a city needs 2 satt twists as a Dorf first.
- 7: same goal with only 11 twists, cities crowd a face (flood), Industrie kills nature next to it (smog).

### 5.4 Validation (Python model, 300 generated boards per day and bot)

| day | good won | good median | good ★★★ / ★★ | greedy won | weak won | pp / cyc / slice farmer won (100 boards) |
|---|---|---|---|---|---|---|
| 1 | **99.7 %** | 5 | 28 / 70 % | 98.7 % | 90.3 % | 0 / 18 / 0 % |
| 2 | **100 %** | 6 | 33 / 66 % | 98.0 % | 55.3 % | 0 / 0 / 10 % |
| 3 | **96.7 %** | 5 | 24 / 56 % | 39.7 % | 0.3 % | 0 / 0 / 3 % |
| 4 | **90.0 %** | 7 | 36 / 34 % | 45.3 % | 9.3 % | 0 / 2 / 0 % |
| 5 | **89.3 %** | 4 | 45 / 27 % | 21.0 % | 4.0 % | 0 / 0 / 3 % |
| 6 | **76.0 %** | 5.5 | 22 / 30 % | 39.3 % | 2.0 % | 0 / 0 / 0 % |
| 7 | **71.3 %** | 5 | 27 / 27 % | 28.7 % | 1.7 % | 0 / 1 / 0 % |

Targets: good ≥ 95 % days 1–2 ✓; 85–95 % days 3–5: 90 / 89 ✓, day 3 96.7 % (½ point above; the 8-twist limit is
already tight – one twist less gives 92 % but halves the greedy rate); 70–90 % days 6–7 ✓ (76 / 71); the curve falls
every day ✓; weak clearly worse ✓; ★★★ reachable, not automatic (22–45 %) ✓; **no farmer beats an honest bot on any
day** ✓. Every good-bot loss ends at the twist limit, almost always one short of the task (day 7: 69 of 86 losses
at 2/3, 16 at 1/3; days 4–6: 30/30, 31/32, 68/72 at 2/3).

Bots: `good` = the hint (1-ply over 27 twists, rain and meteor, then 2-ply on the best 6); `greedy` = 1-ply, no tools;
`weak` = half random, half „something grows or gets satt“. Farmers are oracles (best of all options per board):
`pp` best ping-pong of 27 moves, `cyc` best of rot4 / m m m2 / pp2 / A B A′ B′ / A A′ B B′, `slice` one slice only,
best of its 3 moves each twist (good-bot value) with rain, best of 9 slices.

### 5.5 Pools

- 20 boards per day, placed by sticker type (½ corners, 40 % edges, 10 % centres per kind), start rules of 4.3,
  ≤ 3 growable kinds, day 1 board 0 = tutorial (slice x = 1 makes an Erde row), the good bot wins in 3 (days 4–7: 4)
  … limit − 2 twists, no single twist wins, and **farm-proof**: `pp`, `cyc` and `slice` never win the board.
- Rejected while building (Rev. 9; days 1, 2 and 4 kept, days 3, 5, 6, 7 rebuilt with `b3/export8b.py`): day 3: 2
  farm; day 5: 69 bot, 5 farm; day 6: 10 bot; day 7: 72 bot (Rev. 8: day 1: 3 farm, 1 bot; day 2: 1 farm; day 4: 5
  bot, 2 farm).
- On the pools: good 100 % every day; greedy 95 / 100 / 55 / 35 / 25 / 30 / 15 %; weak (4 seeds) 88 / 40 / 0 / 10 /
  8 / 1 / 2 %; pp, cyc, slice **0 %** every day.
- Pool ★★★ / ★★ / ★ (of 20): 4/15/1, 5/15/0, 4/14/2, 7/7/6, 9/11/0, 5/8/7, 7/3/10; median `solved_in`
  5, 6, 5.5, 8, 5.5, 5, 6.5.
- Replay: all 140 solutions win exactly at `solved_in` with the stars of the model, in Python and in the GDScript
  port. File: `gdpd_sim/b3/gdpd_concept8_boards.json` (format as today, `code` gets `R` = Stein; per board also
  `growable`). Copy to `gdpd/data/days_schoepfung.json` and `gdpd/docs/gdpd_7_tage_boards.json` when the rules ship.
- Welt des Tages uses templates 2–7 of this table and their pools.

### 5.6 „Neuer Morgen“ (presentation only)

Rules start from the pool board; this is only how it appears. Each day is a **new world** (a pool board, not the
player's board of yesterday), so the pill says „Neuer Morgen“ and only a few fields grow up visibly (Rev. 9: before,
every field of the target kind was labelled „Erde wird Wiese“ – 18 of 18 meadows on day 3).
- First start of a day ≥ 2 from the overview (not on „Nochmal“, not in Weiterbauen): at most
  `Days.OVERNIGHT_MAX` = 4 fields whose kind is a `to` of the day's `overnight` list (spread evenly over the matching
  fields) are first drawn as their `from` kind; 0.4 s after the board is visible a soft wave from
  the camera-facing centre outwards (60 ms stagger, the normal growth pop at 70 % scale, one soft chime) turns them
  into today's kind. New landscape (Stein day 5, Kirchen day 6, Industrie day 7) fades in with the wave.
- Pill (top, `MOUSE_FILTER_IGNORE`, 1.8 s): caps **„Neuer Morgen“**, line: day 2/3 **„Erde wird Wiese“**,
  day 4 **„Wiesen werden Wald“**, day 5 **„Tiere werden Hütten“**, day 6 **„Hütten werden Dörfer“**, day 7
  **„Dörfer werden Städte“**.
- Never blocks input; a swipe during the wave finishes it at once and counts. The goal card comes after the wave.

---

## 6. The daily task is always visible, also after the win

### 6.1 Task chip (top, always on screen)

- Icon of the counted kind + progress + the connect hint as icons, e.g. day 4: `🛖 2/3 satt · 🛖 ← 🐄`;
  day 5: `🏘 1/3 satt · 🏘 ← 🍞 🔨`; day 6/7: `🏙 0/3 satt · 🏙 ← 🍞 🔨 🙏`.
- Tapping the chip highlights the fields that count (gold) and the fields that are one need short (outline +
  the missing need icon). No extra text.
- Days 1–3: `🌿 3/8` etc. as today.

### 6.2 Fields: need icons (Gedeihen days)

- Over every people field a tiny row of its need icons (max 3): grey = missing, white = met. Satt = all white +
  a soft gold ring. `fed` 1/2 shows as one filled dot („wächst bald“); `hungry` 2–3 shows as a sad tint;
  at `hungry` 3 a pulsing missing icon („gleich schrumpft es“).
- Icons: 🍞 `food` (Ähre/Brot), 🔨 `work` (Hammer), 🙏 `faith` (Kerze/Licht), 💧 `water` (free play later).
- Sources glow softly toward a people neighbour they serve (thin light line), so connections are visible.

### 6.3 Weiterbauen after the win („weiter farmen“)

- All rules continue, no twist limit, the day stays won. The chip becomes **„Extra: …“**: the same task with one
  more (task + 1, then + 2, then + 3 on days 1–3; only + 1 on days 4–7); each extra gives a small celebration and
  +1 ✦ in the overview. Model (good bot, 10 twists per extra, 30 boards/day): days 1–3 reached + 1 / + 2 / + 3 in
  100 / 97–100 / 83–100 % (median 1, 2–3, 4–5 twists); days 4–7 reached + 1 in 40–52 % (median 2.5–5 twists), + 2
  never (sources run out) → days 4–7 offer **one** extra, then „Bau weiter“.
- Every new growth (a row, or a field reaching a people level for the first time) gives +1 ✦. Farming pays nothing:
  new growth per twist in Weiterbauen (20 twists after the win, 30 boards/day):

| day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| honest (1-ply, most new growth) | 0.31 | 0.60 | 0.94 | 0.63 | 0.04 | 0.24 | 0.07 |
| best ping-pong | 0.05 | 0.05 | 0.21 | 0.09 | 0.01 | 0.04 | 0.01 |
| random twists | 0.10 | 0.12 | 0.29 | 0.07 | 0.02 | 0.11 | 0.05 |

---

## 7. Event contract (rules → UI/visuals)

`end_round()` / tools return the existing events plus (one dictionary each, `type` first):

| type | fields | visual | pill (caps · line) |
|---|---|---|---|
| `grow` | field, from, kind, others | growth pop (as today) | – |
| `consume` | field (new Hütte), others (became Wiese) | animals walk into the hut, grass on their fields | „3 Tiere · 1 Hütte“ |
| `satt_new` | field | gold ring pop, need icons turn white | „Satt!“ (first time per day only) |
| `satt_lost` | field, missing | ring fades, missing icon grey | – |
| `thrive` | field, from, kind | rise animation (hut → village → town) | „Hütte wird Dorf“ / „Dorf wird Stadt“ |
| `starve` | field, from, kind | sink animation, dust | „Dorf schrumpft“ / „Stadt schrumpft“ |
| `bolt_warn` | field | dark cloud over the field, small flash icon | „Blitz kommt!“ |
| `bolt` / `bolt_miss` / `bolt_cancel` | field | lightning + flames / cloud leaves / rain on it | „Feuer!“ / – / „Regen schützt“ |
| `ignite` | field | flames start | „Feuer breitet sich aus“ (once per fire) |
| `burnt` | field, from, kind | ash, then the new kind | – |
| `rain_out` | field | steam | „Gelöscht!“ |
| `war_start` | churches, front | crossed swords over the churches, red front tint | „Krieg droht!“ · „Trenn die Kirchen“ |
| `war_hit` | field, from, kind | fire/smoke on the field | „Krieg!“ |
| `war_end` | – | doves | „Frieden“ |
| `meteor` | field, from | meteor + crater | „Meteor!“ |
| `smog` | industry, field, from, kind | grey haze from the factory to the field | „Smog!“ (once per day) |
| `flood_warn` | face | water level rises at the face edges | „Das Meer steigt!“ · „Zu viel Stadt“ |
| `flood` | face, field, from | water over the field | „Flut!“ |

State for the HUD and field views (read after every round): per field `fed`, `hungry`, `need_state()` (met,
missing), `burning`, `fresh`; global `bolt`, `war_on`, `front`, `flood_warn`, `faith` (day 6–7), `rain`, task
progress. Non-blocking overlays use `MOUSE_FILTER_IGNORE`.

---

## 8. Metrics before / after (summary)

| metric | before (current game) | after (Spec v2) |
|---|---|---|
| ping-pong regrowth loop (period 4, day 5: 85 % of boards regrow every 4th twist) | yes (real GDScript) | gone: no miss-fire on days; `once` everywhere |
| best ping-pong growth/twist, days 2–7 | 0.28 0.27 0.20 0.28 0.20 0.21 (real GDScript) | 0.04 0.10 0.08 0.00 0.00 0.00 (model, 100 boards) |
| best cycle of any kind growth/twist, days 2–7 | 0.45 0.45 0.24 0.32 0.27 0.28 | 0.15 0.27 0.15 0.03 0.04 0.04 |
| honest growth/twist (rows), days 1–7 | 1.56 1.30 1.23 1.05 0.90 0.78 0.85 | 1.64 1.54 1.78 0.62 0.74 0.99 0.49 (+ Gedeihen 0.54 1.15 0.64 on days 5–7) |
| farmers that win a pool board | comm 3 (day 1), slice day 2 55 % | **0** (pools filtered; generated boards ≤ 18 %, always far below honest) |
| Gewitter regrowths per day, „Gewitter on any field“ | 148 | no Gewitter on the days; free play 0.7 with `once` |
| growable kinds on a start board (days 1–7) | 1, 2, 4, 5, 7, 8, 9 | 1, 2, 2, 2, 3, 3, 2 |
| good-bot win curve (300 boards) | 100 100 93 88 89 87 82 | 99.7 100 96.7 90.0 89.3 76.0 71.3 |
| greedy win curve | 99 99 36 37 82 70 64 | 98.7 98.0 39.7 45.3 21.0 39.3 28.7 |
| weak win curve | 90 61 0 2 1 8 1 | 90.3 55.3 0.3 9.3 4.0 2.0 1.7 |
| free play Mittel: median slice back and forth grows on | 66 % of twists | 35 % (faith 49 → 10 per 30 twists) |

---

## 9. Player texts (all new or changed; ≤ 6 words)

| where | text |
|---|---|
| rule (help, day 1 card) | „Bring 3 gleiche in eine Reihe.“ · „Jede Reihe wächst nur einmal.“ |
| `spent` pill / coach | „Schon gewachsen“ · „Bring ein anderes Feld rein“ / „Diese Reihe ist schon gewachsen.“ |
| task chips | „Lass 8 Wiesen wachsen“ · „Lass 5 Wälder wachsen“ · „Erschaffe 4 Tiere“ · „Versorge 3 Hütten“ · „Mach 3 Dörfer satt“ · „Mach 3 Städte satt“ |
| reveal cards (caps · line) | 3 „Neu: Blitz“ · „Regen löscht Feuer“ · 4 „Neu: Menschen“ · „Menschen brauchen Nahrung“ · 5 „Neu: Arbeit“ · „Dorf braucht Nahrung und Arbeit“ · 6 „Neu: Glaube“ · „Kirche an Kirche: Krieg!“ · 7 „Neu: Fabriken“ · „Zu viel Stadt: Flut!“ |
| coach (first time each) | „Tiere neben die Hütte“ · „Wald oder Stein gibt Arbeit“ · „Stadt braucht eine Kirche“ · „Satt? Dann wächst es.“ · „Regen neben Hütten: Acker“ · „Meteor bereit“ · „Fabrik weg vom Wald“ |
| field pills | „Hütte satt!“ / „Dorf satt!“ (only the goal kind, once per day) · „Hunger“ · „Keine Arbeit“ · „Zweifel“ (faith missing) · „Wächst bald“ |
| events | see section 7 |
| overnight | „Neuer Morgen“ + lines of 5.6 |
| after the win | „Geschafft!“ · „Weiterbauen“ · chip „Extra: 4 Hütten satt“ / „Extra: 9 Wiesen“ (etc.) · „Bau weiter“ |
| free play help (optional) | „Nachwachsen schließt keine Reihe.“ |

---

## 10. Implementation map

| file | change |
|---|---|
| `scripts/field_data.gd` | Stein (16), `KIND_COUNT` 17, names/icons; flags `people`, `source_of` |
| `scripts/game_state.gd` | `once` (Spec v1 diff), day path: `rows`/`next8`, consume, Gedeihen (`fed`, `hungry`, `maxlvl`), Blitz/Feuer, Krieg (front), Meteor, Smog (Industrie), Flut, rain targets, round order 4.5, goal `satt`, `preview()`; clone/save/undo carry the new arrays. Port `rules8.gd` 1:1 – it already runs on GameState's geometry |
| `scripts/days.gd` | table 5.2 (`DAY8` as config dictionaries), overnight lists, texts 9; drop wishes/Waage/Gewitter on days |
| `data/days_schoepfung.json`, `docs/gdpd_7_tage_boards.json` | new pools (5.5) |
| `scripts/field_view.gd`, `models.gd` | Stein mesh (low grey rock), need icon row, satt ring, fed dot, hunger tint, burning, flood water, crater |
| `scripts/world.gd` | Blitz cloud + strike, fire spread, war swords/front tint, meteor, smog haze, sea level per face, overnight wave, source light lines |
| `scripts/day_ui.gd` / `ui.gd` | task chip with connect icons (6.1), extras, pills of section 7, reveal cards, coach lines |
| `scripts/game.gd` | Weiterbauen extras, ✦ for new growth, overnight trigger, Meteor tool button (days 6–7) |
| `tests/test_rules.gd`, `scripts/main.gd`, `.github/workflows/gdpd.yml` | sections 11 and 12 |

---

## 11. Test plan (`tests/test_rules.gd`, must end with „0 Fehler“)

1. **once_basic / once_new_trio / once_cascade / once_face** (as Spec v1): a spent row never grows again; another
   trio does; cascades respect `spent`; a grown face spends all its lines.
2. **xcheck8**: the 560 random + 140 pool cases of `cases8*.json` (copy to `tests/data/`) replay with 0 mismatches
   (kinds, positions, fed, hungry, burning, fresh, bolt, war, front, flood warn, faith, rain, twists, won, made,
   progress, satt).
3. **pool_replay**: 140 solutions win exactly at `solved_in` with their stars.
4. **consume**: a Tiere row → target Hütte, the other two Wiese, `made[HUT]` +1.
5. **needs**: Hütte next to Acker is satt; Dorf next to Acker only is not, + Stein is; Stadt needs a Kirche; a
   burning Hütte or a front field is never satt.
6. **thrive_timing**: satt 2 twists → grows (day 5 Hütte → Dorf), `top` stops it (day 4); hungry 4 twists → Dorf →
   Hütte; Hütte never shrinks; shrink + regrow counts `made` once.
7. **bolt**: day 3: warning after twist 1, strike after twist 2 on the same field, rain on it cancels; fire does not
   spread into a nass field; burnt fields are fresh for 2 steps.
8. **war**: two churches touch → `war_start`, no damage; next twist front falls one level and spreads; separating
   them → `war_end`; Meteor on a church (12 Glaube) ends it.
9. **flood / smog**: weight 5 → warning, next twist low wet fields of that face become Wasser; Industrie withers the
   best nature neighbour every twist.
10. **farm_pools**: on every pool board `pp`, `cyc`, `slice` never win (model port or recorded results).
11. **kinds_per_day**: every pool board has ≤ 3 growable kinds and ≤ `Days.VISIBLE_MAX` visible kinds (Rev. 9); days 3+ have no Erde, days 5+ no Wiese row.
12. **preview**: on day 5 board 0 some move lists a field in `satt_new`; on boards 0–2 of days 4–7 the preview's
    `satt_new` / `satt_lost` equal the real events of every move (Rev. 9).
13. Free play: **regrow_safe** and **free_farm** (Mittel median slice back and forth grows on ≤ 40 % of twists).

---

## 12. Tour checks (`main.gd`; add the names to the check list in `.github/workflows/gdpd.yml`)

| name | what it checks (real input, new pools) |
|---|---|
| `no_farming` | day 2, board 0: real swipes on slice x = 1, alternating direction, 6 times → **exactly 1** growth (twist 1), no growth in twists 2–6. Shot `no_farming.jpg`. Over all pools the best ping-pong of any slice gives ≤ 4 growths in 6 twists, all in the first 2 twists except day 3 (Blitz) ≤ 2 and days 4/7 ≤ 1 |
| `spent_feedback` | a `spent` row shows „Schon gewachsen“, input never blocked |
| `overnight_growth` | start day 3 from the overview: within 0.5 s Wiesen drawn as Erde, pill „Über Nacht gewachsen“ / „Erde wird Wiese“, after ≤ 2.5 s every field shows its pool kind; a swipe during the wave counts. Shots `overnight_a.jpg`, `overnight_b.jpg`; „Nochmal“ shows no wave |
| `task_chip` | days 1–7: the chip is visible after start, after 3 twists and after the win; days 4–7 show the connect icons |
| `bolt_warn` | day 3 board 0: after the twist [0, 1, 1] the warning cloud is on a Wald/Tiere field (the camera turns to it); after the next twist it burns (or rain on it cancels it: „Regen schützt“) |
| `consume_hut` | day 4 board 0, solution twist 1: field 8 becomes Hütte, 23 and 24 become Wiese, the Hütte is satt (gold ring) |
| `thrive_preview` | day 5 board 0: while dragging the first move that makes a field satt (and can be swiped in view), that field shows the „satt“ preview; after release it is satt |
| `war_preview` | day 6 board 0: dragging a move with `war_risk` shows crossed swords before release; after it „Krieg droht!“ |
| `flood_warn` | day 7 board 0: the first move that crowds a face (weight ≥ 5) brings „Das Meer steigt!“; the camera shows that face (blue rim, rising water) |
| `extra_task` | win day 4 board 0 by its solution: chip changes to „Extra: Versorge 4 Hütten“, Weiterbauen has no limit |
| `kinds_per_day` | the started board has ≤ 3 growable kinds and at most `Days.VISIBLE_MAX` visible kinds besides Wasser; prints the lists |
| `help_once` | help shows „Jede Reihe wächst nur einmal.“ |

---

## 13. Open items

- Einfach free play: `rot4` (one slice, same direction) still beats the eval bot through group contacts. Candidate
  (not yet measured): a group that grew together cannot group-grow again in the next twist („Gerade gewachsen ·
  Kurz Pause“, only Einfach).
- Day 3 sits ½ point above the 85–95 % band (96.7 %); real play data decides between limit 8 and 7.
- The weak bot wins almost nothing from day 3 (real players are better than random). Watch day 4–7 retries; the
  existing „Gnade“ (+ twists on „Nochmal“) is the first lever, then `shrink_after` 5.
- Free play Gedeihen (needs, Wasser for Großstadt) needs its own balance pass.

---

## 14. Files (scratch) and how to re-run

Scratchpad: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/`

- **Model (new concept):** `gdpd_sim/b3/` – `engine8.py` (rules; `GS8` extends the cross-checked `engine7.GS`),
  `days8.py` (`DAY8`, `OVERNIGHT8`, board generator), `bot8.py` (good/greedy/weak), `farm8.py` (pp, cyc, slice),
  `run8.py` (`python3 run8.py gen:300 1,2,3,4,5,6,7 good,greedy,weak '{}' out.json`; `pool:<file>`; overrides like
  `'{"3":{"limit":7}}'`), `export8.py` (pools), `cont8.py` (Weiterbauen farming), `extra8.py` (extras),
  `xcheck8.py` (cross-check), `diag.py`. Results: `res300*.json/log`, `farm100*.json/log`, `poolres.*`.
- **Pools:** `gdpd_sim/b3/gdpd_concept8_boards.json`.
- **GDScript reference port + cross-check:** `b3/x8/rules8.gd` (`class_name Rules8`, uses `GameState` geometry),
  `b3/x8/xcheck8.gd`; cases/outputs `b3/x8/cases8.json` + `out8.json` (560 random cases incl. farming patterns,
  10 357 steps: 73 wars, 62 floods, 350 meteors, 1267 burns, 2462 thrive, 2955 starve, 216 consumes) and
  `cases8_pool.json` + `out8_pool.json` (140 pool solutions, 1002 steps). Run: `python3 xcheck8.py gen|pool …`,
  `godot --headless --path b3/x8 --script res://xcheck8.gd`, `python3 xcheck8.py cmp …` → 0 mismatches.
- **Exploit (real GDScript):** `b3/gd0/farm.gd` on a copy of the current repo, log `b3/farm_before_rerun.log`;
  Spec v1 scripts and patched copies in `b2/` (`farm*.gd`, `strike_farm.gd`, `farm_free.gd`, `replay_b2.gd`,
  `balance2_game_state.diff` for `once` + `regrow_safe`, logs `farm_free_variants.log`).
- Spec v1 model (old day table with `once`): `gdpd_sim/b2/`.

---

## 15. Implementation status (rules shipped in `gdpd/`)

The rules of sections 2–7 run in the real game. `GameState` switches to them when the day config has `rows`
(`v8 = true`; every day of `Days.DAYS` has it, old packs without `rows` keep the old day rules). The 140 new pool boards
are in `data/days_schoepfung.json` and `docs/gdpd_7_tage_boards.json`.

- **Port check:** `GameState` itself (not the scratch `rules8.gd`) replays all 560 random cases and all 140 pool
  solutions of the Python model, with 0 mismatches over 11 359 steps. 187 of the random cases are kept with an md5
  per case in `tests/data/xcheck8_cases.json` and checked by `test_xcheck8`.
- **`once`:** applies in all modes, for straight and diagonal rows, Einfach groups, whole faces and cascades.
  Free play also has „Nachwachsen schließt keine Reihe“.
- **Stein:** `FieldData.STONE = 16`, `KIND_COUNT = 17`, board code `R`.
  - Art: `FieldView` has 17 kinds; Stein has its own ground, icon `stone` and model (GDPD_GRAFIK.md 14).

### API (GameState, new days)

| call | returns |
|---|---|
| `satt(f)`, `satt_ids()`, `need_state(f)` | `{"met": [...], "missing": [...]}` (need names: `food`, `work`, `faith`) |
| `field_state8(f)` | `{people, satt, met, missing, fed, hungry, grow_after, shrink_after, burning, fresh, front, bolt, wet}`, for field views |
| `preview8(axis, layer, turns)` | the contract of 4.6; also in `Game.preview(...)["supply"]` |
| `city_weight8(face)`, `church_touch8()`, `goal_needs()`, `goal_need_icons()`, `extra_max()`, `extra_target()`, `value8()` | (helpers) |
| state | `bolt`, `war_on`, `front`, `flood_warn`, `faith`, `rain`, `extra_level`; per field `fed`, `hungry`, `maxlvl` (`FieldData`, copied by `copy()`) |
| `day_status()` adds | `v8`, `needs`, `need_icons`, `extra_level`, `extra_max`, `extra_target`, `extra_text`, `bolt`, `war_on`, `front`, `flood_warn`, `faith`, `rain` |

- **Tools:** Regen as in 4.2. The Meteor uses the Gewitter slot: `play({"type": "strike"|"meteor", "field"})`
  costs `GameState.METEOR_COST` (12). The hint returns `"strike"` for it.
- **Hint:** `best_day_action` is the bot `good` (tools first, then 1-ply over 27 twists and 2-ply on the best 6).
  On the pools it wins 20/20/20/20/17/20/17.

### Events

Old type names are kept where `world.gd` already animates them:

| spec name (section 7) | event type in the game | note |
|---|---|---|
| `grow` | `merge` | `others`, plus `consume: bool` and `eaten: [ids]` (the 2 Tiere that became Wiese) |
| `burnt` | `burn` | `field`, `from`, `kind` |
| `smog` | one `polluted` per field (`field`, `by`/`industry`, `from`, `kind`), then one `smog` (`w`, `fields`) | |
| everything else | the spec name | `consume`, `satt_new`, `satt_lost` (with `missing`), `thrive` (with `first`), `starve`, `bolt_warn`, `bolt`, `bolt_miss`, `bolt_cancel`, `ignite`, `rain_out`, `rain`, `war_start` (`churches`, `front`), `war_hit`, `war_end`, `meteor`, `flood_warn` (`face`, `new`, `weight`), `flood` (`face`, `field`, `from`), `income` (Glaube next to churches), `extra` (`level`, `target`, `max`, `done`, `text`) |

- **`miss`** (always `counted: false`) only comes when the twist grew nothing and none of the events above happened.
- **Silent rows:** the `still` event has new reasons `people` („Keine Reihe · Menschen wachsen durch Nachbarn“),
  `done` („Heute keine Reihe“ · the task) and `stone`. `rest` now means „forms rows on a later day“, with `next`
  from the day ladder.

### Game and UI signals

- **`Game.overnight_growth(info)`:** fired when a day ≥ 2 is started, but not by „Nochmal“, the Welt des Tages or
  Weiterbauen.
  - `info = {"type": "overnight", "day", "changes": [{"field", "from", "kind"}], "caps", "line"}`; also in
    `day_info()["overnight"]`.
  - The day UI shows the pill after „Los!“. The art track's wave goes on this signal.
- **`Game.extra_done(info)`:** fired after an `extra` event.
- **Day chip:** it gets the need icons (`chip_needs`). In Weiterbauen it shows „Extra: …“, then „Bau weiter“.
  `day_ui._pill8` shows one short pill per round, taken from the table in section 7.
- **Tour checks (section 12):** `no_farming`, `spent_feedback`, `help_once`, `overnight_growth`, `bolt_warn`,
  `consume_hut`, `extra_task`, `thrive_preview`, `war_preview`, `meteor`, `flood_warn`, `kinds_per_day`, `task_chip`.
  - They replace `day4_wish`, `day5_choice`, `day6_faith`, `day6_war`, `day7_green` and `day7_smog`.

### Presentation (rules and art tracks joined)

- **Supply preview while dragging:** `World._show_preview` reads `preview(...)["supply"]`. People fields that become
  satt get a green rim and an up arrow, those that lose supply a red rim and a down arrow (`FieldView.set_supply`).
  `fire_risk` and flood-risk fields glow red, touching churches show swords. Everything clears on release.
- **Overnight growth:** `World` holds yesterday's kind on the changed fields under the goal card; after „Los!“ the
  day UI shows the pill „Über Nacht gewachsen“ and calls `World.overnight_wave()`: the fields grow in a wave from
  top to bottom of the screen (staggered growth, soft light, a few motes). A twist or a round ends the wave at once.
- **Rule events in the world:** `bolt` (lightning from the sky), `ignite` (embers jump over), `rain_out` /
  `bolt_cancel` (wet ground, steam), `war_start` (camera to the churches, war mood, swords; the front glows),
  `war_end` (mood back, light on the churches), `satt_lost`, plus the existing `thrive`, `satt_new`, `starve`,
  `war_hit`, `flood`, `merge` (with `consume`), `burn`, `polluted` / `smog`.
- **Silent rows:** badges for the new reasons `people` (person), `done` (goal) and `stone` (stone).
- **Meteor:** on days 6–7 the Gewitter slot shows the meteor icon as well as the label.
- **Tour:** new checks `supply_preview` (held drag on day 5: the target field gets the green mark, all marks gone after
  release) and `look_life` (close-ups on day 7: water, forest, village, animals, people; animals and people are
  alive). `overnight_growth` now also checks the wave, `no_farming` that the reason pill was shown.

---

## 16. Review round Rev. 9 (7. November 2026)

What changed after the review of the integrated build (rules, pools, readability; graphics in GDPD_GRAFIK.md 15):

| finding | change | check |
|---|---|---|
| Meteor farmable (+1 per person next to a church on every twist; back and forth → meteor after ~6 twists) | Glaube only for a **new level next to a church**, +3 (`GameState.FAITH_STEP`, `FieldData.flvl`; same in `engine8.py`) | `test_day_toggles`: back and forth brings 0; no day-6 board affords a meteor in 6 back-and-forth twists |
| Too many different fields at once (2/3/3/4/7/9/10 kinds incl. Wasser) | compositions of days 5–7 (5.1), pools rebuilt; at most 1/2/2/3/5/6/6 kinds besides Wasser | `test_day_boards` (`Days.VISIBLE_MAX`), tour `kinds_per_day` |
| Difficulty spike on day 3, dip on day 6 | day 3: 10 twists; day 6: 12 twists, ★★ ≤ 6; day 7: ★★ ≤ 6 | `test_day_table`; hint/greedy/weak per day (5.5) |
| Preview missed merges, consume, war, thriving | `preview8(…, post)` from the resolved clone | `test_preview8`: preview = events on 324 moves |
| „Über Nacht gewachsen“ on every field of an unrelated board | „Neuer Morgen“, at most 4 fields | `test_overnight`, tour `overnight_growth` |
| Extra chip cut off („EXTRA: LASS 11 WIESEN WACHS“) | short noun form „Extra: 11 Wiesen“ / „Extra: 4 Hütten satt“ | `test_extras`, tour `extra_task` |
| „Satt!“ pill while the chip stayed 0/3 | pill only for the goal kind: „Dorf satt!“ | – |
| Hint froze the phone (190–370 ms desktop) | search on a clone in `WorkerThreadPool`, the Tipp button pulses; a stale result is dropped | – |

Re-run: `cd gdpd_sim/b3 && python3 export8b.py 3,5,6,7 pools9.json` (needs `engine8.py` with `FAITH_STEP`,
`days8.py` of Rev. 9), then `python3 mk_test_cases.py gdpd/tests/data/xcheck8_cases.json` (187 cases, 3380 steps).
