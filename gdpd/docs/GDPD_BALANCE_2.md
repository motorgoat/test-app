# gdpd – Balance 2: kein Farmen, wenige Arten, über Nacht gewachsen (Spec v1)

This spec is for implementers, so it is written in English. Every text a player sees is in simple German (du-form),
as short as possible (2–6 words), and is written here exactly as it should appear.

It builds on `GDPD_REGELN.md` (v1.1), `GDPD_7_TAGE.md` (the 7 days) and `GDPD_TAEGLICH_CHARAKTER.md` (one day per
real day, Welt des Tages, Weiterbauen). Everything not changed here stays as it is there.

**Player feedback this answers (verbatim):**
- „Teilweise ist es aber auch viel zu leicht, weil ich einfach immer die gleiche Scheibe hin und her drehen kann,
  damit es immer gleich Upgrades gibt.“
- „Sollten nicht zu viele verschiedene Felder auf einmal aktiv sein? Wenn der nächste Tag erreicht wird, könnten sich
  ja die niedrigeren Upgraden, damit man nicht zu viel verschiedene hat und es zu unübersichtlich wird. Es kann ja
  dann von Tag zu Tag schwerer werden.“

**Validated with:** the real GDScript (`game_state.gd`, headless scripts on all 140 pool boards and free play) and the
Python rules model (cross-checked against the GDScript, 0 mismatches before and after the change). Files: section 11.

---

## 0. Decisions (summary)

| # | decision | why (one line) |
|---|---|---|
| 1 | **Jede Reihe wächst nur einmal.** A row (its 3 fields + their kind) that has grown never grows again. | Kills every repeat loop (fire, Gewitter, war, smog falls) and changes nothing for honest play (good/greedy/weak bots identical on all 140 boards). |
| 2 | Rejected: „a field that grew rests K twists“ (`pause`). | Hurts honest play (good bot ★★★ day 3: 55 → 40/30 %) and does **not** stop the loops (pp unchanged, Gewitter loop still 2.2 growths per twist). |
| 3 | Free play: rule 1 plus **„Nachwachsen schließt keine Reihe“** (regrowth never lands on an Erde field that would complete a row). | In free play the passive regrowth late-merge grew something on 66 % of all back-and-forth twists. |
| 4 | Days: **at most 3 growable kinds** on every start board; the lower kinds of yesterday have **grown overnight** („Über Nacht gewachsen“, presentation only). | Fewer different fields at once; each day continues the world of the day before. |
| 5 | **Rising difficulty**: good-bot win rate 100 → 100 → 92 → 89 → 89 → 88 → 82 %, greedy and weak fall off from day 3; ★★★ 23–58 %. | „Es kann ja dann von Tag zu Tag schwerer werden.“ |
| 6 | New pools (20 per day, solutions), every board **farm-proof**: neither ping-pong, cycle nor single-slice farmer wins it. | Shipped boards cannot be beaten by farming even by an oracle. |
| 7 | Wishes move from day 4 to day 5 (day 4 has no Haus, so a wish could not grow anything). | One new thing per day; a fulfilled wish always shows growth. |

---

## 1. The exploit, reproduced with the real GDScript

### 1.1 Method

Scratch copy of `gdpd/` (unchanged scripts), headless:
- `farm.gd`: on all 140 pool boards, honest play = the hint (`best_day_action`, rain included) vs. pure cycles, each
  played for the day limit (after a win it continues in Weiterbauen): `pp` = one slice back and forth
  (m, m′, m, m′ …), `rot4` = same slice same direction, `rot3` = m, m, m2, `pp2` = half turn twice,
  `comm` = A B A′ B′, `dbl` = A A′ B B′ (two-slice cycles from the 4 best slices). For every board the **best**
  move/pair is kept (oracle farmer).
- `strike_farm.gd` (day 7): the hint vs. the hint + „Gewitter on any field when it makes something grow“.
- `farm_free.gd`: free play Einfach/Mittel/Schwer, 12 seeds, 30 twists: eval bot vs. best pp, best rot4, median pp.

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

Day 7 Gewitter (real GDScript, 20 boards): hint 2.6 Gewitter per day, 0 regrowths by Gewitter; „Gewitter on any
field“: **148 Gewitter per day, 148 regrowths** – an endless faith fountain without a single twist.

Free play (real GDScript, 30 twists, 12 seeds): Mittel, any slice back and forth (median slice) grows something on
**66 %** of the twists (Schwer 68 %, Einfach 27 %), Einfach `rot4` (one slice, same direction) out-earns the eval bot
(faith 7419 vs. 4828).

### 1.3 Why the current rules let it through (traced event by event)

1. **Fire reset (days 2–7, free play).** Twist A makes the row (a, b, c) of kind k grow: c → k+1. Twisting back and
   forth then misses three times; the 3rd miss burns the last swiped row (it contains c). Next twist c falls back to
   k, the trio (a, b, c, k) stands again, and the late merge makes it grow **again** („merge … late“ in the trace).
   `broken` only remembers the rows of the *last* twist, `standing` only the rows at turn start, `spent` exists only
   for Einfach groups – nothing remembers that this exact row already grew. So the same Wald appears again and
   again at the same spot: „immer gleich Upgrades“.
2. **Gewitter reset (day 7, free play).** Gewitter lets the field fall one step (any field, 15 Glaube). If that field
   was the target of a row, the old trio is complete again and grows in the same round (+50 Glaube for a Dorf row,
   minus 15). Gewitter is no twist, so it costs neither twists nor misses.
3. **Passive regrowth (free play).** Each twist one Erde with ≥ 2 nature neighbours becomes Wiese and joins the late
   merges. With many Wiesen around, it completes a Wiese row almost every twist, whatever slice is turned.
4. **Einfach groups (free play).** A completing row makes the whole connected group grow; rotating one slice in one
   direction keeps bringing new group contacts (this is real growth, but faster than thinking).
5. **What is not the cause:** straight rows on side faces of the slice (they keep their key when the face rotates,
   `standing` blocks them), and quarter turns that bring new stickers (honest new rows, bounded – every growth raises
   a field, so without falls the total growth of a board is finite).

---

## 2. The rule: „Jede Reihe wächst nur einmal“

### 2.1 Exact rule

- `spent` (exists today for Einfach) becomes the memory of **every** row that has grown, in all modes:
  key = `line_key(line)` = the 3 field ids (sorted) + the kind **before** growing.
- When a row grows (straight or diagonal, Einfach group or not, first pass or cascade, normal or late), its key goes
  into `spent` **before** the target changes kind. When a whole face grows, all lines of that face go into `spent`.
- A row whose key is in `spent` never counts again: in the first pass via `counts()` (as now), and **also in cascade
  passes** (`pass_i > 0`; today cascades skip `counts()`).
- `spent` is kept for the whole game (day attempt or free-play game), copied by `clone()`, part of undo and the save.
  Size: one entry per growth (a day < 40, a 300-twist free game < 600).
- Nothing else changes: `standing`, `broken`, target field, combo, cascades, faces, faith, misses, fire.
- A burnt field that falls can still grow in a **new** row (another trio, or the same fields with another kind).
- Config: `once` (default `true` in days and free play). Days read it from the day config (`"once": true`).

### 2.2 Why this rule (one line for the player, zero cost for honest play)

| variant (current pools, 20 boards/day) | good won / ★★★ (days 1–7) | farmers | verdict |
|---|---|---|---|
| current rules | 100 % all days / 60 20 55 45 50 30 70 | slice farmer wins day 2 55 %; day-7 Gewitter farmer 3.35 growths/twist, ★★★ 85 % | exploit |
| **once** | **identical** (100 % / 60 20 55 45 50 30 65) | pp growth halved, slice farmer day 2 55 → 5 %, Gewitter farmer 0.95 growths/twist (= honest) | **chosen** |
| pause 1 twist | 95–100 % / 60 15 40 35 50 35 70 | pp unchanged, slice day 2 50 %, Gewitter farmer 2.60 | hurts honest, not farmers |
| pause 2 twists | 95–100 % / 60 10 30 25 55 35 70 | pp unchanged, Gewitter farmer 2.15 | worse |

Greedy and weak bots: identical with `once` on all 140 boards (to the decimal). The rule only ever blocks a row
that already grew, which honest play never needs.

### 2.3 Feedback (the existing `spent` path)

The still/miss feedback of `GDPD_7_TAGE.md` 1.2a already has `why = "spent"`; it now fires for every repeat:
- badge `check` on the 3 fields, pill caps **„Schon gewachsen“**, big line **„Bring ein anderes Feld rein“**
  (already in `ui.gd`; keep).
- It counts as a miss (as `repeat`/`standing`), so the honest cure is unchanged: a new field.
- Help (Regeln, row list) gets one line: **„Jede Reihe wächst nur einmal.“**
- Coach (once per profile, the first time a `spent` still row is shown): **„Diese Reihe ist schon gewachsen.“**
- After a fire the burnt field falls; if it re-forms its old trio, that trio shows the `spent` pill (verified: day 2
  board 0, slice x = 1 back and forth: t4 shows `burn`, `repeat/spent`, `still/spent`, `miss/spent`).

### 2.4 Reference implementation (scratch, verified)

`/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/b2/balance2_game_state.diff`
(game_state.gd, ~40 lines) and `balance2_days.diff` (days.gd day table). Core:

```gdscript
var once := true              # jede Reihe wächst nur einmal („Schon gewachsen“)
# _apply_day_rules:  once = bool(cfg.get("once", true))      _apply_free_rules: once = true
# clone():           gs.once = once
# resolve_faces, before the face grows:          if once: _spend_face(face)   # all lines of that face → spent
# resolve_merges, collecting rows:               if pass_i > 0 and once and spent.has(line_key(ln)): continue
# resolve_merges, Einfach branch before growing: if once: spent[line_key(line)] = true
# resolve_merges, normal branch before _grow_to: if once: spent[line_key(line)] = true
```

Do **not** use the experimental `regrow_merge = false` from the diff (it makes regrown Wiesen pile up into full
faces; free play Mittel then grew 4.3 fields per back-and-forth twist). Use `regrow_safe` (section 3).

---

## 3. Free play

- Rule 2.1 is on.
- **„Nachwachsen schließt keine Reihe.“** Regrowth (one Erde → Wiese per twist, ≥ 2 nature neighbours, not in smog)
  skips every Erde field that would complete a row of 3 Wiesen as Wiese (straight, or diagonal where diagonals count
  for Wiese). It still adds material; the player has to make the row.
- Results (real GDScript, 12 seeds × 30 twists, `farm_free.gd`): see table 3.1.

### 3.1 Free play before / after

FREEPLAY_TABLE

---

## 4. The days: fewer kinds, overnight growth, rising difficulty

### 4.1 Rule of thumb

- Every start board has **at most 3 growable kinds** (kinds that can form a counting row today) plus Wasser and
  finished fields. A kind made today that may not grow yet **rests** (as now) – e.g. the goal kind.
- The lowest kinds of yesterday are gone: they **grew overnight**. Day 3 starts without Erde, day 4 without Wiese,
  day 6 without Wiese/Wald/Tiere, and so on.
- Falls (fire, Gewitter, war) can briefly bring back a lower kind (e.g. a burnt Wiese becomes Erde); that is the
  price of the fire and not counted.

### 4.2 Kinds per day

| day | start board (rest Wasser) | growable at start | made today, rests | unlocked (Days `unlocked`) | overnight (presentation) |
|---|---|---|---|---|---|
| 1 Land | Erde 22 | Erde | Wiese | Erde, Wiese | – |
| 2 Pflanzen | Wiese 10, Erde 16 | Erde, Wiese | Wald | Erde, Wiese, Wald | Erde → Wiese |
| 3 Tiere | Wiese 14, Wald 12, Großer Wald 4 | Wiese, Wald, Großer Wald | Tiere | Erde, Wiese, Wald, Großer Wald, Tiere | Erde → Wiese |
| 4 Menschen | Wald 10, Großer Wald 9, Tiere 7 | Wald, Großer Wald, Tiere | Hütte | Wiese, Wald, Großer Wald, Tiere, Hütte | Wiese → Wald |
| 5 Nahrung | Wiese 14, Hütte 8, Wald 3 | Wiese, Hütte (+ Acker once chosen) | Wald, Haus | Wiese, Wald, Acker, Hütte, Haus | Tiere → Hütte |
| 6 Glaube | Hütte 8, Haus 8, Dorf 6 | Hütte, Haus, Dorf | Stadt (Kirche ★) | Hütte, Haus, Dorf, Stadt, Kirche | Hütte → Haus |
| 7 Ruhe | Dorf 7, Stadt 6, Wald 10, Großer Wald 2, Industrie 1, Kirche 2 | Wald, Dorf, Stadt | Großer Wald, Großstadt (Industrie ★) | Wald, Großer Wald, Dorf, Stadt, Kirche, Großstadt, Industrie | Haus → Dorf |

Checked on all 140 new pool boards (real GDScript): max growable kinds at start = 1, 2, 3, 3, 2, 3, 3.
Day 7 start W median +24 (yellow, as before); day 5 W −43 (Waage not shown, used for nothing since `scale: false`).

### 4.3 Day table (Balance 2)

| day | goal (chip) | limit | ★★★ ≤ | ★★ ≤ | systems | change vs. today |
|---|---|---|---|---|---|---|
| 1 | Lass 8 Wiesen wachsen | 15 | 5 | 8 | no fire | – |
| 2 | Lass 5 Wälder wachsen | **14** | 5 | 9 | Regen 1/6, fire | limit 15 → 14 |
| 3 | Erschaffe 3 Tiere | 12 | **6** | **9** | Regen 1/6, fire | no Erde; ★ 7/10 → 6/9 |
| 4 | Baue 4 Hütten | 14 | 8 | 11 | Regen 1/6, fire | no Wiese/Erde; Hütte rests; **no wishes** |
| 5 | Erfülle 3 Wünsche | **15** | **7** | **11** | Regen 1/6, fire, wishes `wald`,`acker` from twist 1 **every 2**, Wiese card | limit 18 → 15; only Wiese/Hütte/Wald on the board; wishes are the new thing |
| 6 | Sammle **180** Glauben · Kein Krieg! | **12** | **7** | **10** | **no Regen**, fire, faith, income, war = fail, Dorf card | 150 → 180, 13 → 12, no wishes, no Regen |
| 7 | 250 Glauben, Waage grün | 13 | **8** | 11 | Regen 1/6, fire, faith, income, war, smog, Gewitter, Dorf + Stadt card, Waage shown | **no wishes**; ★ 9 → 8 |

Config keys as in `GDPD_7_TAGE.md` 2.1, plus `"once": true` and `"overnight": [[from, to], …]` per day. The exact
`days.gd` table is in `balance2_days.diff`. Texts of the goal cards stay; day 5 reveal becomes „Neu: Wünsche“ with
„Wald oder Acker? Du wählst.“; day 6 goal text „Sammle 180 Glauben“.

What makes each day harder than the one before (besides the numbers):
- 2: first fire, two steps from Erde to Wald. 3: three-step chain (Wiese → Wald → Großer Wald → Tiere), 12 twists.
- 4: chain to Hütte with 4 targets. 5: plan adjacency (wish fields) and choose Wald or Acker; wishes come every
  2 twists and pop after 8. 6: no Regen at all, faith needs Dorf rows/churches, one war loses the day.
- 7: two goals at once (faith **and** green Waage), smog, Gewitter costs faith.

### 4.4 Validation (Python model, 300 generated boards per day and bot, rule `once` on)

| day | good won | good median | good ★★★ / ★★ | greedy won | weak won | pp / cyc / slice farmer won (60 boards) | Gewitter farmer (striker) won / ★★★ |
|---|---|---|---|---|---|---|---|
| 1 | **100 %** | 5 | 58 / 42 % | 99 % | 90 % | 0 / 13 / 0 % | 100 / 57 % (no Gewitter) |
| 2 | **100 %** | 6 | 23 / 77 % | 99 % | 51 % | 0 / 0 / 8 % | 100 / 27 % (no Gewitter) |
| 3 | **92 %** | 7 | 26 / 56 % | 48 % | 1 % | 0 / 0 / 3 % | 95 / 33 % (no Gewitter) |
| 4 | **89 %** | 9 | 39 / 37 % | 53 % | 3 % | 0 / 0 / 0 % | 87 / 33 % (no Gewitter) |
| 5 | **89 %** | 8 | 26 / 46 % | 86 % | 8 % | 5 / 23 / 20 % | 85 / 22 % (no Gewitter) |
| 6 | **88 %** | 9 | 24 / 43 % | 80 % | 12 % | 0 / 2 / 0 % | 85 / 17 % (no Gewitter) |
| 7 | **82 %** | 9 | 37 / 35 % | 81 % | 10 % | 0 / 3 / 2 % | **72 / 48 %** |

Targets: good ≥ 95 % on days 1–2 ✓, 85–95 % on days 3–5 ✓ (92/89/89), 70–90 % on days 6–7 ✓ (88/82); weak clearly
worse ✓; ★★★ reachable, not automatic (23–58 %) ✓; the curve falls every day ✓; no farming bot beats the honest
bots in win rate on any day ✓ (the shipped pools are additionally farm-proof, 4.5).

Farm bots (all oracles: they try every option and keep the best game): `pp` best ping-pong of 27 moves; `cyc` best of
rot4 / m m m2 / pp2 / A B A′ B′ / A A′ B B′; `slice` best of the 9 slices, each twist the best of its 3 moves (good-bot
value) with Regen; `striker` = the good bot that may also use Gewitter on **any** field. The day-7 striker still
gets more ★★★ than the good bot (48 vs. 37 %) by paying ~8 Gewitter (120 Glauben) per day – that is a paid tool
used well, not a loop (growth per twist 0.83, honest 0.58; without `once`: 2.32 growths per twist, 97 % won, median
4 twists, 92 % ★★★). A further option, tested and not needed: Gewitter never makes a row grow in its own round
(`strike_merge: false`: striker 67 % won, ★★★ 40 % vs. good 38 %).

Same table with `once` off (new day table): good/greedy/weak identical within 1 %; farmers: slice wins day 2 40 %
(with `once` 8 %), day 3 15 % (3 %); day-7 striker 97 % won in a median of 4 twists.

### 4.5 Pools

- 20 boards per day, placed by sticker type, no ready row, churches never touch, day 1 board 0 = tutorial
  (slice x = 1 makes an Erde row), the good bot wins in 3 … limit − 2 twists, days 5–7 not solvable in one move.
- **New filter:** no board where the `pp`, `cyc` or `slice0` (single slice, no Regen) farmer wins the day
  (rejected: day 1: 3, day 5: 9, day 6: 1, day 7: 1).
- File (scratch, to be copied to `gdpd/data/days_schoepfung.json` and `gdpd/docs/gdpd_7_tage_boards.json` when the
  rule ships): `…/scratchpad/gdpd_sim/b2/gdpd_balance2_boards.json` (same format, plus `"rules"` and `"stats"`).
- Replay: all 140 solutions win exactly at `solved_in` with the stars of the model, in the Python model **and** in
  the patched GDScript (`replay_b2.gd`, with `gs.will = {}` per step like `test_day_replay`).
- Pool good-bot ★★★ per day: 12, 4, 6, 9, 8, 6, 7 of 20; median solved_in 5, 6, 7, 9, 8, 8, 9.
- On the pools (20 boards): good wins 100 % every day; greedy 95/100/60/35/90/95/100 %; weak 90/70/0/5/0/5/15 %;
  pp 0 %, cyc 0 %, slice ≤ 5 %, striker 90 % (day 7).
- Welt des Tages uses the templates 2–7 and their pools, so it inherits all of this.

### 4.6 „Über Nacht gewachsen“ (presentation only)

Rules start from the pool board as always; this is only how the board appears.
- When a day ≥ 2 is started from the overview (first attempt of the session; not on „Nochmal“, not in Weiterbauen):
  every field whose kind is a `to` of the day's `overnight` list is first drawn as its `from` kind (day 3: all Wiesen
  are drawn as Erde, day 5: all Hütten as Tiere …).
- 0.4 s after the board is visible, a soft wave from the camera-facing centre outwards (60 ms stagger, the normal
  growth pop at 70 % scale, no faith numbers, no sound stack – one soft chime) turns them into today's kind.
- Pill (top, `MOUSE_FILTER_IGNORE`, 1.8 s): caps **„Über Nacht gewachsen“**, line per day:
  day 2/3 **„Erde wird Wiese“**, day 4 **„Wiesen werden Wald“**, day 5 **„Tiere werden Hütten“**,
  day 6 **„Hütten werden Häuser“**, day 7 **„Häuser werden Dörfer“**.
- Never blocks input; a swipe during the wave finishes it at once (fields jump to today's kind) and the swipe counts.
- The goal card comes after the wave (or the wave runs behind the card's scrim if the card is already up).
- Welt des Tages: same wave with its template's list (optional, cheap).

### 4.7 Day 5 and 6 details

- Day 5 board: Wiese 14, Hütte 8, Wald 3 (the 3 Wälder rest; they exist so that „Wald, bitte!“ wishes can be met
  by moving them). Wishes `wald` (2) : `acker` (2) by the Gleichgewicht weights (no Waage). A fulfilled wish makes the
  Hütte a Haus (Haus rests). Coach at the first card stays „Wald oder Acker? Du wählst.“
- Day 6 has no Regen and no gift rain: faith is the only resource. Board W is +100 (no nature); the Waage is hidden
  and smog is off on day 6, so this is invisible.

---

## 5. Metrics before / after (summary)

| metric | before | after |
|---|---|---|
| honest (hint, real GDScript) growth/twist, days 1–7 | 1.56 1.30 1.23 1.05 0.90 0.78 0.85 | 1.57 1.30 1.26 1.05 0.88 0.69 0.66 (new days) |
| best ping-pong growth/twist, days 2–7 (real GDScript) | 0.28 0.27 0.20 0.28 0.20 0.21 | 0.15 0.19 0.10 0.11 0.08 0.08 |
| best cycle of any kind growth/twist, days 2–7 | 0.45 0.45 0.24 0.32 0.27 0.28 | 0.42 0.47 0.22 0.27 0.16 0.20 (only real new rows left) |
| farmers that win a pool board (real GDScript, 6 cycle types × 140 boards) | 3 (day 1) | 2 (day 1, comm) |
| Gewitter regrowths per day, „Gewitter on any field“ (real GDScript, day 7) | **148** | **0.7** |
| single-slice farmer wins day 2 (model, pools) | 55 % | 5 % (new pools 0 by filter) |
| good / greedy / weak bots on the old pools with `once` | – | identical to before |
| growable kinds on a start board (days 1–7) | 1, 2, 4, 5, 7, 8, 9 | 1, 2, 3, 3, 2, 3, 3 |
| good-bot win curve (300 boards) | 100 100 93 88 89 87 82 | 100 100 92 89 89 88 82 |
| greedy win curve | 99 99 36 37 82 70 64 | 99 99 48 53 86 80 81 |
| weak win curve | 90 61 0 2 1 8 1 | 90 51 1 3 8 12 10 |
| free play | see 3.1 | see 3.1 |

---

## 6. Player texts (all new or changed)

| where | text |
|---|---|
| rule line in help | „Jede Reihe wächst nur einmal.“ |
| still/miss pill, `spent` | caps „Schon gewachsen“ · line „Bring ein anderes Feld rein“ (existing) |
| coach, first `spent` row | „Diese Reihe ist schon gewachsen.“ |
| overnight pill caps | „Über Nacht gewachsen“ |
| overnight lines | „Erde wird Wiese“ · „Wiesen werden Wald“ · „Tiere werden Hütten“ · „Hütten werden Häuser“ · „Häuser werden Dörfer“ |
| day 5 reveal | „Neu: Wünsche“ · „Wald oder Acker? Du wählst.“ |
| day 6 goal | „Sammle 180 Glauben“ (rule line „Kein Krieg!“) |
| free play help | „Nachwachsen schließt keine Reihe.“ (only if a help line is wanted; the behaviour needs no text) |

---

## 7. Implementation map

| file | change |
|---|---|
| `scripts/game_state.gd` | `once`, `regrow_safe`, `_spend_face()`, spent on every growth (before `_grow_to`), spent check in cascade passes, regrowth skip; clone/save/undo carry `spent` (already) and the two flags |
| `scripts/days.gd` | new `_L4`…`_L7`, day table 4.3 (`once`, `overnight`), texts 6; `BOARDS_PATH` unchanged (copy the new pool over it) |
| `data/days_schoepfung.json`, `docs/gdpd_7_tage_boards.json` | new pools (4.5) |
| `scripts/world.gd` / `field_view.gd` | overnight wave: per-field display override (`from` kind) and the staggered grow pop |
| `scripts/day_ui.gd` / `ui.gd` | overnight pill; help line; coach for first `spent` |
| `scripts/game.gd` | trigger overnight on the first start of a day ≥ 2 from the overview |
| `tests/test_rules.gd`, `scripts/main.gd`, `.github/workflows/gdpd.yml` | section 8 and 9 |

Known test fallout with only the rule switched on (old table, old pools; scratch run): 3 failures –
`test_day_replay` and `test_daily_world` (2 old pool solutions play differently under the rule), and `test_card_deterministic`
(`cards > 500` threshold, only with the rejected `regrow_merge = false`). New pools fix the first two.

---

## 8. Test plan (`tests/test_rules.gd`, must end with „0 Fehler“)

1. **once_basic**: a row grows; burn its target; next twist the burnt field falls, the same trio stands → no growth,
   events `repeat` (spent) + `still` why `spent`, the twist is a miss.
2. **once_new_trio**: after that, bringing a different third field of the same kind makes the row grow (it is new).
3. **once_cascade**: a cascade pass never re-grows a spent key (construct: target falls inside the same round by war).
4. **once_face**: a face of 9 grows; all 8 straight + 2 diagonal keys of it are in `spent`.
5. **strike_no_loop**: day 7: Gewitter on a Stadt that just grew from a Dorf row → no growth, faith −15 only;
   200 such Gewitter in a row → total growth 0.
6. **pp_farm_pools**: on every pool board, the best ping-pong of the 27 moves for the day limit never wins, and its
   growth per twist stays below the hint's on the same board.
7. **slice_farm_pools**: single slice, best of its 3 moves each twist, no Regen: never wins a pool board.
8. **kinds_per_day**: every pool board has ≤ 3 growable kinds at start (`can_row`), and day 3 has no Erde, day 4 no
   Wiese, day 6/7 no Wiese.
9. **overnight_table**: `Days.config(n)["overnight"]` as in 4.2; every `to` kind exists on every pool board of day n.
10. **day_replay** (existing): 140 new solutions win exactly at `solved_in` with the stars of the model.
11. **regrow_safe**: free play: an Erde with 2 nature neighbours that would complete a Wiese row does not regrow;
    another Erde does.
12. **free_farm**: free play Mittel, 12 seeds, median slice back and forth 30 twists: growth on ≤ 40 % of twists.
13. **xcheck**: the model cross-check (section 11) stays at 0 mismatches.
14. Existing `test_day_table`, `test_day_goals`, `test_day_wishes`, `test_day_bots`: update the numbers to 4.3
    (day 4 no wishes, day 5 wishes every 2, day 6 180/12, day 7 no wishes).

---

## 9. Tour checks (`main.gd`; add to the list in `.github/workflows/gdpd.yml`)

| name | what it checks |
|---|---|
| `no_farming` | day 2, pool board 0 (new pool): **real swipes** on slice x = 1, alternating direction, 6 times. Growth count over the 6 twists ≤ 1 (model and patched GDScript: exactly 1, at the first twist; before: 2 – the 5th twist re-grew the burnt Wald), and at least one `spent` pill „Schon gewachsen“ was shown (5th twist, after the fire). Shot `no_farming.jpg`. |
| `spent_feedback` | that pill: 3 fields glow with the `check` badge, caps „Schon gewachsen“, line „Bring ein anderes Feld rein“, input never blocked |
| `overnight_growth` | start day 3 from the overview: within 0.5 s the Wiesen are drawn as Erde, the pill „Über Nacht gewachsen“ / „Erde wird Wiese“ is visible, after ≤ 2.5 s every field shows its pool kind; a swipe during the wave is accepted and counted. Shots `overnight_a.jpg`, `overnight_b.jpg` |
| `overnight_retry` | „Nochmal“ on that day: no wave |
| `kinds_per_day` | for days 1–7: the started board has ≤ 3 growable kinds (`can_row`); prints the lists |
| `strike_no_loop` | day 7: Gewitter on a field that just grew: no growth, chip faith −15 |
| `day5_wish` | replaces `day4_wish`: first wish bubble on day 5; day 4 shows no wish |
| `help_once` | help shows „Jede Reihe wächst nur einmal.“ |

---

## 10. Open items

- Real play data: log per attempt `spent` pills shown; if players hit „Schon gewachsen“ more than ~1× per day, add
  the coach line earlier (day 2).
- Free play still needs the tuning pass from `GDPD_7_TAGE.md` 3.2 (this spec only removes the farming).

---

## 11. Files (scratch) and how to re-run

Scratchpad: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/`

- Model: `gdpd_sim/b2/` – `engine7.py` (rules; new cfg `once`, `pause`, `regrow_merge`, `strike_merge`; mirrors the
  GDScript rest rule „a resting row is no miss“), `days.py` (`DAYS2` = this table, `DAYS` = current; `table='old'`),
  `bot7.py` (good/greedy/weak), `farm7.py` (pp, cyc, slice, slice0, striker), `runb2.py`
  (`python3 runb2.py gen:300 1,2,3,4,5,6,7 good,greedy,weak '{}'`, `pool:<file>` for pool boards,
  overrides e.g. `'{"all":{"table":"old","once":true}}'`), `export_b2.py` (pools), `xcheck_days.py` + `xcheck_pp.py`
  (cross-check cases).
- Cross-check: current GDScript vs. model with the current table: 360 cases, 5998 steps, **0 mismatches**. Patched
  GDScript (`b2/gd/`, rule + new table) vs. model with the new table: 610 cases (random play incl. 260 Gewitter +
  210 farming patterns), 9134 steps, **0 mismatches**, 53 `spent` blocks and 11 resting-row turns exercised.
- Real-GDScript scripts (scratch copies of `gdpd/`, `b2/gd/` patched, `b2/gd_once/` rule only):
  `farm.gd`, `farm2.gd`, `strike_farm.gd`, `farm_free.gd`, `trace_free.gd`, `trace_tour.gd`, `replay_b2.gd`,
  `xcheck_days.gd`. Logs: `b2/*.log`, raw per-board data `b2/farm_out_before.json`, `b2/gd/farm_out.json`.
- Pools: `gdpd_sim/b2/gdpd_balance2_boards.json`. Reference diffs: `b2/balance2_game_state.diff`,
  `b2/balance2_days.diff`.
