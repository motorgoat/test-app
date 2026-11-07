# gdpd – Die Schöpfung: Kampagne und Regeln (Spec v1)

This spec is for implementers, so it is written in English. Every text a player sees is in simple German (du-form),
as short as possible (2–6 words), and is written here exactly as it should appear.

It replaces the 7-day table of `GDPD_BALANCE_2.md` (section 5) and the day unlock of `GDPD_TAEGLICH_CHARAKTER.md`
1.2 with the campaign **„Die Schöpfung“** decided by Philipp (`NAECHSTE_SCHRITTE.md`, 7 November 2026): 7 Genesis days
as acts, 30 levels along the earth history, one new level per real day (about a month), then the daily
„Welt des Tages“ and later new worlds. Everything that is not changed here stays as built: `once`, the preview while
twisting, need icons, the own character and coach, streak, reminders, the seamless look, the cancel strip.

**Validated with:** the Python rules model `gdpd_sim/b4/engine9.py` (a generic extension of the cross-checked
`engine7`/`engine8` geometry and rows), bots `good` (= the hint), `greedy`, `weak` and an oracle `farmer`
(best of ping-pong, 5 cycle patterns and single-slice play), **300 generated boards per level and bot**, 100
carry-over chains per act, Weiterbauen farming runs and a group-cap experiment. Pools of 20 boards per level with
one solution each are exported (section 9.7). Files and re-run: section 18.

**Never spoil:** a level's title, icon, story and reveal card appear only once the level is open. Locked levels
show a lock or „?“ and „Morgen wartet etwas Neues“. Act names are shown only for acts already reached.

---

## 0. Decisions (summary)

| # | decision | why (one line) |
|---|---|---|
| 1 | **30 levels in 7 acts** (4 · 4 · 4 · 3 · 4 · 9 · 2) along the earth history: glowing earth → atmosphere → first life → plants → sun and seasons → life in water and air → animals and people → rest. | Philipp's frame; act 6 is the longest as decided. |
| 2 | **Three verbs everywhere:** Erschaffen (rows, `once`), Verbinden/Gedeihen (generic needs: one table for lava, water life, plants, animals, people), Zusammenwachsen (groups give strength min(size, 3); double supply grows twice as fast). | One rule set from lava to cities; the task chip always says what to connect. |
| 3 | **No step limit, no failing; steps are counted.** Stars by steps, points = 20 × stars + 5 per step under par. **Gnade:** from the 1-star zone, every 3 steps without progress +1 Regen/Wunder. | „Man kommt immer weiter“; fewer steps = more points; no dead ends. |
| 4 | **Dangers only as consequences**, all warned one round ahead: Vulkan (lava clump ≥ 5), Blitz (dry forest group ≥ 3 without water), Hunger (missing food, H = 4, morning reserve 3), Rudel (predator group ≥ 3), Krieg, Smog (warned now), Flut. The timed bolt of v8 is gone. | Philipp: „Blitz nur bei trockenem Wald ohne Wasser daneben“. |
| 5 | **Progress drops on losses:** `make` = made − lost; a danger on a made goal field is −1 with a „−1 Tier“ cue; growing up or a consume is no loss. | Backlog „Ziel-Fortschritt zählt Verluste ab“. |
| 6 | **Water is dead at first**; life appears only by play: rain → Ursuppe, warmth → Einzeller, rows → Algen → Fische; the sky turns blue with the algae. | Backlog „Wasser ist am Anfang tot“. |
| 7 | **The world carries over within an act** (yesterday's end world, overnight growth, fitted to the level's start composition, repaired to the start rules, else the pool board); each act starts on a fresh pool board. | „Die echte Welt von gestern weiterführen“, while every start stays validated. |
| 8 | **People grow only where the next level is fed** („Wächst bald“ until then); animals in the people levels 24–28 are herded (no animal hunger), animal hunger is the theme of levels 20–23 and 29–30. | Without it towns grew and starved in a loop (sim: 5–15 starvations per game). |
| 9 | **Points are the only currency** (1 old coin = 20 points), spent in a fair shop (shield 100, miracles 25/50 max one per level, cosmetics, later worlds); hint free in levels 1–5 and after a stall. | Backlog „Punkte sind die Währung“. |
| 10 | **Veterans:** everybody starts at level 1, players with old progress get a fast track (3 new levels per Spieltag up to their equivalent level), old stars become points, the Welt des Tages stays open for those who finished the old 7 days. | Nobody loses a daily habit; the story still starts at the beginning. |
| 11 | **After level 30:** Welt des Tages from 14 templates (one strong level per act, 266 worlds), replays, later packs Insel/Wüste/Winter. | The streak keeps its meaning. |
| 12 | Backlog UI items: HUD centred and +15 %, tap the god to open it, cancel strip stays, **100-Sekunden-Challenge** replaces „40 Drehungen“ in free play. | `NAECHSTE_SCHRITTE.md`. |

---

## 1. The three verbs and the four principles

| verb (player word) | rule | where it starts |
|---|---|---|
| **Erschaffen** („Bring 3 gleiche in eine Reihe.“) | 3 equal fields in a **new** straight row on one face: the target field grows to the next kind of the level's row table. `once` (every row grows only once), `standing`, `broken`, cascades and the whole-face bonus as in v8. A *consume* row changes the 2 other fields too (3 Tiere → 1 Hütte + 2 Wiesen). | level 1 |
| **Verbinden / Gedeihen** (task chip shows what to connect, e.g. „Gib den Tieren Futter“) | a kind with **needs** grows (or makes something next to it) when its neighbours meet the needs for **G = 2** round ends in a row; living kinds starve when the needs stay unmet for **H = 4** round ends (warned at H − 1). Neighbours = the 4 stickers around a field, **across cube edges too**. | level 2 (lava cools at the water) |
| **Zusammenwachsen** (seen, not explained in words: merge look + `×2` badge) | equal kinds that touch form one **group** (forest, field, lake, herd, town). A source group gives **strength = min(size, CAP = 3)** to every field it touches; the supply of a need is the **sum of the strengths of the distinct source groups** touching the field. | level 6 (2 Lava together = enough heat); taught as a task in level 15 |

Four principles that hold in every level:
1. **Dangers are consequences of play, never a timer.** Each danger has an exact trigger in the world state and is
   **warned one round ahead** (section 3.6). Good play avoids all of them (validated, section 13).
2. **No step limit, no failing.** Steps (= twists) are counted, never limited; fewer steps = more stars and points.
   A level cannot be lost; a danger costs fields and therefore steps. **No dead ends:** every kind a task counts can be
   (re)made in that level, and from the 1-star zone on the game gives help (Gnade, 3.5).
3. **Progress drops on losses.** A goal field that was made in this level and falls by a danger counts −1
   (`goal_loss` with a short „−1 Tier“ cue). Growing up (Fels → Erde, Dorf → Stadt) or being consumed by a row is no loss.
4. **Few kinds at once.** At most 3 growable kinds and at most 6 visible kinds besides water on every start board;
   the world evolves between levels (carry-over within an act, section 5).

---

## 2. Kinds

27 kinds. Ids 0–16 exist (`FieldData`), 17–26 are new. Board code: one letter per id
(`CODE = "EwWAgTHhDSKGIMPoR" + "LUzafmnvrs"`). „Water family“ (`WATERS`) = Wasser, Ursuppe, Einzeller, Algen, Fische:
all of them count as water for wetness, the water-body look, flood and fire (never burn). Tier = order on the life
ladder (for icons and sorting; no rule uses it).

| id | key | name (German) | icon | tier | family | arises by | gives (source of) | falls to (danger) |
|---|---|---|---|---|---|---|---|---|
| 17 | `lava` | Lava | `lava` | 0 | geology | start board; eruption | 🔥 Wärme (`heat`, `spark`) | – (rain cools it: Fels) |
| 16 | `stone` | Fels (was „Stein“) | `stone` | 1 | geology | row of 3 Lava; Lava with 2 water neighbours (Gedeihen); rain on Lava | ⛰ Mineral (`mineral`), 🔨 Arbeit (`work`) | Lava (eruption) |
| 0 | `empty` | Erde | `empty` | 2 | land | row of 3 Fels; rain on Fels | – | – |
| 15 | `water` | Wasser (Urozean, dead) | `water` | 0 | water | background | 💧 (`wet`) | – |
| 18 | `soup` | Ursuppe | `soup` | 1 | water | rain on shore water; Wasser with 🔥🔥 + ⛰ (Gedeihen) | 💧 | – |
| 19 | `cells` | Einzeller | `cells` | 2 | water | Ursuppe with 🔥🔥 (Gedeihen, level 7) or with Lava/Einzeller (level 8+) | 💧, ✨ Leben (`spark`) | – |
| 20 | `algae` | Algen | `algae` | 3 | water | row of 3 Einzeller; a fish that went ashore | 💧, 🌿 Algen (`algae`) | – |
| 21 | `fish` | Fische | `fish` | 4 | water | row of 3 Algen | 💧, 🐟 Fisch (`fish`) | – |
| 22 | `moss` | Moos | `moss` | 3 | plant | Erde with 🌿🌿 (Gedeihen); row of 3 Erde; rain on Erde | – | Erde (smog) |
| 23 | `fern` | Farn | `fern` | 4 | plant | row of 3 Moos; Moos with 💧💧 (Gedeihen, level 12); rain on Moos | – | Erde (fire) |
| 1 | `meadow` | Wiese | `meadow` | 3 | plant | row of 3 Erde; rain on Erde; what burnt / eaten land becomes | 🌾 Futter (`plants`), 🦶 Ufer (`shore`) | Erde (smog) |
| 2 | `forest` | Wald | `smallforest` | 5 | plant | row of 3 Farne (act 3) or 3 Wiesen (act 4+); Wiese with ☀ + 💧 (level 13); rain on Wiese | 🌾 Futter, 🔨 Arbeit | Erde (act 3) / Wiese (fire) |
| 26 | `seed` | Saat | `seed` | 4 | food | row of 3 Wiesen (act 4); rain on Wiese (act 4) or on Wiese next to people (act 6+) | – | Wiese (fire, smog) |
| 3 | `field` | Acker (reif) | `field` | 5 | food | Saat with ☀ + 💧 (Gedeihen); rain on Saat | 🍞 Nahrung (`food`) | Wiese (fire, smog) |
| 24 | `birds` | Vögel | `birds` | 6 | animal | Wald with 🐟🐟 (Gedeihen); row of 3 Wälder (level 18) | – | Wiese (fire), Wald (smog) |
| 5 | `animals` | Tiere (Pflanzenfresser) | `animals` | 6 | animal | fish next to a meadow for 2 rounds (Landgang, level 19); row of 3 Wälder (act 6) | 🍖 Beute (`prey`), 🍞 Nahrung | Erde (hunger), Wiese (fire, pack), Wald (smog) |
| 25 | `pred` | Raubtiere | `pred` | 7 | animal | row of 3 Tiere (level 21–22) | – | Wiese (hunger), Wald (smog) |
| 6 | `hut` | Hütte | `hut` | 8 | people | row of 3 Tiere (consume: the other 2 become Wiese) | – | Wiese (fire, war, flood) |
| 8 | `village` | Dorf | `village` | 9 | people | Hütte with 🍞 for 2 rounds (only if the Dorf would be satt) | – | Hütte (hunger, fire, war) |
| 9 | `town` | Stadt | `town` | 10 | people | Dorf with 🍞🔨 for 2 rounds (only if the Stadt would be satt) | – | Dorf (hunger, war) |
| 10 | `church` | Kirche | `church` | 10 | finished | start board | 🙏 Glaube (`faith`) | – (meteor: Erde) |
| 12 | `industry` | Industrie | `industry` | 10 | finished | start board | 🔨 Arbeit; Smog | – (meteor: Erde) |

Not used in the campaign (free play only): Großer Wald 4, Haus 7, Großstadt 11, Metropole 13, Paradies 14.
`FieldData.KIND_COUNT` becomes 27; `KIND_KEY`, `KIND_NAME`, `KIND_SHORT`, `KIND_ARTICLE`, `KIND_PLURAL`, `KIND_ICON`,
`DOWN`, `TIER` get the 10 new entries (plural: Lava, Ursuppen, Einzeller, Algen, Fische, Moose, Farne, Vögel,
Raubtiere, Saaten). New icons (SVG, `icons/`): `lava`, `soup`, `cells`, `algae`, `fish`, `moss`, `fern`, `birds`,
`pred`, `seed`, plus need icons `heat` (flame), `mineral` (rock), `spark` (sparkle), `sun`, `prey` (paw), `plants`
(grass blade), `fishneed` (fish outline), `shore` (foot), `wet` (drop, exists as `rain`).

---

## 3. Rules

### 3.1 Erschaffen (rows)

Exactly v8 (`GDPD_BALANCE_2.md` 4.2): straight rows only, `once` for every row (straight, face, cascade, rain),
`standing`/`broken`, max 6 cascades, kinds outside the level's `rows` set are silent (`still` reasons as v8 plus
`water_life` „Wasser wächst durch Leben“). The row table (`next`) and the consume table are per level (section 4).

### 3.2 Gedeihen (generic thriving)

`thrive[k] = {needs: {need: amount}, up: kind | null, spawn: [on_kinds, into, after] | null, down: kind | null,
G: int (default 2)}`. At step 9 of the round (3.8), on one snapshot of the board:

- **satt** = every need has `supply(f, need) ≥ amount`, the field is not burning and not in a war front.
- satt → `hungry = 0`, `fed += 1`; when `fed ≥ G`:
  - `up`: the field becomes `up` (event `thrive`). **People** (Hütte, Dorf) only grow when the next level would be
    satt on that spot (`up_ok`); otherwise `fed` stays at G and the field shows „Wächst bald“ with the missing icon of
    the next level.
  - `spawn` (Landgang): the lowest-id neighbour of a kind in `on_kinds` becomes `into` (event `spawn`), the field
    itself becomes `after` (a fish that went ashore leaves algae behind).
- not satt → `fed = 0`; only if `down` is set: `hungry += 1`; at `hungry == H − 1` event `hunger_warn`; at
  `hungry ≥ H` the field falls to `down` (event `starve`, a loss if it was a made goal field).
- **Vorrat (morning reserve):** fields with a `down` that are on the start board begin with `hungry = −GRACE` (3), so
  nothing starves in the first 4 + 3 rounds; fields made during play start at 0.
- `fed` / `hungry` belong to the field and move with it; they reset when the field changes kind.
- Special needs: `sun` = 1 if the field is on the **sun face** (face 0, +y, the top face in the start view), else 0;
  `wet` = the **number** of water-family neighbours (so „💧💧“ means 2 water neighbours).

### 3.3 Zusammenwachsen (groups and strength)

- Group = connected same-kind fields (4-neighbourhood across edges). Recomputed once per kind/position change.
- `supply(f, need)` for normal needs = Σ over the **distinct** source groups touching f of `min(group size, CAP)`,
  CAP = 3. So: two Algen next to a field, or one Algen pair touching it, both give 🌿 2; a 5-field forest touching a
  town gives 🔨 3, not 5.
- Visible: groups merge visually (section 10); a need icon shows `have/need` when the amount is > 1 (`🍞 1/2`).
- CAP was chosen by simulation (9.5): without the bonus (CAP 1) the group levels need 25–60 % more steps; CAP ≥ 4
  changes nothing measurable but would let one huge group feed everything.

### 3.4 Needs and sources (all levels)

| need | icon | sources |
|---|---|---|
| `wet` | 💧 | water family (counted per neighbour) |
| `sun` | ☀ | the field is on the sun face |
| `heat` | 🔥 | Lava |
| `mineral` | ⛰ | Fels |
| `spark` | ✨ | Lava, Einzeller |
| `algae` | 🌿 | Algen |
| `fish` | 🐟 | Fische |
| `shore` | 🦶 | Wiese |
| `plants` | 🌾 | Wiese, Wald |
| `prey` | 🍖 | Tiere |
| `food` | 🍞 | Tiere, Acker |
| `work` | 🔨 | Wald, Fels, Industrie |
| `faith` | 🙏 | Kirche |

| thriver | needs | result | levels |
|---|---|---|---|
| Lava | 💧 2 | Fels (+1 Regen in act 2: steam) | 2–5 |
| Wasser | 🔥 2, ⛰ 1 | Ursuppe | 6 |
| Ursuppe | 🔥 2 (level 7) · ✨ 1 (level 8–9) | Einzeller | 7–9 |
| Erde | 🌿 2 | Moos | 10–11 |
| Moos | 💧 2 | Farn | 12 |
| Wiese | ☀ 1, 💧 1 | Wald | 13 |
| Saat | ☀ 1, 💧 1 | Acker | 14–15, 25–30 |
| Wald | 🐟 2 | Vögel | 18 |
| Fische | 🦶 1 | spawn: the meadow becomes Tiere, the fish field Algen | 19 |
| Tiere | 🌾 1 | – (starve → Erde) | 20–30 |
| Raubtiere | 🍖 1 | – (starve → Wiese) | 21–23 |
| Hütte | 🍞 1 | Dorf (level 26+) | 24–30 |
| Dorf | 🍞 1, 🔨 1 | Stadt (level 27+); starve → Hütte | 26–30 |
| Stadt | STADT_NEEDS | starve → Dorf | 27–30 |

### 3.5 Tools: Regen / Wunder, Meteor, Gnade

- **Regen** (tool slot, no step): one charge turns the tapped field by the level's rain table (first matching rule):

| act | rain table (field → result) |
|---|---|
| 1 | „Wunder“ (no sky yet, same slot, sparkle icon): Lava → Fels; level 4 also Fels → Erde |
| 2 | Lava → Fels (level 5), Wasser at the shore (a non-water neighbour) → Ursuppe (6–8), Fels → Erde |
| 3 | Moos → Farn, Erde → Moos; level 9: shore water → Ursuppe |
| 4 | level 13: Wiese → Wald, Erde → Wiese; levels 14–15: Saat → Acker, Wiese → Saat |
| 5 | Wiese → Wald |
| 6–7 | levels 20–23: Erde → Wiese; 24: Erde → Wiese, Wiese → Wald; 25–30: Saat → Acker, Wiese next to people → Saat, other Wiese → Wald |

  Rain on a burning field puts out every fire on that face; on the warned bolt field it cancels the strike; a field
  made by rain may complete a row (counts as usual). Charges: `rain_start`, +1 every `rain_every` steps, max 3; in
  act 2 (level 5) the sky fills by **steam**: every Lava that cools at the water adds +1 („+1 Regen“).
- **Meteor** (level 23: 1 free charge; levels 27–30: +1 charge per 12 Glaube; shop: section 6): the tapped
  non-water field becomes Erde (crater). It is a loss when it hits a made goal field. Typical use: split a pack, end a
  war (a church), remove an Industrie.
- **Glaube** (levels 27–30): +3 once per level a people field reaches next to a Kirche (v8 rule, farm-proof).
- **Gnade (no dead ends):** from the 1-star zone on (steps > ★★ threshold), every 3 steps without new goal progress
  give +1 Regen/Wunder charge (max 3), pill „Hilfe von oben“. It never helps before, so it cannot change stars.

### 3.6 Dangers (consequences, each warned one round ahead)

| danger | levels | trigger (end of a round) | warning | effect one round later if the trigger still holds | how good play avoids it |
|---|---|---|---|---|---|
| **Vulkan** | 3–8 | a Lava group of ≥ **5** (no crater resting) | `volcano_warn` on the crater (the member with most lava neighbours, ties: lowest id): smoke | `erupt`: up to **3** non-water, non-lava neighbours of the group (crater first, then by id) become Lava; the group rests 2 rounds | split the clump, cool lava at the water, rain on lava |
| **Blitz** | 12–19, 29–30 | a **dry forest**: a Wald group of ≥ **3** where no member touches water | `bolt_warn` on the member of the biggest dry group with most flammable neighbours (ties: LCG, v8) | the field burns if it is still in a dry group; fire spreads each round to flammable, non-wet, non-fresh neighbours, then burns down (Wald → Erde in act 3, → Wiese later; Farn → Erde; Tiere, Hütte, Saat, Acker → Wiese; Dorf → Hütte) | keep forests near water or small; move water next to it; rain |
| **Hunger** | 20–30 | a thriver with `down` is not satt | `hunger_warn` at `hungry = H − 1` (3), pulsing icon | `starve` at H (4): Tiere → Erde, Raubtiere → Wiese, Dorf → Hütte, Stadt → Dorf (Hütte never) | bring food; people grow only where the next level is fed |
| **Rudel** | 23 | a Raubtier group of ≥ **3** touches Tiere | `pack_warn` on the threatened Tiere | every warned Tiere still next to the pack becomes Wiese | keep predators apart; meteor |
| **Krieg** | 27–30 | a Kirche touches a Kirche | `war_start` (no damage) | as v8: the front falls one level per round and spreads | separate the churches; meteor on one |
| **Smog** | 28–30 | an Industrie touches nature | `smog_warn` on its best nature neighbour (Tiere/Vögel > Wald/Farn > Acker/Saat > Wiese/Moos) | that field withers one step if still next to the industry | keep industry away from nature, next to Fels/Wasser/towns |
| **Flut** | 28–30 | a face with city weight ≥ 5 (Dorf 1, Stadt 2, Industrie 2) | `flood_warn` (as v8) | low wet fields of that face become Wasser (as v8) | spread the towns over faces |

There is no danger on a timer. The bolt of v8 (every E twists) is replaced by the dry-forest trigger.

### 3.7 Goals and progress

| type | progress | used in |
|---|---|---|
| `make` kinds n | made − lost: every field that becomes a goal kind by a row, thriving, spawn or rain counts +1 and is marked `mk`; a danger that changes an `mk` field counts −1 (`goal_loss`). Growing up, being consumed by a row or a fish leaving for land clears `mk` without a loss | 1–14, 16, 18–19 |
| `satt` kind n | number of fields of the kind that are satt at the end of the round (drops by itself when one starves) | 20–29 |
| `group` kind n | size of the biggest group of the kind | 15, 17 |
| `hold` [sub-goals] k | rounds in a row in which all sub-goals hold and **no damage** happened (warnings are allowed) | 30 |

Several sub-goals (levels 22, 29) must hold at the same time; the chip shows both. The level is won at the end of the
round (or tool use) in which all sub-goals are met.

### 3.8 Order of a round (exact)

1. Rows (creation, `once`, consume). 2. `steps += 1`; `fresh −= 1`. 3. Fire spreads and burns down. 4. Blitz
(strike or new warning). 5. Vulkan (eruption or new warning). 6. Smog. 7. Flut. 8. Krieg. 9. Rudel. 10. Gedeihen
(satt / grow / spawn / hunger / starve; steam rain). 11. Glaube → meteor charges. 12. Rain refill every N steps.
13. Goal check (hold counter, Gnade). Tools (rain, meteor) are no step: rows of the tool, then the goal check.

### 3.9 Steps, stars, points

- `steps` = twists. Stars: ★★★ if steps ≤ s3, ★★ if ≤ s2, else ★ (always at least ★ when the level is done).
- **Points** of a level = **20 × stars + 5 × max(0, par − steps)**, `par = s2 + 4`. A replay pays only the improvement
  over the best result so far; the Welt des Tages pays fully once per Spieltag.
- Points are the only currency (section 6).

---

## 4. The campaign

### 4.1 Acts

| act | Genesis day (overview caps) | earth history | levels | new verbs and systems | start of the act (fresh pool board) |
|---|---|---|---|---|---|
| 1 | „Licht“ | glowing earth, lava, a dead primordial ocean, rock | 1–4 | rows; first Gedeihen (lava cools between 2 water fields); Vulkan; Erde | Lava and Fels, a small ocean |
| 2 | „Himmel“ | steam becomes atmosphere, first rain, primordial soup, first cells | 5–8 | rain (from steam, then from the sky); dead water comes alive; group strength (🔥🔥) | Fels, Lava, Erde; the ocean grows |
| 3 | „Land und Pflanzen“ | algae make oxygen, the sky turns blue, moss, ferns, forests | 9–12 | water rows; land greened by algae; Blitz on dry forests | Einzeller in the sea, bare land |
| 4 | „Sonne, Mond und Sterne“ | day and night, seasons: growth and harvest | 13–15 | the sun face (☀); Saat → Acker; Zusammenwachsen as a task | meadows, a few forests, algae |
| 5 | „Leben in Wasser und Luft“ | fish, schools, birds, the move to land | 16–19 | rows in the sea; groups in water; Vögel (🐟🐟); Landgang (spawn) | algae, meadows, forests |
| 6 | „Tiere und Menschen“ | herbivores, predators, food chain, meteor, people, farming, villages, faith and war, towns and industry | 20–28 | hunger; predators; two goals at once; Rudel + Meteor; people (consume); Ackerbau; Dorf; Kirche/Krieg/Glaube; Smog/Flut | each level of the act carries the world on |
| 7 | „Ruhe“ | the balance of the finished world | 29–30 | everything; `hold` (rest without damage) | towns, animals, meadows |

Overview: the 7 acts are 7 tiles (as the 7 days now); a tile opens into its levels (a row of dots, the current one
pulsing). Locked acts and levels show only a lock / „?“ (no title, no icon).

### 4.2 Level table (texts, goal, stars)

Goal types and counting: 3.7. Stars: ★★★ / ★★ thresholds in steps (★ = done). `par` = ★★ + 4 (points, 3.9).

| # | act | title | story (card) | task chip | goal (exact) | new (reveal caps · line) | stars ★★★/★★ ≤ | par |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Glut | „Die Erde glüht.“ | „Mach 6 Felsen“ | make Fels 6 | „Neu: Drehen“ · „Bring 3 gleiche in eine Reihe.“ | 4 / 6 | 10 |
| 2 | 1 | Abkühlen | „Das Meer kühlt die Glut.“ | „Mach 11 Felsen“ | make Fels 11 | „Neu: Abkühlen“ · „Lava zwischen zwei Wasser“ | 4 / 5 | 9 |
| 3 | 1 | Vulkan | „Die Glut bricht aus.“ | „Mach 16 Felsen“ | make Fels 16 | „Neu: Vulkan“ · „Zu viel Lava bricht aus“ | 5 / 7 | 11 |
| 4 | 1 | Urkontinent | „Land entsteht.“ | „Lass 11 Erde entstehen“ | make Erde 11 | „Neu: Land“ · „3 Felsen werden Erde“ | 5 / 6 | 10 |
| 5 | 2 | Atmosphäre | „Dampf wird Himmel.“ | „Lass 14 Erde entstehen“ | make Erde 14 | „Neu: Regen“ · „Dampf macht Wolken“ | 4 / 6 | 10 |
| 6 | 2 | Urmeer | „Das Meer wird reich.“ | „Mach 10 Ursuppe“ | make Ursuppe 10 | „Neu: Ursuppe“ · „Wasser braucht Glut und Fels“ | 5 / 7 | 11 |
| 7 | 2 | Erstes Leben | „Der erste Funke.“ | „Erschaffe 5 Einzeller“ | make Einzeller 5 | „Neu: Leben“ · „Ursuppe braucht viel Wärme“ | 4 / 6 | 10 |
| 8 | 2 | Leben teilt sich | „Leben teilt sich.“ | „Erschaffe 11 Einzeller“ | make Einzeller 11 | „Neu: Teilen“ · „Leben weckt Leben“ | 5 / 7 | 11 |
| 9 | 3 | Algen | „Grün im Meer.“ | „Lass 5 Algen wachsen“ | make Algen 5 | „Neu: Algen“ · „3 Einzeller werden Algen“ | 4 / 6 | 10 |
| 10 | 3 | Blauer Himmel | „Der Himmel wird blau.“ | „Lass 9 Moos wachsen“ | make Moos 9 | „Neu: Moos“ · „Algen machen das Land grün“ | 5 / 6 | 10 |
| 11 | 3 | Farne | „Grün wird höher.“ | „Lass 7 Farne wachsen“ | make Farn 7 | „Neu: Farne“ · „3 Moos werden Farn“ | 6 / 8 | 12 |
| 12 | 3 | Wälder | „Die ersten Wälder.“ | „Lass 7 Wälder wachsen“ | make Wald 7 | „Neu: Blitz“ · „Trockener Wald brennt“ | 6 / 7 | 11 |
| 13 | 4 | Tag und Nacht | „Die Sonne geht auf.“ | „Lass 12 Wälder wachsen“ | make Wald 12 | „Neu: Sonne“ · „Oben ist Tag“ | 5 / 6 | 10 |
| 14 | 4 | Saat | „Korn reift im Sommer.“ | „Lass 5 Felder reifen“ | make Acker 5 | „Neu: Saat“ · „Saat braucht Sonne und Wasser“ | 5 / 8 | 12 |
| 15 | 4 | Ernte | „Zeit der Ernte.“ | „Mach ein Feld aus 6“ | group Acker 6 | „Neu: Zusammenwachsen“ · „Gleiche wachsen zusammen“ | 5 / 8 | 12 |
| 16 | 5 | Fische | „Leben im Meer.“ | „Erschaffe 6 Fische“ | make Fische 6 | „Neu: Fische“ · „3 Algen werden Fisch“ | 5 / 6 | 10 |
| 17 | 5 | Schwärme | „Fische ziehen zusammen.“ | „Mach einen Schwarm aus 5“ | group Fische 5 | „Neu: Schwarm“ · „Fische schwimmen zusammen“ | 5 / 8 | 12 |
| 18 | 5 | Vögel | „Leben in der Luft.“ | „Lass 6 Vögel nisten“ | make Vögel 6 | „Neu: Vögel“ · „Vögel brauchen Fische“ | 5 / 7 | 11 |
| 19 | 5 | Landgang | „Raus aus dem Wasser.“ | „Bring 6 Tiere an Land“ | make Tiere 6 | „Neu: Landgang“ · „Fische gehen an Land“ | 6 / 7 | 11 |
| 20 | 6 | Futter | „Die Tiere haben Hunger.“ | „Gib 6 Tieren Futter“ | satt Tiere 6 | „Neu: Hunger“ · „Tiere brauchen Pflanzen“ | 3 / 5 | 9 |
| 21 | 6 | Raubtiere | „Jäger und Gejagte.“ | „Mach 3 Raubtiere satt“ | satt Raubtiere 3 | „Neu: Raubtiere“ · „Raubtiere brauchen Tiere“ | 4 / 6 | 10 |
| 22 | 6 | Nahrungskette | „Jeder frisst jeden.“ | „Mach alle satt“ | satt Raubtiere 3 + satt Tiere 4 | „Neu: Nahrungskette“ · „Jeder braucht sein Futter“ | 3 / 5 | 9 |
| 23 | 6 | Meteor | „Ein Stein fällt vom Himmel.“ | „Rette 6 Tiere“ | satt Tiere 6 | „Neu: Meteor“ · „Rudel jagen Herden“ | 2 / 3 | 7 |
| 24 | 6 | Menschen | „Die ersten Menschen.“ | „Versorge 3 Hütten“ | satt Hütte 3 | „Neu: Menschen“ · „3 Tiere werden Hütte“ | 5 / 11 | 15 |
| 25 | 6 | Ackerbau | „Die Menschen säen.“ | „Versorge 4 Hütten“ | satt Hütte 4 | „Neu: Ackerbau“ · „Regen neben Hütten: Saat“ | 4 / 6 | 10 |
| 26 | 6 | Dörfer | „Aus Hütten werden Dörfer.“ | „Mach 4 Dörfer satt“ | satt Dorf 4 | „Neu: Dörfer“ · „Dorf braucht Nahrung und Arbeit“ | 3 / 8 | 12 |
| 27 | 6 | Glaube | „Die Menschen glauben.“ | „Mach 2 Städte satt“ | satt Stadt 2 | „Neu: Glaube“ · „Kirche an Kirche: Krieg!“ | 3 / 5 | 9 |
| 28 | 6 | Städte | „Rauch über den Städten.“ | „Mach 2 Städte satt“ | satt Stadt 2 | „Neu: Fabriken“ · „Zu viel Stadt: Flut!“ | 3 / 6 | 10 |
| 29 | 7 | Gleichgewicht | „Alles im Gleichgewicht.“ | „Mach alle satt“ | satt Stadt 2 + satt Tiere 3 | „Neu: Gleichgewicht“ · „Menschen und Tiere satt“ | 4 / 9 | 13 |
| 30 | 7 | Der siebte Tag | „Und es war gut.“ | „Halte 3 Runden Ruhe“ | hold [satt Stadt 2 + satt Tiere 3] 3 | „Der siebte Tag“ · „Lass deine Welt ruhen“ | 7 / 11 | 15 |

### 4.3 Level rules (start board, systems, the new thing)

Start board = counts on the 54 fields (rest Wasser), placed by sticker type (½ corners, 40 % edges, 10 % centres per kind), then repaired to the start rules (5). Every level enables only the systems listed.

| # | start board (rest Wasser) | rules of the level | new thing |
|---|---|---|---|
| 1 | Lava 18, Fels 14, Wasser 22 | rows Lava→Fels; rain Lava→Fels; charges 0 | rows; Lava → Fels |
| 2 | Fels 22, Lava 18, Wasser 14 | rows Lava→Fels; Lava 💧💧→Fels; rain Lava→Fels; charges 0 | first Gedeihen: Lava with 💧💧 cools to Fels |
| 3 | Lava 20, Fels 20, Wasser 14 | rows Lava→Fels; Lava 💧💧→Fels; rain Lava→Fels; charges 0; dangers/tools: Vulkan | danger Vulkan (lava clump ≥ 5), loss −1 |
| 4 | Fels 22, Lava 16, Wasser 16 | rows Fels→Erde, Lava→Fels; Lava 💧💧→Fels; rain Fels→Erde, Lava→Fels; charges 0; dangers/tools: Vulkan | rows Fels → Erde |
| 5 | Fels 18, Lava 14, Wasser 22 | rows Fels→Erde; Lava 💧💧→Fels; rain Lava→Fels, Fels→Erde; charges 0 + steam; dangers/tools: Vulkan | steam → rain charges; rain Fels → Erde |
| 6 | Fels 16, Erde 8, Lava 5, Wasser 25 | rows Fels→Erde; Wasser 🔥🔥⛰→Ursuppe; rain Wasser(shore)→Ursuppe, Fels→Erde; charges 1 +1/4; dangers/tools: Vulkan | Wasser with 🔥🔥 ⛰ → Ursuppe; group strength |
| 7 | Fels 14, Erde 8, Ursuppe 6, Lava 5, Wasser 21 | rows Fels→Erde; Ursuppe 🔥🔥→Einzeller; rain Wasser(shore)→Ursuppe, Fels→Erde; charges 1 +1/4; dangers/tools: Vulkan | Ursuppe with 🔥🔥 → Einzeller |
| 8 | Fels 10, Ursuppe 9, Erde 6, Lava 5, Einzeller 2, Wasser 22 | rows Fels→Erde; Ursuppe ✨→Einzeller; rain Wasser(shore)→Ursuppe, Fels→Erde; charges 1 +1/4; dangers/tools: Vulkan | Einzeller spark Ursuppe (✨) |
| 9 | Einzeller 14, Fels 8, Erde 8, Wasser 24 | rows Einzeller→Algen; Ursuppe ✨→Einzeller; rain Wasser(shore)→Ursuppe; charges 1 +1/5 | rows Einzeller → Algen |
| 10 | Erde 14, Einzeller 6, Fels 6, Algen 4, Wasser 24 | rows Erde→Moos, Einzeller→Algen; Erde 🌿🌿→Moos; rain Erde→Moos; charges 1 +1/5 | Erde with 🌿🌿 → Moos; sky turns blue |
| 11 | Moos 12, Erde 8, Fels 6, Algen 4, Wasser 24 | rows Erde→Moos, Moos→Farn; Erde 🌿🌿→Moos; rain Moos→Farn, Erde→Moos; charges 1 +1/5 | rows Moos → Farn |
| 12 | Farn 10, Moos 10, Erde 4, Fels 4, Algen 3, Wasser 23 | rows Moos→Farn, Farn→Wald; Moos 💧💧→Farn; rain Moos→Farn, Erde→Moos; charges 1 +1/5; dangers/tools: Blitz | rows Farn → Wald; danger Blitz (dry forest) |
| 13 | Wiese 14, Erde 6, Wald 3, Algen 3, Fels 3, Wasser 25 | rows Erde→Wiese, Wiese→Wald; Wiese ☀💧→Wald; rain Wiese→Wald, Erde→Wiese; charges 1 +1/5; dangers/tools: Blitz | sun face: Wiese with ☀💧 → Wald |
| 14 | Wiese 14, Erde 6, Wald 4, Algen 3, Wasser 27 | rows Erde→Wiese, Wiese→Saat; Saat ☀💧→Acker; rain Saat→Acker, Wiese→Saat; charges 1 +1/4; dangers/tools: Blitz | Saat → Acker (☀💧) |
| 15 | Wiese 12, Wald 4, Acker 3, Saat 3, Erde 3, Algen 3, Wasser 26 | rows Erde→Wiese, Wiese→Saat; Saat ☀💧→Acker; rain Saat→Acker, Wiese→Saat; charges 1 +1/4; dangers/tools: Blitz | group goal (Zusammenwachsen) |
| 16 | Algen 15, Wiese 8, Wald 6, Fels 4, Wasser 21 | rows Algen→Fische; rain Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz | rows Algen → Fische |
| 17 | Algen 10, Wiese 8, Wald 6, Fische 4, Fels 4, Wasser 22 | rows Algen→Fische; rain Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz | group goal in water |
| 18 | Wald 10, Algen 9, Wiese 8, Fische 3, Fels 2, Wasser 22 | rows Wald→Vögel, Algen→Fische; Wald 🐟🐟→Vögel; rain Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz | Wald with 🐟🐟 → Vögel |
| 19 | Algen 10, Wiese 10, Wald 6, Fische 3, Vögel 2, Wasser 23 | rows Algen→Fische; Fische 🦶→spawn Tiere; rain Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz | spawn: fish + meadow → Tiere |
| 20 | Erde 10, Tiere 7, Fels 6, Wald 3, Wiese 3, Wasser 25 | rows Erde→Wiese, Wald→Tiere; Tiere 🌾→–, starve→Erde; rain Erde→Wiese; charges 1 +1/5 | needs + hunger for animals |
| 21 | Tiere 10, Erde 7, Wiese 5, Fels 4, Wald 3, Wasser 25 | rows Erde→Wiese, Wald→Tiere, Tiere→Raubtiere; Tiere 🌾→–, starve→Erde; Raubtiere 🍖→–, starve→Wiese; rain Erde→Wiese; charges 1 +1/5 | predators need prey |
| 22 | Tiere 7, Erde 7, Wiese 4, Fels 4, Raubtiere 3, Wald 3, Wasser 26 | rows Erde→Wiese, Wald→Tiere, Tiere→Raubtiere; Tiere 🌾→–, starve→Erde; Raubtiere 🍖→–, starve→Wiese; rain Erde→Wiese; charges 1 +1/5 | two satt goals at once |
| 23 | Tiere 8, Erde 7, Raubtiere 4, Wiese 4, Wald 3, Fels 3, Wasser 25 | rows Erde→Wiese, Wald→Tiere; Tiere 🌾→–, starve→Erde; Raubtiere 🍖→–, starve→Wiese; rain Erde→Wiese; charges 1 +1/5; dangers/tools: Rudel, Meteor ×1 | danger Rudel; Meteor tool |
| 24 | Tiere 13, Wald 10, Wiese 2, Wasser 29 | rows Wald→Tiere, Tiere→Hütte; consume Tiere (others → Wiese); Hütte 🍞→–; rain Erde→Wiese, Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz | 3 Tiere → Hütte (consume); Hütte 🍞 |
| 25 | Wiese 10, Wald 6, Hütte 5, Tiere 2, Erde 2, Wasser 29 | rows Wald→Tiere; Hütte 🍞→–; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Blitz | rain Wiese next to people → Saat → Acker |
| 26 | Wiese 7, Wald 6, Hütte 5, Tiere 4, Acker 3, Fels 3, Saat 2, Wasser 24 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→–, starve→Hütte; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Blitz | Hütte → Dorf (🍞🔨) |
| 27 | Wald 7, Dorf 6, Acker 4, Tiere 4, Kirche 3, Fels 3, Wiese 3, Wasser 24 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Glaube→Meteor | Kirche, Krieg, Glaube → Meteor; Stadt |
| 28 | Wald 7, Acker 5, Tiere 4, Stadt 3, Kirche 3, Wiese 3, Dorf 2, Industrie 1, Wasser 26 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Smog, Flut, Glaube→Meteor | Smog, Flut |
| 29 | Wald 7, Tiere 6, Wiese 6, Stadt 3, Acker 3, Dorf 2, Kirche 2, Industrie 1, Wasser 24 | rows Wald→Tiere; Tiere 🌾→–, starve→Erde; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Blitz, Krieg, Smog, Flut, Glaube→Meteor | two satt goals, all systems |
| 30 | Tiere 6, Wiese 6, Wald 6, Acker 4, Stadt 3, Kirche 2, Fels 2, Dorf 1, Wasser 24 | rows Wald→Tiere; Tiere 🌾→–, starve→Erde; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Glaube→Meteor | hold goal (3 rounds, no damage) |

### 4.4 Notes per level

- **Level 1, board 0 = tutorial:** the demo move (axis 0, layer 1, turns 1) makes a Lava row; the hand shows it once
  („Schau: 3 gleiche in eine Reihe.“), then „Jetzt du!“ (as built for day 1).
- **Start rules (all levels):** no counting row, no satt goal field, no progress, at most `satt_max` satt thrivers
  (0 in act 1–2, 1–3 later), no church touches a church, group goals start with no group bigger than 1, no single twist
  wins. Levels 3 and 23: half of the pool boards start with the danger already built (a lava clump of 5 / a pack of
  3), so the new danger shows after the first twist.
- **Visible kinds:** at most 6 besides water on every start board (the user's „nicht zu viele verschiedene Felder“);
  at most 3 growable kinds (row kinds with ≥ 3 fields + thrivers with a result).
- **Overnight growth inside an act** (carry, section 5): level 27 `[[Hütte, Dorf]]`, level 28 `[[Dorf, Stadt]]`,
  level 30 `[[Saat, Acker]]`; all other levels only fit the composition (the wave shows the changed fields).
- **No dead ends:** every counted kind has a way to be (re)made in its level (rows, thriving, rain): e.g. level 20
  has Wald → Tiere rows although the task is feeding, level 27 lets Hütte grow to Dorf again; plus Gnade (3.5).
- **Sun face** (levels 13–15, 25–30 for Saat): face 0 in `GameState.FACE_NORMALS` (+y). The camera starts with it
  on top; the art shows the sun above it (section 10).

---

## 5. The world carries over within an act (decision)

**Decision: yes, within an act; a new act starts on a fresh, validated board.** The player's world of yesterday is
the start of today's level (the backlog item „die echte Welt von gestern weiterführen“), so building feels
continuous; the first level of an act is a pool board because the era changes the whole look (and a validated board
resets any mess). Validated by simulation: CARRY_LINE.

**Algorithm (`Campaign.carry(prev_board, level, seed)`, model `b4/carry9.py`, deterministic):**
1. `prev_board` = the 54 kinds by **slot** at the end of the last session of the previous level (after Weiterbauen),
   saved as `[kampagne] welt` (section 13).
2. *Overnight:* the level's `overnight` list (`[from, to]`, e.g. level 27: Hütte → Dorf) is applied to every field.
3. *Retire:* kinds the level does not use become their retire kind (Lava → Fels, Moos → Wiese, Farn → Wald,
   Saat → Wiese, Vögel → Wald, Fische/Einzeller → Algen, Raubtiere → Tiere, …; chain until allowed; else Wasser).
4. *Fit:* the counts are fitted **exactly** to the level's start composition: while a kind is short, the surplus
   field (a kind above its count, Wasser included) with the most neighbours of the short kind becomes that kind
   (new things grow next to their own kind; ties: the level seed's LCG).
5. *Repair:* the generator's swap hill-climb (swaps of two fields of the same sticker type) until the start rules
   hold: no counting row, no satt goal field, no church contact, at most `satt_max` satt thrivers, no single twist
   wins. 3000 swaps at most.
6. If 5 fails, the level's pool board is used instead (`fallback`). The presentation („Neuer Morgen“ wave,
   `GDPD_BALANCE_2.md` 5.6) shows the fields whose kind changed in steps 2–5 growing up (max 6 in the wave, the rest
   fade).

The start board is stored as `[kampagne] start` so a restart of the same level (app closed mid-level) shows the same
world. „Nochmal · mehr Sterne“ replays the **same** start board (it was the player's world), not a new one.

---

## 6. Points and the shop

**One currency: Punkte** (coins are merged: 1 old coin = 20 points).

| source | points | cap |
|---|---|---|
| level done | 20 × stars + 5 × max(0, par − steps) | replays pay only the improvement |
| Welt des Tages | same formula | once per Spieltag |
| Weiterbauen | +1 per new growth (a row, or a field reaching a kind by thriving for the first time); +10 per extra task | 30 per Spieltag |
| streak milestone (every 7 days) | +50 (when shields are full; else +1 shield as now) | – |

Typical income (model, good bot): POINTS_LINE.

| shop item (`Shop.ITEMS`) | price | rule |
|---|---|---|
| Serienschutz | 100 | max 2 held (as now) |
| Wunder: Regen | 25 | +1 Regen in the current level, max 1 per level; no step |
| Wunder: Meteor | 50 | +1 Meteor (from level 23), max 1 per level |
| Tipp | 10 | the hint is **free** in levels 1–5 and after 3 steps without progress (never a pay-wall on the core verb) |
| Zurück | 5 | one step back |
| Teile für deinen Gott (Hut, Krone, Flügel, …) | 150–300 | cosmetic |
| Skins (Spaghettimonster-Farben, Gold, Nacht) | 500 | cosmetic |
| Themes / neue Welten (Insel, Wüste, Winter) | 1500 | the Welt des Tages also uses them for free once a week (no pay-wall) |

Fairness rules: twisting, rain charges from the level, Gnade and the hint after a stall are free; bought miracles
never give more than one extra charge per level; stars and points stay comparable because bought miracles are no
steps but are limited to one per kind per level.

---

## 7. Weiterbauen (keep playing after the win)

As now (`GDPD_TAEGLICH_CHARAKTER.md` 2): no limit, all rules on, the level stays won, stars frozen. New:
- **Extra tasks**: the chip becomes „Extra: …“ – `make` and `group` goals: target + 2, then + 4; `satt` goals:
  target + 1; `hold`: + 2 rounds. Each extra: +10 points and a small celebration. At most 2 extras, then
  „Bau weiter“ (free building, +1 per new growth).
- **Extras of the world** (things to do that are not on the task, shown as small icons in the dock):
  act 1–2 „Vulkan zähmen“ (cool the biggest lava group), act 3 „Himmel ganz blau“ (sky_blue = 1), act 4
  „Großes Feld“ (a 6-field Acker), act 5 „Großer Schwarm“, act 6 „Herde“ / „Großstadt-Viertel“, act 7 „Paradies“
  (every living field satt). Each +10 once per level; pure fun, never needed.
- **Farming pays nothing:** WEITER_LINE.
- The world after Weiterbauen is what the next level of the act starts from (section 5).

---

## 8. After the campaign: Welt des Tages and new worlds

- From the Spieltag after the first win of level 30: every Spieltag one **Welt des Tages** (WdT), same for
  everyone in the time zone. `template(key)` = `WDT[posmod(key, 14)]` with
  `WDT = [3, 6, 8, 10, 12, 13, 15, 17, 19, 22, 23, 26, 27, 29]` (one strong level of every act, two of acts 2–6,
  never a tutorial); `board(key) = 1 + posmod(floor(key / 14), pool_size − 1)` (board 0 is the level's teaching
  board). 14 × 19 = 266 worlds before one repeats. Stars, mercy and points as in the campaign; the world does not
  carry over (each WdT is its own world).
- Replays of campaign levels stay open forever (stars, points for improvements).
- **New worlds later** (packs as data, `GDPD_7_TAGE.md` 3.3 format, now with the level keys of section 4): Insel
  (water-heavy boards, fish and birds), Wüste (few water fields, Fels, Lava, oases: `wet` is precious), Winter (a
  new `frozen` state of water: no `wet` until the sun face thaws it). Each pack: 10 levels, its own era visuals, then
  it joins the WdT rotation.

---

## 9. Validation (TBD)

---

## 10. Era visuals (hooks for the art track)

The world look follows the earth history. `Campaign.era(level)` returns one dictionary; `World.set_era(era, blend_s)`
blends to it (2 s at a level start, 0 s on load). Everything stays inside the seamless diorama look of
`GDPD_GRAFIK.md` (ground shader with 8-neighbour masks, water as one body); only palette, sky and ambient life change.

| act | sky (`backdrop.gdshader`) | light | water (one body, `look.gd::water_*`) | ground / life | ambient |
|---|---|---|---|---|---|
| 1 Licht | near black red, glow from below, no clouds; stars faint | warm key from the lava (emission), low sun | dark, steaming, grey-black, no glitter (`life = 0`) | Lava: emissive cracks, slow pulse; Fels: dark basalt; Erde: brown-grey dust | heat shimmer over lava, sparks, steam where lava touches water |
| 2 Himmel | brown-orange haze, first clouds (count = rain charges), rain curtains | sun behind haze, soft | grey-brown, Ursuppe patches ochre and turbid; Einzeller: faint green-blue glow dots | wet dark rock after rain | drizzle, lightning far away (no gameplay), steam |
| 3 Land und Pflanzen | haze → **blue**: `sky_blue = clamp(algae_fields / 8, 0, 1)` blends from the act-2 haze to clear blue (first level of the act starts at 0.25) | sun gets white | blue-green, Algen: green streaks that drift; dead water stays dark | Moos: low velvet green carpet; Farn: feathery fronds; Wald: conifers (no leaves yet) | mist over moss, insects (late) |
| 4 Sonne, Mond, Sterne | **day/night split**: the sun face (face 0, top) is lit by a visible sun disc, the bottom face shows night with stars and a moon; side faces dawn/dusk; a slow sun arc moves 15° per twist (pure look) | strong sun on face 0, cool moonlight below | clear, glitter only under the sun | Wiese: meadows with flowers; Saat: light green rows; Acker (reif): golden | birds of the day not yet; fireflies at night side |
| 5 Wasser und Luft | clear, cumulus clouds, gulls far away | normal | clear blue; Fische: schools that swim (one school per fish group, size ~ group); Algen sway | as act 4 + Vögel: nests in trees, birds circling the group | waves, splashes |
| 6 Tiere und Menschen | normal; smog (level 28+) greys the sky by the number of Industrie fields (0.15 each) | normal; war mood (existing) | normal; flood rising on warned faces | herds that walk and graze (group = one herd), predators that prowl; people visible (GDPD_GRAFIK 9.2) | dust, smoke from towns, church bells (sound later) |
| 7 Ruhe | golden evening light, soft clouds; on `hold` progress the light warms per held round | warm | calm, mirror | everything alive and moving, no warnings visible | birds, slow wind; at the win a long sunset |

Per field (all acts): the existing `FieldView` states plus `molten` (lava pulse), `steam` (lava next to water, cooling
dots 1/2), `alive` (water life level 0–3: dead, cells, algae, fish), `ripe` (Saat → Acker gold), `nest` (Vögel),
`herd` / `pack` (animal groups), `dry` (forest group without water: slightly browner, crackle when warned).

**Merge visuals (Zusammenwachsen).** Same kinds that touch are drawn as one: one forest canopy, one field with
continuous furrows, one lake, one herd, one town (the seam rule of `GDPD_GRAFIK.md` 16 already treats same kinds as
„self“; extend it to the new kinds). A group with strength ≥ 2 shows a small number badge on its biggest field while
a need line points to it (`×2`, `×3`). Twisting them apart splits the look at once.

---

## 11. Event contract (rules → UI / visuals)

`end_round()` and the tools return a list of dictionaries (`type` first). Names below are final; the old v8 names stay
where they exist (`merge` for `grow`, `burn` for `burnt`, …, `GDPD_BALANCE_2.md` 15).

| type | payload | visual | pill (caps · line), max one per round |
|---|---|---|---|
| `grow` (`merge`) | field, from, kind, others, eaten | growth pop; `eaten` fields turn to their consume kind | – |
| `face` | field (centre), from, kind | whole face pops | „Ganze Seite!“ |
| `thrive` | field, from, kind, first | rise animation | per kind: „Lava wird Fels“, „Ursuppe lebt!“, „Moos wird Farn“, „Saat reift“, „Vögel nisten“, „Hütte wird Dorf“, „Dorf wird Stadt“ |
| `spawn` | field (fish), target, kind | an animal climbs from the water onto the meadow | „Landgang!“ |
| `steam` | field | steam puff, a cloud joins the sky | „+1 Regen“ (first time per level) |
| `satt_new` / `satt_lost` | field, missing | gold ring / ring fades | goal kind only: „Tier satt!“, „Hütte satt!“ … |
| `hunger_warn` | field, kind | pulsing missing icon, sad tint | „Hunger!“ · „Bring Futter“ |
| `starve` | field, from, kind | sink animation, dust | „Verhungert“ |
| `goal_loss` | field, kind, cause, progress | red „−1“ flies from the field to the goal chip, chip shakes | „−1 Fels“ / „−1 Tier“ (kind name) |
| `volcano_warn` | crater, fields | smoke column on the crater, ground glows | „Vulkan grollt!“ · „Teil die Lava“ |
| `erupt` | crater, field, from | lava flows onto the field | „Ausbruch!“ |
| `volcano_calm` | crater | smoke stops | „Ruhe“ |
| `bolt_warn` | field | dark cloud, crackle on the dry forest | „Blitz droht!“ · „Wasser an den Wald“ |
| `bolt` / `bolt_miss` / `bolt_cancel` | field | lightning + flames / cloud leaves / rain on it | „Feuer!“ / – / „Regen schützt“ |
| `ignite`, `burnt` (`burn`), `rain_out` | field (+ from, kind) | as v8 | as v8 |
| `pack_warn` | fields (threatened Tiere) | predators crouch, red eyes toward the herd | „Rudel jagt!“ · „Trenn die Raubtiere“ |
| `pack_hunt` | field | chase, the animal field turns to grass | „Gejagt!“ |
| `smog_warn` | industry, field | grey haze creeps toward the field | „Smog droht!“ |
| `smog` (`polluted`) | industry, field, from, kind | the field withers | „Smog!“ |
| `flood_warn`, `flood`, `war_start`, `war_hit`, `war_end`, `meteor` | as v8 | as v8 | as v8 |
| `meteor_ready` | – | meteor icon in the tool slot pops | „Meteor bereit“ |
| `mercy` | – | a soft light from above, +1 on the tool | „Hilfe von oben“ |
| `level_progress` | sub, value, target, delta | goal chip counts (ghost value while dragging) | – |
| `hold` | rounds, target, ok | rest ring around the chip fills (act 7) | „Ruhe hält“ / „Unruhe!“ |
| `era` | act, level, sky_blue, life | `World.set_era` | – |

State for HUD and field views after every round: per field `fed`, `hungry`, `need_state()` (met / missing with
amounts: `{"food": [1, 2]}` = has 1 of 2), `burning`, `fresh`, `mk` (counts for the goal), group id and strength;
global `bolt`, `volc`, `pack_warn`, `smog_warn`, `war_on`, `front`, `flood_warn`, `faith`, `rain`, `meteors`,
`held`, task progress per sub-goal, `steps`. Non-blocking overlays use `MOUSE_FILTER_IGNORE`.

**Preview while twisting (extends `GDPD_BALANCE_2.md` 4.6).** `preview(move)` returns the v8 keys plus
`goal_delta` (per sub-goal, after the whole round, including losses), `volcano_risk` (crater would be warned or
erupt), `bolt_risk` (forest groups that become dry), `pack_risk`, `smog_risk`, `hunger` (fields that would reach the
warning) and `merge` (`[[kind, size_before, size_after], …]` for groups the twist joins or splits). The chip shows
`5→6/11` green or `6→5/11` red, also for a loss.

---

## 12. HUD and UI items from the backlog

- **HUD more central and bigger** (Philipp): the goal chip, menu, points, streak and dock move 8 % of the screen width
  towards the centre (safe-area aware), all chips +15 % height, the goal chip becomes the widest element in the
  top row and shows up to two sub-goals (`🐺 1/2 · 🦌 3/4`). Step counter next to it: `👣 7` and the next star
  threshold as a small ring (`★★★ bis 5`). Tour check `hud_central` (chip centre within 12 % of screen centre,
  every chip ≥ 56 px high at 1080 × 2340).
- **Tap your god on the overview opens it:** the character portrait in the header is a button (`character_open`):
  view, change parts and colours, change the tone. Same sheet as the creator, „Fertig“ saves. Tour check
  `god_tap_opens`.
- **Cancel strip at the bottom:** stays as built (compact, near the bottom centre). Tour check stays.
- **Free play: „100-Sekunden-Challenge“ replaces „40 Drehungen“.** Rules = free play Mittel (or the chosen level),
  a 100 s clock that starts with the first twist (not before), no twist limit, score = Glaube at the end. A fire
  costs 5 s (pill „−5 s“), the choice card pauses the clock (the pill choice does not), no Tipp and no Zurück. Record
  per mode (`rekord.cfg [rekord] sek100_<mode>`), shown on the free-play card („Rekord 412“). At 0 s: „Zeit!“ and
  the result card with the record celebration. Old `runden40_punkte` stays readable (shown as „Alter Rekord“ once).
  Tour check `free_100s` (clock starts on the first twist, a fire takes 5 s, the card pauses).

---

## 13. Save format v3 and migration

`user://rekord.cfg`, `[schoepfung] version = 3`. New section `[kampagne]`:

| key | type | meaning |
|---|---|---|
| `version` | int | 1 |
| `level` | int | highest unlocked level (1–30) |
| `sterne` | Array[int] (30) | best stars per level |
| `schritte` | Array[int] (30) | best steps per level (0 = never won) |
| `gewonnen_am` | Array[int] (30) | Spieltag of the first win per level, −1 = none |
| `letzter_neuer` | int | Spieltag of the latest first win (unlock rule of `GDPD_TAEGLICH_CHARAKTER.md` 1.2, now over 30 levels) |
| `welt` | String | 54-char board of the world at the end of the last session of the current act (slot order, `CODE`), "" = none |
| `welt_level` | int | the level that world belongs to |
| `start` | String | start board of the current (not yet won) level, so a restart shows the same world |
| `schnell_bis` | int | fast-track target level for veterans (0 = none, section 13.1) |
| `punkte` | int | points (the single currency, replaces `[konto] credits`) |
| `punkte_tag` | Array[int] | `[key, points]` earned in Weiterbauen today (cap) |
| `gekauft` | Array[String] | shop item ids owned (parts, skins, themes) |

`[taeglich]` keeps streak, shields, reminders and the clock (unchanged); `wdt_*` stays for the Welt des Tages.

### 13.1 Migration of existing players (save v2 → v3)

| old state (`[schoepfung] sterne`, `fertig`) | new state |
|---|---|
| new player | level 1 (story from the start) |
| any old progress | level 1 is open **and** fast track: `schnell_bis = T(old)`, where `T` = 4, 8, 12, 19, 24, 26, 28 for old days 1–7 won (highest won day). While `level < schnell_bis`, up to **3 new levels per Spieltag** open (instead of 1); the overview says „Schnellstart: 3 heute“ |
| `fertig == true` (all 7 old days) | as above with `schnell_bis = 28`, and the **Welt des Tages stays available every day** during the campaign (veterans keep their daily meaning); free play stays open |
| old stars | not copied (different levels); each old star becomes **20 points** once („Danke fürs Mitspielen: +140 Punkte“) |
| `[konto] credits` | × 20 → `punkte` (1 old coin = 20 points; shield price 5 coins = 100 points keeps its value) |
| streak, shields, character, reminders | unchanged |
| `wdt_*` | unchanged |

The old day pools (`data/days_schoepfung.json`) stay in the build as the Welt-des-Tages templates until the campaign
pools (`data/kampagne_schoepfung.json`) take that role (section 8). Tests: `test_migrate_v3` (each row above).

---

## 14. Test plan (`tests/test_rules.gd`, must end with „ 0 Fehler“)

1. **kinds9**: `FieldData.KIND_COUNT` 27, names, icons, `CODE` letters (`LUzafmnvrs` after `R`), water family,
   `decode(encode(b)) == b` for every pool board.
2. **groups / strength**: same-kind groups across cube edges; strength = min(size, CAP); supply sums distinct groups,
   never the same group twice (a city next to two fields of one 3-group gets 3, not 6).
3. **thrive generic**: up after G satt rounds; spawn (fish + meadow → animals, fish → algae); hunger warning at H − 1,
   starve at H (Tiere → Erde, Dorf → Hütte, Stadt → Dorf), Hütte never starves; `fed`/`hungry` move with the field.
4. **cooling + steam**: lava with 2 water neighbours becomes Fels after 2 rounds; with `steam_rain` +1 rain (max 3).
5. **volcano**: a lava group of 5 warns; still ≥ 5 at the next round end → up to 3 neighbours become lava, made Fels
   among them count as `goal_loss`; splitting the group → `volcano_calm`; craters rest 2 rounds.
6. **bolt9**: only dry forest groups (≥ 3, no water neighbour) are warned; water moved next to it cancels the strike
   (`bolt_miss`); rain cancels; fire never spreads into wet fields.
7. **pack / smog9**: warnings one round ahead; separating the pack or the industry cancels.
8. **goal progress with losses**: `make` = made − lost; evolving upward is no loss; a consume is no loss; a danger on
   a made field is −1 and sends `goal_loss`; `satt`, `group`, `hold` (resets on any threat).
9. **mercy**: from the 1-star zone, every 3 rounds without new progress +1 rain/Wunder (max 3), never before.
10. **points**: 20 × stars + 5 × max(0, par − steps); replay pays only the improvement; Weiterbauen +1 per new growth
    (row, or a (field, kind) reached by thriving for the first time), cap 30 per Spieltag.
11. **xcheck9**: replay the model cases (section 16) with 0 mismatches.
12. **pool_replay9**: every pool solution of `kampagne_schoepfung.json` wins at exactly `solved_in` with its stars.
13. **carry9**: carrying the stored end world of level n into n + 1 gives exactly the comp, passes the start rules,
    or falls back to the pool board; the same input gives the same board (deterministic).
14. **unlock30 / fasttrack / migrate_v3**: one new level per Spieltag (3 on the fast track), clock rules unchanged.
15. **texts9**: every new player text ≤ 6 words (existing test: ≤ 8), no locked title appears anywhere (no spoiler).
16. **free_100s**: clock starts at the first twist, −5 s per fire, paused by the card, no hint/undo.

## 15. Tour checks (`main.gd`; add the names to the list in `.github/workflows/gdpd.yml` when they exist)

| name | what it checks (real input) |
|---|---|
| `l1_tutorial_lava` | level 1 board 0: the demo move makes a Lava row → Fels; chip `1/6`; shot |
| `cooling_steam` | level 2: a twist that puts lava between 2 water fields shows steam dots 1/2; after the 2nd round Fels |
| `volcano_warn` | level 3 board with a clump: after twist 1 „Vulkan grollt!“ and the smoke; splitting it gives „Ruhe“ |
| `goal_loss_cue` | level 3: an eruption over a made Fels shows „−1 Fels“ and the chip drops (`9→8/16`) |
| `rain_from_steam` | level 5: steam adds a rain charge (tool count +1) |
| `water_alive` | levels 6–9: water look changes dead → soup → cells → algae (shots per stage) |
| `sky_blue` | level 10: sky_blue rises with algae (two shots, value printed) |
| `dry_forest_bolt` | level 12: a dry forest group gets the warning; moving water next to it cancels it |
| `sun_face` | level 13: a meadow on the sun face with water shows ☀💧 met; on the side face ☀ grey |
| `group_merge` | level 15: two ripe fields joined show one field and the `×2` badge; split again shows two |
| `landgang` | level 19: a fish next to a meadow for 2 rounds → animals appear on the meadow, the fish field becomes algae |
| `hunger_warn` | level 20: an animal without plants pulses „Hunger!“ at round 3 and starves at round 4 (−1 cue is not shown for satt goals, the chip simply drops) |
| `pack_warn` | level 23: a pack of 3 warns; the meteor on one predator cancels it |
| `town_needs_group` | level 27: a town next to one Acker shows 🍞 1/2; joining a second Acker makes it satt |
| `hold_rest` | level 30: holding the state fills the rest ring; a warning resets it |
| `carry_world` | win level 1, next Spieltag (test button): level 2 starts with yesterday's Fels where they were (≥ 50 % of fields keep their kind) |
| `no_step_limit` | any level: 40 twists without winning never fails the level; the star ring shows ★ |
| `points_shop` | win → points fly to the header; the shop sells a shield for 100 |
| `hud_central`, `god_tap_opens`, `free_100s` | section 12 |
| `no_spoiler_campaign` | overview: locked levels show only a lock/„?“, never a title or icon |

Existing checks that change: `kinds_per_day` → `kinds_per_level`, `task_chip` (two sub-goals, step counter),
`extra_task` (section 9), `day_locked_until_tomorrow` (30 levels), `daily_world` (section 8).

---

## 16. Godot cross-check plan

Same method as v8 (`GDPD_BALANCE_2.md` 13/15), which found 0 mismatches over 11 359 steps:

1. **Cases** (`b4/xcheck9.py gen cases9.json 600`): 600 cases over all 30 levels (20 per level), styles round-robin:
   random twists, ping-pong farming, good-bot actions, random with many tools (rain and meteor on random legal
   fields), plus the 600 pool solutions. Each case: `level`, `seed`, `kinds` (board string), `actions`
   (`["twist", [a, l, t]]`, `["rain", f]`, `["meteor", f]`) up to 40 actions.
2. **Record** after every action: kinds by field id, positions, `fed`, `hungry`, `burning`, `fresh`, `mk`, `bolt`,
   `volc`, `crater_rest`, `pack_warn`, `smog_warn`, `war_on`, `front`, `flood_warn`, `faith`, `meteors`, `rain`,
   `twists`, `won`, `made − lost` per goal kind, progress per sub-goal, `held`, the satt set, group labels
   (canonical: the smallest field id per group), and the event types in order.
3. **GDScript side**: `tests/xcheck9.gd` (headless, `--script`) loads `cases9.json`, plays each case through the real
   `GameState` (not a scratch port), writes `out9.json`; `python3 xcheck9.py cmp cases9.json out9.json` must report
   0 mismatches. Mapping (as v8, `Days.solution_step`): model `["twist", [a, l, t]]` =
   `GameState.play({"type": "twist", "axis": a, "layer": l, "turns": t})` (layer −1..1), `["rain", f]` =
   `{"type": "rain", "field": f}`, `["meteor", f]` = `{"type": "strike", "field": f}` (the meteor keeps the Gewitter
   slot). The tutorial check of `export9.py` uses model move `(0, 1, 1)` = axis 0, layer 1, turns 1 (as v8).
4. **Keep in CI**: 200 of the cases with an md5 per case in `tests/data/xcheck9_cases.json` (`test_xcheck9`), as
   with `xcheck8`.
5. **Order of the port**: kinds and `CODE` → groups/strength/supply → generic thrive → dangers one by one
   (volcano, bolt9, pack, smog9) → goals with losses → tools and mercy → points. Cross-check after each step with the
   cases of the levels that use only the ported systems (levels 1–5 first, then 6–12, …).
6. **Determinism**: the only random choice is the bolt tie-break (model LCG, as v8); everything else uses sorted field
   ids. Group labels, `supply` and the eruption order are deterministic by field id.
7. **Performance check**: `test_bonus_stress`-style: 3000 random twists on level 28 in Weiterbauen, every round
   < 30 ms on desktop (groups are recomputed once per round, cached until a kind or position changes).

---

## 17. Implementation map

| file | change |
|---|---|
| `scripts/field_data.gd` | 10 new kinds (17–26), `KIND_COUNT` 27, names/plurals/icons, `WATERS`, `LIVING`, Stein shown as „Fels“ |
| `scripts/game_state.gd` | campaign path (`camp = true` when the level config has `thrive`): groups + strength cache, generic `supply`/`satt`/`thrive` with `up`/`spawn`/`down`, `up_ok`, `rich` (double supply grows twice as fast), Vorrat (`hungry = −3` in the morning), dangers `volcano`, `bolt9` (dry forest), `pack`, `smog9` (warned), goal types `make` (made − lost, `mk` per field), `group`, `hold`, mercy, steam rain, points; clone/undo/save carry the new arrays. v8 days keep their path until removed |
| `scripts/campaign.gd` (new, replaces `days.gd` for the campaign) | the level table (section 4) as config dictionaries, pools, `carry()`, `era()`, texts of `texts9.py`, unlock over 30 levels, fast track, WdT templates |
| `scripts/daily.gd` | `next_new_level`, `level_unlocked` over 30 levels; fast track (3 per Spieltag while `level < schnell_bis`); WdT template list of section 8 |
| `scripts/shop.gd` (new) + `ui.gd` | points header chip, shop sheet (section 6), coin migration |
| `scripts/game.gd` | world save/carry (`[kampagne] welt`, `start`), Weiterbauen extras, points, mercy pill, 100-s challenge mode |
| `scripts/world.gd`, `look.gd`, `field_view.gd`, `models.gd`, shaders | era visuals (section 10), new kind models (lava cracks, soup, cells glow, algae, fish schools, moss, fern, seed rows, birds, predators), merge look for all kinds, sun face light, `×2` badge |
| `scripts/day_ui.gd` | two-sub-goal chip, step counter + star ring, `−1` cue, reveal cards and coach lines of section 4, HUD centred (section 12) |
| `data/kampagne_schoepfung.json` | the pools of section 9.7 (copy from `gdpd_sim/b4/kampagne_schoepfung_b4.json`) |
| `tests/test_rules.gd`, `tests/xcheck9.gd`, `scripts/main.gd`, `.github/workflows/gdpd.yml` | sections 14–16 |

## 18. Files (scratch) and how to re-run

Scratchpad: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/gdpd_sim/b4/`

- `engine9.py` (rules), `levels9.py` (the 30 levels, generator with the swap hill-climb), `texts9.py` (player texts),
  `bot9.py` (good/greedy/weak), `farm9.py` (pp/cyc/slice/farmer), `carry9.py` (carry-over), `run9.py`
  (`python3 run9.py gen:300 all good,greedy,weak '{}' out.json`; `chain:100`; `pool:<file>`; overrides
  `'{"27": {"cap": 1}}'`), `cont9.py` (Weiterbauen farming), `tune9.py` / `sweep9.py` (quick variant sweeps),
  `stars9.py` (star thresholds from a run), `export9.py` (pools), `xcheck9.py` (Godot cross-check cases),
  `mk_doc.py` (the tables of this spec), `final9.sh` (the whole validation pipeline).
- Results: `res_main.json/log` (good/greedy/weak, 300 boards × 30 levels), `res_farm.json/log`, `res_chain.json/log`,
  `cont.log`, `res_cap{1,2,3,9}.json/log`, `export.log`, pools `kampagne_schoepfung_b4.json`, cross-check cases
  `cases9.json`, `cases9_pool.json`.
