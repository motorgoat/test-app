# gdpd – Die Schöpfung in 7 Tagen (Level- und Baum-Spec v1)

This spec is for implementers, so it is written in English. Every text a player sees is in simple German (du-form)
and is written here exactly as it should appear.

It builds on `GDPD_REGELN.md` (v1.1, "the rules"). Everything not changed here stays as it is there: geometry, the
one rule (3 equal fields in a **new** row grow), `standing`/`broken`/`spent`, target field, cascades, faces, choice
card and mini pill, wishes, war, Weltwaage, smog, tools, faith.

**Why.** Player feedback: life has to come first (an Acker as the very first choice makes no sense), and nobody knew
what to do or what the goal was. Answer: a campaign of 7 days. Each day has **one** clear task that is always on
screen, a limited number of twists, 1–3 stars, and exactly **one** new thing. Day 1 is the tutorial. After day 7 the
world is complete and free play opens.

Validated with the Python model (section 8). Board pools and replayable solutions: `gdpd/docs/gdpd_7_tage_boards.json`.

---

## 0. Summary of the changes

| area | v1.1 | 7 days |
|---|---|---|
| first growth | Wiese → **choice** Wald · Acker | Erde → Wiese → Wald → Großer Wald → Tiere → Hütte → Haus → Dorf (no choice before day 5) |
| Erde | never forms a row | **3 Erde in a new row → Wiese** |
| background | Erde | new kind **Wasser** (never forms a row, never changes) |
| Großer Wald | choice Tiere · Hütte | → Tiere (no choice) |
| Tiere | → Paradies | → **Hütte** (free play: choice Hütte · Paradies) |
| goal | endless, „Vollendet“ | per day: one goal, twist limit, stars; free play keeps „Vollendet“ |
| unlocked kinds | all | per day; a kind whose next kind is still locked **rests** (forms no row) |
| boards | random generator | validated pools (20 per day), sticker-type aware |
| hearts | 3 / 5 | **none in the 7 days** (fire still burns); free play as before |
| hint | costs a credit | **free in the 7 days** (product decision, see 4.6) |

---

## 1. The kind tree

### 1.1 Kind table (replaces the table in GDPD_REGELN §1)

Ids 0–14 stay the same (saves, tests and art keep working). Wasser is appended as id 15.

| id | key | name | icon | tier | family | 3 in a new row → | choice (option 2) and from when | falls to |
|---|---|---|---|---|---|---|---|---|
| 0 | `empty` | Erde | `empty` | 0 | land | **Wiese** | – | Erde |
| 1 | `meadow` | Wiese | `meadow` | 1 | nature | Wald | **Acker**, from day 5 | Erde |
| 2 | `forest` | Wald | `smallforest` | 2 | nature | Großer Wald | – | Wiese |
| 3 | `field` | Acker | `field` | 2 | food | Hütte | – | Wiese |
| 4 | `bigforest` | Großer Wald | `nature` | 3 | nature | **Tiere** | – (was a choice) | Wald |
| 5 | `animals` | Tiere | `animals` | 4 | nature | **Hütte** | **Paradies**, free play only | Großer Wald |
| 6 | `hut` | Hütte | `hut` | 5 | people | Haus | – | **Tiere** |
| 7 | `house` | Haus | `house` | 6 | people | Dorf | – | Hütte |
| 8 | `village` | Dorf | `village` | 7 | people | Stadt | **Kirche**, from day 6 | Haus |
| 9 | `town` | Stadt | `town` | 8 | people | Großstadt | **Industrie**, from day 7 | Dorf |
| 10 | `church` ★ | Kirche | `church` | 8 | faith | – | – | Dorf (war: Haus) |
| 11 | `bigcity` | Großstadt | `bigcity` | 9 | people | Metropole | – | Stadt |
| 12 | `industry` ★ | Industrie | `industry` | 9 | industry | – | – | Stadt (Gewitter/Flut: Erde) |
| 13 | `metropolis` ★ | Metropole | `metropolis` | 10 | people | – | – | Großstadt |
| 14 | `paradise` ★ | Paradies | `paradise` | 5 | nature | – | – | Tiere |
| 15 | `water` | Wasser | **`water` (new)** | 0 | none | never a row | – | Wasser |

- The first option of a choice is always the default way. Before the choice is unlocked, the branch simply goes the
  default way and no card appears (`next_kind(k, 0)`).
- `FieldData.CHOICE` becomes `{MEADOW: [FOREST, FIELD], VILLAGE: [TOWN, CHURCH], TOWN: [BIGCITY, INDUSTRY],
  ANIMALS: [HUT, PARADISE]}` and the game state decides which of them are active (section 2.1, `choices`).
- `NEXT = [MEADOW, FOREST, BIGFOREST, HUT, ANIMALS, HUT, HOUSE, VILLAGE, TOWN, BIGCITY, -1, METROPOLIS, -1, -1, -1, -1]`
  (default way of each kind; -1 = finished or Wasser).
- `DOWN = [EMPTY, EMPTY, MEADOW, MEADOW, FOREST, BIGFOREST, ANIMALS, HUT, HOUSE, VILLAGE, VILLAGE, TOWN, TOWN,
  BIGCITY, ANIMALS, WATER]`. A burning Erde stays Erde. Fire never sets Erde or Wasser on fire.
- `TIER = [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 5, 0]`, so `GROW_FAITH` needs an 11th entry:
  `GROW_FAITH = [0, 2, 4, 7, 11, 16, 24, 35, 50, 75, 100]`.
- `AGE_OF = [0, 0, 0, 1, 0, 0, 1, 2, 3, 4, 4, 5, 5, 6, 0, 0]` (unchanged meaning; only used in free play).
- Sets: `NATURE = {Wiese, Wald, Großer Wald, Tiere, Paradies}`; `PEOPLE` and `FINISHED` unchanged. Erde and Wasser are
  neither nature nor civilisation (weight 0 on the Weltwaage).
- Regen: Erde → Wiese → Wald → Großer Wald as now, but only if the result is unlocked today. Never on Wasser.
- Gewitter/Flut never touch Wasser.

**Why this order.** Land → plants → animals → people → food/faith/industry. Nothing can be chosen before people exist.
Acker → Hütte stays (food brings people). Tiere → Hütte keeps the one-rule promise: three Tiere in a row bring
people – there are no mixed recipes.

**Paradies (Naturwunder).** It leaves the life chain. In the 7 days it never appears. In free play it is the second
option of a Tiere card (a finished nature field, +1 Glaube per twist). That keeps a green finished kind for the
„Vollendet“ balance. Card: header „Dein Wille geschehe“, title „Was wird aus den Tieren?“, option 1 **Hütte** –
„Menschen ziehen zu den Tieren.“, option 2 **Paradies** – „Ein Naturwunder. Wächst nicht mehr, bringt Glauben.“

### 1.2 The rule "rests today"

`GameState.can_row(k)` (instance method; replaces the static `FieldData.can_row` in all rule code) is true when
`k` is not Wasser, not finished, and its default next kind is **unlocked** in the current day. So on day 1 three
Wiesen in a row do nothing, on day 3 three Tiere do nothing, and so on. The goals are built so that this is never
needed, and it keeps each day to exactly one new thing. Long-press on such a field adds „Morgen wächst hier mehr.“
The same check is used by `lines()`, `resolve_faces()`, `touched_corners()`, `stuck()` and the hint.

### 1.3 Sticker types (cube physics, important for boards)

A straight row on a face is always **corner–edge–corner** or **edge–centre–edge** (a diagonal is
corner–centre–corner). Twists never change the type of a sticker (24 corners, 24 edges, 6 centres). A kind that sits
only on edge stickers can never form a straight row.

The model showed this is real: on day 4 boards with random placement the hint bot often had 10–14 Tiere and still
could not make a single row (all on edges), and lost 8 % of the days. With type-aware placement (about half of each
kind on corners, 40 % on edges, 10 % on centres) it won 100 %. Therefore:

- All shipped boards are placed by sticker type (pools in section 6).
- Recommendation for free play: use the same placement (section 3.2).

Texts and tests below call a field's type `TYPE[id]` (3 corner, 2 edge, 1 centre = number of non-zero coordinates
of `p`).

### 1.4 Texts (German) – changes to `KIND_HELP`

| kind | text |
|---|---|
| Erde | „Erde. Drei in einer Reihe werden eine Wiese.“ |
| Wiese | before day 5: „Wiese. Drei in einer Reihe werden ein Wald.“; from day 5: „Wiese. Drei in einer Reihe: Wald oder Acker – du wählst.“ |
| Wald | „Wald. Drei in einer Reihe werden ein großer Wald.“ |
| Großer Wald | „Großer Wald. Drei in einer Reihe bringen Tiere.“ |
| Tiere | „Tiere. Drei in einer Reihe: Menschen ziehen ein – eine Hütte.“ (free play: „… eine Hütte oder ein Paradies.“) |
| Acker | „Acker. Essen für Menschen. Drei in einer Reihe: eine Hütte.“ |
| Wasser | „Wasser. Hier wächst nichts.“ |
| any resting kind (1.2) | its text + „Morgen wächst hier mehr.“ |

The Wiese card (day 5 on): title „Was soll hier wachsen?“, **Wald** – „Für Tiere und frische Luft.“, **Acker** –
„Essen für die Menschen.“

---

## 2. The 7 days

### 2.1 Day config (one dictionary per day; `Days.DAYS[n]`)

| field | meaning |
|---|---|
| `unlocked` | kinds that may be created today (everything else rests, see 1.2) |
| `choices` | kinds whose card is active (others go the default way) |
| `goal` | `["make", [kinds], N]` · `["wishes", N]` · `["faith", N]` · `["faith", N, "green"]` |
| `limit` | twists for the day (before mercy, 4.5) |
| `stars` | `[a, b]`: ★★★ if solved in ≤ a twists, ★★ if ≤ b, else ★ |
| `rain_start`, `rain_every` | Regen at start, +1 every so many twists (max 3); gift when stuck: on from day 2 |
| `fire` | misses burn the last swiped row (`FIRE_AFTER = 3`), **no heart is lost** |
| `wishes`, `wish_types`, `wish_from`, `wish_every` | wishes on/off, allowed types, first at twist `wish_from`, then every `wish_every` twists (max 2 open, 8 twists to fulfil, as v1.1) |
| `scale` | Weltwaage used for wish types (and visible) |
| `scale_visible` | Weltwaage chip shown in the HUD (default = `scale`); off on days 5–6, so the Waage is new only on day 7 |
| `income`, `war`, `no_war`, `smog`, `strike` | systems on/off; `no_war`: a war fails the day |
| — always off in days | hearts, diagonals, Einfach groups, regrowth, Blitz, Monsun, Flut, ages, „Vollendet“ |

Common rules for all days:
- **Lines:** straight rows only (no diagonals, no Einfach groups). That is the simplest picture for beginners
  („drei in einer Reihe“), and the sticker rule (1.3) keeps it solvable.
- **Faith** starts at 0 every day. It is counted from day 1 (wishes give +15 as always), but shown only from day 6.
- **Goal check:** after every `end_round()` and after every rain (`resolve_now`). The day is won the moment the goal
  is met, also on the last twist.
- **Fail:** twists used = `limit` (+ mercy) and the goal is not met; day 6 also on any war.
- **No hearts in the days.** Misses still count (flame chip) and the 3rd miss still burns the swiped row (it falls one
  step). That is the lesson „dreh nicht blind“. Rationale from the model: with the twist limits below, hearts only
  removed weak players earlier (fire was the fail reason in 80–100 % of weak-bot fails on days 3–7) while never
  mattering for good play; one fail condition is clearer.

**Counting rule `made[kind]`.** Every time a field **changes to** a kind by growth, `made[kind] += 1`. Growth means:
a row, a face, a cascade, Regen, a fulfilled wish (and Blitz/Monsun in free play). Not counted: falls (fire, war,
smog, Gewitter, Flut), regrowth, the start board. A field that grows twice in one turn (cascade) counts for both
kinds. `made` is part of `clone()`, undo and the save. It never goes down, so the goal chip never goes backwards.

### 2.2 Day table

| day | title | goal (chip) | counting | limit | ★★★ ≤ | ★★ ≤ | new thing | unlocked (new) | choices |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Land | Lass 8 Wiesen wachsen | `made[Wiese] ≥ 8` | 15 | 5 | 8 | drehen, 3 in einer Reihe | Erde, Wiese | – |
| 2 | Pflanzen | Lass 5 Wälder wachsen | `made[Wald] ≥ 5` | 15 | 5 | 9 | Regen (+ Feuer) | Wald | – |
| 3 | Tiere | Erschaffe 3 Tiere | `made[Tiere] ≥ 3` | 12 | 7 | 10 | Leben: Großer Wald, Tiere | Großer Wald, Tiere | – |
| 4 | Menschen | Baue 4 Hütten | `made[Hütte] ≥ 4` | 14 | 8 | 11 | Menschen (+ ihre Wünsche) | Hütte, Haus, Dorf | – |
| 5 | Nahrung | Erfülle 3 Wünsche | wishes fulfilled ≥ 3 | 18 | 10 | 14 | Wahl-Karte, Acker | Acker | Wiese |
| 6 | Glaube | Sammle 150 Glauben · Kein Krieg! | faith ≥ 150; war = fail | 13 | 8 | 11 | Glaube, Kirche, Krieg | Stadt, Kirche | Wiese, Dorf |
| 7 | Ruhe | Sammle 250 Glauben – mit grüner Waage | faith ≥ 250 **and** −50 < W < 20 at that moment | 13 | 9 | 11 | Industrie & Gewitter (Weltwaage, Smog) | Großstadt, Industrie | Wiese, Dorf, Stadt |

Systems per day (✓ = on):

| day | Regen (start / every) | fire | wishes (types, first, every) | Waage | income | war | smog | Gewitter |
|---|---|---|---|---|---|---|---|---|
| 1 | – | – | – | – | – | – | – | – |
| 2 | 1 / 6 | ✓ | – | – | – | – | – | – |
| 3 | 1 / 6 | ✓ | – | – | – | – | – | – |
| 4 | 1 / 6 | ✓ | Wald, Tiere, Regen · 2 · 3 | – | – | – | – | – |
| 5 | 1 / 6 | ✓ | all four · 1 · 3 | ✓ (hidden) | – | – | – | – |
| 6 | 1 / 6 | ✓ | all four · 2 · 3 | ✓ (hidden) | ✓ | ✓ (fail) | – | – |
| 7 | 1 / 6 | ✓ | all four · 2 · 3 | ✓ | ✓ | ✓ (−faith) | ✓ | ✓ (15 Glaube) |

Wish details for the days:
- First wish after twist `wish_from`, then every `wish_every` twists: `twists >= wish_from and (twists − wish_from) %
  wish_every == 0`.
- Without the Waage (day 4) the weights are the „Gleichgewicht“ set (Wald 2, Acker 2, Tiere 1, Regen 1), filtered by
  `wish_types`. With the Waage the zones of v1.1 apply (W ≤ −50: only Acker).
- **Change to v1.1 (also for free play):** an Acker wish is possible when an Acker **can be made** (the Wiese card is
  active), not only when an Acker already exists. Otherwise day 5 (no Acker on the board) would never get hunger
  wishes.
- In the days, wishes use the day LCG (section 6.3), so the shipped solutions replay exactly.

### 2.3 The days in detail

Start boards come from the pools (section 6). Composition, the rest is Wasser:

| day | start board (counts) | start W | extra board rules |
|---|---|---|---|
| 1 | Erde 22 | 0 | pool board 0: the slice x = 1, one quarter turn (`[0, 1, 1]`) makes a new Erde row (tutorial) |
| 2 | Wiese 10, Erde 16 | −100 | no single twist makes a Wald |
| 3 | Wald 12, Großer Wald 4, Wiese 10, Erde 8 | −100 | no single twist makes Tiere |
| 4 | Tiere 7, Großer Wald 8, Wald 8, Wiese 6, Erde 4 | −100 | no single twist makes a Hütte |
| 5 | Hütte 5, Haus 3, Tiere 3, Großer Wald 4, Wald 6, Wiese 12, Erde 6 | about −60 (hunger) | – |
| 6 | Dorf 6, Haus 6, Hütte 4, Acker 2, Wald 6, Wiese 8, Großer Wald 3, Tiere 2 | about −8 | – |
| 7 | Stadt 7, Dorf 5, Industrie 1, Kirche 2, Haus 4, Hütte 2, Acker 2, Wald 4, Wiese 8, Großer Wald 2, Tiere 2 | about +31 (yellow) | churches never touch |

All boards: no ready row of a kind that can row today; kinds placed by sticker type (1.3).

**Day 1 – Land (the tutorial)**
- Intro card: „Am ersten Tag ist alles Wasser und nackte Erde. Mach die Welt grün!“
- Goal: „Lass 8 Wiesen wachsen“ (chip: `meadow` icon, „3/8“).
- Tutorial flow (replaces the v1.1 tutorial; no card, no income):
  1. A hand shows the swipe of slice x = 1. Coach: „Dreh die Scheibe. Drei gleiche in einer Reihe wachsen!“
     The player swipes; the new Erde row grows a Wiese. Coach: „Aus drei Erden wird eine Wiese. Super!“
  2. „Jetzt du! Finde selbst drei Erden für eine Reihe.“ The onboarding auto-hint (`ONBOARD_HINT_SECONDS`) glows.
  3. After the 2nd growth: „Gut so! Du bist der Gott dieser Welt.“ – then quiet play until the goal.
  - The camera turns to the first Wiese (it may grow on a side face), so the „it grew!“ moment is not missed.
  - The hand and the slice glow only ever show a twist that grows: if the first twist was a different one and the
    guided slice no longer makes a Wiese, `Game.tutorial_move()` returns a twist that does (top-face slices first),
    or `{}` if none does. After the first twist that grows nothing the dock (with the free „Tipp“) comes in.
- The guided twist counts as twist 1. No fire, so nothing can go wrong.
- Fail: twists used up → fail card (practically never: hint bot 100 %, weak bot 90 %).

**Day 2 – Pflanzen**
- Intro: „Am zweiten Tag wachsen die ersten Pflanzen.“
- Goal: „Lass 5 Wälder wachsen“ (`smallforest`). Erde rows still make Wiesen (material).
- New thing: Regen. Reveal: „Neu: Regen“. Goal card „Neu“: „Drei Wiesen in einer Reihe werden ein Wald. Schneller:
  Tipp auf Regen und dann auf eine Wiese.“ In the game the lane says the row rule („Drei Wiesen in einer Reihe werden
  ein Wald.“) and a coach at the rain button says „Tipp auf Regen und dann auf eine Wiese – sie wird sofort ein Wald.“
  (`coach_tool`).
- Fire is introduced with Regen (the cure comes with the danger). Coach at the 2nd miss in a row: „Achtung: Wächst bei
  der nächsten Drehung wieder nichts, brennt es. Regen löscht Feuer.“
- Regen counts for the goal (a Wiese that becomes a Wald by rain is a Wald that grew).

**Day 3 – Tiere**
- Intro: „Am dritten Tag kommt das Leben. Im großen Wald leben Tiere.“
- Goal: „Erschaffe 3 Tiere“ (`animals`).
- Coach: „Drei Wälder werden ein großer Wald. Drei große Wälder bringen Tiere.“
- Regen on a Wald makes a Großer Wald (helps).

**Day 4 – Menschen**
- Intro: „Am vierten Tag kommen die Menschen. Sie leben dort, wo Tiere sind.“
- Goal: „Baue 4 Hütten“ (`hut`).
- Coach: „Drei Tiere in einer Reihe: Menschen ziehen ein – eine Hütte!“
- Wishes appear (types Wald, Tiere, Regen). First wish coach (v1.1 text): the wish text +
  „Erfüll den Wunsch – dann wächst ihr Haus.“ A fulfilled wish makes the Hütte a Haus. That is fine: the goal counts
  Hütten that **grew**, not Hütten that are still there.

**Day 5 – Nahrung**
- Intro: „Am fünften Tag haben die Menschen Hunger. Oft wünschen sie sich einen Acker.“
- Goal: „Erfülle 3 Wünsche“ (`wish`).
- New thing: the choice. Reveal: „Neu: Du entscheidest!“ Coach at the first card: „Aus drei Wiesen wird Wald oder
  Acker. Ein Acker macht die Menschen satt.“ The full card is shown for the first 3 Wiese cards (v1.1 rule), then the
  mini pill. **In the days the full card has no time limit** (only the mini pill keeps its 2 s), so a beginner can
  read the first choice in peace.
- The Weltwaage already steers the wish types (the board starts in the wild zone, so wishes are hunger wishes), but it
  is **not shown** on days 5 and 6 (`scale_visible: false`): one new thing per day. It appears on day 7, where it is
  part of the goal.
- Rain wishes are fulfilled by rain on the same face (v1.1), so Regen is a second way.

**Day 6 – Glaube**
- Intro: „Am sechsten Tag beten die Menschen zu dir.“
- Goal: „Sammle 150 Glauben“ + rule line „Kein Krieg!“ (`faith`).
- New thing: Glaube (the faith box appears top-left), Kirche, Krieg. Coach at the first Dorf card: „Eine Kirche bringt
  jede Runde Glauben. Aber bring nie zwei Kirchen zusammen – das gibt Krieg!“
- Faith comes from growth (`GROW_FAITH` by tier × combo), wishes (+15) and church income (+3 per twist).
- A war ends the day: fail card with caps „Krieg!“, title „Zwei Kirchen haben sich getroffen.“ and the line „Halte die
  Kirchen auseinander – versuch es nochmal.“ (the drag preview already shows the swords).
- The „Kein Krieg!“ tag sits centred under the goal chip (the row of the Weltwaage, which is hidden on day 6).

**Day 7 – Ruhe**
- Intro: „Am siebten Tag ruht die Welt – aber nur, wenn sie im Gleichgewicht ist.“ Tile icon: `balance`.
- Goal: „Sammle 250 Glauben – mit grüner Waage“. The chip always shows both halves: „x/250“ and the caps
  „Glaube + grüne Waage“ (green: „Glaube · Waage grün“). If the faith is reached but the Waage is not green, the caps
  say „Waage ins Grüne bringen“ with the balance icon on red. Green = Gleichgewicht, −50 < W < 20.
- Goal card „Neu: Industrie & Gewitter“: „Industrie bringt viel Glauben, macht aber Smog. Mit Gewitter (kostet 15
  Glauben) strafst du eine Fabrik.“ The reveal flies „Neu: Gewitter“ to its dock button; the Weltwaage is shown from
  the start (it is the goal).
- The start board is already yellow (W ≈ +31) and has one Industrie, so the player sees the problem at once.
- New things: Industrie (Stadt card), smog (W ≥ 50), Gewitter (dock, 15 Glaube).
  Coach at day start: „Industrie bringt viel Glauben – aber zu viel Stadt macht die Luft schmutzig. Bring die Waage
  ins Grüne: mit Wald, oder strafe eine Fabrik mit Gewitter.“
- War costs faith as in v1.1 (no fail). In the model the hint bot used Gewitter 2.4 times per day and built 2.2
  Industrie: the day really teaches the trade-off. Smog itself (W ≥ 50) was not reached by the bots; it is the warning
  shown on the red end of the Waage.

**After day 7.** Success card variant: „Deine Welt ist vollendet!“ with the 7 day icons and the total stars
(„17 von 21 Sternen“), then „Freies Spiel ist jetzt offen.“ and the button „Freies Spiel“.

---

## 3. Free play and level packs

### 3.1 Free play (after day 7)

- The current modes become **Freies Spiel**: Einfach / Mittel / Schwer / 40 Drehungen, with hearts, Blitz, Monsun,
  Flut, regrowth, ages and „Vollendet“ as in v1.1.
- They use the **new tree** (section 1) with all choices active (Wiese, Dorf, Stadt, Tiere → Paradies). Players
  must not relearn the rules.
- Existing players (`tutorial_done == true` in `rekord.cfg`) keep free play unlocked; the campaign starts at day 1
  for them, with a small „Neu: Die Schöpfung in 7 Tagen“ banner.

### 3.2 Free-play board and goal (provisional, re-validate before shipping)

With Erde able to form rows, the v1.1 start generator does not work (an Erde/Wiese board always has ready rows), and
with too much Wasser the world is too small. Model result (`free7.py`, n = 30 per row, 300-twist cap):

- Board: Wiese 26, Erde 24, Wasser 4, sticker-type placement, then break ready rows by swapping a row field with a
  field of another kind and the same sticker type.
- `COMPLETE_AT = [36, 18, 16]` (was 36/22/22): the new tree has no finished nature kind except Paradies, so fewer
  finished fields are reached.

| mode | bot | twists median (p10–p90) | won | faith median | smog |
|---|---|---|---|---|---|
| Einfach | eval | 31 (19–44) | 57 % | 5877 | 46 % |
| Einfach | random | 37 (20–50) | 40 % | 4310 | 61 % |
| Mittel | eval | 64 (49–78) | 17 % | 1538 | 0 % |
| Mittel | random | 82 (58–102) | 67 % | 2783 | 0 % |
| Schwer | eval | 67 (49–77) | 17 % | 1306 | 0 % |
| Schwer | random | 73 (55–95) | 43 % | 1775 | 0 % |

The free-play eval bot is weaker than random in Mittel/Schwer because it takes Paradies for the instant +1 income and
then stays in the wild zone. That is a bot artefact, but it also means free play needs its own tuning pass (wish
weights, Paradies value, `COMPLETE_AT`). **Open item:** run `free7.py` with n ≥ 200 and tune before shipping free play;
the 7 days do not depend on it.

### 3.3 Level packs (extension points)

A pack is data, not code:

```
{"id": "schoepfung", "title": "Die Schöpfung in 7 Tagen", "days": [
  {"title": "Land", "intro": "...", "goal": ["make", [1], 8], "limit": 15, "stars": [5, 8],
   "unlocked": [0, 1], "choices": [], "rain": [0, 0], "fire": false, "wishes": null, "scale": false,
   "income": false, "war": "off", "smog": false, "strike": false, "new": "drehen", "coach": ["..."],
   "boards": ["oooEoE..."]}, ...]}
```

- `Days` loads packs from `res://data/packs/*.json`; the first pack is the one above (built from
  `gdpd_7_tage_boards.json`).
- Hooks a later pack can use without engine changes: other start kinds (an „Insel“ pack = more Wasser; a „Wüste“ pack =
  less Erde, Regen as the main tool; a „Winter“ pack = fire off, few twists), other goals from the same 4 goal types,
  per-day `rain`, `wishes`, and the board pool.
- New kinds (e.g. Sand, Eis) need code: an id ≥ 16, a row in the kind table, `DOWN`, weights and an icon.
- The Python tool creates and validates pools: `days.py` (config + generator), `bot7.py`, `export7.py`.

### 3.4 Progress save

In `user://rekord.cfg` (written by `Game._save_profile()`), section `[schoepfung]`:

| key | type | meaning |
|---|---|---|
| `sterne` | Array[int] (7) | best stars per day, 0 = not solved |
| `beste` | Array[int] (7) | fewest twists per day, 0 = none |
| `frei` | int | highest day that can be played (1 … 7; 8 = all done) |
| `fehlversuche` | Array[int] (7) | failed attempts since the last win of that day (mercy, 4.5) |
| `brett` | Array[int] (7) | index of the next pool board per day |
| `fertig` | bool | day 7 solved once (free play open, „Vollendet“ shown) |
| `version` | int | 1 |

Packs later: section `[pack_<id>]` with the same keys. A day that is in progress is not saved (leaving = abandon, no
penalty).

---

## 4. UI flow

### 4.1 Start: the day overview

- Title „Die Schöpfung in 7 Tagen“. Seven tiles in a grid of 4 + 3 (portrait). Each tile: day number („Tag 3“),
  the icon of its new thing (`empty`/`meadow` → day 1, `rain`, `animals`, `hut`, `field`, `church`, `balance`),
  three small stars (filled = earned), a lock on days after `frei`.
- Tap a tile → goal card. Tap a locked tile → the lock shakes, toast „Erst Tag %d schaffen.“
- If a free-play game is running (twists or faith), tapping a day (or „Tag n spielen“) first asks „Tag n starten?“
  („Dein freies Spiel endet …“), like a new free-play game does.
- Below the tiles: button „Freies Spiel“; locked until `fertig` with „Nach Tag 7“.
- First start ever: skip the overview and go straight into day 1.

### 4.2 Goal card (day start)

A modal card over the cube (the cube already shows the start board):
- „Tag 4 · Menschen“ (small), the story intro line, the goal in big type with its icon („Baue 4 Hütten“), and
  „in 14 Drehungen“.
- If the day has a new thing: a „Neu“ row with the icon and one line (the unlock reveal, 4.6).
- Star line: „★★★ in 8 Drehungen“.
- Button „Los!“. Nothing else.

### 4.3 Goal chip (always on screen)

- Replaces the „Vollendet“ chip in the HUD during days: goal icon + progress („2/4“), and next to it the twists left
  as a ring around a small number („11“). The last 3 twists tint the ring orange.
- Progress pops (+1 bounce) when it moves. Long-press: the goal text + „Noch 11 Drehungen.“
- Day 7: both halves of the goal at all times (see 2.3); „Waage ins Grüne bringen“ on red when the faith is reached but
  W is not green.
- Day 6: a small „Kein Krieg!“ tag centred under the chip.

### 4.4 Success and fail

- **Success card**: confetti/heart burst, „Tag 4 geschafft!“, stars fly in one by one, „in 9 Drehungen“ (with fewer
  than 3 stars: „in 9 Drehungen · 3 Sterne mit höchstens 8“), buttons „Weiter zu Tag 5 · Nahrung“ (primary) and
  „Nochmal · mehr Sterne“. On day 7: section 2.3 „After day 7“.
- **Fail card**: no shame, no cost. Caps „Keine Drehungen mehr.“ (or „Feuer“), title „Fast geschafft!“ only when at
  least half of the goal was reached, else „Versuch es nochmal!“ (war on day 6: see 2.3), the progress reached
  („3/4 Hütten“), button „Nochmal“ and a small line „Nächster Versuch: +2 Drehungen“ when mercy applies.
- „Nochmal“ loads the **next** board of the pool (index `brett`), so a retry is fresh and never a memory test.

### 4.5 Mercy (Gnade)

Each failed attempt of a day gives the next attempt +2 twists, at most +6 („Gott hat Geduld: +2 Drehungen“ in the
goal card). Stars still use the base thresholds (twists used), so mercy never gives stars for free. Reset on a win.
Model effect of +6 (4th attempt): the no-foresight bot goes from 36–70 % to 65–95 % on days 3–7 (table 8.2).

### 4.6 Unlock reveal and hint

- Reveal: at the goal card of a day with a new thing, the new icon zooms in with „Neu: Regen“ (etc.). In the game it
  arrives in its place (dock button, Waage under the HUD, faith box) with a short glow. One coach line (2.3), once.
- Help card („So geht's“) in a day: first „Deine Aufgabe“ (goal, twists left, fewer twists = more stars) and „Was
  wächst woraus“ as a picture row of what can grow today (Erde → Wiese → Wald → …); only rows the day knows. On days
  4–5 (no faith shown) the wish row says „… dann wächst ihr Haus.“
- Menu: title „Menü“; the „Profil“ tile is hidden until profiles exist; „Wahl-Karte immer zeigen“ only after the first
  choice card. Free-play modes: Einfach „Entspannt – mehr wächst mit“, Mittel „Auch schräge Reihen zählen“, Schwer
  „Nur gerade Reihen – wie in den 7 Tagen“; free-play card „Bau deine Welt weiter, bis sie vollendet ist.“
- The hint („Tipp“) is **free during the 7 days** (recommended; product decision): the days are the learning path,
  and the target success rates assume a player who uses tips when stuck. In the days it uses the goal value (7.2),
  not faith. The onboarding auto-hint (glow after `ONBOARD_HINT_SECONDS`) is on for days 1–2.

---

## 5. Implementation map (GDScript)

- `field_data.gd`: kind table 1.1 (+ `WATER = 15`, `KIND_COUNT = 16`, names, icons, help texts 1.4), `CHOICE` with
  Tiere, new `NEXT`/`DOWN`/`TIER`/`AGE_OF`.
- `balance.gd`: `GROW_FAITH` 11 entries; `DAY_*` constants are not needed there – the day table lives in a new
  `scripts/days.gd` (`class_name Days`, the table of 2.2 + pool loading).
- `game_state.gd`:
  - `day: Dictionary` (the config; `{}` = free play), `made: Array` (16 ints), `day_won`, `day_lost`, `day_won_at`,
    `day_limit` (limit + mercy).
  - `can_row(k)` instance method (1.2); `grown(k)` asks a card only if `choices` has `k`.
  - Erde rows: `can_row(EMPTY)` is true when Wiese is unlocked; the start-board helpers that use `EMPTY` as "blank"
    (`_break_ready_lines`, `_bloom_once`, tutorial board) must use Wasser for blanking.
  - `made` counting in every growth place (rows, faces, Einfach groups, `_fulfil`, rain, Blitz, Monsun).
  - Day switches: `hearts = false`, `diagonals = false`, `easy = false`, `REGROW` off, income/war/smog/wishes/tools
    from the day config; `no_war` → `day_lost = "war"`.
  - `goal_progress()`, `goal_met()`, `check_day()` (after `end_round` and `resolve_now`).
  - Day LCG for wishes (6.3), cloned with the state.
- `game.gd`: day flow (start day N, mercy, next board, success/fail, save 3.4), hint in days (7.2).
- `ui.gd`: overview, goal card, goal chip, success/fail cards, reveal, „Freies Spiel“ entry.
- `world.gd` / `field_view.gd` / `models.gd`: Wasser tile (flat, animated blue, no tile edge), `water` icon.
- `main.gd`: tour (9.3).

---

## 6. Boards

### 6.1 Format

`gdpd/docs/gdpd_7_tage_boards.json` (copy to `res://data/days_schoepfung.json`; `docs/` is ignored by Godot):

```
{"code": "EwWAgTHhDSKGIMPo",
 "days": {"1": [{"board": "<54 chars>", "seed": 1, "solved_in": 6, "stars": 2,
                 "solution": [["twist", [1, 0, 2], {}], ["rain", 17, {}], ["twist", [0, 1, 1], {"1": 1}], ...]}, ... 20 boards],
          ... "7": [...]}}
```

- One char per field id, in the order of `GameState.setup()` (x, y, z loops over −1, 0, 1, then axis a with
  `p[a] != 0`). `code[k]` is the char of kind `k`: E Erde, w Wiese, W Wald, A Acker, g Großer Wald, T Tiere, H Hütte,
  h Haus, D Dorf, S Stadt, K Kirche, G Großstadt, I Industrie, M Metropole, P Paradies, o Wasser.
- `solution`: the hint bot's winning actions (twist `[axis, layer, turns]`, rain/strike on a field id, card answers
  `{kind: option}`). Each one was replayed in the model and wins at exactly `solved_in`.
- Pool rule: the hint bot wins the board with at least 2 twists to spare and in ≥ 3 twists. Day 1 board 0 is the
  tutorial board (slice `[0, 1, 1]` makes the first Erde row).

### 6.2 Board order

Attempt `i` of a day uses `pool[(brett) % 20]`; `brett` advances after every attempt (win or fail). An attempt on an
explicitly chosen board („Tutorial nochmal“ = day 1 board 0) never rewinds it: `brett = max(brett, index + 1)`. The first visit to
day 1 always uses board 0 (tutorial).

### 6.3 Day RNG (exact replays)

Days do not use Godot's `RandomNumberGenerator` for rules. A 31-bit LCG as in the Python model:
`rng = (seed * 7919 + 17) & 0x7fffffff` at day start (seed = the board's `seed`), and
`rand(n): rng = (rng * 1103515245 + 12345) & 0x7fffffff; return (rng >> 8) % n`. It is used only by `_make_wish`
(type, then field), in that order. It is part of `clone()` and undo. Free play keeps `rng`.

---

## 7. Bots used for validation (and the in-game hint)

### 7.1 Bots

- **good** (= the in-game hint): every turn it previews all 27 twists, each with both card options, and every useful
  Regen target; takes the best by goal value (7.2). If no twist makes goal progress, it also runs the 2-step search
  (first twist after which a second twist of another slice forms the most valuable new rows) and adds 10 × that value.
  Uses Regen when it raises the value by > 4 (> 8 for the last drop while fire is on). Day 7: also previews Gewitter on
  every Industrie when W ≥ 15.
- **greedy** (normal player without foresight): the same 1-step preview, no 2-step search, never uses Regen.
- **weak** (casual / careless): a growing twist half of the time (random among the twists that make any new row),
  otherwise a random twist; random card answers; 25 % chance per turn to rain on a random field.

### 7.2 Goal value (hint in days)

`V = 1e6 if won · −1e5 if lost by war · otherwise:`
- make: `100 × progress + 3 × Σ_fields w(dist)` where `dist` = growth steps from the field's kind to the goal kind and
  `w = {1: 6, 2: 2.5, 3: 1, 4: 0.4, 5: 0.15}`;
- wishes: `100 × fulfilled + 6 per open wish (+4 if hunger and an Acker exists) + 2 × min(Acker, 4) + 0.5 × people`;
- faith: `min(faith, target) + 0.8 × income × min(twists left, 6) − 4 × max(0, churches − 2)`; with „green“:
  `− 2 × (W − 17)` when W ≥ 20 and `− 2 × (−47 − W)` when W ≤ −50;
- all: `− 36 × misses` in the days (no hearts; free play: `− 12 × misses`, ×3 on the last heart), `− 3` per
  burning field,
  `+ Σ over lines with two equal fields and one other: w(kind)` (row potential).

The GDScript hint should use the same terms; exact weights may differ, the test (9.1, item 14) only checks that the
hint solves the pool boards.

---

## 8. Validation (Python model)

Model: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/gdpd_sim/`
- `engine.py` – v1.1 rules. Cross-checked against the **current** `gdpd/scripts/game_state.gd` with
  `xcheck_gdpd.py` + `gdpd_x/xcheck.gd`: 400 random boards (all kinds, all 3 levels, random card answers, wishes off
  because the RNGs differ) × up to 15 twists = 5338 turns, **0 mismatches** in kinds, faith, hearts, misses and
  positions (209 wars, 1682 smog turns covered). Two model bugs were fixed on the way (faces and fulfilled wishes now
  count as growth; „Vollendet“ bonus only once) – the GDScript was right.
- `engine7.py` – the rules of this spec. `xcheck7_old.py` configures it with the v1.1 tree and replays the same 400
  cases against the GDScript traces: **0 mismatches**, so the refactor is exact.
- `days.py` (day table, generator), `bot7.py` (bots), `run7.py`/`tune.py` (runs), `final7.py` + `report7.py`
  (this table), `export7.py` (pools), `free7.py` (free play).

### 8.1 Final metrics (300 seeded boards per day and bot; unfiltered generator boards)

| day | limit | ★★★ ≤ | ★★ ≤ | good won | good twists min / median / p90 | good ★★★ / ★★ / ★ | greedy won | weak won |
|---|---|---|---|---|---|---|---|---|
| 1 Land | 15 | 5 | 8 | **100 %** | 3 / 5 / 6 | 58 / 42 / 0 % | 99 % | 90 % |
| 2 Pflanzen | 15 | 5 | 9 | **100 %** | 4 / 6 / 6 | 23 / 77 / 0 % | 99 % | 61 % |
| 3 Tiere | 12 | 7 | 10 | **93 %** | 4 / 7 / 10 | 51 / 38 / 5 % | 36 % | 0 % |
| 4 Menschen | 14 | 8 | 11 | **88 %** | 5 / 9 / 12 | 42 / 34 / 12 % | 37 % | 2 % |
| 5 Nahrung | 18 | 10 | 14 | **89 %** | 7 / 10 / 16 | 45 / 32 / 12 % | 82 % | 1 % |
| 6 Glaube | 13 | 8 | 11 | **87 %** | 3 / 9 / 12 | 32 / 42 / 13 % | 70 % | 8 % |
| 7 Ruhe | 13 | 9 | 11 | **82 %** | 6 / 9 / 12 | 48 / 22 / 12 % | 64 % | 1 % |

Targets: good ≥ 95 % on days 1–2 ✓, 85–95 % on days 3–5 ✓, 70–90 % on days 6–7 ✓; weak clearly worse ✓; ★★★ reachable
but not automatic (good bot 23–58 %) ✓; no day solved in fewer than 3 twists (minimum over all 6300 games) ✓.

### 8.2 Mercy and details

| day | greedy +6 twists | weak +6 twists | good: fires / Regen used / wishes ok of made / cards / Gewitter / wars |
|---|---|---|---|
| 1 | 99 % | 100 % | 0 / 0 / – / 0 / – / – |
| 2 | 100 % | 94 % | 0.19 / 1.4 / – / 0 / – / – |
| 3 | 77 % | 8 % | 0.47 / 1.8 / – / 0 / – / – |
| 4 | 65 % | 8 % | 0.92 / 1.8 / 0.6 of 1.5 / 0 / – / – |
| 5 | 93 % | 4 % | 0.98 / 0.3 / 2.8 of 3.9 / 4.4 / – / – |
| 6 | 95 % | 27 % | 0.86 / 0.6 / 1.8 of 3.0 / 3.3 / – / 0 |
| 7 | 91 % | 7 % | 1.24 / 1.5 / 1.9 of 3.1 / 4.3 / 2.43 / 0.12 |

Reading:
- Days 1–2 are friendly to everyone (weak bot 90 % / 61 %). From day 3 on the days need a plan: the no-foresight bot
  wins 36–82 %, the careless bot almost never. That is the intended answer to „man dreht einfach nur die Scheiben“:
  aimless twisting no longer works, looking for rows (or tapping „Tipp“) does.
- Fail reasons: always the twist limit (hearts are off; day 6 wars: 0 in 900 games – the preview prevents them).
- Day 5: every bot makes 4–5 cards per day; the hint bot builds about 4 Acker and fulfils 2.8 wishes.
- Day 7: the hint bot builds 2.2 Industrie and uses Gewitter 2.4 times – the day teaches the trade-off. Smog (W ≥ 50)
  was never reached by any bot.
- Model limits: the bots see all 6 faces; a human sees 3. That is why the hint is free in the days and why mercy
  exists. Tune with real play data later (log per attempt: day, board, twists used, won, stars, hints used).

---

## 9. Test plan

### 9.1 Rule tests (`tests/test_rules.gd`, must end with „0 Fehler“) – new or changed

1. Kind table 1.1: 16 kinds; `NEXT`/`DOWN`/`TIER` as listed; Wasser never `can_row`, never burns, never changes by
   rain, Gewitter or Flut; Paradies only via the Tiere card.
2. Erde rows: 3 Erde in a new row → the target becomes Wiese, the other two stay Erde; a standing Erde row does not
   count; Erde rows in free play too.
3. Rests today (1.2): with `unlocked = {Erde, Wiese}` a new Wiese row does nothing and counts as a miss; with Wald
   unlocked it grows.
4. Choices per day: day 4 config → a Wiese row makes Wald and `card == -1`; day 5 → card for Wiese; day 6 → card for
   Dorf; day 7 → card for Stadt; Großer Wald never has a card; free play → Tiere card (Hütte/Paradies).
5. `made` counting: row, cascade (both kinds), face (9), rain, fulfilled wish count; fire, war, smog, Gewitter and
   regrowth do not; `made` survives `clone()` and undo.
6. Goals: `make` (≥ N), `wishes` (fulfilled count), `faith`, `faith+green` (not met at W = 25 with enough faith; met
   at W = 10); won on the last allowed twist; lost after `limit` twists; day 6 war → lost „war“.
7. Stars from `stars = [a, b]` and twists used; mercy adds twists but not stars.
8. No hearts in days: three misses burn the row, `lives` unchanged, day not lost.
9. Wishes in days: first at `wish_from`, then every `wish_every`; allowed types only; hunger wish possible without an
   Acker on the board when the Wiese card is active (and not before day 5).
10. Day LCG: the same seed and actions give the same wishes; `clone()` copies the LCG state.
11. Boards: every pool board has 54 chars, no ready row of a kind that can row on its day, churches never adjacent,
    each row-able kind with ≥ 3 fields has at least 2 corner stickers.
12. **Pool replay (the cross-check)**: for every day, replay `solution` of boards 0–4 from the JSON on a fresh day
    state; the day must be won exactly at `solved_in`. Days 1–3 must replay all 20 boards (no wishes involved).
13. No pre-solved boards: on every pool board of days 2–4 no single twist makes goal progress; on all days the goal
    is not met at twist 0.
14. Hint: on 3 pool boards per day, playing only `best_move()` (with its card choice and rain) wins within the limit.
15. Save 3.4: write → read round trip; `frei` unlocks the next day after a win; mercy counter resets on a win.

`tests/test_models.gd`: the `water` icon/tile and the `animals`/`field` tiles exist.

### 9.2 Smoke

`--quit-after 6000` from a clean profile: day 1 starts directly (no overview on first launch), no SCRIPT ERROR.

### 9.3 Screenshot tour (`main.gd`) – new CHECK names

Add to the tour and to the expected list in `.github/workflows/gdpd.yml`:

| name | what it checks |
|---|---|
| `day_overview` | 7 tiles, day 1 open, days 2–7 locked, „Freies Spiel“ locked |
| `day1_goal_card` | goal card text „Lass 8 Wiesen wachsen“, „in 15 Drehungen“ |
| `day1_tutorial` | guided swipe of slice x = 1 grows a Wiese; chip shows „1/8“ |
| `goal_chip` | chip progress and twists left update after a twist |
| `day1_your_turn` | „Jetzt du!“ lane, hand gone, dock with „Tipp“ visible |
| `day_success` | success card with stars and „Weiter zu Tag 2 · Pflanzen“ (tour plays with the hint) |
| `day_next` | day 2 goal card with „Neu: Regen“ |
| `day2_rain_reveal` | „Neu: Regen“ reveal, rain on a Wiese counts for the goal |
| `day_help` | help in day 2: „Deine Aufgabe“ + „Was wächst woraus“ (Erde → Wiese → Wald), no faith/choice rows |
| `day_fail` | fail card after the limit, „Nochmal“ loads the next board, +2 twists |
| `day4_wish` | day 4: first wish bubble, coach „… dann wächst ihr Haus“ (no faith shown) |
| `day5_choice` | Wiese card appears, Acker option, no time limit, Waage **not** visible |
| `day6_faith` | faith in the goal chip, „Kein Krieg!“ tag |
| `day6_war` | two churches meet: the day is lost, fail card with the war text |
| `day7_green` | „Waage ins Grüne bringen“ with „250/250“ when faith is reached but W ≥ 20; Waage visible |
| `day7_smog` | too much industry: smog |
| `world_complete` | after day 7: „Deine Welt ist vollendet!“, free play unlocked |

The v1.1 checks that depend on free play (`tutorial_choice`, `tutorial`, `choice*`, `war`, `smog`, `strike`,
`flood`, `complete`, `game_over`, …) move to a free-play section of the tour; `tutorial_choice` and `tutorial` are
replaced by `day1_tutorial` (update the workflow list accordingly).

### 9.4 Model re-runs

After any change to rules, limits or boards: `python3 final7.py 300 && python3 report7.py` must stay inside the
targets of 8.1, and `python3 export7.py` regenerates the pools (their replay assert must pass).

---

## 10. Constants (put into `days.gd` / `balance.gd`)

```
GROW_FAITH = [0, 2, 4, 7, 11, 16, 24, 35, 50, 75, 100]
DAY_LIMIT  = [15, 15, 12, 14, 18, 13, 13]
DAY_STARS  = [[5, 8], [5, 9], [7, 10], [8, 11], [10, 14], [8, 11], [9, 11]]
DAY_GOAL   = [["make", [MEADOW], 8], ["make", [FOREST], 5], ["make", [ANIMALS], 3], ["make", [HUT], 4],
              ["wishes", 3], ["faith", 150], ["faith", 250, "green"]]
DAY_RAIN   = [[0, 0], [1, 6], [1, 6], [1, 6], [1, 6], [1, 6], [1, 6]]      # start, +1 every n twists (max 3)
DAY_WISH   = [null, null, null, [2, 3], [1, 3], [2, 3], [2, 3]]             # first at twist, then every
MERCY_TWISTS = 2;  MERCY_MAX = 6
FIRE_AFTER = 3     # days: burns, no heart lost
FREE_COMPLETE_AT = [36, 18, 16]   # provisional (3.2)
```
