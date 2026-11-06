# gdpd – Regeln (Spec v1)

Working title shown to players: **gdpd**. A god game on the 3×3×3 cube, built on the engine of
`god_does_play_dice/` (that folder and its workflow are never touched; gdpd lives in `gdpd/`).

This spec is for implementers, so it is written in English. Every text a player sees is in simple German (du-form)
and is written here exactly as it should appear.

The numbers here were validated with a Python model of the engine and a bot (section 12). The model is in the
scratchpad: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/gdpd_sim/`
(`engine.py` rules, `bot.py` bot, `run.py` batch runner, `xcheck_*.py` cross-check against the original GDScript).

---

## 0. What stays exactly as in the original engine

These parts stay unchanged. The rules model reproduces the original `game_state.gd` exactly: 300 random boards ×
12 twists, 3451 turns, all identical in stages, score, hearts, misses and field positions.

- Geometry, `FieldData.p/n`, `apply_rotation`, centre fields move with middle slices, `neighbors()` (4 orthogonal
  neighbours, also across cube edges), `lines()` order, diagonals (Mittel: from tier 2, Einfach: from tier 1,
  Schwer: none).
- **The one rule players know:** 3 equal fields in a **new** row grow. `standing` / `broken` / `spent`,
  `target_index` (the field that arrived last grows, the other two stay), combo, cascades (`MAX_CASCADES = 6`),
  full face of 9 (×`FACE_BONUS`), Einfach group growth, `spent` for rows that grew together.
- Misses / fire / hearts, `last_row`, burning fields drop one step at the next round end, late merges after fire.
- Preview = `clone()` + `end_round()`, undo = `undo_state` clone, deterministic `rng` (cloned with the state).

What changes: `stage:int` becomes **`kind:int`** (an id into the kind table). Its tier, family and next kind
come from the table, not from `stage + 1`.

---

## 1. Kinds (15)

`tier` is used for ordering, faith and diagonals. `family` decides what counts as nature or civilisation, and
which fields are people.
**Finished** kinds (★) never grow, never form a row, and never make a full face. Rain/bolt/monsoon/wish growth leaves them unchanged.

| id | key | German name | icon | tier | family | 3 in a new row → | per twist (if no smog) | falls to (fire, war, Gewitter, Flut, smog) |
|---|---|---|---|---|---|---|---|---|
| 0 | `empty` | Erde | `empty` | 0 | – | never a row | regrows (see 5) | – |
| 1 | `meadow` | Wiese | `meadow` | 1 | nature | **CHOICE** Wald · Acker | – | Erde |
| 2 | `forest` | Wald | `smallforest` | 2 | nature | Großer Wald | – | Wiese |
| 3 | `field` | Acker | **`field` (new)** | 2 | food | Hütte | – | Wiese |
| 4 | `bigforest` | Großer Wald | `nature` | 3 | nature | **CHOICE** Tiere · Hütte | – | Wald |
| 5 | `animals` | Tiere | **`animals` (new; `paw` is the small fallback)** | 4 | nature | Paradies | – | Großer Wald |
| 6 | `hut` | Hütte | `hut` | 4 | people | Haus | – | Acker |
| 7 | `house` | Haus | `house` | 5 | people | Dorf | – | Hütte |
| 8 | `village` | Dorf | `village` | 6 | people | **CHOICE** Stadt · Kirche | – | Haus |
| 9 | `town` | Stadt | `town` | 7 | people | **CHOICE** Großstadt · Industrie | – | Dorf |
| 10 | `church` ★ | Kirche | `church` | 7 | faith (people) | never a row (two congregations touching = war) | **+3 Glaube** | Dorf (war: Haus) |
| 11 | `bigcity` | Großstadt | `bigcity` | 8 | people | Metropole | – | Stadt |
| 12 | `industry` ★ | Industrie | `industry` | 8 | industry | – | **+5 Glaube**; with smog: 0, and it withers 1 nature field next to it | Stadt (Gewitter/Flut: Erde) |
| 13 | `metropolis` ★ | Metropole | `metropolis` | 9 | people | – | **+2 Glaube** | Großstadt |
| 14 | `paradise` ★ | Paradies | **`paradise` (new)** | 6 | nature | – | **+1 Glaube** | Tiere |

- Option order on every card = the order in the table. The **first** option is the default.
- Sets used in the rules:
  - `NATURE = {meadow, forest, bigforest, animals, paradise}`
  - `PEOPLE = {hut, house, village, town, church, bigcity, metropolis}` (they can make wishes)
  - `FINISHED = {church, industry, metropolis, paradise}`
  - `NO_ROW = {empty} ∪ FINISHED`
- Icons we reuse: `empty meadow smallforest nature hut house village town bigcity metropolis church industry faith
  swords smog flood storm lightning rain monsoon balance star hunger heart fire`.
  **New icons:** `field` (Acker), `animals` (Tiere, a field tile; `paw` already exists and fits the wish bubble),
  `paradise` (Paradies), `wish` (speech bubble), `strike` (Gewitter tool, or reuse `storm`).
  `star` is reused for the small "fertig" badge.
- Why finished kinds never form a row: otherwise a world full of Paradies (or Metropole) keeps forming new
  finished rows forever. The model showed that with "count once per triple", nature-only play in Einfach became
  endless (100 % reached the 300-twist cap with 128k faith). Finished fields instead **pay faith every twist**
  and **use up space**. That trade-off is the core of the game.

---

## 2. Choices – "Dein Wille geschehe"

**When a choice comes up:** a field whose kind has a CHOICE grows (from a row, an Einfach group, a full face,
bolt, monsoon, a fulfilled wish, or a cascade).

**At most one card per turn.** The card is for the **first** branching growth that the turn's resolution meets.
The order is: faces, then rows in `lines()` order and cascade passes, then late merges; for bolt/monsoon, the
target order. The kind of that growth is the card kind.
- Every growth of the card kind in the same turn uses the answer, also later cascades and late merges.
- Any **other** branching kind in the same turn uses its **habit** (see below), without a card.

**Habit (`will[kind]`, stored in GameState).** It starts with option 1 for every branching kind and is set to the
last answer the player gave on a card for that kind. It is part of `clone()`, the save and undo.
- Card default (timeout or tap outside) = the habit.
- Frequency: in the model a card comes on about 2 of 3 twists (Mittel about 50 cards per 75 twists), mostly for
  Wiese. So the full card is shown only the **first 3 times per kind**.
- After that a **mini card** appears instead: a small pill above the new field with both icons. The habit is
  highlighted. It does not block, disappears after 2.0 s and takes the habit. Tapping the other icon switches.
  Long-pressing the mini pill opens the full card.
  Settings can switch this off: "Immer fragen".

**Card UI (agreed).**
- One card, two big buttons (icon + one short line).
- Tapping outside the card or waiting `CHOICE_TIMEOUT = 6.0 s` picks the default.
- Twisting is blocked only while the card is open. Everything else stays ignorable (`MOUSE_FILTER_IGNORE` on the
  scrim, not STOP; outside taps go to a full-screen `Control` that only closes the card).
- The new field appears where the row completed (target field). The player never places fields.

| card kind | title | option 1 (default) | option 2 |
|---|---|---|---|
| Wiese | Was soll hier wachsen? | **Wald** – „Wald für Tiere und frische Luft.“ | **Acker** – „Essen – dann kommen Menschen.“ |
| Großer Wald | Wer soll hier leben? | **Tiere** – „Tiere machen den Wald lebendig.“ | **Hütte** – „Die ersten Menschen ziehen ein.“ |
| Dorf | Was baut das Dorf? | **Stadt** – „Die Menschen bauen eine Stadt.“ | **Kirche** – „Viel Glaube. Aber Kirchen streiten gern.“ |
| Stadt | Wie wächst die Stadt? | **Großstadt** – „Mehr Menschen, mehr Leben.“ | **Industrie** – „Schnell viel Glaube – aber Smog.“ |

Card header for all: **„Dein Wille geschehe“** (small), then the title.

**Einfach groups.**
- The whole group takes the chosen kind (one card for the group).
- Exception (validated): if the chosen or next kind is **finished** (Kirche, Industrie, Paradies, Metropole),
  only the fields of the completing row grow, not the whole group.
  Without this, one card turned whole village blobs into a church blob, and every later twist through it started
  a war (Einfach eval bot: 12.7 wars per game → 0.15). It also filled the world in about 10 twists.
  Player text in help: „In Einfach wächst die ganze Gruppe mit. Fertige Felder entstehen aber nur in der Reihe.“

**How to implement it (no async inside `end_round`).**
- `GameState.answers: Dictionary` (kind → 0/1), `GameState.card := -1`, `GameState.card_field := -1`.
- `grown(kind) -> int` gives the next kind.
  - For a CHOICE: if `card == -1`, set `card = kind` (and `card_field`). If `kind == card` and
    `answers.has(kind)`, take `answers[kind]`, else take `will[kind]`.
- Flow in `game.gd.play_turn` (likewise `use_bonus`):
  1. `probe = state.clone(); probe.apply_rotation(...); probe.end_round({})`
  2. If `probe.card == -1`, play it as now.
  3. Otherwise, emit `choice_needed(kind, field)` and wait for the answer, with the default after the timeout.
     Then `state.end_round({kind: answer})` and set `will[kind] = answer`.
- This is deterministic because the turn up to the first branch does not depend on the answer.
- Preview while dragging (`Game.preview`): uses the habit and shows a small "?" badge on the target field when a
  card will come.

**Hint and bot.**
- `best_move()` evaluates every twist with **both** options of its card (2 clones) and keeps the better one.
  - Score = faith after the turn + 0.5 × income per twist after the turn, −60 for a heart lost, −10000 if the world
    dies, −3 for each burning field.
  - Ties go to the option that keeps the balance W (section 5) closer to 0.
- When the player follows a bought hint and the card appears, the recommended option gets the hint glow
  (`best["choice"] = 0/1`).
- Bot test (`run_bot`) does the same.
- **Undo** restores the whole state from before the turn (fields, faith, wishes, `will`, rain, timers).
  The card itself is not part of the state.

---

## 3. Faith (Glaube) – the main number

`score` **is** faith (rename `score` → `faith`, display „Glaube“ with icon `faith`). There are no separate points.

**Sources**

| source | amount |
|---|---|
| a row/group/face grows | `GROW_FAITH[tier of the kind before growing] × combo` with `GROW_FAITH = [0,2,4,7,11,16,24,35,50,75]` (same as `MERGE_POINTS`); Einfach × group size / 3; full face × 9 |
| every **twist** without smog | +3 per Kirche, +5 per Industrie, +2 per Metropole, +1 per Paradies |
| fulfilled wish | +15 (and the wishing field grows one step) |
| world complete ("Vollendet") | +10 % of faith per heart left |

**Sinks**

| sink | amount |
|---|---|
| war | −max(20, 20 % of faith) per war turn |
| Gewitter (tool) | −15 |
| Flut (tool) | −40 |

- Faith never drops below 0. A tool that costs more than you have is greyed out with the text
  „Dafür brauchst du %d Glauben.“
- Income comes only on **twists**, never on rain, tools or the tutorial auto move, so it cannot be farmed.
- Display: the top-left box shows faith (as the score box now). Gains fly in as „+12“.
  Each twist, after the merge pop, one small summed „+8“ pill shows the income from finished fields.
- `faith_earned` is the total ever earned (never reduced). It drives the monsoon refill.
- Records / leaderboard: `_best[mode] = max(_best[mode], faith at game end)` (same keys as now: einfach / mittel /
  schwer / challenge). Spending faith on a punishment lowers the final number. That is intended: the world is
  saved at a price.

---

## 4. War (Krieg)

**Congregations.**
- When a turn starts (`_remember_before`, i.e. before the first change), compute
  `congregation[field_id] = component number`.
- Components are the connected groups of Kirche fields through `neighbors()`: orthogonal, **also across cube
  edges**. Diagonals do not count.
- Two churches touch when one is in the other's `neighbors()`.

**When there is war.**
- After the twist's merges, check every adjacent pair of churches (a, b).
- It is war if both were churches at turn start and `congregation[a] != congregation[b]`.
- Only **twists** can start a war: rain, bolt, monsoon, Gewitter and Flut never move fields.
- Churches born in this turn never fight in this turn. Next turn they are part of their congregation, so a church
  that grows next to a church is peaceful.
- War is checked **once per turn**, so it cannot loop. Its changes go into the late-merge set like fire.

**Effect.**
- Every church in such a pair becomes **Haus** (two steps down: „Viele Menschen sterben.“).
- Faith −max(20, 20 % of (faith + this turn's growth faith)).
- Event `{"type":"war","fields":[ids]}`; FX: swords icon on each warring church, red flash, short shake,
  churches crumble.

**How to avoid it.**
- Keep churches apart, or let them grow next to each other (one congregation).
- The drag preview shows crossed swords over churches that would fight. The hint and bot avoid it, because their
  preview contains the faith loss.

**Model results.** Eval (hint) bot: 1.7–1.9 wars per game in Mittel/Schwer, 0.15 in Einfach. Balanced mixed bot:
0.3–0.7. Always-church: 10–32. So wars are occasional and clearly caused by your own choices.

---

## 5. Balance, smog and regrowth

**One indicator: the world scale (Weltwaage).**
- `N = Σ` nature weights: Wiese 1, Wald 2, Großer Wald 3, Tiere 3, Paradies 4.
- `C = Σ` civilisation weights: Acker 1, Hütte 1, Haus 2, Dorf 2, Stadt 3, Kirche 2, Großstadt 4, Metropole 5,
  Industrie 6.
- `W = round(100 · (C − N) / (C + N))`, or 0 if both are 0.
- W runs from −100 (only nature) to +100 (only city). It has no memory: it is computed from the board, so preview
  and undo stay simple and it recovers as soon as the board changes.

| zone | W | colour | effect |
|---|---|---|---|
| Wildnis | W ≤ −50 | red (left) | people wish for an Acker |
| Gleichgewicht | −50 < W < 20 | green | everything normal |
| Viel Stadt | 20 ≤ W < 50 | yellow | people wish for Wald, Tiere or Regen |
| Smog | W ≥ 50 | red (right) | **this twist:** no income; every Industrie withers 1 nature field next to it (the highest tier first, ties by `neighbors()` order) one step; no regrowth |

- "Withers" means one step down: Tiere → Großer Wald („Die Tiere fliehen.“), Großer Wald → Wald, Wald → Wiese,
  Wiese → Erde, Paradies → Tiere. The field is marked `fresh = 2`, which shows smoke.
- W is checked after the war step of each twist.

**Recovery.**
- Every Wald and Tier you add pulls W left, and so does Regen (it grows nature).
- Gewitter on an Industrie removes 6 from C at once.
- Flut lowers all city on one face.

**Regrowth** (new; the original had it switched off).
- Each twist without smog, **one** Erde field with ≥ 2 nature neighbours becomes Wiese.
- Most nature neighbours first, ties by lowest id; not on `fresh` fields.
- It joins the late merges (it can complete a row).
- Why: without it, worlds ran out of material and nature play died in about 25 twists. With it, Mittel survival
  doubled (bot median 28 → about 70 twists).

**Model results.**
- Always-industry/civ bot: 62–81 % of its twists in smog, about 25 % less faith than the eval bot.
- Eval/mixed bots: 0 % smog in Mittel/Schwer; Einfach eval 30 %, Einfach mixed 7 %.

---

## 6. Wishes (Wünsche)

- A **wish** is `{type, field (id), left}`.
- It is drawn as a speech bubble anchored to that field id, so it rides along with every twist.
  It shows the wish icon and a small ring with the twists left.
- At most **2** wishes at a time.

**Making wishes.**
- Only on twists, and only when `twists ≥ 3` and `twists % 4 == 0`.
- Candidate fields are PEOPLE fields without a wish.
- Type by W:
  - W ≥ 20: Wald 3 : Tiere 2 : Regen 1
  - W ≤ −50: Acker only
  - otherwise: Wald 2 : Acker 2 : Tiere 1 : Regen 1
- A type is only possible if its target exists somewhere on the cube (for Regen: `rain > 0`).
- The field is drawn from the candidates where the wish is not already fulfilled, with the state `rng`
  (cloned, so preview matches).

| type | icon | fulfilled when (checked after every twist; Regen when you use rain) | bubble text (long-press) |
|---|---|---|---|
| Wald | `smallforest` | a Wald or Großer Wald is one of the field's 4 neighbours | „Wir wünschen uns einen Wald neben uns.“ |
| Tiere | `paw` | Tiere or Paradies next to it | „Wir möchten Tiere sehen.“ |
| Acker | `field` | an Acker next to it | „Wir haben Hunger. Bring uns einen Acker.“ |
| Regen | `rain` | rain is used on any field of the same face | „Es ist so trocken. Lass es bei uns regnen.“ |

**Results.**
- Fulfilled: +15 faith, and the wishing field **grows one step** (choice rules apply), with a heart burst FX.
- Missed: after **8** twists the bubble pops quietly. Nothing else happens (soft).
- If the field stops being PEOPLE (war, Flut, Gewitter), the wish disappears.
- `wishes` is part of `clone()` (a deep copy), the save and undo.
- Model results: eval/mixed bots fulfil 75–87 %, civ-heavy bots 38–44 %, with 8–16 wishes per game.

---

## 7. God tools (dock: at most 5)

| tool | icon | type | target | effect | how you get it |
|---|---|---|---|---|---|
| **Regen** | `rain` | blessing, **not a turn** (as now, `resolve_now`) | an Erde/Wiese/Wald field or a burning field | burning: put out only. Otherwise Erde→Wiese, Wiese→Wald (never a card), Wald→Großer Wald. Fulfils Regen wishes on that face | start 1; +1 **every 5 twists**; max 3; gift when stuck (as now); 2 coins when empty |
| **Blitz** | `lightning` | blessing, turn | corner field | the corner diagonal of that face grows one step each (cards as in 2) | 3 equal growable fields at a cube corner (as now), max 2; 3 coins |
| **Monsun** | `monsoon` | blessing, turn | a face | all 9 grow one step (finished stay) | first Haus, then +1 every 150 earned faith, max 1; 5 coins |
| **Gewitter** | `storm` | punishment, turn | any non-empty field | Industrie → Erde (smoking, no regrowth for 2 twists); anything else falls one step | costs **15 Glaube**; appears with the first finished field |
| **Flut** | `flood` | punishment, turn | a face | every Acker/people/Kirche/Industrie field on the face falls one step (Industrie → Erde); nature stays; fires go out | costs **40 Glaube**; appears with the first smog |

- Tool turns (Blitz, Monsun, Gewitter, Flut) use `end_round()` without `_rotated`: no income, no miss, no war, no
  wish timers. This is the same as the bonuses now.
- Rain milestones are counted in twists, not faith. With faith thresholds, high-income worlds had endless rain
  and survived about 4× longer than nature worlds, only because of income.
- Gewitter is also the way to free a world clogged with finished fields („Platz machen“). In the model the eval bot
  used it 1–2 times per game.

---

## 8. Fire, hearts, win and modes

- **Misses and fire:** as now. A miss is a twist where nothing grew, late merges included. Income, wishes and war
  do not count as growth. Every 3rd miss sets the last swiped row on fire and costs 1 heart. At the next round end,
  burning fields fall one step (the „falls to“ column).
- **Hearts:** Einfach **5** (the model needs this: Einfach worlds fill fastest), Mittel 3, Schwer 3, Challenge 3.
- **Lose:** no hearts left → „Deine Welt ist verbrannt.“
- **Win (new): „Vollendet!“** (endless modes only).
  - Condition, checked at round end: the number of finished fields (Kirche, Industrie, Metropole, Paradies) is at
    least **36 (Einfach) / 22 (Mittel) / 22 (Schwer)**, **and** the world scale is not red (−50 < W < 50).
  - Bonus +10 % faith per heart left, end screen „Deine Welt ist vollendet!“.
  - A world full of only paradise (W = −100) or only city never counts as complete, so the balance is the goal.
  - HUD chip after the first finished field: `star` + „12/22“.
- **Modes:**
  - Einfach: groups, diagonals from tier 1, 5 hearts.
  - Mittel: rows + diagonals from tier 2.
  - Schwer: straight rows only.
  - **40-Drehungen-Challenge:** Mittel rules, ends after 40 twists, no win check, highest faith. The bot never died
    within 40 twists; it is a score race.
- Continue after game over (2 coins): as now (1 heart back, or rain if stuck).

---

## 9. Ages (Zeitalter)

The age follows the most advanced civilisation kind **ever built** (`best_age`, same idea as `best_stage`).
Nature kinds never change the age.

| age | reached with | next goal text („Als Nächstes: …“) |
|---|---|---|
| Urzeit | start | „Steinzeit – leg einen Acker an oder bau eine Hütte.“ |
| Steinzeit | first Acker or Hütte | „Antike – bau ein Haus.“ |
| Antike | Haus (unlocks Monsun) | „Mittelalter – bau ein Dorf.“ |
| Mittelalter | Dorf | „Neuzeit – bau eine Stadt oder eine Kirche.“ |
| Neuzeit | Stadt or Kirche | „Industriezeitalter – bau eine Großstadt oder Industrie.“ |
| Industriezeitalter | Großstadt or Industrie | „Moderne – bau eine Metropole.“ |
| Moderne | Metropole | „Vollende deine Welt!“ |

---

## 10. Tutorial and progressive reveal

**Tutorial.** It uses the existing tutorial board: two meadow pairs on top, the third meadow arrives with the
x = 1 slice. `no_fire` stays on, the card has no timeout, and there is no income.
1. Auto move: the row completes, then the card opens with a pointing hand.
   Coach: „Drei gleiche in einer Reihe wachsen. Du bestimmst, was daraus wird!“
   The player taps one option.
2. „Jetzt du! Wisch über die leuchtende Reihe.“ The player twists, and the card comes again (free choice).
   Coach after the answer: „Gut so! Du bist der Gott dieser Welt.“
3. `fill_after_tutorial()` as now → free play.

**Progressive reveal.**
- Each new thing appears only when it first matters, with one coach line, once.
- Coach lines are non-blocking and queued like `COACH` now; at most one per twist.

| trigger | what appears | coach (German) |
|---|---|---|
| start | Glaube, hearts, Regen | (as now: Regen hint) |
| first Acker or Hütte | world scale under the HUD | „Das ist deine Weltwaage: links Natur, rechts Stadt. Halte sie im Grünen.“ |
| first wish | speech bubble | „Die Menschen haben einen Wunsch! Erfüll ihn in 8 Drehungen – das bringt Glauben.“ |
| first Kirche | – | „Eine Kirche bringt jede Runde Glauben. Aber bring nie zwei Kirchen zusammen!“ |
| first war | swords FX | „Krieg! Zwei Kirchen haben sich getroffen. Halte sie auseinander.“ |
| first finished field | star badge, Gewitter in dock, „Vollendet“ chip | „Fertig! Dieses Feld wächst nicht mehr, bringt aber Glauben. Mit Gewitter machst du wieder Platz.“ |
| first Industrie | – | „Industrie bringt viel Glauben – aber zu viel macht Smog.“ |
| first smog | red scale, Flut in dock | „Smog! Wälder welken, Tiere fliehen. Pflanz Wald oder strafe die Industrie.“ |
| 10 twists with W ≤ −80 and no PEOPLE | – | „Ohne Menschen glaubt niemand an dich. Wähl auch mal Acker oder Hütte.“ |
| first mini card | mini pill | „Du hast dich entschieden. Das gilt jetzt, bis du es änderst – tipp zum Wechseln.“ |

---

## 11. Long-press texts (German)

Everything new is explained by long-press (`_tap_or_explain` / `_explain_only`).

| element | text |
|---|---|
| Glaube (score box) | „Glaube. Du bekommst ihn, wenn etwas wächst, für erfüllte Wünsche und jede Runde von fertigen Feldern. Wunder und Strafen kosten Glauben.“ |
| Weltwaage | „Die Weltwaage. Links Natur, rechts Stadt. Grün ist gut. Ganz rechts kommt Smog, ganz links fehlt den Menschen Essen.“ |
| Wahl-Karte | „Dein Wille geschehe: Du entscheidest, was hier wächst. Tippst du daneben, gilt deine letzte Wahl.“ |
| Mini-Wahl | „Deine letzte Wahl gilt. Tipp auf das andere Bild, um zu wechseln.“ |
| Wiese | „Wiese. Drei in einer Reihe: Wald oder Acker – du wählst.“ |
| Wald | „Wald. Drei in einer Reihe werden ein großer Wald.“ |
| Acker | „Acker. Essen für Menschen. Drei in einer Reihe: eine Hütte.“ |
| Großer Wald | „Großer Wald. Drei in einer Reihe: Tiere oder eine Hütte.“ |
| Tiere | „Tiere. Drei in einer Reihe: ein Paradies.“ |
| Paradies | „Paradies. Fertig – wächst nicht mehr. Bringt jede Runde 1 Glauben.“ |
| Hütte / Haus | „Hier wohnen Menschen. Drei in einer Reihe wachsen weiter.“ |
| Dorf | „Dorf. Drei in einer Reihe: Stadt oder Kirche.“ |
| Stadt | „Stadt. Drei in einer Reihe: Großstadt oder Industrie.“ |
| Kirche | „Kirche. Fertig. Bringt jede Runde 3 Glauben. Treffen sich zwei Kirchen durch eine Drehung, gibt es Krieg.“ |
| Industrie | „Industrie. Fertig. Bringt jede Runde 5 Glauben – aber sie macht die Welt schmutzig.“ |
| Großstadt | „Großstadt. Drei in einer Reihe: eine Metropole.“ |
| Metropole | „Metropole. Fertig. Bringt jede Runde 2 Glauben.“ |
| Stern (fertig) | „Fertig: Dieses Feld wächst nicht mehr und bildet keine Reihe.“ |
| Wunsch-Blase | type text from section 6 + „Noch %d Drehungen.“ |
| Krieg (Schwerter) | „Krieg: Zwei Kirchen haben sich getroffen. Viele Menschen sterben, du verlierst Glauben.“ |
| Smog | „Smog: Zu viel Stadt. Industrie lässt Wälder welken und Tiere fliehen. Es gibt keinen Glauben pro Runde.“ |
| Regen | „Regen lässt Natur wachsen: Erde wird Wiese, Wiese wird Wald, Wald wird großer Wald. Er löscht auch Feuer.“ |
| Blitz | „Blitz: Die Schräge an einer Ecke wächst. Du bekommst ihn, wenn sich an einer Ecke 3 gleiche treffen.“ |
| Monsun | „Monsun: Eine ganze Seite wächst.“ |
| Gewitter | „Gewitter: Du strafst ein Feld. Industrie wird zu Erde, alles andere schrumpft. Kostet 15 Glauben.“ |
| Flut | „Flut: Eine Seite wird reingewaschen. Städte und Industrie schrumpfen, die Natur bleibt. Kostet 40 Glauben.“ |
| Vollendet-Chip | „Vollende deine Welt: %d fertige Felder – und die Waage nicht im Roten.“ |
| Zeitalter | (as now, texts from section 9) |

---

## 12. Test plan and validated metrics

### 12.1 Rule tests (`gdpd/tests/test_rules.gd`, must end with „0 Fehler“)

1. **Kind table:** every non-finished kind has a next kind; CHOICE kinds are exactly Wiese, Großer Wald, Dorf
   and Stadt; every `falls to` stays in range; finished kinds are `NO_ROW`.
2. **Choice:** a meadow row with `answers {Wiese:1}` makes Acker at the target field, with `{}` the habit
   (Wald at first). The other two fields stay Wiese.
3. **One card per turn:** a turn with a meadow row and a town row at once (built board) gives `card` = the first
   one in `lines()` order. The second one uses its habit.
4. **Card discovery is deterministic:** `probe.card` equals the card of the real `end_round(answers)` for 200
   random boards × 27 twists.
5. **Einfach:** a meadow group of 5 + row → all 5 become the chosen kind. A village group of 5 + row with
   Kirche → only the 3 row fields become Kirche.
6. **Finished never form a row:** 3 Paradies / Industrie / Metropole / Kirche in a new row → no growth, it counts
   as a miss, no face bonus.
7. **War:**
   - Two separate churches brought together by a twist → both Haus, faith −max(20, 20 %), event `war`.
   - Two adjacent churches moved together in one slice → no war.
   - A church that grew next to a church → no war, then or later while they stay connected.
   - Rain, bolt, monsoon and tools never cause war.
   - Exhaustive check: every new church contact made by one twist on a 2-church board starts a war. In the model:
     all 432 cases did.
8. **Balance:** W for constructed boards (all nature → −100, 10 industry + 1 big forest → 90).
   Smog at W ≥ 50: no income, each industry withers its highest-tier nature neighbour, no regrowth.
9. **Regrowth:** exactly one Erde with ≥ 2 nature neighbours becomes Wiese per twist. Not with smog, not on
   `fresh` fields, never on rain/tool turns.
10. **Income:** only on twists; Kirche 3, Industrie 5, Metropole 2, Paradies 1; 0 with smog.
11. **Wishes:**
    - They are made only on twist 4, 8, …, max 2, only for PEOPLE fields, only with a reachable target.
    - Fulfilment by adjacency after a twist gives +15 and growth; Regen fulfilment works on the same face.
    - Timeout after 8 twists.
    - A wish rides with its field through a twist (same field id, new position).
    - `clone()` copies wishes deeply: changing the clone does not change the original.
12. **Tools:**
    - Regen targets and results (Wiese → Wald without a card); not a turn.
    - Gewitter: Industrie → Erde, others one step down, −15. Flut: face rule, −40. Greyed out without faith.
    - Rain +1 every 5 twists, max 3.
13. **Win:** 22 finished fields with W in (−50, 50) → `completed`, bonus +10 % per heart. With W = −100 → not
    completed.
14. **Preview = real turn:** for random states, `Game.preview(...)` faith/kinds equal the real `play_turn` with the
    same answer, including wishes and the rng.
15. **Undo:** after a turn with a card, war and a wish, undo restores kinds, faith, wishes, `will`, rain and hearts
    exactly.
16. **Ages:** table in section 9.
17. **Hint:** on a board where only option 2 makes a second row next turn, `best_move()` returns
    `choice = 1` (for the first card).
18. **Bot smoke test (print, not assert):** run_bot with seeds 11, 22, 33 for Mittel. Print twists, faith, wars,
    smog twists, wishes ok/missed, kinds reached. Assert only: no SCRIPT ERROR, faith ≥ 0, and a passive bot gains
    no faith.

### 12.2 Bot used for validation

- Greedy "hint" bot. Each turn it previews all 27 twists (+ bolt, monsoon, and punishments when W ≥ 40).
  - If nothing grows: the 2-step search of `best_move`.
  - If even that finds nothing: Gewitter on the field that makes a row possible again.
  - It rains for rows, fires, or pairs when it holds 2+ rain.
- Choice strategies:
  - `eval`: previews both options, like the hint.
  - `nature`: always option 1, the default/timeout player.
  - `civ`: always option 2 (Acker, Hütte, Kirche, Industrie).
  - `mixed`: balance-aware.
  - `random`.
- 200 games per mode and strategy (4000 games). Endless games are capped at 300 twists.
- Two differences from this spec, neither of which changes the rules:
  - In the model, a second branching kind in the same turn takes option 1 instead of the habit. For the fixed
    strategies that is the same thing.
  - The mini card is UI only.
- Reference: the same bot on the **original** ladder rules in the same model runs to the 300 cap in Einfach and
  Mittel (median 300; the endgame there is endless because metropolis rows always count). Schwer median: 31.

### 12.3 Final metrics (constants as in this spec)

Columns:
- twists: median (p10–p90), cap = share of games that hit the 300-twist cap
- won = Vollendet
- faith: median at game end
- war games = share of games with at least one war
- smog: share of twists in smog
- wish: share of wishes fulfilled

| mode | strategy | twists median (p10–p90) | cap | won | faith (median) | faith/twist | wars/game | war games | smog | wish | wishes/game | Gewitter/game |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Einfach | eval | 38 (28–46) | 0 % | **65 %** | 2839 | 82 | 0.15 | 13 % | 30 % | 78 % | 7.6 | 1.9 |
| Einfach | nature | 47 (43–51) | 0 % | 0 % | 1860 | 41 | 0 | 0 % | 0 % | – | 0 | 3.6 |
| Einfach | civ | 69 (44–206) | 5 % | 20 % | 1121 | 85 | 32.1 | 100 % | 81 % | 38 % | 23.2 | 2.7 |
| Einfach | mixed | 39 (31–45) | 0 % | **69 %** | 2694 | 79 | 0.74 | 58 % | 7 % | 75 % | 8.9 | 1.2 |
| Einfach | random | 41 (31–49) | 0 % | 63 % | 2689 | 73 | 0.36 | 27 % | 19 % | 74 % | 8.6 | 1.7 |
| Mittel | eval | 74 (52–100) | 0 % | **28 %** | 1685 | 31 | 1.71 | 61 % | 0 % | 75 % | 16.0 | 1.2 |
| Mittel | nature | 71 (54–87) | 1 % | 0 % | 1595 | 22 | 0 | 0 % | 0 % | – | 0 | 6.2 |
| Mittel | civ | 84 (58–214) | 5 % | 16 % | 1316 | 35 | 9.8 | 80 % | 65 % | 44 % | 24.4 | 3.3 |
| Mittel | mixed | 62 (49–77) | 0 % | 4 % | 1498 | 26 | 0.34 | 26 % | 0 % | 79 % | 14.2 | 0.4 |
| Mittel | random | 64 (48–80) | 0 % | 2 % | 1212 | 21 | 0.35 | 26 % | 0 % | 78 % | 13.3 | 0.4 |
| Schwer | eval | 73 (48–103) | 0 % | **22 %** | 1368 | 25 | 1.91 | 62 % | 0 % | 75 % | 15.9 | 1.4 |
| Schwer | nature | 70 (50–87) | 0 % | 0 % | 1152 | 17 | 0 | 0 % | 0 % | – | 0 | 2.4 |
| Schwer | civ | 86 (52–300) | 10 % | 13 % | 1012 | 28 | 11.3 | 74 % | 69 % | 40 % | 25.6 | 2.8 |
| Schwer | mixed | 59 (44–77) | 0 % | 0 % | 984 | 19 | 0.47 | 38 % | 0 % | 83 % | 12.9 | 0.4 |
| Schwer | random | 61 (45–77) | 0 % | 0 % | 900 | 16 | 0.23 | 18 % | 0 % | 81 % | 12.2 | 0.5 |
| Challenge 40 | eval | 40 | – | – | 780 | 21 | 0.01 | 1 % | 0 % | 85 % | 7.7 | 0.2 |
| Challenge 40 | nature | 40 | – | – | 762 | 19 | 0 | 0 % | 0 % | – | 0 | 0 |
| Challenge 40 | civ | 40 | – | – | **1014** | 26 | 0.02 | 2 % | 35 % | 67 % | 7.1 | 0.3 |
| Challenge 40 | mixed | 40 | – | – | 828 | 22 | 0.04 | 4 % | 0 % | 87 % | 8.9 | 0.1 |
| Challenge 40 | random | 40 | – | – | 626 | 17 | 0.03 | 2 % | 0 % | 86 % | 7.6 | 0.2 |

**Branches reached** (share of games in which the kind was ever built):

| mode | strategy | Acker | Tiere | Hütte | Dorf | Stadt | Kirche | Großstadt | Industrie | Metropole | Paradies |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Einfach | eval | 89 | 88 | 100 | 98 | 98 | 66 | 95 | 34 | 96 | 83 |
| Einfach | random | 96 | 96 | 100 | 100 | 100 | 84 | 96 | 65 | 96 | 93 |
| Mittel | eval | 98 | 90 | 100 | 100 | 90 | 100 | 41 | 76 | 32 | 82 |
| Mittel | random | 100 | 100 | 100 | 100 | 93 | 94 | 46 | 64 | 30 | 92 |
| Schwer | eval | 100 | 84 | 100 | 99 | 82 | 96 | 40 | 65 | 32 | 69 |
| Schwer | random | 100 | 97 | 100 | 99 | 86 | 88 | 32 | 44 | 18 | 82 |
| Challenge 40 | random | 100 | 92 | 100 | 98 | 56 | 50 | 8 | 10 | 2 | 57 |

**Reading.**
- **Neither trivial nor hopeless.**
  - The best bot completes the world in 65 % (Einfach), 28 % (Mittel) and 22 % (Schwer) of games.
  - The default-only player (never answers a card) never wins: the world fills with paradise but has no people.
  - Nobody hits the 300-twist cap except some civ games.
  - The bot is weaker than a human with hints, so human win rates will be higher.
- **Choices matter.** The eval bot earns the most faith in endless modes. Always-civ survives longer but earns
  20–60 % less, because of wars and smog. In the 40-twist challenge, aggressive civ play earns the most:
  a high-risk score race, which fits a short mode.
- **Wars:** occasional for good play (about 1 in 40 twists), avoidable (mixed 0.3–0.7 per game), heavy only when
  you always build churches.
- **Pollution:** decisive for industry-heavy play (65–81 % of twists in smog); almost absent for balanced play.
- **Wishes:** fulfilled 75–87 % with sensible play; 38–44 % when the world is all city.
- **All branches** are reached (random bot: every kind in ≥ 18 % of Mittel/Schwer games).

### 12.4 Metric targets for the GDScript bot test

These are checks on the printed bot stats, not CI asserts. Use 20 seeds, eval strategy, in Mittel:
- median twists 50–110
- won 15–40 %
- wars per game 0.5–3
- smog share < 10 %
- wish fulfilment 60–90 %
- Hütte, Kirche and Paradies each reached in ≥ 60 % of games

If a GDScript change moves these out of range, compare with `run.py` before tuning.

---

## 13. Balance constants (put into `gdpd/scripts/balance.gd`)

```
GROW_FAITH = [0, 2, 4, 7, 11, 16, 24, 35, 50, 75]   # by tier, x combo
FACE_BONUS = 9;  MAX_CASCADES = 6;  OTHERS_DROP = 0
DIAGONAL_FROM_TIER = 2 (Einfach 1, Schwer off)
LIVES = 3;  LIVES_EASY = 5;  FIRE_AFTER = 3
START_MEADOW = 0.5;  START_NATURE = 0.40
INCOME = {church: 3, industry: 5, metropolis: 2, paradise: 1}        # per twist, 0 with smog
NATURE_WEIGHT = {meadow: 1, forest: 2, bigforest: 3, animals: 3, paradise: 4}
CIV_WEIGHT = {field: 1, hut: 1, house: 2, village: 2, town: 3, church: 2, bigcity: 4, metropolis: 5, industry: 6}
WILD_AT = -50;  CITY_AT = 20;  SMOG_AT = 50
REGROW_PER_TWIST = 1;  REGROW_NEIGHBORS = 2
WAR_FAITH_MIN = 20;  WAR_FAITH_PCT = 20;  WAR_DROP = house
WISH_EVERY = 4;  WISH_FROM_TWIST = 3;  WISH_MAX = 2;  WISH_TWISTS = 8;  WISH_FAITH = 15
RAIN_START = 1;  RAIN_EVERY_TWISTS = 5;  RAIN_MAX = 3
BOLT_MAX = 2;  MONSOON_EVERY_FAITH = 150 (earned);  MONSOON_MAX = 1
STRIKE_COST = 15;  FLOOD_COST = 40          # faith
RAIN_COST = 2;  BOLT_COST = 3;  MONSOON_COST = 5   # coins, as now
COMPLETE_AT = [36, 22, 22];  COMPLETE_BONUS_PCT_PER_HEART = 10   # needs WILD_AT < W < SMOG_AT
CHOICE_TIMEOUT = 6.0;  CHOICE_FULL_CARDS = 3;  MINI_CARD_SECONDS = 2.0
MAX_TWISTS = 40
```

### Round order (`end_round`, twist turn)

Bold steps are new.

1. Faces, then rows (with cascades and the card).
2. **War.**
3. **Smog** (W ≥ 50: wither).
4. **Regrowth** (not with smog).
5. `fresh` −1.
6. Burning fields fall.
7. **Wishes:** check, grow or expire.
8. Late merges of everything changed in steps 2–7.
9. **Income.**
10. Faith, milestones, bolts.
11. `twists += 1`; **rain every 5 twists**.
12. Miss / fire.
13. **Make a wish.**
14. `broken`.
15. **Completion check.**
16. (`game.gd`) gift when stuck.

Tool turns run steps 1, 5, 6, 8, 10, 12 (never a miss), 14 and 15.
