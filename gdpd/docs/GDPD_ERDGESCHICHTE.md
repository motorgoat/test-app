# gdpd – Erdgeschichte: Kampagne in Zeitaltern (Spec v1)

This spec is for implementers, so it is written in English. Every text a player sees is in simple German (du-form,
2–6 words, never more than 8) and is written here exactly as it should appear.

**It replaces the frame of `GDPD_SCHOEPFUNG.md`** (7 Genesis days as acts, 30 levels) by Philipp's decision of
10 November 2026 (`NAECHSTE_SCHRITTE.md`, „Erdgeschichte ausführlicher“): *„dann kommen noch dinos usw vor den affen
etc...mach es sehr ausführlich“* and *„es soll auch nich nur 7 tage lang sein oder so...halten wir uns nicht an die
bibel“*. So:

- **No Genesis frame anywhere:** no „Tag 1–7“, no act names „Licht / Himmel / …“, no „Schöpfungstag“, no
  „Der siebte Tag“, no „Und es war gut.“. The campaign is called **„Erdgeschichte“** and follows the history of the
  earth in **20 eras (Zeitalter)** with **60 levels** (more than double), from the glowing earth over the Cambrian sea,
  fish, the first forests, amphibians, dinosaurs, the meteor, mammals, the ice age and the apes to fire, hunters,
  farming, faith, cities, industry and balance.
- **One new level per real day** (as built), **open-ended:** eras and levels are data (`data/kampagne_erde.json`);
  new eras can be appended later without touching code (section 10).
- **Every quality rule of `GDPD_SCHOEPFUNG.md` and Build 12 stays binding**: rows grow `once`, no silent rows
  (Build 12 late pass), Gedeihen with lasting seals („Versorgt bleibt versorgt.“), group strength min(size, 3),
  dangers only as warned consequences, losses count (`make` = made − lost), steps counted not limited, generous
  stars (★★ for ≥ 85 % of average players), points `30 + 10 × stars + 5 × max(0, par − steps)`, the world carries over
  (now: within an era), `Campaign.ensure` + `reach9` + the safety-net gift, the top HUD always shows the concrete next
  action (`next_action`), never spoil, Welt des Tages after the campaign, the running level is saved.

**Validated with:** the Python rules model `gdpd_sim/b6/engine10.py` (a generic extension of the cross-checked
`engine9`; every old level runs unchanged), the bots `good` (= the hint), `greedy` (= the average player), `weak`
(casual), `weaklong` (casual without a step cap) and the oracle `farmer`, **200 generated boards per level and bot**
(60 levels: 36 000 games for good/greedy/weak, 12 000 farmer games), **100 carried-world chains per era for the good
and for the greedy bot** (12 000 more games), 100 uncapped casual games per level with a danger or hunger, and
exported pools of 20 boards per level with one checked solution each (section 11). Files and re-run: section 16.

**Never spoil:** an era's name, tile icon and card appear only once its first level is open; a level's title, story,
task, reveal card and icon only once the level is open. Locked tiles show only a lock / „?“ and „Morgen wartet etwas
Neues“. Notifications never name the next level or era. The scripted meteor is announced only inside its own level
(its title and story are shown when that level opens, never before).

---

## 0. Decisions (summary)

| # | decision | why (one line) |
|---|---|---|
| 1 | **20 eras, 60 levels** (4 · 3 · 4 · 3 · 3 · 3 · 4 · 3 · 6 · 2 · 4 · 3 · 3 · 2 · 2 · 4 · 2 · 1 · 2 · 2), ordered by earth history; one new level per real day (two months), then the Welt des Tages; new eras can be appended. | Philipp 10 Nov: „sehr ausführlich“, „nicht nur 7 Tage“, „nicht an die Bibel halten“. |
| 2 | **All 30 old levels stay** (same rules, same start composition, same thresholds model) where they fit the history: 20 unchanged, 10 re-skinned with era kinds (Quallen → Fische, Farn → Wald in the light, Fisch → Amphibien on Moos, Saurier instead of Tiere, Frühmenschen build huts). 30 levels are new. | Validated content keeps its quality; the new levels add the eras Philipp asked for. |
| 3 | **13 new kinds (ids 27–39)**: Quallen, Trilobiten, Insekten, Amphibien, Reptilien, Saurier, Raubsaurier, Flugsaurier, Eis, Mammut, Affen, Frühmenschen, Feuerstelle; 3 new needs (🌲 Holz, 🐞 Insekten, ❄ Kälte); Tiere (5) become the mammals, Raubtiere (25) the mammal predators, Vögel (24) come after the meteor. | Dinos before apes, as asked; every kind arises by the three existing verbs. |
| 4 | **Three new consequences, all generic and warned one round ahead:** *Jagd* (a hunter group ≥ 3 hunts the prey next to it; the old Rudel is one instance; a herd ≥ 3 can be safe), *Gletscher* (an Eis group ≥ 4 freezes 2 neighbours; the old Vulkan rule with other numbers; Eis on the sun face thaws; a Feuerstelle keeps the ice away), *Einschlag* (scripted, explained, warned from the level start: after the first twist every dinosaur becomes Erde). | Philipp: dangers are consequences; the meteor that ends the dinosaurs is history, so it is scripted but explained. |
| 5 | **Eras replace acts for carry-over:** the world carries over within an era (overnight, retire, fit, repair, `ensure`), every era starts on a fresh validated pool board (the look changes completely). | Same rule as before, one level of granularity finer. |
| 6 | **Save migration by content:** every old level maps to the new level that continues it (`OLD_TO_NEW`, section 8); stars, steps, win days and points are kept; the new levels before a player's position open at once as „Nachholen“ (optional, no story spoiler, they lie in the past), the daily unlock continues after the mapped position. | Nobody loses progress or stars; veterans get extra content at once. |
| 7 | **Stars and points unchanged in method** (`stars12.py` = `stars11.py`): ★★★ where the good bot gets it in ≈ 55 %, ★★ where the average player gets ★★ or better in ≥ 85 % and the good bot in ≥ 98 %, at least the casual bot's median (levels 1–5) or 35th percentile; par = ★★★ + 4. | Feedback 8 Nov („2 Sterne gut erreichbar“) stays binding. |
| 8 | **Welt des Tages** after level 60 rotates over one strong level per era (20 templates). | The streak keeps its meaning. |

---

## 1. The three verbs and the principles (unchanged)

Exactly as `GDPD_SCHOEPFUNG.md` 1–3 and Build 12: **Erschaffen** (3 equal in a new straight row grow, `once`, late
pass: every straight row of a row kind on the board has grown after each action), **Verbinden / Gedeihen** (needs from
the 4 neighbours across edges, lasting seals, G = 2 satt rounds to grow, H = 4 to starve, morning reserve 3),
**Zusammenwachsen** (strength = min(group size, 3)). Principles: dangers are warned consequences; no step limit, no
failing, no dead ends (rows, thriving, rain and the gift can always remake what a task counts); progress drops on
losses; few kinds at once (≤ 6 visible kinds besides water and ≤ 3 growable kinds on every start board).

---

## 2. Eras (Zeitalter) and their look

`Campaign.era_of(n)` returns the era id; `Campaign.era(n)` the look dictionary for `World.set_era` (`Eras.ERAS`).
The overview shows one tile per **reached** era (its German title and icon), opening into its level dots; later eras
are one „?“ tile. The first level of an era shows the era card (title + line) before the level card.

| # | id | tile title · card line (German) | levels | sky (`backdrop`) | water | land / life | ambient | `Eras` preset |
|---|---|---|---|---|---|---|---|---|
| 1 | `urerde` | „Urerde“ · „Die Erde ist jung.“ | 1–4 | near-black red, glow from below | dark grey, steaming, dead | basalt, glowing lava cracks | embers, steam | `glut` (1–3), `glut_kuehl` (4) |
| 2 | `urozean` | „Urozean“ · „Das erste Meer.“ | 5–7 | brown-orange haze, first clouds (count = rain charges) | grey-brown, Ursuppe ochre | wet dark rock | drizzle, far lightning | `dunst` |
| 3 | `leben` | „Erstes Leben“ · „Leben im Wasser.“ | 8–11 | haze → blue: `sky_blue = clamp(Algen / 8, 0, 1)` (level 11 ends clear blue) | cells glow, algae streaks | bare land | steam fades | `dunst` → `blau` (mix by algae) |
| 4 | `kambrium` | „Kambrium“ · „Das Meer wimmelt.“ | 12–14 | clear pale blue, few clouds | **clear turquoise**, Quallen drift and pulse (soft glow), Trilobiten crawl on the shallow floor next to rock | bare grey-brown land, **no plants** | slow swell | `kambrium` (new) |
| 5 | `fische` | „Zeit der Fische“ · „Fische erobern das Meer.“ | 15–17 | as 4, cumulus | deep blue, fish schools (one school per group, size ~ group) | bare land, algae at the shore | splashes | `meer` (new) |
| 6 | `landpflanzen` | „Grün an Land“ · „Pflanzen gehen an Land.“ | 18–20 | clear blue | blue-green | Moos velvet, Farn fronds, first green at the shore | mist over moss | `landgang` (new: damp shore, ferns) |
| 7 | `urwald` | „Urwald“ · „Riesige Wälder.“ | 21–24 | humid green-grey haze, warm light; from level 22 the **sun face** (top = day) | dark, swampy, roots | giant ferns and conifer-like trees (`primeval`), Insekten: dragonflies over the canopy | mist, buzzing | `karbon` (new; `sunface` on from 22) |
| 8 | `landgang` | „Landgang“ · „Tiere gehen an Land.“ | 25–27 | as 7 | swampy shore | Amphibien (frogs/salamanders) at the shore, Reptilien sun on rocks, eggs | croaking | `karbon` |
| 9 | `saurier` | „Saurierzeit“ · „Die Zeit der Riesen.“ | 28–33 | warm hazy, a far volcano plume | warm blue | cycads/ferns, dinosaur herds (group = one herd), Raubsaurier prowl, Flugsaurier circle above forests | dust, calls | `saurier` (new, `plume`) |
| 10 | `meteor` | „Der Einschlag“ · „Ein Stein vom Himmel.“ | 34–35 | level 34 starts `saurier` with a **glowing meteor in the sky** (warned), the impact turns it to **`asche`**: dark ash sky, red dim sun, ash falling; level 35 clears from `asche` to `tag` by `dust_clear = clamp(Wiesen / 10, 0, 1)` | grey | crater rim, ash fields (Erde), small mammals peek out | ash flakes | `saurier` → impact → `asche` (new); 35: `asche` → `erholung` mixed by `dust_clear` |
| 11 | `saeuger` | „Säugetiere“ · „Die Säugetiere übernehmen.“ | 36–39 | normal, cumulus | clear | meadows, mammal herds (`wild`), wolves | birds (from 36) | `saeuger` (new) |
| 12 | `eiszeit` | „Eiszeit“ · „Die Welt friert.“ | 40–42 | pale cold sky, low sun; snow flurries | cold blue, ice floes; Eis fields are white-blue sheets that merge into one glacier | snow on the ground of every land kind, Mammuts with fur | breath steam, snow | `eiszeit` (new: `blanket` snow, `ice`) |
| 13 | `affen` | „Affen“ · „Leben in den Bäumen.“ | 43–45 | warm, golden | clear | savanna grass (Wiese golden), forests with climbing Affen, Frühmenschen stand | heat shimmer | `savanne` (new) |
| 14 | `feuer` | „Feuer“ · „Der erste Funke.“ | 46–47 | `savanne` evening; level 47 cold (`eiszeit` light) | as before | Feuerstellen glow and smoke; warm light circle around them | sparks | `feuer` (46, new), `jaeger` (47: ice-age steppe) |
| 15 | `jaeger` | „Jäger und Sammler“ · „Jagen und sammeln.“ | 48–49 | `savanne` | clear | camps, hunters, first huts | smoke | `jaeger` (48), `menschen` (49) |
| 16 | `ackerbau` | „Ackerbau“ · „Die Menschen säen.“ | 50–53 | seasons as the old act 4 (sun face on) | clear | Saat rows, golden Äcker, Hütten → Dörfer | – | `fruehling` (50), `sommer` (51), `herbst` (52–53): the sun face is needed for Saat |
| 17 | `glaube` | „Glaube“ · „Die Menschen glauben.“ | 54–55 | evening | clear | churches, villages, towns | bells (sound later) | `glaube` (new) |
| 18 | `staedte` | „Große Städte“ · „Zu viele Menschen.“ | 56 | normal | flood rising on warned faces | towns | – | `abend` |
| 19 | `industrie` | „Industrie“ · „Rauch und Maschinen.“ | 57–58 | smog greys the sky (0.15 per Industrie) | as before | factories | smoke | `abend` + smog |
| 20 | `gleichgewicht` | „Gleichgewicht“ · „Alles in Balance.“ | 59–60 | golden evening; on `hold` progress the light warms | calm, mirror | everything alive, no warnings | birds, slow wind | `vollendet` |

**The looks are specified in `GDPD_ERDGESCHICHTE_GRAFIK.md`** (binding for art: preset keys, colours, `blanket`,
`ice`, `plume`, `dust_sun`, falling snow/ash, model branches, the meteor and ice-age events, prototypes); the table
above is only the contract between the rules and that spec (which preset a level uses, and the two values the rules
feed: `sky_blue` from the Algen and `dust_clear` from the Wiesen of level 35). `Eras.of(era_id, level)` replaces
`Eras.of(act, level)`; `Eras.act_of` is removed (the era comes from the level config).

---

## 3. Kinds

40 kinds. Ids 0–26 exist (`FieldData`, `GDPD_SCHOEPFUNG.md` 2); **27–39 are new**. Board code: one letter per id,
`CODE = "EwWAgTHhDSKGIMPoR" + "LUzafmnvrs" + "qtibedxpcjkyF"`. The water family (`WATERS`) grows by Quallen and
Trilobiten (they count as water for wetness, the water body, flood and fire). `LIVING` (hunger icons) gets
Amphibien, Saurier, Raubsaurier, Mammut, Affen, Frühmenschen.

| id | key | name (German) · plural | icon | code | family | arises by | gives (source of) | falls to (danger) |
|---|---|---|---|---|---|---|---|---|
| 27 | `jelly` | Qualle · Quallen | `jelly` | `q` | water | row of 3 Algen (levels 12–17, 26–27); rain on Algen (15–17, 26–27) | 💧 | – (retire: Algen) |
| 28 | `trilo` | Trilobit · Trilobiten | `trilo` | `t` | water | Qualle with ⛰⛰ (2 Fels strength, Gedeihen) | 💧 | – |
| 29 | `insects` | Insekten · Insekten | `insects` | `i` | animal (small) | Farn with 🌲🌲 (2 Wald strength) | 🐞 Insekten (`bugs`) | Moos (fire) |
| 30 | `amphib` | Amphibie · Amphibien | `amphib` | `b` | animal | Landgang: a Fisch next to Moos (🦶) for 2 rounds → the Moos becomes Amphibien, the fish field Algen | – | Moos (hunger, fire) |
| 31 | `reptile` | Reptil · Reptilien | `reptile` | `e` | animal | row of 3 Amphibien | – | – |
| 32 | `sauro` | Saurier · Saurier | `sauro` | `d` | animal (herbivore) | row of 3 Wälder (levels 28–33); rain on a Wald next to Farn | 🍖 Beute (`prey`) | Wald (hunger), Farn (Jagd) |
| 33 | `rex` | Raubsaurier · Raubsaurier | `rex` | `x` | animal (predator) | row of 3 Saurier | – | Wald (hunger) |
| 34 | `ptero` | Flugsaurier · Flugsaurier | `ptero` | `p` | animal (air) | Wald with 🐟🐟 (Gedeihen); row of 3 Wälder | – | Farn (fire) |
| 35 | `ice` | Eis · Eis | `ice` | `c` | water-like land (not `WATERS`: gives no 💧, does not burn) | start board; Gletscher (freezes neighbours) | ❄ Kälte (`cold`) | – (thaws in the sun: Wasser) |
| 36 | `mammoth` | Mammut · Mammuts | `mammoth` | `j` | animal | row of 3 Tiere (eiszeit) | 🍖 (not used) | Wald (hunger); never freezes |
| 37 | `apes` | Affe · Affen | `apes` | `k` | animal | Tiere with 🌲🌲 (Gedeihen) | – | Wiese (fire) |
| 38 | `early` | Frühmensch · Frühmenschen | `early` | `y` | people (early) | row of 3 Affen | – | Affen (hunger: they go back to the trees) |
| 39 | `camp` | Feuerstelle · Feuerstellen | `camp` | `F` | finished | Frühmensch with ⛰ + 🌲 (Gedeihen) | 🔥 Wärme (`heat`) | – ; no field next to it freezes |

Re-used kinds in new roles (no new id): **Tiere (5)** are the mammals from level 35 on (small mammals survive the
impact), **Raubtiere (25)** the wolves, **Vögel (24)** appear after the meteor (level 36), **Wald (2)** is the
source of 🌲. `FieldData.KIND_COUNT` becomes 40; `KIND_KEY`, `KIND_NAME`, `KIND_SHORT`, `KIND_ARTICLE`
(die Qualle, der Trilobit, die Insekten, die Amphibie, das Reptil, der Saurier, der Raubsaurier, der Flugsaurier,
das Eis, das Mammut, der Affe, der Frühmensch, die Feuerstelle), `KIND_PLURAL`, `KIND_ICON`, `DOWN`, `TIER`
(27: 5, 28: 5, 29: 5, 30: 6, 31: 6, 32: 7, 33: 8, 34: 7, 35: 0, 36: 7, 37: 8, 38: 9, 39: 9) get the new entries.
New icons (SVG, `icons/`): the 13 kinds plus need icons `wood` (tree), `bugs` (beetle), `cold` (snowflake); hint
icons `ice` (glacier warning) and `meteor_fall` (impact warning). Models (`models.gd`, `GDPD_SCHOEPFUNG_GRAFIK.md`
style): translucent pulsing jellyfish, armoured crawling trilobites, dragonfly swarm, frogs, lizards with eggs,
long-neck herds, a T-rex silhouette, flying pterosaurs, an ice sheet (merging), woolly mammoths, apes on branches,
upright early humans with spears, a campfire with smoke and light.

### 3.1 Needs and sources (additions)

| need | icon | sources (all levels) | new |
|---|---|---|---|
| `wood` | 🌲 | Wald | yes: Insekten, Affen, Feuerstelle |
| `bugs` | 🐞 | Insekten | yes: Amphibien |
| `cold` | ❄ | Eis | yes: Mammut |
| `heat` | 🔥 | Lava, **Feuerstelle** | Feuerstelle added |
| `plants` | 🌾 | Wiese, Wald, **Farn** | Farn added (Saurier eat ferns) |
| `prey` | 🍖 | Tiere, **Saurier** | Saurier added |
| `shore` | 🦶 | Wiese, **Moos** | Moos added (Landgang on moss) |

No old level changes by these additions (no old level has Farn next to Tiere, Saurier, Moos with fish, or a
Feuerstelle); the model re-ran all old levels inside the new campaign (section 11).

| thriver | needs | result | levels |
|---|---|---|---|
| Qualle | ⛰ 2 | Trilobit | 13–14 |
| Moos | 💧 2 | Farn | 20–21 |
| Farn | ☀ 1, 💧 1 | Wald („Farne suchen das Licht“) | 22–23 |
| Farn | 🌲 2 | Insekten | 24 |
| Fisch | 🦶 1 | spawn: the Moos becomes Amphibien, the fish field Algen | 25–27 |
| Amphibie | 🐞 1 | – (starve → Moos) | 26–27 |
| Saurier | 🌾 1 | – (starve → Wald) | 28–33 |
| Raubsaurier | 🍖 1 | – (starve → Wald) | 29, 31–33 |
| Wald | 🐟 2 | Flugsaurier (30) / Vögel (36) | 30, 36 |
| Erde (ash) | 🌾 3 | Wiese („Aus Asche wird Wiese“) | 34 |
| Eis | ☀ 1 | Wasser (thaws) | 40, 42, 47 |
| Mammut | 🌾 1, ❄ 1 | – (starve → Wald) | 41–42 |
| Tiere | 🌲 2 | Affen | 43–45 |
| Frühmensch | ⛰ 1, 🌲 1 | Feuerstelle | 46 |
| Frühmensch | 🔥 1 (47) · 🔥 1, 🍖 1 (48) | – (starve → Affen) | 47–48 |

All old thrive rules stay (`GDPD_SCHOEPFUNG.md` 3.4).

---

## 4. New rules (all generic; the model is `engine10.py`)

### 4.1 Jagd (generic hunt; the old Rudel is one instance)

`cfg.hunt = [[hunter, [prey kinds], falls_to, at, herd], …]`.

- **Trigger (end of a round, step 9 of 3.8):** a field of `hunter` in a group of ≥ `at` that touches a field of a
  prey kind, unless `herd > 0` and that prey field is in a prey group of ≥ `herd` („Eine Herde schützt“).
- **Warning:** `pack_warn` with the threatened prey fields (as v2).
- **Effect one round later:** every warned prey field that is *still* a target falls to `falls_to` (event
  `pack_hunt`, a loss if it was a made goal field; for `satt` goals the count simply drops). If anything was hunted,
  no new warning this round.
- **Avoid:** split the hunters (< 3 together), move the prey away, put prey together in a herd (where `herd` is set),
  the meteor tool on a hunter (level 38).
- Instances: level 38 (old 23) `[[Raubtiere, [Tiere], Wiese, 3, 0]]`; 32 `[[Raubsaurier, [Saurier], Farn, 3, 0]]`;
  33 `[[Raubsaurier, [Saurier], Farn, 3, 3]]`; 39 `[[Raubtiere, [Tiere], Wiese, 3, 3]]`; 48 „zu viele Jäger“
  `[[Frühmenschen, [Tiere], Wiese, 3, 0]]`.
- Texts: pill „Rudel jagt!“ · „Trenn die Raubtiere“ (Raubtiere), „Raubsaurier jagen!“ · „Trenn die Raubsaurier“,
  „Die Tiere fliehen!“ · „Trenn die Jäger“ (Frühmenschen); next action „Trenn die Raubsaurier!“ / „Trenn die
  Jäger!“ / „Bilde eine Herde!“ (when moving the prey into a herd of ≥ `herd` is the averting twist).

### 4.2 Gletscher, Tauen, Feuerstelle (the ice age)

`cfg.glacier = {at: 4, max: 2, rest: 2, over: [Wasser, Wiese, Wald, Tiere, Erde, Moos, Farn, Affen, Frühmenschen],
immune: [Mammut, Feuerstelle]}` — the Vulkan rule with other parameters (`_volcano_step9` becomes
`_spread_step9(params)`, used for both).

- **Trigger:** an Eis group of ≥ 4 whose fields are not resting. **Warning:** `glacier_warn` on the crater (the member
  with most Eis neighbours, ties: lowest id): frost creeps out, the threatened neighbours get a blue rim.
- **Effect one round later** if the group is still ≥ 4: up to 2 neighbours of the group (crater first, then by id)
  that are in `over`, not `immune` and **not next to a Feuerstelle** become Eis (event `freeze`; a loss on a made
  goal field). The group rests 2 rounds. Otherwise `glacier_calm`.
- **Tauen:** Eis on the sun face thaws to Wasser after 2 round ends (a normal thrive rule `Eis: ☀ 1 → Wasser`; pill
  „Eis taut“). Start boards never have Eis on the sun face (start rule `satt_max`).
- **Avoid:** split the ice (< 4 together), turn ice to the top, keep a Feuerstelle next to what must not freeze.
- Texts: pill „Gletscher wächst!“ · „Teil das Eis“; next action „Teil das Eis!“ or „Eis in die Sonne drehen“.

### 4.3 Einschlag (scripted, explained, warned)

`cfg.impact = {at: 1, kill: {Saurier: Erde, Raubsaurier: Erde, Flugsaurier: Erde}}` (level 34 only).

- **Warned from the level start:** the level card says „Ein Stein fällt vom Himmel.“ · „Neu: Einschlag · Die Saurier
  sterben aus“; the meteor glows in the sky; the HUD pill „Meteor kommt!“ and the next action „Dreh, der Meteor
  kommt“ (any twist; the hint suggests the best one).
- **Effect** at the end of round `at` (right after the rows, before fire): every field of a `kill` kind becomes the
  given kind (event `impact` with the list of fields; never a `goal_loss`: the goal counts Wiesen). The camera shows
  the impact on the face with most dinosaurs (2.5 s, skippable), the era look blends `saurier` → `asche` (`GDPD_ERDGESCHICHTE_GRAFIK.md` 8.1) (2 s), the
  survivors (Tiere) shake off the dust. Rows through the new Erde fields grow in the late pass at once (Build 12),
  so the player sees the first green immediately. (The model has no late pass, so there these ash rows only count
  when a twist forms them again: level 34 is somewhat easier in the game than in 11; its ★★★/★★ = 4/8 are kept and
  re-measured with the tour check `impact_scripted`.)
- **After the impact:** Erde with 🌾 3 (a plant group of 3, or several groups) becomes Wiese („Aus Asche wird Wiese“),
  3 Erde in a row become Wiese, rain on Erde makes Wiese; goal `make Wiese 12`.
- Why scripted: the extinction is the turning point of the history, not a player mistake; it is never a loss, it is
  shown, explained and the level goal builds on it (the ash is the material for the meadows).

### 4.4 Rain conditions by kind

A rain rule's condition may be a kind id: the tapped field must touch that kind. Used for „Regen lockt Saurier“
`[Wald, Farn, Saurier]` (levels 28–33) and „Regen lockt Tiere“ `[Wald, Wiese, Tiere]` (40–42, 48), the dinosaur and
ice-age versions of the old valve (`GDPD_SCHOEPFUNG.md` v2 item 5: no dead ends after starvation).
„Regen wird Schnee“ `[Wasser, shore, Eis]` (levels 41–42, first rule): rain on shore water makes Eis, so a Mammut
can always get ❄ again (without it 35–48 % of casual games in 41–42 ended with all ice thawed and no way back).

### 4.5 Order of a round (3.8 of the old spec, extended)

1 rows (creation, `once`, consume) · 2 `steps += 1` · **2b Einschlag** · 3 fire · 4 Blitz · 5 Vulkan · **5b
Gletscher** · 6 Smog · 7 Flut · 8 Krieg · **9 Jagd (generic, replaces Rudel)** · 10 Gedeihen (seal step first; thaw
is a thrive) · 11 Glaube → meteor · 12 rain refill · 13 Build 12 late pass · 14 goal check (hold, Gnade).
`hold` (level 60) counts `freeze` and `pack_hunt` as damage.

### 4.6 Still reasons and field sheet

A kind outside the level's rows shows its `still` reason as before; new reasons: `dino` „Saurier wachsen nicht mehr“
(level 34 before the impact: Saurier are no row kind there), `ice` „Eis wächst nicht in Reihen“, `camp` „Feuer
wächst nicht“ (Feuerstelle). The field sheet (`ui._fill_sheet`) shows the
row picture from `row_result(k)` and the thrive line from the level's thrive table (e.g. „Farn + 🌲🌲 → Insekten“).

---

## 5. The campaign: 60 levels

### 5.1 Level table (texts, goal, stars, points)

Goal counting (unchanged, `GDPD_SCHOEPFUNG.md` 3.7): `make` = made − lost (a danger on a made goal field is −1 with the „−1 …“ cue; growing up, a consume or a fish going ashore is no loss); `satt` = goal fields satt at the round end (lasting seals; it drops only when a danger changes a satt field or an unfed one starves); `group` = the biggest group; `hold` = rounds in a row with all sub-goals met and no damage. Two sub-goals: both chips are shown, the level is won when both hold at one round end. Stars: ★★★ / ★★ thresholds in steps (★ = done, never a fail), from the simulation (11.2). `par` = ★★★ + 4. Points = 30 + 10 × stars + 5 × max(0, par − steps); the last column is the model average per game (good bot / average player). „old n“ = the level of „Die Schöpfung“ it continues (migration, 9).

| # | era | title | story (card) | task chip | goal (exact) | new (reveal caps · line) | ★★★ / ★★ ≤ | par | points good / average |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Urerde | Glut (old 1) | „Die Erde glüht.“ | „Mach 6 Felsen“ | make Fels 6 | „Neu: Drehen“ · „Bring 3 gleiche in eine Reihe.“ | 4 / 10 | 8 | 73 / 68 |
| 2 | Urerde | Abkühlen (old 2) | „Das Meer kühlt die Glut.“ | „Mach 11 Felsen“ | make Fels 11 | „Neu: Abkühlen“ · „Lava zwischen zwei Wasser“ | 4 / 10 | 8 | 72 / 64 |
| 3 | Urerde | Vulkan (old 3) | „Die Glut bricht aus.“ | „Mach 14 Felsen“ | make Fels 14 | „Neu: Vulkan“ · „Zu viel Lava bricht aus“ | 5 / 11 | 9 | 77 / 68 |
| 4 | Urerde | Urkontinent (old 4) | „Land entsteht.“ | „Lass 11 Erde entstehen“ | make Erde 11 | „Neu: Land“ · „3 Felsen werden Erde“ | 5 / 14 | 9 | 69 / 65 |
| 5 | Urozean | Atmosphäre (old 5) | „Dampf wird Himmel.“ | „Lass 14 Erde entstehen“ | make Erde 14 | „Neu: Regen“ · „Dampf macht Wolken“ | 5 / 17 | 9 | 75 / 77 |
| 6 | Urozean | Urmeer (old 6) | „Das Meer wird reich.“ | „Mach 10 Ursuppe“ | make Ursuppe 10 | „Neu: Ursuppe“ · „Wasser braucht Glut und Fels“ | 4 / 11 | 8 | 73 / 70 |
| 7 | Urozean | Heiße Quellen | „Es brodelt im Meer.“ | „Mach 14 Ursuppe“ | make Ursuppe 14 | „Neu: Heiße Quellen“ · „Viel Glut, viel Ursuppe“ | 4 / 9 | 8 | 75 / 72 |
| 8 | Erstes Leben | Erstes Leben (old 7) | „Leben beginnt.“ | „Erschaffe 5 Einzeller“ | make Einzeller 5 | „Neu: Leben“ · „Ursuppe braucht viel Wärme“ | 5 / 10 | 9 | 75 / 69 |
| 9 | Erstes Leben | Leben teilt sich (old 8) | „Aus eins wird zwei.“ | „Erschaffe 11 Einzeller“ | make Einzeller 11 | „Neu: Teilen“ · „Leben weckt Leben“ | 5 / 11 | 9 | 79 / 77 |
| 10 | Erstes Leben | Algen (old 9) | „Grün im Meer.“ | „Lass 5 Algen wachsen“ | make Algen 5 | „Neu: Algen“ · „3 Einzeller werden Algen“ | 4 / 9 | 8 | 71 / 64 |
| 11 | Erstes Leben | Sauerstoff | „Der Himmel wird blau.“ | „Mach einen Algenteppich aus 5“ | group Algen 5 | „Neu: Sauerstoff“ · „Algen machen den Himmel blau“ | 5 / 14 | 9 | 73 / 60 |
| 12 | Kambrium | Quallen | „Die ersten Tiere.“ | „Lass 6 Quallen entstehen“ | make Quallen 6 | „Neu: Quallen“ · „3 Algen werden Qualle“ | 4 / 10 | 8 | 70 / 66 |
| 13 | Kambrium | Trilobiten | „Panzer aus Stein.“ | „Lass 7 Trilobiten entstehen“ | make Trilobiten 7 | „Neu: Trilobiten“ · „Quallen brauchen zwei Felsen“ | 4 / 9 | 8 | 74 / 68 |
| 14 | Kambrium | Vielfalt | „Leben in allen Formen.“ | „Lass 6 Quallen entstehen“ + „Lass 5 Trilobiten entstehen“ | make Quallen 6 + make Trilobiten 5 | „Neu: Vielfalt“ · „Zwei Ziele zugleich“ | 5 / 14 | 9 | 72 / 67 |
| 15 | Zeit der Fische | Fische (old 16) | „Die ersten Fische.“ | „Erschaffe 6 Fische“ | make Fische 6 | „Neu: Fische“ · „3 Quallen werden Fisch“ | 5 / 11 | 9 | 69 / 62 |
| 16 | Zeit der Fische | Schwärme (old 17) | „Fische ziehen zusammen.“ | „Mach einen Schwarm aus 5“ | group Fische 5 | „Neu: Schwarm“ · „Fische schwimmen zusammen“ | 5 / 19 | 9 | 72 / 59 |
| 17 | Zeit der Fische | Fischreich | „Das Meer ist voll.“ | „Erschaffe 7 Fische“ | make Fische 7 | „Neu: Fischreich“ · „Algen, Quallen, Fische“ | 6 / 13 | 10 | 75 / 67 |
| 18 | Grün an Land | Moos (old 10) | „Grün kriecht an Land.“ | „Lass 9 Moos wachsen“ | make Moos 9 | „Neu: Moos“ · „Algen machen das Land grün“ | 5 / 10 | 9 | 74 / 67 |
| 19 | Grün an Land | Farne (old 11) | „Grün wird höher.“ | „Lass 7 Farne wachsen“ | make Farn 7 | „Neu: Farne“ · „3 Moos werden Farn“ | 6 / 13 | 10 | 71 / 64 |
| 20 | Grün an Land | Feuchtes Ufer | „Am Ufer wird es grün.“ | „Mach ein Farnfeld aus 11“ | group Farn 11 | „Neu: Feuchtes Ufer“ · „Moos am Wasser wird Farn“ | 5 / 13 | 9 | 77 / 70 |
| 21 | Urwald | Wälder (old 12) | „Die ersten Wälder.“ | „Lass 7 Wälder wachsen“ | make Wald 7 | „Neu: Blitz“ · „Trockener Wald brennt“ | 6 / 13 | 10 | 72 / 68 |
| 22 | Urwald | Licht (old 13) | „Farne suchen das Licht.“ | „Lass 12 Wälder wachsen“ | make Wald 12 | „Neu: Sonne“ · „Oben ist Tag“ | 5 / 11 | 9 | 78 / 76 |
| 23 | Urwald | Urwald | „Ein Wald ohne Ende.“ | „Mach einen Urwald aus 9“ | group Wald 9 | „Neu: Urwald“ · „Großer Wald braucht Wasser“ | 4 / 11 | 8 | 76 / 69 |
| 24 | Urwald | Insekten | „Im Urwald summt es.“ | „Lass 9 Insekten schwärmen“ | make Insekten 9 | „Neu: Insekten“ · „Farn zwischen Wäldern“ | 5 / 11 | 9 | 75 / 69 |
| 25 | Landgang | Landgang (old 19) | „Raus aus dem Wasser.“ | „Bring 6 Amphibien an Land“ | make Amphibien 6 | „Neu: Landgang“ · „Fische gehen an Land“ | 4 / 9 | 8 | 74 / 65 |
| 26 | Landgang | Frösche | „Frösche haben Hunger.“ | „Gib 8 Amphibien Futter“ | satt Amphibien 8 | „Neu: Hunger“ · „Amphibien fressen Insekten“ | 5 / 16 | 9 | 77 / 67 |
| 27 | Landgang | Reptilien | „Eier an Land.“ | „Lass 4 Reptilien schlüpfen“ | make Reptilien 4 | „Neu: Reptilien“ · „3 Amphibien werden Reptil“ | 4 / 16 | 8 | 76 / 69 |
| 28 | Saurierzeit | Saurier (old 20) | „Riesen ziehen durchs Land.“ | „Gib 6 Sauriern Futter“ | satt Saurier 6 | „Neu: Saurier“ · „Saurier brauchen Pflanzen“ | 3 / 8 | 7 | 74 / 68 |
| 29 | Saurierzeit | Raubsaurier (old 21) | „Jäger und Gejagte.“ | „Mach 3 Raubsaurier satt“ | satt Raubsaurier 3 | „Neu: Raubsaurier“ · „Raubsaurier brauchen Saurier“ | 4 / 16 | 8 | 75 / 64 |
| 30 | Saurierzeit | Flugsaurier (old 18) | „Riesen am Himmel.“ | „Lass 6 Flugsaurier fliegen“ | make Flugsaurier 6 | „Neu: Flugsaurier“ · „Flugsaurier brauchen Fische“ | 5 / 11 | 9 | 72 / 65 |
| 31 | Saurierzeit | Nahrungskette (old 22) | „Fressen und gefressen werden.“ | „Mach alle satt“ | satt Raubsaurier 3 + satt Saurier 5 | „Neu: Nahrungskette“ · „Jeder braucht sein Futter“ | 4 / 14 | 8 | 77 / 71 |
| 32 | Saurierzeit | Jagd | „Die Raubsaurier jagen.“ | „Rette 8 Saurier“ | satt Saurier 8 | „Neu: Jagd“ · „3 Raubsaurier jagen Saurier“ | 3 / 10 | 7 | 76 / 71 |
| 33 | Saurierzeit | Herde | „Zusammen sind sie stark.“ | „Bilde eine Herde aus 7“ | group Saurier 7 | „Neu: Herde“ · „Eine Herde schützt“ | 3 / 13 | 7 | 75 / 65 |
| 34 | Der Einschlag | Einschlag | „Ein Stein fällt vom Himmel.“ | „Lass 12 Wiesen wachsen“ | make Wiese 12 | „Neu: Einschlag“ · „Die Saurier sterben aus“ | 4 / 8 | 8 | 79 / 77 |
| 35 | Der Einschlag | Überleben | „Die Kleinen überleben.“ | „Gib 6 Tieren Futter“ | satt Tiere 6 | „Neu: Säugetiere“ · „Tiere brauchen Pflanzen“ | 3 / 8 | 7 | 74 / 69 |
| 36 | Säugetiere | Vögel | „Federn statt Schuppen.“ | „Lass 6 Vögel nisten“ | make Vögel 6 | „Neu: Vögel“ · „Vögel brauchen Fische“ | 5 / 11 | 9 | 73 / 65 |
| 37 | Säugetiere | Raubtiere | „Wölfe auf der Jagd.“ | „Mach 3 Raubtiere satt“ | satt Raubtiere 3 | „Neu: Raubtiere“ · „Raubtiere brauchen Tiere“ | 4 / 16 | 8 | 75 / 63 |
| 38 | Säugetiere | Rudel (old 23) | „Das Rudel ist hungrig.“ | „Rette 6 Tiere“ | satt Tiere 6 | „Neu: Dein Meteor“ · „Er fällt, wo du tippst“ | 2 / 7 | 6 | 74 / 70 |
| 39 | Säugetiere | Herden | „Herden ziehen weit.“ | „Bilde eine Herde aus 7“ | group Tiere 7 | „Neu: Herden“ · „Eine Herde schützt“ | 3 / 13 | 7 | 73 / 65 |
| 40 | Eiszeit | Eiszeit | „Es wird kalt.“ | „Gib 9 Tieren Futter“ | satt Tiere 9 | „Neu: Eiszeit“ · „Zu viel Eis friert“ | 4 / 14 | 8 | 77 / 71 |
| 41 | Eiszeit | Mammut | „Riesen im Schnee.“ | „Mach 4 Mammuts satt“ | satt Mammut 4 | „Neu: Mammut“ · „Mammut braucht Gras und Eis“ | 5 / 11 | 9 | 76 / 64 |
| 42 | Eiszeit | Tauwetter | „Das Eis weicht.“ | „Mach alle satt“ | satt Mammut 2 + satt Tiere 5 | „Neu: Tauwetter“ · „Eis taut in der Sonne“ | 3 / 13 | 7 | 75 / 70 |
| 43 | Affen | Affen | „Hoch in die Bäume.“ | „Lass 9 Affen klettern“ | make Affen 9 | „Neu: Affen“ · „Tiere zwischen zwei Wäldern“ | 5 / 11 | 9 | 74 / 65 |
| 44 | Affen | Horde | „Affen halten zusammen.“ | „Bilde eine Horde aus 7“ | group Affen 7 | „Neu: Horde“ · „Affen bleiben zusammen“ | 4 / 12 | 8 | 75 / 66 |
| 45 | Affen | Aufrecht | „Sie stehen auf.“ | „Lass 5 Frühmenschen gehen“ | make Frühmenschen 5 | „Neu: Frühmenschen“ · „3 Affen werden Frühmensch“ | 5 / 12 | 9 | 75 / 70 |
| 46 | Feuer | Feuer | „Ein Funke im Dunkeln.“ | „Mach 7 Feuerstellen“ | make Feuerstelle 7 | „Neu: Feuer“ · „Stein und Holz machen Feuer“ | 5 / 10 | 9 | 73 / 63 |
| 47 | Feuer | Wärme | „Feuer gegen die Kälte.“ | „Wärme 5 Frühmenschen“ | satt Frühmenschen 5 | „Neu: Wärme“ · „Feuer hält das Eis fern“ | 4 / 16 | 8 | 72 / 62 |
| 48 | Jäger und Sammler | Jäger | „Die Jagd beginnt.“ | „Mach 4 Jäger satt“ | satt Frühmenschen 4 | „Neu: Jäger“ · „Zu viele Jäger verjagen Tiere“ | 3 / 7 | 7 | 71 / 62 |
| 49 | Jäger und Sammler | Sesshaft (old 24) | „Sie bleiben hier.“ | „Versorge 3 Hütten“ | satt Hütte 3 | „Neu: Hütten“ · „3 Frühmenschen bauen eine Hütte“ | 4 / 14 | 8 | 77 / 64 |
| 50 | Ackerbau | Saat (old 14) | „Korn reift im Sommer.“ | „Lass 5 Felder reifen“ | make Acker 5 | „Neu: Saat“ · „Saat braucht Sonne und Wasser“ | 6 / 11 | 10 | 76 / 67 |
| 51 | Ackerbau | Ernte (old 15) | „Zeit der Ernte.“ | „Bring 6 Äcker zusammen“ | group Acker 6 | „Neu: Ernte“ · „Großes Feld, große Ernte“ | 6 / 14 | 10 | 73 / 64 |
| 52 | Ackerbau | Ackerbau (old 25) | „Felder statt Jagd.“ | „Versorge 5 Hütten“ | satt Hütte 5 | „Neu: Ackerbau“ · „Regen neben Hütten: Saat“ | 5 / 13 | 9 | 76 / 63 |
| 53 | Ackerbau | Dörfer (old 26) | „Aus Hütten werden Dörfer.“ | „Mach 4 Dörfer satt“ | satt Dorf 4 | „Neu: Dörfer“ · „Dorf braucht Nahrung und Arbeit“ | 4 / 11 | 8 | 70 / 59 |
| 54 | Glaube | Glaube (old 27) | „Die ersten Kirchen.“ | „Mach 2 Städte satt“ | satt Stadt 2 | „Neu: Glaube“ · „Kirche an Kirche: Krieg!“ | 3 / 7 | 7 | 73 / 67 |
| 55 | Glaube | Frieden | „Frieden zwischen den Dörfern.“ | „Mach 2 Städte satt“ + „Mach 2 Dörfer satt“ | satt Stadt 2 + satt Dorf 2 | „Neu: Frieden“ · „Halte die Kirchen getrennt“ | 3 / 8 | 7 | 72 / 66 |
| 56 | Große Städte | Städte | „Immer mehr Menschen.“ | „Mach 3 Städte satt“ | satt Stadt 3 | „Neu: Flut“ · „Zu viel Stadt: Flut!“ | 5 / 15 | 9 | 76 / 63 |
| 57 | Industrie | Fabriken (old 28) | „Rauch über den Städten.“ | „Mach 3 Städte satt“ | satt Stadt 3 | „Neu: Fabriken“ · „Fabrik macht Smog“ | 4 / 16 | 8 | 70 / 59 |
| 58 | Industrie | Rauch | „Mehr Fabriken, mehr Rauch.“ | „Mach 3 Städte satt“ | satt Stadt 3 | „Neu: Zwei Fabriken“ · „Schütz die Natur“ | 5 / 15 | 9 | 76 / 60 |
| 59 | Gleichgewicht | Gleichgewicht (old 29) | „Alles im Gleichgewicht.“ | „Mach alle satt“ | satt Stadt 2 + satt Tiere 4 | „Neu: Gleichgewicht“ · „Menschen und Tiere satt“ | 5 / 19 | 9 | 72 / 56 |
| 60 | Gleichgewicht | Blühende Welt (old 30) | „Deine Welt lebt.“ | „Halte 3 Runden das Gleichgewicht“ | hold [satt Stadt 2 + satt Tiere 3] 3 | „Neu: Balance“ · „Halte alles satt“ | 6 / 16 | 10 | 73 / 60 |

### 5.2 Level rules (start board, systems, the new thing)

Start board = counts on the 54 fields (rest Wasser), placed by sticker type (½ corners, 40 % edges, 10 % centres per kind), then repaired to the start rules (5.3). Carry-over inside an era (6) fits the player's world to exactly this composition. Every level enables only the systems listed.

| # | start board (rest Wasser) | rules of the level | new thing |
|---|---|---|---|
| 1 | Lava 18, Fels 14, Wasser 22 | rows Lava→Fels; rain Lava→Fels; charges 0 | rows; Lava → Fels (tutorial board 0) |
| 2 | Fels 22, Lava 18, Wasser 14 | rows Lava→Fels; Lava 💧💧→Fels; rain Lava→Fels; charges 0 | first Gedeihen: Lava with 💧💧 cools to Fels |
| 3 | Lava 20, Fels 20, Wasser 14 | rows Lava→Fels; Lava 💧💧→Fels; rain Lava→Fels; charges 0; dangers/tools: Vulkan | danger Vulkan (lava clump ≥ 5), loss −1 |
| 4 | Fels 22, Lava 16, Wasser 16 | rows Fels→Erde, Lava→Fels; Lava 💧💧→Fels; rain Fels→Erde, Lava→Fels; charges 0; dangers/tools: Vulkan | rows Fels → Erde |
| 5 | Fels 18, Lava 14, Wasser 22 | rows Fels→Erde; Lava 💧💧→Fels; rain Lava→Fels, Fels→Erde; charges 0 + steam; dangers/tools: Vulkan | steam → rain charges; rain Fels → Erde |
| 6 | Fels 16, Erde 8, Lava 5, Wasser 25 | rows Fels→Erde; Wasser 🔥🔥⛰→Ursuppe; rain Wasser(shore)→Ursuppe, Fels→Erde; charges 1 +1/4; dangers/tools: Vulkan | Wasser with 🔥🔥 ⛰ → Ursuppe; group strength |
| 7 | Fels 16, Lava 8, Erde 6, Wasser 24 | rows Fels→Erde; Wasser 🔥🔥⛰→Ursuppe; rain Wasser(shore)→Ursuppe, Fels→Erde; charges 1 +1/4; dangers/tools: Vulkan | more Lava (clump on half the boards): Ursuppe vs. Vulkan |
| 8 | Fels 14, Erde 8, Ursuppe 6, Lava 5, Wasser 21 | rows Fels→Erde; Ursuppe 🔥🔥→Einzeller; rain Wasser(shore)→Ursuppe, Fels→Erde; charges 1 +1/4; dangers/tools: Vulkan | Ursuppe with 🔥🔥 → Einzeller |
| 9 | Fels 10, Ursuppe 9, Erde 6, Lava 5, Einzeller 2, Wasser 22 | rows Fels→Erde; Ursuppe ✨→Einzeller; rain Wasser(shore)→Ursuppe, Fels→Erde; charges 1 +1/4; dangers/tools: Vulkan | Einzeller spark Ursuppe (✨) |
| 10 | Einzeller 14, Fels 8, Erde 8, Wasser 24 | rows Einzeller→Algen; Ursuppe ✨→Einzeller; rain Wasser(shore)→Ursuppe; charges 1 +1/5 | rows Einzeller → Algen |
| 11 | Einzeller 13, Fels 8, Erde 6, Algen 3, Ursuppe 3, Wasser 21 | rows Einzeller→Algen; Ursuppe ✨→Einzeller; rain Wasser(shore)→Ursuppe; charges 1 +1/5 | group goal Algen; sky_blue follows the algae |
| 12 | Algen 15, Fels 8, Erde 8, Wasser 23 | rows Algen→Quallen; rain Wasser(shore)→Algen; charges 1 +1/5 | rows Algen → Quallen (new kind 27) |
| 13 | Algen 9, Fels 9, Quallen 8, Erde 6, Wasser 22 | rows Algen→Quallen; Quallen ⛰⛰→Trilobiten; rain Wasser(shore)→Algen; charges 1 +1/5 | Quallen with ⛰⛰ → Trilobiten (new kind 28) |
| 14 | Algen 14, Fels 10, Erde 6, Quallen 3, Wasser 21 | rows Algen→Quallen; Quallen ⛰⛰→Trilobiten; rain Wasser(shore)→Algen; charges 1 +1/5 | two make goals at once (Quallen + Trilobiten) |
| 15 | Quallen 13, Algen 7, Fels 6, Erde 6, Wasser 22 | rows Algen→Quallen, Quallen→Fische; rain Algen→Quallen; charges 1 +1/5 | rows Quallen → Fische (old 16) |
| 16 | Quallen 10, Algen 6, Fels 6, Fische 4, Erde 4, Wasser 24 | rows Algen→Quallen, Quallen→Fische; rain Algen→Quallen; charges 1 +1/5 | group goal in water (old 17) |
| 17 | Quallen 14, Algen 9, Fels 4, Erde 4, Wasser 23 | rows Algen→Quallen, Quallen→Fische; rain Algen→Quallen; charges 1 +1/5 | the full water ladder Algen → Quallen → Fische |
| 18 | Erde 14, Einzeller 6, Fels 6, Algen 4, Wasser 24 | rows Erde→Moos, Einzeller→Algen; Erde 🌿🌿→Moos; rain Erde→Moos; charges 1 +1/5 | Erde with 🌿🌿 → Moos (old 10) |
| 19 | Moos 12, Erde 8, Fels 6, Algen 4, Wasser 24 | rows Erde→Moos, Moos→Farn; Erde 🌿🌿→Moos; rain Moos→Farn, Erde→Moos; charges 1 +1/5 | rows Moos → Farn (old 11) |
| 20 | Moos 12, Erde 8, Fels 4, Farn 3, Algen 3, Wasser 24 | rows Erde→Moos, Moos→Farn; Moos 💧💧→Farn; rain Moos→Farn, Erde→Moos; charges 1 +1/5 | Moos with 💧💧 → Farn; group goal Farn |
| 21 | Farn 10, Moos 10, Erde 4, Fels 4, Algen 3, Wasser 23 | rows Moos→Farn, Farn→Wald; Moos 💧💧→Farn; rain Moos→Farn, Erde→Moos; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Erde, Farn→Erde | rows Farn → Wald; danger Blitz (old 12) |
| 22 | Farn 14, Moos 6, Wald 3, Algen 3, Fels 3, Wasser 25 | rows Moos→Farn, Farn→Wald; Farn ☀💧→Wald; rain Farn→Wald, Moos→Farn; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Moos, Farn→Moos | sun face: Farn with ☀💧 → Wald (old 13) |
| 23 | Farn 12, Moos 6, Wald 4, Algen 4, Fels 3, Wasser 25 | rows Moos→Farn, Farn→Wald; Farn ☀💧→Wald; rain Farn→Wald, Moos→Farn; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Moos, Farn→Moos | group goal Wald against the dry-forest bolt |
| 24 | Farn 10, Wald 8, Moos 6, Algen 4, Wasser 26 | rows Moos→Farn, Farn→Wald; Farn 🌲🌲→Insekten; rain Moos→Farn; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Moos, Farn→Moos, Insekten→Moos | Farn with 🌲🌲 → Insekten (new kind 29) |
| 25 | Quallen 12, Moos 10, Wald 5, Fische 4, Wasser 23 | rows Quallen→Fische; Fische 🦶→spawn Amphibien on Moos, fish → Algen; rain Quallen→Fische; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Moos, Amphibien→Moos | spawn: Fisch + Moos → Amphibien (new kind 30), old 19 |
| 26 | Amphibien 9, Moos 8, Quallen 6, Insekten 4, Fische 4, Wasser 23 | rows Algen→Quallen, Quallen→Fische; Fische 🦶→spawn Amphibien on Moos, fish → Algen; Amphibien 🐞→–, starve→Moos; rain Quallen→Fische, Algen→Quallen; charges 1 +1/5 | needs + hunger for Amphibien (🐞) |
| 27 | Amphibien 12, Moos 8, Insekten 5, Quallen 4, Fische 3, Wasser 22 | rows Algen→Quallen, Quallen→Fische, Amphibien→Reptilien; Fische 🦶→spawn Amphibien on Moos, fish → Algen; Amphibien 🐞→–, starve→Moos; rain Quallen→Fische, Algen→Quallen; charges 1 +1/5 | rows Amphibien → Reptilien (new kind 31) |
| 28 | Moos 10, Saurier 7, Fels 6, Wald 3, Farn 3, Wasser 25 | rows Wald→Saurier, Moos→Farn; Saurier 🌾→–, starve→Wald; rain Moos→Farn, Wald(next to Farn)→Saurier; charges 1 +1/5 | Saurier (new kind 32) need 🌾; rows Wald → Saurier (old 20) |
| 29 | Saurier 10, Moos 7, Farn 5, Fels 4, Wald 3, Wasser 25 | rows Wald→Saurier, Moos→Farn, Saurier→Raubsaurier; Saurier 🌾→–, starve→Wald; Raubsaurier 🍖→–, starve→Wald; rain Moos→Farn, Wald(next to Farn)→Saurier; charges 1 +1/5 | Raubsaurier (new kind 33) need 🍖 (old 21) |
| 30 | Wald 10, Quallen 9, Farn 8, Fische 3, Fels 2, Wasser 22 | rows Wald→Flugsaurier, Quallen→Fische; Wald 🐟🐟→Flugsaurier; rain Farn→Wald; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Farn, Flugsaurier→Farn | Wald with 🐟🐟 → Flugsaurier (new kind 34), old 18 |
| 31 | Saurier 7, Moos 7, Farn 4, Fels 4, Raubsaurier 3, Wald 3, Wasser 26 | rows Wald→Saurier, Moos→Farn, Saurier→Raubsaurier; Saurier 🌾→–, starve→Wald; Raubsaurier 🍖→–, starve→Wald; rain Moos→Farn, Wald(next to Farn)→Saurier; charges 1 +1/5 | two satt goals at once (old 22) |
| 32 | Saurier 10, Moos 7, Raubsaurier 4, Farn 4, Wald 3, Fels 3, Wasser 23 | rows Wald→Saurier, Moos→Farn; Saurier 🌾→–, starve→Wald; Raubsaurier 🍖→–, starve→Wald; rain Moos→Farn, Wald(next to Farn)→Saurier; charges 1 +1/5; dangers/tools: Jagd Raubsaurier≥3 → Saurier→Farn | danger Jagd (hunter group ≥ 3), no meteor |
| 33 | Saurier 10, Moos 6, Farn 5, Wald 4, Raubsaurier 3, Wasser 26 | rows Wald→Saurier, Moos→Farn; Saurier 🌾→–, starve→Wald; Raubsaurier 🍖→–, starve→Wald; rain Moos→Farn, Wald(next to Farn)→Saurier; charges 1 +1/5; dangers/tools: Jagd Raubsaurier≥3 → Saurier→Farn, herd ≥3 safe | group goal; prey in a group ≥ 3 is safe |
| 34 | Saurier 9, Farn 9, Wald 4, Raubsaurier 3, Flugsaurier 3, Tiere 3, Wasser 23 | rows Erde→Wiese; Erde 🌾🌾🌾→Wiese; rain Erde→Wiese; charges 1 +1/4; dangers/tools: Einschlag after twist 1: Saurier/Raubsaurier/Flugsaurier → Erde | scripted impact after twist 1: dinosaurs → Erde; Wiese regrows |
| 35 | Erde 10, Tiere 7, Fels 6, Wald 3, Wiese 3, Wasser 25 | rows Erde→Wiese, Wald→Tiere; Tiere 🌾→–, starve→Wald; rain Erde→Wiese, Wald(meadow)→Tiere; charges 1 +1/5 | mammals (Tiere) need 🌾 (old 20 rules) |
| 36 | Wald 10, Quallen 9, Wiese 8, Fische 3, Fels 2, Wasser 22 | rows Wald→Vögel, Quallen→Fische; Wald 🐟🐟→Vögel; rain Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Wiese, Vögel→Wiese | Wald with 🐟🐟 → Vögel (old 18 rules) |
| 37 | Tiere 10, Erde 7, Wiese 5, Fels 4, Wald 3, Wasser 25 | rows Erde→Wiese, Wald→Tiere, Tiere→Raubtiere; Tiere 🌾→–, starve→Wald; Raubtiere 🍖→–, starve→Wald; rain Erde→Wiese, Wald(meadow)→Tiere; charges 1 +1/5 | Raubtiere need 🍖 (old 21) |
| 38 | Tiere 8, Erde 7, Raubtiere 4, Wiese 4, Wald 3, Fels 3, Wasser 25 | rows Erde→Wiese, Wald→Tiere; Tiere 🌾→–, starve→Wald; Raubtiere 🍖→–, starve→Wald; rain Erde→Wiese, Wald(meadow)→Tiere; charges 1 +1/5; dangers/tools: Jagd Raubtiere≥3 → Tiere→Wiese, Meteor ×1 | danger Rudel; Meteor tool (old 23) |
| 39 | Tiere 10, Erde 6, Wiese 5, Wald 4, Raubtiere 3, Wasser 26 | rows Erde→Wiese, Wald→Tiere; Tiere 🌾→–, starve→Wald; Raubtiere 🍖→–, starve→Wald; rain Erde→Wiese, Wald(meadow)→Tiere; charges 1 +1/5; dangers/tools: Jagd Raubtiere≥3 → Tiere→Wiese, herd ≥3 safe | group goal Tiere; a herd ≥ 3 is safe from the pack |
| 40 | Eis 10, Tiere 10, Wiese 4, Wald 4, Erde 3, Wasser 23 | rows Erde→Wiese, Wald→Tiere; Tiere 🌾→–, starve→Wald; Eis ☀→Wasser; rain Erde→Wiese, Wald(next to Wiese)→Tiere; charges 1 +1/5; dangers/tools: Gletscher Eis≥4 freezes 2 (immune Mammut/Feuerstelle, not next to Feuerstelle) | danger Gletscher (Eis group ≥ 4 freezes 2 neighbours); Eis thaws in the sun |
| 41 | Tiere 10, Eis 7, Wiese 5, Wald 5, Mammut 2, Wasser 25 | rows Wald→Tiere, Tiere→Mammut; Mammut 🌾❄→–, starve→Wald; rain Wasser(shore)→Eis, Wiese→Wald, Wald(next to Wiese)→Tiere; charges 1 +1/5; dangers/tools: Gletscher Eis≥4 freezes 2 (immune Mammut/Feuerstelle, not next to Feuerstelle) | Mammut (new kind 36) need 🌾 + ❄; immune to the glacier |
| 42 | Tiere 7, Eis 7, Wiese 5, Wald 5, Mammut 3, Wasser 27 | rows Wald→Tiere, Tiere→Mammut; Tiere 🌾→–, starve→Wald; Eis ☀→Wasser; Mammut 🌾❄→–, starve→Wald; rain Wasser(shore)→Eis, Wiese→Wald, Wald(next to Wiese)→Tiere; charges 1 +1/5; dangers/tools: Gletscher Eis≥4 freezes 2 (immune Mammut/Feuerstelle, not next to Feuerstelle) | two satt goals (Mammut + Tiere) with glacier and thaw |
| 43 | Wald 10, Tiere 7, Wiese 7, Fels 3, Wasser 27 | rows Wiese→Wald, Wald→Tiere; Tiere 🌲🌲→Affen; rain Wiese→Wald; charges 1 +1/5 | Tiere with 🌲🌲 → Affen (new kind 37) |
| 44 | Wald 9, Affen 6, Tiere 6, Wiese 5, Wasser 28 | rows Wiese→Wald, Wald→Tiere; Tiere 🌲🌲→Affen; rain Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Wiese, Tiere→Wiese, Affen→Wiese | group goal Affen with the bolt |
| 45 | Affen 12, Wald 8, Wiese 6, Tiere 4, Wasser 24 | rows Wald→Tiere, Affen→Frühmenschen; Tiere 🌲🌲→Affen; rain Wiese→Wald; charges 1 +1/5 | rows Affen → Frühmenschen (new kind 38) |
| 46 | Frühmenschen 8, Wald 8, Fels 6, Affen 6, Wiese 5, Wasser 21 | rows Affen→Frühmenschen; Frühmenschen ⛰🌲→Feuerstelle; rain Wiese→Wald; charges 1 +1/5 | Frühmenschen with ⛰ + 🌲 → Feuerstelle (new kind 39) |
| 47 | Frühmenschen 8, Eis 7, Affen 6, Wiese 4, Wald 4, Feuerstelle 3, Wasser 22 | rows Affen→Frühmenschen; Eis ☀→Wasser; Frühmenschen 🔥→–, starve→Affen; rain Wiese→Wald; charges 1 +1/5; dangers/tools: Gletscher Eis≥4 freezes 2 (immune Mammut/Feuerstelle, not next to Feuerstelle) | Frühmenschen need 🔥; no freezing next to a Feuerstelle |
| 48 | Frühmenschen 7, Tiere 6, Wald 6, Feuerstelle 4, Affen 4, Wiese 3, Wasser 24 | rows Wald→Tiere, Affen→Frühmenschen; Frühmenschen 🔥🍖→–, starve→Affen; rain Wald(next to Wiese)→Tiere; charges 1 +1/5; dangers/tools: Jagd Frühmenschen≥3 → Tiere→Wiese | Frühmenschen need 🔥 + 🍖; hunter group ≥ 3 drives Tiere away |
| 49 | Frühmenschen 16, Tiere 6, Wald 5, Wasser 27 | rows Wald→Tiere, Frühmenschen→Hütte; consume Frühmenschen (others → Wiese); Hütte 🍞→–; rain Erde→Wiese, Wiese→Wald; charges 1 +1/5; dangers/tools: Blitz, burn Wald→Wiese, Tiere→Wiese, Hütte→Wiese | 3 Frühmenschen → Hütte (consume); Hütte 🍞 (old 24) |
| 50 | Wiese 14, Erde 6, Wald 4, Algen 3, Wasser 27 | rows Erde→Wiese, Wiese→Saat; Saat ☀💧→Acker; rain Saat→Acker, Wiese→Saat; charges 1 +1/4; dangers/tools: Blitz, burn Wald→Wiese, Acker→Wiese, Saat→Wiese | Saat → Acker (☀💧), old 14 |
| 51 | Wiese 12, Wald 4, Acker 3, Saat 3, Erde 3, Algen 3, Wasser 26 | rows Erde→Wiese, Wiese→Saat; Saat ☀💧→Acker; rain Saat→Acker, Wiese→Saat; charges 1 +1/4; dangers/tools: Blitz, burn Wald→Wiese, Acker→Wiese, Saat→Wiese | group goal Acker (old 15) |
| 52 | Wiese 10, Hütte 6, Wald 6, Tiere 2, Erde 2, Wasser 28 | rows Wald→Tiere; Hütte 🍞→–; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Blitz, burn Wald→Wiese, Acker→Wiese, Tiere→Wiese, Hütte→Wiese, Saat→Wiese | rain Wiese next to people → Saat → Acker (old 25) |
| 53 | Wiese 9, Wald 7, Hütte 5, Tiere 4, Acker 3, Wasser 26 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→–, starve→Hütte; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Blitz, burn Wald→Wiese, Acker→Wiese, Tiere→Wiese, Hütte→Wiese, Dorf→Hütte, Saat→Wiese | Hütte → Dorf (🍞🔨), old 26 |
| 54 | Wald 8, Dorf 6, Acker 4, Tiere 4, Kirche 3, Wiese 3, Wasser 26 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Glaube→Meteor; overnight Hütte→Dorf | Kirche, Krieg, Glaube → Meteor; Stadt (old 27) |
| 55 | Wald 8, Dorf 7, Acker 5, Kirche 4, Tiere 3, Wasser 27 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Glaube→Meteor | 4 churches on the board; two satt goals |
| 56 | Wald 8, Acker 6, Stadt 4, Tiere 4, Kirche 3, Wasser 29 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Flut, Glaube→Meteor; overnight Dorf→Stadt | Flut (crowded face) without industry |
| 57 | Wald 8, Acker 6, Stadt 4, Tiere 4, Kirche 3, Industrie 1, Wasser 28 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Smog, Flut, Glaube→Meteor | Smog + Flut (old 28) |
| 58 | Wald 8, Acker 6, Stadt 4, Kirche 3, Tiere 3, Industrie 2, Wasser 28 | rows Wald→Tiere; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Smog, Flut, Glaube→Meteor; overnight Dorf→Stadt | 2 industries |
| 59 | Wald 9, Tiere 6, Acker 4, Stadt 3, Kirche 2, Industrie 1, Wasser 29 | rows Wald→Tiere; Tiere 🌾→–, starve→Wald; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt, starve→Hütte; Stadt 🍞🔨🙏→–, starve→Dorf; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Blitz, Krieg, Smog, Flut, Glaube→Meteor, burn Wald→Wiese, Tiere→Wiese | two satt goals, all systems (old 29) |
| 60 | Wald 7, Tiere 6, Wiese 6, Stadt 4, Acker 4, Kirche 2, Wasser 25 | rows Wald→Tiere; Tiere 🌾→–; Hütte 🍞→Dorf; Dorf 🍞🔨→Stadt; Stadt 🍞🔨🙏→–; Saat ☀💧→Acker; rain Saat→Acker, Wiese(people)→Saat, Wiese(nopeople)→Wald; charges 2 +1/3; dangers/tools: Krieg, Glaube→Meteor; overnight Saat→Acker | hold goal (3 rounds, no damage), old 30 |

### 5.3 Notes per level (design and tuning decisions)

- **Start rules (all levels, unchanged):** no counting row, no satt goal field, no progress, at most `satt_max`
  satt thrivers, no church next to a church, group goals start with no group bigger than `group_max`, no single
  twist wins, satt goals reachable by sticker type, ≤ 6 visible kinds besides water, ≤ 3 growable kinds. Half of the
  pool boards of the danger-introducing levels start with the danger built (`clump`): 3 and 7 (Lava 5), 32, 33, 38,
  39 (a pack of 3), 40 (an Eis group of 4), so the new warning shows after the first twist.
- **Old levels kept 1:1** (rules, composition, target): 1–6, 8–10 (old 7–9), 18–19 (old 10–11), 21 (old 12),
  50–54 (old 14, 15, 25, 26, 27), 57 (old 28), 59–60 (old 29–30; only the texts lost the Genesis words: „Der siebte
  Tag“ → „Blühende Welt“ (first „Ruhe“, renamed: rest is the seventh-day frame), „Und es war gut.“ → „Deine Welt lebt.“). Re-skinned with the kinds of their era (same numbers):
  15–16 (old 16–17: fish from Quallen, as the water ladder is now Einzeller → Algen → Quallen → Fische), 22 (old 13:
  Farn instead of Wiese, Moos instead of Erde), 25 (old 19: Amphibien onto Moos; rows Quallen → Fisch, rain Qualle →
  Fisch, 12 Quallen and 4 fish instead of 10 Algen and 3 fish because the ladder is one step longer), 28, 29, 31
  (old 20–22 with Saurier/Raubsaurier, Farn as food, Moos → Farn rows), 30 (old 18: Flugsaurier), 38 (old 23: the
  generic hunt, identical numbers), 49 (old 24: 3 Frühmenschen build a hut; 16 Frühmenschen because they do not
  regrow, see below).
- **Tuning steps of this spec (200–40 boards each, model numbers):**
  - 13 Trilobiten 5 → 7 and 14 Vielfalt 5 + 4 → 6 + 5: the ⛰⛰ thriving is quick (good median 3 → 4–5).
  - 17 „Panzerfische“ (make Fische 4 + Trilobiten 3) was **dropped**: Trilobiten grew on their own out of the Quallen
    the fish rows need (good bot 85 %, greedy 20–60 % done). Replaced by „Fischreich“ (make Fische 7, the full water
    ladder Algen → Quallen → Fische; 9 was too long: good median 9).
  - 20 Feuchtes Ufer group Farn 5 → 11, 23 Urwald group Wald 6 → 9, 24 Insekten 6 → 9, 32 Jagd 6 → 8 satt Saurier,
    33 Herde group 5 → 7, 39 Herden 5 → 7, 40 Eiszeit 6 → 9 (10 Eis), 41 Mammut 3 → 4, 43 Affen 6 → 9, 44 Horde
    5 → 7, 46 Feuer 5 → 7: the first versions were won in 2–3 steps by every bot.
  - 25 Landgang: with Algen → Quallen → Fisch the first version needed 10–11 steps (greedy 60 % done): more Quallen,
    rain makes fish directly.
  - 26/27: casual players starved all Amphibien into Moos and ran out of fish (weak bot 89–92 % done within 80):
    the rows Algen → Quallen came back (fish can always be remade; weak 100 %).
  - 41/42: the ice thawed completely and a Mammut could never get ❄ again (weak bot 52–65 % done, a real dead end):
    level 41 has no thaw (the peak of the ice age), and rain on shore water makes Eis („Regen wird Schnee“, 41–42);
    weak 99.5 % / 99.5 %.
  - 48 Jäger: satt 5 → 4 and 4 Feuerstellen (the good bot starved hunters at 5).
  - 49 Sesshaft: Frühmenschen do not regrow, so a consume row (3 → 1 Hütte + 2 Wiesen) could leave too few in a line:
    12 → 16 Frühmenschen (greedy 86 % → 97.5 % done).
- **Level 34 Einschlag** is the one scripted level: 15 dinosaur fields become ash after twist 1 in every game; the
  goal (12 Wiesen) is built from that ash (rows of 3 Erde, Erde with 🌾 3 next to the surviving ferns and forests,
  rain), so the turning point is also the material of the task. ★★★ is easy there (good 92 %) by design: it is a
  story level; it is not a WdT template.
- **Level 38 Rudel** (old 23) keeps its meteor charge and its 2-step ★★★ (the meteor story beat moved from „the
  meteor that ends the dinosaurs“ to „a meteor splits the wolf pack“; no spoiler: level 34 came before).
- **No dead ends (checked, 11.5):** every counted kind can be remade in its level: Quallen/Fische by rows and rain,
  Amphibien by Landgang (fish by rows), Saurier by Wald rows and „Regen lockt Saurier“, Tiere by Wald rows and „Regen
  lockt Tiere“, Mammut by Tiere rows (❄ by „Regen wird Schnee“), Affen by thriving, Frühmenschen by Affen rows,
  Feuerstellen by thriving, Hütten by consume rows; plus Gnade and the gift.
- **Sun face:** levels 22–23 (Farn ☀💧), 50–53 and 59–60 (Saat), 40, 42 and 47 (Eis thaws on face 0; not in 41, the peak of the ice age).

---

## 6. The world carries over within an era; every level stays solvable

Same algorithm as `GDPD_SCHOEPFUNG.md` 5 / 5.1 (`Campaign.carry`, model `b6/carry10.py`), with **era** in place of
act: the end world of level n starts level n + 1 if both are in the same era; the first level of an era is a pool
board. Steps: overnight (`[from, to]` of the level), **retire** (kinds the level does not use fall back along their
history; new entries: Qualle → Algen, Trilobit → Qualle, Fisch → Qualle (was Algen), Insekten → Farn, Amphibie →
Moos, Reptil → Amphibie, Saurier → Wald, Raubsaurier → Saurier, Flugsaurier → Wald, Eis → Wasser, Mammut → Tiere,
Affe → Tiere, Frühmensch → Affe, Feuerstelle → Fels), fit to the start composition, repair to the start rules
(3000 swaps), else the pool board (`fallback`, „Heute eine frische Welt“).

`Campaign.ensure` (every start path) adds for the new systems: Eis clumps above `CLUMP_CAP_ICE = 5` are split like
lava clumps (glacier levels), Raubsaurier/Raubtiere packs above 3 are split in the first level of a hunt (only where
the pool boards start without a pack), top-up overnight as before (at most 6 fields: „Über Nacht: +3 Quallen“).

`GameState.reach9` (no search, „not ok“ = sure dead end) learns the new sources: a `make` goal of a thrive result
(Trilobit, Insekten, Flugsaurier, Affen, Feuerstelle, Wiese from ash) needs enough fields of the thriving kind plus a
reachable source of each need by sticker type (as for the old thrive results); `make Amphibien` needs fish (or a way
to make fish: Quallen rows/rain) and Moos; `satt` of a kind with `cold`/`bugs`/`wood`/`heat` checks those sources by
sticker type. The **gift** (`gift_plan9`) covers every new goal kind with the same three recipes (make: a source
field becomes the goal kind; group: the biggest group grows by one; satt: the field gets the missing neighbour, e.g.
an Insekten next to a hungry Amphibie, an Eis next to a Mammut, a Feuerstelle next to a cold Frühmensch).

Validated (section 11.4): 100 chains per era with the good bot and 100 with the greedy bot, every level started
from the bot's own end world of yesterday.

---

## 7. The next action for every level type (Build 12 contract, extended)

`GameState.next_action()` stays the single source of the top HUD line; it is computed from the real board after every
action and never names something impossible. Coverage per goal type and new system (all 60 levels):

| situation | line (German) · icons | how it is found |
|---|---|---|
| row toward the goal (all `make` levels with rows: 1, 4, 10, 12, 15, 17, 19, 21, 27, 45 …) | „Dreh 3 Quallen in eine Reihe → Fisch“ | as built (`_act_score9`, chain distance `chain9`) |
| a field becomes supplied (thrive results: Trilobit, Farn, Wald, Insekten, Flugsaurier, Vögel, Affen, Feuerstelle, Wiese from ash, Eis that thaws) | „Qualle neben Fels drehen → Trilobit“, „Farn neben Wald drehen → Insekten“, „Frühmensch neben Fels drehen → Feuerstelle“, „Eis in die Sonne drehen → Wasser“ (only where Wasser helps: never in a goal chain, so only as a danger fix) | `_act_need_text9`: new need words: `wood` → „neben Wald“, `bugs` → „neben Insekten“, `cold` → „neben Eis“, `heat` → „ans Feuer“ (when the source is a Feuerstelle) |
| `satt` goals (26, 28, 29, 31, 32, 35, 37, 38, 40–42, 47–49, 52–60) | „Insekten neben die Frösche“ style: „Amphibie neben Insekten drehen“, „Mammut neben Eis drehen“, „Frühmensch ans Feuer drehen“ | as built (`_act_satt_goal9`) |
| `group` goals (11, 16, 20, 23, 33, 39, 44, 51) | „Mach die Algen-Gruppe größer“, „Bilde eine Herde!“ (Saurier/Tiere where `herd` is set) | as built; the herd wording when the goal kind is a hunt prey with `herd > 0` |
| Landgang spawn (25–27) | „Fisch ans Moos drehen → Amphibie“ | as built (spawn = thrive with result) |
| Jagd warned | „Trenn die Raubsaurier!“ / „Trenn die Raubtiere!“ / „Trenn die Jäger!“ (icon of the hunter) | `_act_threats9`: type `pack` generalised over `cfg.hunt`; fixed when no warned prey is a target any more |
| Gletscher warned | „Teil das Eis!“ (icon `ice`) | type `glacier`: fixed when the crater group is < 4 or the crater is no Eis |
| Einschlag pending (level 34, before twist 1) | „Dreh, der Meteor kommt“ (icon `meteor_fall`), `move` = the best twist of `_act_pick9` | a new first branch: `impact` set and not done |
| hunger warned (26, 27, 28 …) | „Rette die Hungrigen!“ | as built |
| rain helps (rain tables incl. the new `[kind, kind, kind]` conditions) | „Gieß Algen mit Regen → Qualle“ | `_act_rain9` (uses `rain_to9`, which learns the kind condition) |
| meteor tool (38) | „Meteor auf ein Raubtier“ | as built |
| `hold` (60) | as built | as built |
| nothing works | „Hol dir Hilfe“ (gift) | as built |

Tests (`test_next_action_all`, section 13): for every pool board of all 60 levels, after each step of the stored
solution, `next_action()` returns a non-empty `text` of ≤ 6 words; when it names a `move`, playing that move changes
the board as described (a row of that kind grows, the field becomes satt, or the named danger is no longer open);
never the type `help` while `reach9().ok` and the level has an unused row or supply.

---

## 8. Event contract additions (rules → UI / visuals)

| type | payload | visual | pill (caps · line), max one per round |
|---|---|---|---|
| `glacier_warn` | crater, fields | frost creeps from the crater, threatened neighbours get a blue rim | „Gletscher wächst!“ · „Teil das Eis“ |
| `freeze` | crater, field, from | the field ices over (white-blue sheet grows onto it) | „Eis!“ (`−1 Tier` cue if it was a made goal field) |
| `glacier_calm` | crater | frost retreats | „Abgewendet“ |
| `thrive` (Eis → Wasser) | field | ice cracks and melts | „Eis taut“ |
| `pack_warn` / `pack_hunt` (generic) | fields / field, hunter kind | hunter crouches toward the prey / chase, the prey field turns to its `falls_to` | per hunter: „Rudel jagt!“ · „Trenn die Raubtiere“; „Raubsaurier jagen!“ · „Trenn die Raubsaurier“; „Die Tiere fliehen!“ · „Trenn die Jäger“ / „Gejagt!“ |
| `impact_warn` | – (at level start, level 34) | glowing meteor crosses the sky (slowly, every few seconds) | „Meteor kommt!“ |
| `impact` | fields | camera to the impact, flash, shock wave, every listed field becomes ash (Erde), era blend to `asche` | „Einschlag!“ |
| `thrive` (new kinds) | as built | as built | per kind: „Panzer wächst“ (Trilobit), „Farn wird Wald“, „Es summt!“ (Insekten), „Flugsaurier fliegt“, „Asche wird Wiese“, „Affen klettern“, „Feuer brennt!“ (Feuerstelle) |
| `spawn` (Amphibien) | as built | a fish crawls onto the moss and becomes a frog | „Landgang!“ |
| `era` | era id, level, sky_blue, dust_clear | `World.set_era` | – |

`Campaign.PILL` / `THRIVE_PILL` get the entries above; `still_line9` the new reasons of 4.6. Event names of the old
spec stay (`pack_warn`/`pack_hunt` keep their names for every hunter; the payload adds `hunter`).

---

## 9. Migration of existing saves („Die Schöpfung“ → „Erdgeschichte“)

`[kampagne] version` 1 → **2**. All arrays grow from 30 to **60** entries (`Campaign.COUNT` = number of levels in the
data, never a constant in code). Every old level n is copied to `OLD_TO_NEW[n]`:

| old | new | old | new | old | new | old | new | old | new |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 7 | 8 | 13 | 22 | 19 | 25 | 25 | 52 |
| 2 | 2 | 8 | 9 | 14 | 50 | 20 | 28 | 26 | 53 |
| 3 | 3 | 9 | 10 | 15 | 51 | 21 | 29 | 27 | 54 |
| 4 | 4 | 10 | 18 | 16 | 15 | 22 | 31 | 28 | 57 |
| 5 | 5 | 11 | 19 | 17 | 16 | 23 | 38 | 29 | 59 |
| 6 | 6 | 12 | 21 | 18 | 30 | 24 | 49 | 30 | 60 |

| old state | new state |
|---|---|
| `stars[n]`, `steps[n]`, `won_key[n]` of an old level | copied to the mapped level (the mapped level is the same rules and start composition, re-skinned where noted; the thresholds are re-simulated, so the stars are kept as earned, never lowered) |
| points | unchanged (no re-pay; the 20-points-per-old-star thanks of v3 are not paid again) |
| highest won old level k | the **position** `P = POS_OF_OLD[k]` = the largest mapped level of the old levels ≤ k, leaving out the three old levels that moved far ahead (14 Saat → 50, 15 Ernte → 51, 18 Vögel → 30 Flugsaurier): `POS_OF_OLD = [1, 2, 3, 4, 5, 6, 8, 9, 10, 18, 19, 21, 22, 22, 22, 22, 22, 22, 25, 28, 29, 31, 38, 49, 52, 53, 54, 57, 59, 60]` for k = 1 … 30. Every new level `< P` that is not won is **open at once** as „Nachholen“ (a small dot, no story spoiler: it lies behind the player). The daily unlock continues at `P + 1` (one per Spieltag, the first on the next Spieltag after the update). A won level beyond `P` (old 14, 15, 18) stays hidden like any locked level (no era spoiler); when the daily unlock reaches it, it opens already won with its stars and the unlock moves on to the next unwon level the same Spieltag. The campaign is „complete“ only when all 60 are won |
| finished all 30 old levels | `P = 60`: every level is open (all inserted ones as „Nachholen“), the Welt des Tages stays open every day (as before for veterans) |
| `fast_to` (veteran fast track) | mapped by `OLD_TO_NEW` |
| `world` / `world_level` / `start` | kept only if the mapped level is in the same era as the next level to play; otherwise cleared (the next level starts on its pool board) |
| running level (`[lauf]`, Build 12) | its config md5 changes, so it restarts fresh (as specified for any config change); the level number is mapped |
| `next_board` (pool index per level) | mapped like `stars` |
| WdT keys, streak, shields, character, reminders, shop | unchanged |

Overview after the update (once): the character says „Die Welt ist größer geworden.“ (5 words) and the first open
„Nachholen“ tile pulses. Tests: `test_migrate_erde` (each row; a save that finished old 1–19 lands on position 25 with
levels 7, 11–14, 17, 20, 23, 24 open as „Nachholen“, 26 locked until the next Spieltag, 30/50/51 won but hidden;
a save that finished old 1–24 lands on 49 and opens 27 „Nachholen“ levels).

---

## 10. After the campaign; open-ended extension

- **Welt des Tages** (after the first win of level 60, or for veterans as above): templates = one strong level per
  era: `WDT = [3, 7, 11, 14, 16, 20, 23, 27, 32, 35, 38, 40, 44, 47, 48, 51, 54, 56, 58, 59]` (20 templates;
  board key rotation as before: `board(key) = 1 + posmod(floor(key / 20), pool_size − 1)`, 20 × 19 = 380 worlds).
- **Adding eras later = data only:** `data/kampagne_erde.json` holds `eras` (id, title, line, look preset, icon) and
  `config` per level (the format of `export10.cfg_json`: rows, next, consume, thrive with needs/up/spawn/down, rain
  with conditions, hunt, glacier, impact, volcano, bolt, burn, war, smog, flood, faith, goal, stars, par, comp,
  satt_max, era, old) plus the pools. A new level appended to the list unlocks on the next Spieltag after the
  player's last new win (players who had „complete“ get „Neue Level!“ on the overview and lose nothing). New kinds
  need code (`FieldData`, models, icons); new rules should be instances of the generic systems (rows, thrive, spread,
  hunt, impact). Candidates (not in this spec): „Insel“, „Wüste“ (`wet` precious), „Zukunft“ (clean energy against
  smog).
- Replays stay open forever (stars and points only for improvements).

---

## 11. Validation (Python model, `gdpd_sim/b6`)

### 11.1 Method

- **Rules:** `engine10.py` = `engine9` (lasting supply, groups, all old dangers; the rules of the `engine9_mode`
  cross-check) + the generic hunt, glacier and impact (4). Every old level config runs unchanged inside it; the
  Build 12 late pass is not in the model (as for `b4`; the game replays the pools in `engine9_mode` and the hint wins
  the few solutions the late pass changes, `GDPD_SCHOEPFUNG.md` 3.1).
- **Boards:** `levels10.generate(n, seed)`, seeds 1–200 per level, the same seeds for every bot; start rules of 5.3.
- **Bots** (unchanged from `b4`, the danger value knows hunt and glacier): `good` = the hint (tools first, 1-ply over
  27 twists + 2-ply on the best 6, 27 after a stall; cap 40); `greedy` = the average player (1-ply, uses tools, never
  back to the last 4 boards; cap 50); `weak` = casual (half random row/satt twists, random rain, the free hint half
  the time after 3 steps without progress; cap 80); `weaklong` = weak without a practical cap (300); `farmer` =
  oracle best of ping-pong, 5 cycle patterns and single-slice play, horizon 30.
- **Thresholds** (`stars12.py`, method of `stars11.py`): ★★★ where the good bot's ★★★ share is closest to 55 % (40–70 %
  where the integer steps allow it); ★★ = the smallest count with greedy ★★+ ≥ 85 % of all its games and good ≥ 98 %,
  then at least the weak median (levels 1–5) or its 35th percentile, capped at 3 × ★★★ + 4; **new:** then raised
  until the greedy bot also has ★★+ in ≥ 85 % of its carried-world games (11.4) where the cap allows (levels 16, 29,
  37, 49, 52: +1 to +3 steps; `stars12_fresh.json` holds the fresh-board values). The thresholds come
  from `res_main.json` (Gnade there started at a default 10 steps); **every table below is a second full run with the
  final thresholds** (`res_final.json`, same seeds: the shares moved by ≤ 1 point), points recomputed with the final
  par.
- **Targets (task):** always solvable (with the safety net), the good bot completes, the average player ★★ or better
  in ≥ 85 %, farmers never beat honest play, dangers avoidable.

### 11.2 Summary (200 boards per level and bot, 60 levels)

| bot | games | ★★★ | ★★ or better | done within cap | goal losses per game |
|---|---|---|---|---|---|
| good | 12000 | 60 % | 100 % | 99.9 % | 0.00 |
| greedy | 12000 | 37 % | 95 % | 99.0 % | 0.00 |
| weak | 12000 | 1 % | 47 % | 99.9 % | 0.04 |

With the safety net (`play_net`, 100 boards per level): casual player 100 % done within 80, average player 99.98 % within 50 (fresh) and 100 % (carried worlds). Details: 11.5.

### 11.3 Stars and play per level (200 boards per level and bot)

Cells ★★★/★★/★/open = % of all games (open = not done within the bot cap; in the game a level is never lost). Dangers = events per game that changed a field (any kind).

| # | title | ★★★/★★ ≤ | good: median (p25–p75, p90) | good ★★★/★★/★/open % | greedy median | greedy ★★★/★★/★/open % | weak median | weak ★★★/★★/★/open % | good goal losses / game | dangers per good game | dangers per greedy game |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Glut | 4 / 10 | 4 (4–5, 5) | 53/47/0/0 | 5 | 33/65/2/0 | 10 | 0/66/34/0 | 0.00 | – | – |
| 2 | Abkühlen | 4 / 10 | 5 (4–5, 5) | 46/54/0/0 | 6 | 17/83/0/0 | 10 | 0/52/48/0 | 0.00 | – | – |
| 3 | Vulkan | 5 / 11 | 5 (4–6, 6) | 72/28/0/0 | 6 | 35/64/0/0 | 11 | 0/60/40/0 | 0.03 | eruptions 0.8 | eruptions 0.6 |
| 4 | Urkontinent | 5 / 14 | 6 (5–6, 7) | 34/66/0/0 | 6 | 18/82/0/0 | 14 | 0/50/50/0 | 0.01 | eruptions 0.5 | eruptions 0.5 |
| 5 | Atmosphäre | 5 / 17 | 5 (5–6, 6) | 66/34/0/0 | 5 | 76/24/0/0 | 17 | 0/62/38/0 | 0.00 | eruptions 0.5 | eruptions 0.6 |
| 6 | Urmeer | 4 / 11 | 4 (4–5, 6) | 56/44/0/0 | 5 | 46/52/1/0 | 12 | 0/46/54/0 | 0.00 | – | – |
| 7 | Heiße Quellen | 4 / 9 | 4 (4–5, 5) | 66/34/0/0 | 4 | 52/48/0/0 | 10 | 1/42/57/0 | 0.00 | eruptions 0.1 | eruptions 0.1 |
| 8 | Erstes Leben | 5 / 10 | 5 (4–6, 6) | 58/42/0/0 | 6 | 40/56/4/0 | 12 | 0/38/62/0 | 0.00 | – | – |
| 9 | Leben teilt sich | 5 / 11 | 5 (5–5, 5) | 96/4/0/0 | 5 | 83/17/0/0 | 12 | 0/40/60/0 | 0.00 | – | – |
| 10 | Algen | 4 / 9 | 5 (4–5, 6) | 42/57/1/0 | 5 | 18/80/2/0 | 10 | 0/40/60/0 | 0.00 | – | – |
| 11 | Sauerstoff | 5 / 14 | 5 (4–6, 7) | 54/46/0/0 | 7 | 18/72/10/0 | 15 | 0/39/61/0 | 0.00 | – | – |
| 12 | Quallen | 4 / 10 | 5 (4–5, 5) | 34/66/0/0 | 5 | 24/74/2/0 | 11 | 0/50/50/0 | 0.00 | – | – |
| 13 | Trilobiten | 4 / 9 | 4 (4–5, 6) | 58/42/0/0 | 5 | 34/66/0/0 | 10 | 2/40/58/0 | 0.00 | – | – |
| 14 | Vielfalt | 5 / 14 | 5 (5–6, 7) | 52/48/0/0 | 6 | 32/67/2/0 | 16 | 0/34/66/0 | 0.00 | – | – |
| 15 | Fische | 5 / 11 | 6 (5–7, 8) | 42/56/2/0 | 6 | 26/65/6/3 | 12 | 0/38/62/0 | 0.00 | – | – |
| 16 | Schwärme | 5 / 19 | 5 (4–7, 9) | 53/47/0/0 | 9 | 23/66/8/2 | 16 | 0/77/23/0 | 0.00 | – | – |
| 17 | Fischreich | 6 / 13 | 6 (5–7, 8) | 65/34/0/0 | 7 | 41/53/5/1 | 14 | 0/48/52/0 | 0.00 | – | – |
| 18 | Moos | 5 / 10 | 5 (5–6, 7) | 64/36/0/0 | 6 | 39/60/2/0 | 11 | 0/38/62/0 | 0.00 | – | – |
| 19 | Farne | 6 / 13 | 6 (6–8, 9) | 50/50/0/0 | 8 | 31/66/2/0 | 14 | 0/47/53/0 | 0.00 | – | – |
| 20 | Feuchtes Ufer | 5 / 13 | 5 (4–6, 6) | 74/26/0/0 | 5 | 52/48/0/0 | 15 | 0/36/64/0 | 0.00 | – | – |
| 21 | Wälder | 6 / 13 | 7 (6–7, 8) | 48/52/0/0 | 7 | 30/70/0/0 | 14 | 0/35/65/0 | 0.00 | – | – |
| 22 | Licht | 5 / 11 | 5 (5–5, 6) | 86/14/0/0 | 5 | 71/29/0/0 | 12 | 0/42/58/0 | 0.00 | – | – |
| 23 | Urwald | 4 / 11 | 4 (3–5, 5) | 67/33/0/0 | 5 | 40/59/2/0 | 13 | 0/38/62/0 | 0.00 | – | – |
| 24 | Insekten | 5 / 11 | 5 (5–6, 7) | 60/40/0/0 | 6 | 38/62/0/0 | 12 | 0/48/51/0 | 0.00 | – | – |
| 25 | Landgang | 4 / 9 | 4 (4–5, 6) | 60/40/0/0 | 6 | 24/72/3/0 | 10 | 0/42/58/0 | 0.00 | – | – |
| 26 | Frösche | 5 / 16 | 5 (4–6, 6) | 70/30/0/0 | 6 | 36/64/0/0 | 20 | 0/35/65/0 | 0.00 | starve 0.4 | starve 1.9 |
| 27 | Reptilien | 4 / 16 | 4 (4–5, 5) | 69/31/0/0 | 4 | 50/46/2/2 | 18 | 0/42/58/0 | 0.00 | starve 0.2 | starve 1.1 |
| 28 | Saurier | 3 / 8 | 3 (3–4, 5) | 62/37/0/0 | 4 | 39/58/3/0 | 10 | 0/36/64/0 | 0.00 | – | starve 0.1 |
| 29 | Raubsaurier | 4 / 16 | 4 (3–5, 6) | 64/36/0/0 | 5 | 41/46/8/5 | 15 | 0/60/39/0 | 0.00 | starve 0.2 | starve 0.7 |
| 30 | Flugsaurier | 5 / 11 | 5 (5–7, 7) | 52/48/0/0 | 6 | 32/64/4/0 | 12 | 0/44/56/0 | 0.00 | – | – |
| 31 | Nahrungskette | 4 / 14 | 4 (3–5, 5) | 70/30/0/0 | 4 | 50/46/3/1 | 17 | 0/36/64/0 | 0.00 | – | starve 0.3 |
| 32 | Jagd | 3 / 10 | 3 (3–4, 4) | 68/32/0/0 | 4 | 48/52/0/0 | 11 | 0/42/57/0 | 0.00 | – | starve 0.1 |
| 33 | Herde | 3 / 13 | 3 (2–4, 5) | 68/30/1/1 | 4 | 42/46/8/4 | 20 | 0/17/82/0 | 0.00 | starve 0.1, pack_hunts 0.1 | starve 0.6, pack_hunts 0.1 |
| 34 | Einschlag | 4 / 8 | 4 (4–4, 4) | 92/8/0/0 | 4 | 80/20/0/0 | 8 | 1/50/50/0 | 0.00 | – | – |
| 35 | Überleben | 3 / 8 | 3 (3–4, 5) | 60/40/0/0 | 4 | 36/62/2/0 | 11 | 0/36/64/0 | 0.00 | – | – |
| 36 | Vögel | 5 / 11 | 5 (4–6, 8) | 54/44/2/0 | 6 | 32/60/8/0 | 11 | 2/49/50/0 | 0.00 | – | – |
| 37 | Raubtiere | 4 / 16 | 4 (4–5, 5) | 62/38/0/0 | 5 | 39/52/2/6 | 15 | 0/58/42/0 | 0.00 | starve 0.1 | starve 0.5 |
| 38 | Rudel | 2 / 7 | 2 (2–3, 3) | 58/42/0/0 | 3 | 42/57/1/0 | 8 | 0/49/51/0 | 0.00 | – | – |
| 39 | Herden | 3 / 13 | 3 (2–4, 6) | 64/33/2/2 | 4 | 46/39/10/5 | 20 | 0/20/80/0 | 0.00 | starve 0.2 | starve 0.7, pack_hunts 0.1 |
| 40 | Eiszeit | 4 / 14 | 4 (3–5, 5) | 70/30/0/0 | 5 | 44/54/0/0 | 17 | 0/30/68/2 | 0.00 | frozen 0.7 | starve 0.2, frozen 0.5 |
| 41 | Mammut | 5 / 11 | 5 (4–6, 7) | 70/30/0/0 | 6 | 41/46/7/6 | 13 | 1/35/64/0 | 0.00 | frozen 0.1 | starve 0.2, frozen 0.1 |
| 42 | Tauwetter | 3 / 13 | 3 (3–4, 5) | 65/35/0/0 | 4 | 44/55/1/0 | 16 | 0/36/62/1 | 0.00 | frozen 0.1 | starve 0.1, frozen 0.1 |
| 43 | Affen | 5 / 11 | 5 (5–6, 7) | 59/41/0/0 | 6 | 24/74/2/0 | 12 | 0/42/58/0 | 0.00 | – | – |
| 44 | Horde | 4 / 12 | 4 (3–5, 7) | 66/34/0/0 | 5 | 38/58/3/1 | 14 | 0/40/60/0 | 0.00 | – | – |
| 45 | Aufrecht | 5 / 12 | 5 (5–6, 7) | 62/38/0/0 | 6 | 46/54/0/0 | 13 | 0/46/54/0 | 0.00 | – | – |
| 46 | Feuer | 5 / 10 | 5 (4–6, 7) | 55/44/0/0 | 7 | 24/67/9/0 | 12 | 0/39/61/0 | 0.00 | – | – |
| 47 | Wärme | 4 / 16 | 4 (4–5, 6) | 52/48/0/0 | 6 | 24/72/2/1 | 19 | 0/32/67/0 | 0.00 | starve 0.1, frozen 0.1 | starve 1.7, frozen 0.1 |
| 48 | Jäger | 3 / 7 | 4 (3–4, 6) | 46/54/0/0 | 4 | 28/58/9/5 | 11 | 4/42/54/0 | 0.00 | starve 0.1, pack_hunts 0.1 | starve 0.8, pack_hunts 0.2 |
| 49 | Sesshaft | 4 / 14 | 4 (3–5, 6) | 70/30/0/0 | 5 | 36/54/7/2 | 10 | 3/88/8/0 | 0.00 | – | – |
| 50 | Saat | 6 / 11 | 6 (5–7, 8) | 67/33/0/0 | 7 | 38/54/6/2 | 12 | 0/48/52/0 | 0.00 | – | – |
| 51 | Ernte | 6 / 14 | 6 (5–8, 10) | 56/42/2/0 | 8 | 30/64/6/0 | 15 | 2/40/59/0 | 0.00 | – | – |
| 52 | Ackerbau | 5 / 13 | 5 (4–6, 7) | 66/34/0/0 | 7 | 31/58/10/0 | 11 | 1/78/21/0 | 0.00 | – | – |
| 53 | Dörfer | 4 / 11 | 5 (4–6, 7) | 43/57/0/0 | 6 | 18/74/6/1 | 13 | 0/36/62/2 | 0.00 | – | – |
| 54 | Glaube | 3 / 7 | 3 (3–4, 5) | 59/40/0/0 | 4 | 39/55/6/0 | 8 | 2/42/56/0 | 0.00 | – | starve 0.1 |
| 55 | Frieden | 3 / 8 | 4 (3–4, 5) | 48/52/0/0 | 4 | 28/68/4/0 | 10 | 0/35/64/1 | 0.00 | – | starve 0.3 |
| 56 | Städte | 5 / 15 | 5 (4–6, 9) | 66/34/0/0 | 7 | 34/52/13/1 | 13 | 4/60/34/1 | 0.00 | starve 0.3 | starve 1.2 |
| 57 | Fabriken | 4 / 16 | 5 (4–6, 9) | 43/57/0/0 | 7 | 24/63/12/2 | 14 | 4/62/32/1 | 0.00 | starve 0.3, smogged 2.1 | starve 1.3, smogged 2.4 |
| 58 | Rauch | 5 / 15 | 5 (4–6, 7) | 62/38/0/0 | 9 | 28/58/13/1 | 14 | 7/56/37/0 | 0.00 | starve 0.3, smogged 3.5, flooded 0.1 | starve 1.4, smogged 3.9 |
| 59 | Gleichgewicht | 5 / 19 | 5 (4–7, 9) | 55/44/0/0 | 10 | 26/58/10/6 | 15 | 0/78/22/0 | 0.00 | starve 0.7, smogged 2.9 | starve 2.1, smogged 3.8 |
| 60 | Blühende Welt | 6 / 16 | 6 (5–8, 10) | 55/44/1/0 | 9 | 30/54/12/2 | 9 | 4/88/7/0 | 0.00 | – | – |

### 11.4 Carried worlds (100 chains per era: every level after the first of an era starts from the bot's own end world of yesterday)

| # | title | carried, good: done ≤40 / median | fresh, good median | carried, greedy: done ≤50 / median / ★★+ % | fresh, greedy median | fallback to pool (good / greedy chains) |
|---|---|---|---|---|---|---|
| 1 | Glut | 100 % / 4 | 4 | 100 % / 5 / 97 | 5 | 0 / 0 |
| 2 | Abkühlen | 100 % / 5 | 5 | 100 % / 6 / 100 | 6 | 0 / 0 |
| 3 | Vulkan | 100 % / 5 | 5 | 100 % / 6 / 100 | 6 | 0 / 0 |
| 4 | Urkontinent | 100 % / 6 | 6 | 100 % / 6 / 100 | 6 | 0 / 0 |
| 5 | Atmosphäre | 100 % / 5 | 5 | 100 % / 5 / 100 | 5 | 0 / 0 |
| 6 | Urmeer | 100 % / 5 | 4 | 100 % / 5 / 98 | 5 | 0 / 0 |
| 7 | Heiße Quellen | 100 % / 5 | 4 | 100 % / 5 / 100 | 4 | 0 / 0 |
| 8 | Erstes Leben | 100 % / 5 | 5 | 100 % / 6 / 96 | 6 | 0 / 0 |
| 9 | Leben teilt sich | 100 % / 5 | 5 | 100 % / 5 / 100 | 5 | 0 / 0 |
| 10 | Algen | 100 % / 5 | 5 | 100 % / 5 / 92 | 5 | 0 / 0 |
| 11 | Sauerstoff | 100 % / 5 | 5 | 100 % / 7 / 91 | 7 | 0 / 0 |
| 12 | Quallen | 100 % / 5 | 5 | 100 % / 5 / 97 | 5 | 0 / 0 |
| 13 | Trilobiten | 100 % / 4 | 4 | 100 % / 5 / 100 | 5 | 0 / 0 |
| 14 | Vielfalt | 100 % / 5 | 5 | 100 % / 6 / 99 | 6 | 0 / 0 |
| 15 | Fische | 100 % / 6 | 6 | 98 % / 7 / 90 | 6 | 0 / 0 |
| 16 | Schwärme | 97 % / 6 | 5 | 88 % / 11 / 69 | 9 | 0 / 0 |
| 17 | Fischreich | 100 % / 6 | 6 | 99 % / 7 / 94 | 7 | 0 / 0 |
| 18 | Moos | 100 % / 5 | 5 | 100 % / 6 / 98 | 6 | 0 / 0 |
| 19 | Farne | 100 % / 6 | 6 | 100 % / 8 / 96 | 8 | 0 / 0 |
| 20 | Feuchtes Ufer | 100 % / 5 | 5 | 100 % / 5 / 100 | 5 | 1 / 1 |
| 21 | Wälder | 100 % / 7 | 7 | 100 % / 7 / 100 | 7 | 0 / 0 |
| 22 | Licht | 100 % / 5 | 5 | 100 % / 5 / 100 | 5 | 0 / 0 |
| 23 | Urwald | 100 % / 4 | 4 | 100 % / 5 / 99 | 5 | 0 / 0 |
| 24 | Insekten | 100 % / 5 | 5 | 100 % / 6 / 99 | 6 | 0 / 0 |
| 25 | Landgang | 100 % / 4 | 4 | 100 % / 6 / 96 | 6 | 0 / 0 |
| 26 | Frösche | 100 % / 4 | 5 | 100 % / 5 / 100 | 6 | 2 / 0 |
| 27 | Reptilien | 100 % / 4 | 4 | 95 % / 4 / 95 | 4 | 0 / 0 |
| 28 | Saurier | 100 % / 3 | 3 | 100 % / 4 / 99 | 4 | 0 / 0 |
| 29 | Raubsaurier | 100 % / 4 | 4 | 90 % / 6 / 85 | 5 | 0 / 0 |
| 30 | Flugsaurier | 100 % / 5 | 5 | 99 % / 5 / 93 | 6 | 0 / 0 |
| 31 | Nahrungskette | 100 % / 4 | 4 | 99 % / 4 / 98 | 4 | 1 / 1 |
| 32 | Jagd | 100 % / 3 | 3 | 100 % / 4 / 98 | 4 | 0 / 2 |
| 33 | Herde | 98 % / 3 | 3 | 91 % / 3 / 78 | 4 | 0 / 0 |
| 34 | Einschlag | 100 % / 4 | 4 | 100 % / 4 / 100 | 4 | 0 / 0 |
| 35 | Überleben | 99 % / 3 | 3 | 98 % / 4 / 96 | 4 | 7 / 5 |
| 36 | Vögel | 100 % / 5 | 5 | 100 % / 6 / 89 | 6 | 0 / 0 |
| 37 | Raubtiere | 100 % / 4 | 4 | 84 % / 6 / 81 | 5 | 0 / 0 |
| 38 | Rudel | 100 % / 2 | 2 | 100 % / 2 / 100 | 3 | 0 / 3 |
| 39 | Herden | 100 % / 3 | 3 | 94 % / 4 / 82 | 4 | 0 / 0 |
| 40 | Eiszeit | 100 % / 4 | 4 | 100 % / 5 / 99 | 5 | 0 / 0 |
| 41 | Mammut | 100 % / 5 | 5 | 95 % / 5 / 86 | 6 | 0 / 1 |
| 42 | Tauwetter | 100 % / 3 | 3 | 100 % / 3 / 100 | 4 | 1 / 2 |
| 43 | Affen | 100 % / 5 | 5 | 100 % / 6 / 99 | 6 | 0 / 0 |
| 44 | Horde | 100 % / 4 | 4 | 99 % / 6 / 92 | 5 | 0 / 0 |
| 45 | Aufrecht | 100 % / 5 | 5 | 100 % / 6 / 99 | 6 | 0 / 0 |
| 46 | Feuer | 100 % / 5 | 5 | 100 % / 7 / 91 | 7 | 0 / 0 |
| 47 | Wärme | 100 % / 4 | 4 | 99 % / 5 / 95 | 6 | 18 / 16 |
| 48 | Jäger | 100 % / 4 | 4 | 96 % / 4 / 90 | 4 | 0 / 0 |
| 49 | Sesshaft | 100 % / 4 | 4 | 94 % / 6 / 88 | 5 | 0 / 0 |
| 50 | Saat | 100 % / 6 | 6 | 100 % / 7 / 94 | 7 | 0 / 0 |
| 51 | Ernte | 100 % / 6 | 6 | 100 % / 7 / 95 | 8 | 0 / 0 |
| 52 | Ackerbau | 100 % / 5 | 5 | 100 % / 7 / 89 | 7 | 40 / 32 |
| 53 | Dörfer | 100 % / 4 | 5 | 100 % / 5 / 97 | 6 | 0 / 0 |
| 54 | Glaube | 100 % / 3 | 3 | 100 % / 4 / 95 | 4 | 0 / 0 |
| 55 | Frieden | 100 % / 3 | 4 | 100 % / 4 / 99 | 4 | 0 / 0 |
| 56 | Städte | 100 % / 5 | 5 | 99 % / 7 / 89 | 7 | 0 / 0 |
| 57 | Fabriken | 100 % / 5 | 5 | 98 % / 7 / 88 | 7 | 0 / 0 |
| 58 | Rauch | 100 % / 4 | 5 | 100 % / 6 / 90 | 9 | 0 / 0 |
| 59 | Gleichgewicht | 100 % / 5 | 5 | 94 % / 9 / 86 | 10 | 0 / 0 |
| 60 | Blühende Welt | 100 % / 7 | 6 | 97 % / 9 / 85 | 9 | 0 / 1 |

### 11.5 No dead ends: uncapped casual play and the safety net

Casual bot without a step cap (300), 100 boards per level with a danger or hunger, no gift:

| # | title | weak, no cap (≤300): done | median | p90 | max |
|---|---|---|---|---|---|
| 3 | Vulkan | 100 % | 11 | 15 | 18 |
| 4 | Urkontinent | 100 % | 15 | 18 | 28 |
| 5 | Atmosphäre | 100 % | 17 | 21 | 24 |
| 6 | Urmeer | 100 % | 11 | 16 | 20 |
| 7 | Heiße Quellen | 100 % | 11 | 15 | 23 |
| 8 | Erstes Leben | 100 % | 12 | 16 | 18 |
| 9 | Leben teilt sich | 100 % | 12 | 16 | 21 |
| 21 | Wälder | 100 % | 14 | 19 | 22 |
| 22 | Licht | 100 % | 12 | 15 | 19 |
| 23 | Urwald | 100 % | 12 | 19 | 25 |
| 24 | Insekten | 100 % | 12 | 15 | 21 |
| 25 | Landgang | 100 % | 10 | 13 | 21 |
| 26 | Frösche | 100 % | 20 | 29 | 41 |
| 27 | Reptilien | 100 % | 20 | 37 | 66 |
| 28 | Saurier | 100 % | 10 | 18 | 26 |
| 29 | Raubsaurier | 100 % | 15 | 23 | 39 |
| 30 | Flugsaurier | 100 % | 12 | 16 | 21 |
| 31 | Nahrungskette | 100 % | 17 | 24 | 37 |
| 32 | Jagd | 100 % | 11 | 19 | 30 |
| 33 | Herde | 100 % | 21 | 35 | 76 |
| 35 | Überleben | 100 % | 10 | 17 | 20 |
| 36 | Vögel | 100 % | 11 | 16 | 21 |
| 37 | Raubtiere | 100 % | 14 | 26 | 80 |
| 38 | Rudel | 100 % | 7 | 12 | 19 |
| 39 | Herden | 100 % | 20 | 31 | 51 |
| 40 | Eiszeit | 100 % | 17 | 28 | 95 |
| 41 | Mammut | 100 % | 12 | 18 | 22 |
| 42 | Tauwetter | 100 % | 16 | 31 | 101 |
| 44 | Horde | 100 % | 14 | 22 | 25 |
| 47 | Wärme | 100 % | 19 | 26 | 37 |
| 48 | Jäger | 100 % | 12 | 30 | 73 |
| 49 | Sesshaft | 100 % | 10 | 14 | 22 |
| 50 | Saat | 100 % | 11 | 14 | 17 |
| 51 | Ernte | 100 % | 16 | 20 | 25 |
| 52 | Ackerbau | 100 % | 11 | 15 | 24 |
| 53 | Dörfer | 97 % | 12 | 18 | 21 |
| 54 | Glaube | 100 % | 8 | 13 | 19 |
| 55 | Frieden | 100 % | 10 | 17 | 25 |
| 56 | Städte | 100 % | 13 | 22 | 32 |
| 57 | Fabriken | 100 % | 14 | 22 | 33 |
| 58 | Rauch | 100 % | 14 | 22 | 29 |
| 59 | Gleichgewicht | 100 % | 14 | 21 | 187 |
| 60 | Blühende Welt | 100 % | 9 | 15 | 21 |

With the safety net (gift after 6 steps without progress, model of `Game.take_gift`; 100 fresh boards per level and 100 carried chains per era):

| # | title | weak + net: done ≤80 / gifts per game | greedy (no net): done ≤50 | greedy + net: done ≤50 / ★★+ % / gifts | carried, greedy (no net): done / ★★+ % | carried, greedy + net: done / ★★+ % / gifts |
|---|---|---|---|---|---|---|
| 1 | Glut | 100 % / 0.02 | 100.0 % | 100 % / 99 % / 0.02 | 100 % / 97 % | 100 % / 99 % / 0.02 |
| 2 | Abkühlen | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 3 | Vulkan | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 4 | Urkontinent | 100 % / 0.03 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 5 | Atmosphäre | 100 % / 0.01 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 6 | Urmeer | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 98 % | 100 % / 98 % / 0.00 |
| 7 | Heiße Quellen | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 8 | Erstes Leben | 100 % / 0.08 | 100.0 % | 100 % / 96 % / 0.01 | 100 % / 96 % | 100 % / 96 % / 0.01 |
| 9 | Leben teilt sich | 100 % / 0.08 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 10 | Algen | 100 % / 0.05 | 100.0 % | 100 % / 99 % / 0.00 | 100 % / 92 % | 100 % / 92 % / 0.03 |
| 11 | Sauerstoff | 100 % / 0.58 | 100.0 % | 100 % / 100 % / 0.20 | 100 % / 91 % | 100 % / 99 % / 0.17 |
| 12 | Quallen | 100 % / 0.02 | 100.0 % | 100 % / 97 % / 0.01 | 100 % / 97 % | 100 % / 97 % / 0.01 |
| 13 | Trilobiten | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 14 | Vielfalt | 100 % / 0.04 | 100.0 % | 100 % / 100 % / 0.01 | 100 % / 99 % | 100 % / 100 % / 0.03 |
| 15 | Fische | 100 % / 0.06 | 97.0 % | 100 % / 93 % / 0.12 | 98 % / 90 % | 100 % / 93 % / 0.12 |
| 16 | Schwärme | 100 % / 0.68 | 97.5 % | 100 % / 100 % / 0.47 | 88 % / 69 % | 100 % / 99 % / 0.72 |
| 17 | Fischreich | 100 % / 0.08 | 99.0 % | 100 % / 96 % / 0.08 | 99 % / 94 % | 100 % / 94 % / 0.13 |
| 18 | Moos | 100 % / 0.01 | 100.0 % | 100 % / 98 % / 0.00 | 100 % / 98 % | 100 % / 98 % / 0.00 |
| 19 | Farne | 100 % / 0.04 | 100.0 % | 100 % / 98 % / 0.00 | 100 % / 96 % | 100 % / 96 % / 0.00 |
| 20 | Feuchtes Ufer | 100 % / 0.19 | 100.0 % | 100 % / 100 % / 0.01 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 21 | Wälder | 100 % / 0.03 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 22 | Licht | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 23 | Urwald | 100 % / 0.18 | 100.0 % | 100 % / 99 % / 0.00 | 100 % / 99 % | 100 % / 99 % / 0.01 |
| 24 | Insekten | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 99 % | 100 % / 99 % / 0.00 |
| 25 | Landgang | 100 % / 0.02 | 100.0 % | 100 % / 97 % / 0.03 | 100 % / 96 % | 100 % / 97 % / 0.03 |
| 26 | Frösche | 100 % / 0.64 | 100.0 % | 100 % / 99 % / 0.03 | 100 % / 100 % | 100 % / 100 % / 0.01 |
| 27 | Reptilien | 100 % / 0.97 | 98.0 % | 100 % / 100 % / 0.07 | 95 % / 95 % | 100 % / 100 % / 0.04 |
| 28 | Saurier | 100 % / 0.23 | 99.5 % | 100 % / 99 % / 0.00 | 100 % / 99 % | 100 % / 99 % / 0.00 |
| 29 | Raubsaurier | 100 % / 0.77 | 95.0 % | 100 % / 100 % / 0.22 | 90 % / 85 % | 100 % / 99 % / 0.35 |
| 30 | Flugsaurier | 100 % / 0.04 | 100.0 % | 100 % / 95 % / 0.02 | 99 % / 93 % | 100 % / 94 % / 0.06 |
| 31 | Nahrungskette | 100 % / 0.53 | 99.0 % | 100 % / 100 % / 0.04 | 99 % / 98 % | 100 % / 100 % / 0.03 |
| 32 | Jagd | 100 % / 0.18 | 100.0 % | 100 % / 99 % / 0.01 | 100 % / 98 % | 100 % / 99 % / 0.00 |
| 33 | Herde | 100 % / 1.18 | 95.5 % | 100 % / 98 % / 0.13 | 91 % / 78 % | 100 % / 88 % / 0.37 |
| 34 | Einschlag | 100 % / 0.00 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 35 | Überleben | 100 % / 0.19 | 100.0 % | 100 % / 98 % / 0.02 | 98 % / 96 % | 100 % / 96 % / 0.04 |
| 36 | Vögel | 100 % / 0.03 | 100.0 % | 100 % / 89 % / 0.05 | 100 % / 89 % | 100 % / 89 % / 0.05 |
| 37 | Raubtiere | 100 % / 0.72 | 93.5 % | 100 % / 100 % / 0.21 | 84 % / 81 % | 100 % / 99 % / 0.34 |
| 38 | Rudel | 100 % / 0.04 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 100 % | 100 % / 99 % / 0.01 |
| 39 | Herden | 100 % / 1.03 | 95.0 % | 100 % / 97 % / 0.20 | 94 % / 82 % | 100 % / 93 % / 0.27 |
| 40 | Eiszeit | 100 % / 0.46 | 99.5 % | 100 % / 100 % / 0.02 | 100 % / 99 % | 100 % / 100 % / 0.02 |
| 41 | Mammut | 100 % / 0.40 | 94.5 % | 99 % / 96 % / 0.18 | 95 % / 86 % | 100 % / 92 % / 0.14 |
| 42 | Tauwetter | 100 % / 0.71 | 100.0 % | 100 % / 100 % / 0.03 | 100 % / 100 % | 100 % / 100 % / 0.00 |
| 43 | Affen | 100 % / 0.00 | 99.5 % | 100 % / 100 % / 0.01 | 100 % / 99 % | 100 % / 100 % / 0.01 |
| 44 | Horde | 100 % / 0.33 | 99.0 % | 100 % / 99 % / 0.03 | 99 % / 92 % | 100 % / 95 % / 0.08 |
| 45 | Aufrecht | 100 % / 0.09 | 100.0 % | 100 % / 100 % / 0.00 | 100 % / 99 % | 100 % / 98 % / 0.03 |
| 46 | Feuer | 100 % / 0.05 | 100.0 % | 100 % / 92 % / 0.03 | 100 % / 91 % | 100 % / 92 % / 0.03 |
| 47 | Wärme | 100 % / 0.75 | 99.0 % | 100 % / 100 % / 0.12 | 99 % / 95 % | 100 % / 100 % / 0.12 |
| 48 | Jäger | 100 % / 0.58 | 95.0 % | 100 % / 90 % / 0.09 | 96 % / 90 % | 100 % / 90 % / 0.09 |
| 49 | Sesshaft | 100 % / 0.18 | 97.5 % | 100 % / 100 % / 0.20 | 94 % / 88 % | 100 % / 99 % / 0.32 |
| 50 | Saat | 100 % / 0.06 | 98.5 % | 100 % / 95 % / 0.03 | 100 % / 94 % | 100 % / 95 % / 0.03 |
| 51 | Ernte | 100 % / 0.43 | 100.0 % | 100 % / 99 % / 0.23 | 100 % / 95 % | 100 % / 98 % / 0.21 |
| 52 | Ackerbau | 100 % / 0.15 | 100.0 % | 100 % / 96 % / 0.15 | 100 % / 89 % | 100 % / 97 % / 0.15 |
| 53 | Dörfer | 100 % / 0.28 | 99.0 % | 100 % / 96 % / 0.12 | 100 % / 97 % | 100 % / 98 % / 0.05 |
| 54 | Glaube | 100 % / 0.30 | 100.0 % | 100 % / 96 % / 0.02 | 100 % / 95 % | 100 % / 96 % / 0.02 |
| 55 | Frieden | 100 % / 0.30 | 100.0 % | 100 % / 95 % / 0.04 | 100 % / 99 % | 100 % / 99 % / 0.01 |
| 56 | Städte | 100 % / 0.73 | 99.0 % | 100 % / 97 % / 0.28 | 99 % / 89 % | 100 % / 97 % / 0.28 |
| 57 | Fabriken | 100 % / 0.74 | 98.5 % | 100 % / 99 % / 0.35 | 98 % / 88 % | 100 % / 99 % / 0.35 |
| 58 | Rauch | 100 % / 0.71 | 99.0 % | 100 % / 97 % / 0.38 | 100 % / 90 % | 100 % / 93 % / 0.37 |
| 59 | Gleichgewicht | 100 % / 0.67 | 94.0 % | 100 % / 99 % / 0.52 | 94 % / 86 % | 100 % / 99 % / 0.52 |
| 60 | Blühende Welt | 100 % / 0.63 | 97.5 % | 100 % / 100 % / 0.61 | 97 % / 85 % | 100 % / 99 % / 0.63 |

### 11.6 Farmers (oracle, 200 boards per level, horizon 30)

| # | title | farmer done ≤30 | farmer median | good median | farmer ★★★ % | boards farmer faster than good | farmer pts / good pts | best farmer pp/cyc/slice |
|---|---|---|---|---|---|---|---|---|
| 1 | Glut | 100 % | 18 | 4 | 0 | 0 of 200 | 41 / 73 | 0/51/149 |
| 2 | Abkühlen | 99 % | 19 | 5 | 3 | 0 of 200 | 43 / 72 | 0/80/120 |
| 3 | Vulkan | 100 % | 11 | 5 | 2 | 3 of 200 | 47 / 77 | 4/169/27 |
| 4 | Urkontinent | 82 % | 19 | 6 | 0 | 1 of 200 | 36 / 69 | 3/126/71 |
| 5 | Atmosphäre | 98 % | 19 | 5 | 0 | 0 of 200 | 43 / 75 | 0/2/198 |
| 6 | Urmeer | 100 % | 15 | 4 | 8 | 0 of 200 | 46 / 73 | 0/50/150 |
| 7 | Heiße Quellen | 100 % | 8 | 4 | 20 | 0 of 200 | 54 / 75 | 0/83/117 |
| 8 | Erstes Leben | 80 % | 14 | 5 | 2 | 0 of 200 | 37 / 75 | 0/8/192 |
| 9 | Leben teilt sich | 100 % | 9 | 5 | 21 | 0 of 200 | 58 / 79 | 0/0/200 |
| 10 | Algen | 91 % | 21 | 5 | 2 | 0 of 200 | 37 / 71 | 0/31/169 |
| 11 | Sauerstoff | 58 % | 23 | 5 | 2 | 1 of 200 | 25 / 73 | 1/52/147 |
| 12 | Quallen | 96 % | 15 | 5 | 0 | 0 of 200 | 40 / 70 | 0/5/195 |
| 13 | Trilobiten | 47 % | 8 | 4 | 12 | 0 of 200 | 26 / 74 | 6/145/49 |
| 14 | Vielfalt | 73 % | 19 | 5 | 1 | 0 of 200 | 30 / 72 | 0/10/190 |
| 15 | Fische | 7 % | 16 | 6 | 0 | 0 of 200 | 3 / 69 | 3/97/100 |
| 16 | Schwärme | 8 % | 8 | 5 | 2 | 0 of 200 | 5 / 72 | 66/89/45 |
| 17 | Fischreich | 8 % | 20 | 6 | 0 | 0 of 200 | 4 / 75 | 0/85/115 |
| 18 | Moos | 100 % | 18 | 5 | 2 | 0 of 200 | 42 / 74 | 0/5/195 |
| 19 | Farne | 100 % | 18 | 6 | 0 | 0 of 200 | 41 / 71 | 0/1/199 |
| 20 | Feuchtes Ufer | 100 % | 19 | 5 | 2 | 0 of 200 | 42 / 77 | 0/17/183 |
| 21 | Wälder | 20 % | 20 | 7 | 2 | 3 of 200 | 9 / 72 | 0/46/154 |
| 22 | Licht | 100 % | 20 | 5 | 0 | 0 of 200 | 40 / 78 | 0/0/200 |
| 23 | Urwald | 94 % | 17 | 4 | 0 | 0 of 200 | 39 / 76 | 0/10/190 |
| 24 | Insekten | 44 % | 15 | 5 | 2 | 0 of 200 | 20 / 75 | 0/54/146 |
| 25 | Landgang | 100 % | 11 | 4 | 2 | 0 of 200 | 44 / 74 | 0/4/196 |
| 26 | Frösche | 7 % | 8 | 5 | 0 | 0 of 200 | 4 / 77 | 1/137/62 |
| 27 | Reptilien | 14 % | 4 | 4 | 7 | 1 of 200 | 10 / 76 | 27/141/32 |
| 28 | Saurier | 82 % | 10 | 3 | 9 | 0 of 200 | 41 / 74 | 0/11/189 |
| 29 | Raubsaurier | 14 % | 5 | 4 | 6 | 2 of 200 | 10 / 75 | 80/90/30 |
| 30 | Flugsaurier | 26 % | 12 | 5 | 2 | 1 of 200 | 13 / 72 | 2/73/125 |
| 31 | Nahrungskette | 16 % | 6 | 4 | 2 | 0 of 200 | 10 / 77 | 0/45/155 |
| 32 | Jagd | 96 % | 8 | 3 | 7 | 0 of 200 | 52 / 76 | 0/11/189 |
| 33 | Herde | 12 % | 2 | 3 | 8 | 0 of 200 | 9 / 75 | 44/121/35 |
| 34 | Einschlag | 100 % | 5 | 4 | 32 | 3 of 200 | 66 / 79 | 2/28/170 |
| 35 | Überleben | 86 % | 9 | 3 | 3 | 0 of 200 | 43 / 74 | 0/8/192 |
| 36 | Vögel | 25 % | 12 | 5 | 4 | 1 of 200 | 13 / 73 | 2/62/136 |
| 37 | Raubtiere | 10 % | 4 | 4 | 6 | 1 of 200 | 8 / 75 | 87/80/33 |
| 38 | Rudel | 100 % | 5 | 2 | 20 | 0 of 200 | 57 / 74 | 0/20/180 |
| 39 | Herden | 20 % | 3 | 3 | 11 | 1 of 200 | 14 / 73 | 43/127/30 |
| 40 | Eiszeit | 44 % | 15 | 4 | 2 | 0 of 200 | 21 / 77 | 0/28/172 |
| 41 | Mammut | 11 % | 10 | 5 | 2 | 1 of 200 | 6 / 76 | 21/90/89 |
| 42 | Tauwetter | 77 % | 6 | 3 | 11 | 2 of 200 | 43 / 75 | 0/48/152 |
| 43 | Affen | 24 % | 17 | 5 | 0 | 0 of 200 | 11 / 74 | 0/52/148 |
| 44 | Horde | 20 % | 11 | 4 | 4 | 1 of 200 | 11 / 75 | 8/142/50 |
| 45 | Aufrecht | 24 % | 15 | 5 | 2 | 0 of 200 | 11 / 75 | 10/155/35 |
| 46 | Feuer | 14 % | 14 | 5 | 2 | 0 of 200 | 7 / 73 | 4/146/50 |
| 47 | Wärme | 8 % | 7 | 4 | 0 | 0 of 200 | 5 / 72 | 21/178/1 |
| 48 | Jäger | 24 % | 4 | 4 | 10 | 2 of 200 | 16 / 71 | 33/154/13 |
| 49 | Sesshaft | 32 % | 12 | 4 | 4 | 2 of 200 | 16 / 77 | 47/152/1 |
| 50 | Saat | 60 % | 13 | 6 | 2 | 2 of 200 | 27 / 76 | 0/8/192 |
| 51 | Ernte | 38 % | 16 | 6 | 2 | 0 of 200 | 18 / 73 | 0/30/170 |
| 52 | Ackerbau | 20 % | 10 | 5 | 4 | 2 of 200 | 11 / 76 | 1/75/124 |
| 53 | Dörfer | 28 % | 14 | 5 | 2 | 0 of 200 | 13 / 70 | 12/137/51 |
| 54 | Glaube | 48 % | 3 | 3 | 25 | 2 of 200 | 34 / 73 | 66/105/29 |
| 55 | Frieden | 57 % | 7 | 4 | 10 | 1 of 200 | 31 / 72 | 20/173/7 |
| 56 | Städte | 12 % | 7 | 5 | 4 | 1 of 200 | 7 / 76 | 83/117/0 |
| 57 | Fabriken | 15 % | 7 | 5 | 4 | 2 of 200 | 9 / 70 | 89/108/3 |
| 58 | Rauch | 16 % | 9 | 5 | 6 | 0 of 200 | 10 / 76 | 96/102/2 |
| 59 | Gleichgewicht | 13 % | 12 | 5 | 4 | 1 of 200 | 8 / 72 | 11/189/0 |
| 60 | Blühende Welt | 7 % | 5 | 6 | 7 | 4 of 200 | 6 / 73 | 187/6/7 |

### 11.7 Dangers avoidable (100 boards per level with a danger, good and greedy)

Fields a danger changed per game: on a goal-kind field (counts against the task: `make` loss or a satt/group field gone) and on other fields; the last column is the real `make` loss (made − lost).

| # | title | good: danger hits on goal-kind fields / other fields per game (causes) | greedy: goal-kind / other (causes) | good goal losses (`make`) per game |
|---|---|---|---|---|
| 3 | Vulkan | 2.53 / 0.00 (volcano 2.53) | 1.86 / 0.00 (volcano 1.86) | 0.03 |
| 4 | Urkontinent | 0.02 / 1.45 (volcano 0.02) | 0.02 / 1.15 (volcano 0.02) | 0.01 |
| 5 | Atmosphäre | 0.00 / 1.50 (–) | 0.00 / 1.74 (–) | 0.00 |
| 7 | Heiße Quellen | 0.00 / 0.32 (–) | 0.00 / 0.20 (–) | 0.00 |
| 21 | Wälder | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 22 | Licht | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 23 | Urwald | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 24 | Insekten | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 26 | Frösche | 0.46 / 0.00 (hunger 0.46) | 2.41 / 0.00 (hunger 2.41) | 0.00 |
| 27 | Reptilien | 0.00 / 0.09 (–) | 0.00 / 0.88 (–) | 0.00 |
| 28 | Saurier | 0.00 / 0.00 (–) | 0.07 / 0.00 (hunger 0.07) | 0.00 |
| 29 | Raubsaurier | 0.00 / 0.17 (–) | 0.00 / 0.66 (–) | 0.00 |
| 30 | Flugsaurier | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 31 | Nahrungskette | 0.02 / 0.00 (hunger 0.02) | 0.24 / 0.00 (hunger 0.24) | 0.00 |
| 32 | Jagd | 0.01 / 0.00 (pack 0.01) | 0.08 / 0.02 (hunger 0.08) | 0.00 |
| 33 | Herde | 0.22 / 0.05 (hunger 0.09, pack 0.13) | 0.39 / 0.20 (hunger 0.27, pack 0.12) | 0.00 |
| 35 | Überleben | 0.02 / 0.00 (hunger 0.02) | 0.07 / 0.00 (hunger 0.07) | 0.00 |
| 36 | Vögel | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 37 | Raubtiere | 0.00 / 0.05 (–) | 0.00 / 0.50 (–) | 0.00 |
| 38 | Rudel | 0.01 / 0.00 (pack 0.01) | 0.01 / 0.00 (pack 0.01) | 0.00 |
| 39 | Herden | 0.25 / 0.11 (hunger 0.22, pack 0.03) | 0.53 / 0.31 (hunger 0.45, pack 0.08) | 0.00 |
| 40 | Eiszeit | 0.05 / 0.67 (hunger 0.02, ice 0.03) | 0.31 / 0.49 (hunger 0.28, ice 0.03) | 0.00 |
| 41 | Mammut | 0.04 / 0.08 (hunger 0.04) | 0.21 / 0.04 (hunger 0.21) | 0.00 |
| 42 | Tauwetter | 0.08 / 0.14 (hunger 0.08) | 0.18 / 0.08 (hunger 0.18) | 0.00 |
| 44 | Horde | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 47 | Wärme | 0.10 / 0.15 (hunger 0.09, ice 0.01) | 1.54 / 0.18 (hunger 1.52, ice 0.02) | 0.00 |
| 48 | Jäger | 0.03 / 0.16 (hunger 0.03) | 0.65 / 0.18 (hunger 0.65) | 0.00 |
| 49 | Sesshaft | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 50 | Saat | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 51 | Ernte | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 52 | Ackerbau | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 53 | Dörfer | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |
| 54 | Glaube | 0.00 / 0.01 (–) | 0.00 / 0.06 (–) | 0.00 |
| 55 | Frieden | 0.00 / 0.00 (–) | 0.41 / 0.00 (hunger 0.41) | 0.00 |
| 56 | Städte | 0.20 / 0.00 (hunger 0.20) | 1.10 / 0.04 (hunger 1.10) | 0.00 |
| 57 | Fabriken | 0.32 / 2.15 (hunger 0.32) | 1.09 / 2.64 (hunger 1.09) | 0.00 |
| 58 | Rauch | 0.27 / 3.48 (hunger 0.27) | 1.28 / 3.90 (hunger 1.28) | 0.00 |
| 59 | Gleichgewicht | 1.12 / 2.28 (hunger 0.55, smog 0.56, war 0.01) | 2.32 / 3.30 (hunger 1.64, smog 0.68) | 0.00 |
| 60 | Blühende Welt | 0.00 / 0.00 (–) | 0.00 / 0.00 (–) | 0.00 |

### 11.8 Pools (`kampagne_erde_b6.json`, 20 boards per level, 1 200 in total)

Filters (as `export9`): start rules, ≤ 3 growable and ≤ 6 visible kinds, the good bot wins in ≥ 3 steps (old 1 and 23 = levels 1 and 38: ≥ 2) and with ≥ ★★, no single twist wins, farm-proof (the oracle farmer never gets ★★★ and is never faster than the stored solution), level 1 board 0 = tutorial (model move (0, 1, 1) makes a Lava row). Every solution is replayed by `export10.py` and again by `export_gd10.py`.

| # | title | boards | solved_in median | ★★★/★★/★ of the solutions | farmer finishes ≤ 30 (never ★★★, never faster) | rejected (gen / kinds / bot / farm / tut) |
|---|---|---|---|---|---|---|
| 1 | Glut | 20 | 4.0 | 11/9/0 | 20 of 20 | 0 / 0 / 0 / 0 / 0 |
| 2 | Abkühlen | 20 | 5.0 | 8/12/0 | 20 of 20 | 0 / 0 / 0 / 1 / 0 |
| 3 | Vulkan | 20 | 5.0 | 18/2/0 | 20 of 20 | 0 / 0 / 0 / 0 / 0 |
| 4 | Urkontinent | 20 | 6.0 | 9/11/0 | 14 of 20 | 0 / 0 / 0 / 0 / 0 |
| 5 | Atmosphäre | 20 | 5.0 | 14/6/0 | 20 of 20 | 0 / 0 / 0 / 0 / 0 |
| 6 | Urmeer | 20 | 4.5 | 10/10/0 | 20 of 20 | 0 / 0 / 0 / 1 / 0 |
| 7 | Heiße Quellen | 20 | 5.0 | 6/14/0 | 20 of 20 | 0 / 0 / 0 / 3 / 0 |
| 8 | Erstes Leben | 20 | 5.0 | 14/6/0 | 16 of 20 | 0 / 0 / 0 / 1 / 0 |
| 9 | Leben teilt sich | 20 | 5.0 | 18/2/0 | 20 of 20 | 0 / 0 / 0 / 10 / 0 |
| 10 | Algen | 20 | 5.0 | 8/12/0 | 19 of 20 | 0 / 0 / 0 / 0 / 0 |
| 11 | Sauerstoff | 20 | 6.0 | 9/11/0 | 9 of 20 | 0 / 0 / 0 / 1 / 0 |
| 12 | Quallen | 20 | 4.5 | 10/10/0 | 19 of 20 | 0 / 0 / 0 / 0 / 0 |
| 13 | Trilobiten | 20 | 4.0 | 13/7/0 | 7 of 20 | 0 / 0 / 0 / 3 / 0 |
| 14 | Vielfalt | 20 | 5.0 | 14/6/0 | 13 of 20 | 0 / 0 / 0 / 0 / 0 |
| 15 | Fische | 20 | 6.0 | 6/14/0 | 1 of 20 | 0 / 0 / 0 / 0 / 0 |
| 16 | Schwärme | 20 | 6.0 | 8/12/0 | 1 of 20 | 0 / 0 / 0 / 0 / 0 |
| 17 | Fischreich | 20 | 6.0 | 13/7/0 | 1 of 20 | 0 / 0 / 0 / 0 / 0 |
| 18 | Moos | 20 | 5.0 | 12/8/0 | 20 of 20 | 0 / 0 / 0 / 1 / 0 |
| 19 | Farne | 20 | 7.5 | 7/13/0 | 20 of 20 | 0 / 0 / 0 / 0 / 0 |
| 20 | Feuchtes Ufer | 20 | 5.0 | 14/6/0 | 20 of 20 | 0 / 0 / 0 / 1 / 0 |
| 21 | Wälder | 20 | 7.0 | 7/13/0 | 5 of 20 | 0 / 0 / 0 / 1 / 0 |
| 22 | Licht | 20 | 5.0 | 17/3/0 | 20 of 20 | 0 / 0 / 0 / 0 / 0 |
| 23 | Urwald | 20 | 4.0 | 11/9/0 | 19 of 20 | 0 / 0 / 2 / 0 / 0 |
| 24 | Insekten | 20 | 5.0 | 15/5/0 | 12 of 20 | 0 / 0 / 0 / 2 / 0 |
| 25 | Landgang | 20 | 5.0 | 8/12/0 | 20 of 20 | 0 / 0 / 0 / 0 / 0 |
| 26 | Frösche | 20 | 5.0 | 14/6/0 | 0 of 20 | 0 / 0 / 0 / 0 / 0 |
| 27 | Reptilien | 20 | 4.0 | 15/5/0 | 2 of 20 | 0 / 0 / 0 / 4 / 0 |
| 28 | Saurier | 20 | 3.0 | 11/9/0 | 15 of 20 | 0 / 0 / 8 / 2 / 0 |
| 29 | Raubsaurier | 20 | 4.0 | 15/5/0 | 2 of 20 | 0 / 0 / 0 / 1 / 0 |
| 30 | Flugsaurier | 20 | 5.0 | 12/8/0 | 4 of 20 | 0 / 0 / 0 / 0 / 0 |
| 31 | Nahrungskette | 20 | 4.0 | 13/7/0 | 4 of 20 | 0 / 0 / 1 / 0 / 0 |
| 32 | Jagd | 20 | 3.0 | 13/7/0 | 19 of 20 | 0 / 0 / 9 / 1 / 0 |
| 33 | Herde | 20 | 3.0 | 11/9/0 | 0 of 20 | 0 / 0 / 12 / 0 / 0 |
| 34 | Einschlag | 20 | 4.0 | 17/3/0 | 20 of 20 | 0 / 0 / 0 / 7 / 0 |
| 35 | Überleben | 20 | 3.5 | 10/10/0 | 17 of 20 | 0 / 0 / 4 / 0 / 0 |
| 36 | Vögel | 20 | 5.0 | 11/9/0 | 7 of 20 | 0 / 0 / 0 / 0 / 0 |
| 37 | Raubtiere | 20 | 4.0 | 12/8/0 | 0 of 20 | 0 / 0 / 2 / 0 / 0 |
| 38 | Rudel | 20 | 2.0 | 12/8/0 | 20 of 20 | 0 / 0 / 0 / 3 / 0 |
| 39 | Herden | 20 | 3.0 | 15/5/0 | 2 of 20 | 0 / 0 / 9 / 0 / 0 |
| 40 | Eiszeit | 20 | 4.0 | 12/8/0 | 5 of 20 | 0 / 0 / 2 / 0 / 0 |
| 41 | Mammut | 20 | 5.0 | 15/5/0 | 0 of 20 | 0 / 0 / 0 / 2 / 0 |
| 42 | Tauwetter | 20 | 3.0 | 13/7/0 | 14 of 20 | 0 / 0 / 6 / 1 / 0 |
| 43 | Affen | 20 | 5.0 | 14/6/0 | 1 of 20 | 0 / 0 / 0 / 0 / 0 |
| 44 | Horde | 20 | 4.0 | 11/9/0 | 4 of 20 | 0 / 0 / 3 / 0 / 0 |
| 45 | Aufrecht | 20 | 5.0 | 14/6/0 | 4 of 20 | 0 / 0 / 0 / 2 / 0 |
| 46 | Feuer | 20 | 5.0 | 16/4/0 | 3 of 20 | 0 / 0 / 0 / 0 / 0 |
| 47 | Wärme | 20 | 4.0 | 16/4/0 | 2 of 20 | 0 / 0 / 0 / 0 / 0 |
| 48 | Jäger | 20 | 3.0 | 12/8/0 | 6 of 20 | 0 / 0 / 5 / 2 / 0 |
| 49 | Sesshaft | 20 | 4.0 | 14/6/0 | 7 of 20 | 0 / 0 / 1 / 3 / 0 |
| 50 | Saat | 20 | 6.0 | 13/7/0 | 15 of 20 | 0 / 0 / 0 / 0 / 0 |
| 51 | Ernte | 20 | 6.0 | 12/8/0 | 6 of 20 | 0 / 0 / 0 / 0 / 0 |
| 52 | Ackerbau | 20 | 5.0 | 13/7/0 | 3 of 20 | 0 / 0 / 0 / 1 / 0 |
| 53 | Dörfer | 20 | 5.0 | 9/11/0 | 7 of 20 | 0 / 0 / 0 / 0 / 0 |
| 54 | Glaube | 20 | 4.0 | 7/13/0 | 4 of 20 | 0 / 0 / 8 / 3 / 0 |
| 55 | Frieden | 20 | 4.0 | 7/13/0 | 9 of 20 | 0 / 0 / 1 / 1 / 0 |
| 56 | Städte | 20 | 5.0 | 14/6/0 | 3 of 20 | 0 / 0 / 2 / 1 / 0 |
| 57 | Fabriken | 20 | 4.0 | 11/9/0 | 4 of 20 | 0 / 0 / 2 / 0 / 0 |
| 58 | Rauch | 20 | 6.0 | 9/11/0 | 1 of 20 | 0 / 0 / 1 / 0 / 0 |
| 59 | Gleichgewicht | 20 | 4.0 | 12/8/0 | 3 of 20 | 0 / 0 / 0 / 2 / 0 |
| 60 | Blühende Welt | 20 | 6.0 | 11/9/0 | 0 of 20 | 0 / 0 / 1 / 3 / 0 |

### 11.9 What the numbers mean for the game

- **Every level is solvable, also from a carried world, with the safety net.** The good bot finishes 99.9 % of the
  12 000 fresh games within 40 steps (every level ≥ 98.5 %) and 99.9 % of the 6 000 carried-world games. With the
  safety net (`bot10.play_net`: after 6 steps without progress the free gift, +1 progress now, as `Game.take_gift`)
  the casual player finishes **100 %** of 6 000 games within 80 steps and the average player **99.98 %** within 50
  (one game in level 41) and **100 %** of 6 000 carried-world games. The average player needs a gift in ≤ 0.2 games
  per level except 16, 29, 37, 51 and 56–60 (0.2–0.6); the casual player 0.2–1.2 per game in 25 levels (most in the
  group and hunger levels 33, 39, 27). Without any net and without a step cap the
  casual bot finishes 100 % of every danger/hunger level except **level 53 Dörfer (old 26): 97 %** – three games where
  every fed Hütte sat on a centre sticker that can never touch a Wald, so 🔨 is impossible by sticker type. The same
  boards exist in „Die Schöpfung“; `reach9` must count Hütten as Dorf candidates and check 🔨 by sticker type so the
  gift triggers there (test case seeds 47, 78, 84 of `levels10.generate(53, seed)`, section 13 item 10).
- **Stars stay generous (feedback 8 Nov):** the average player gets ★★ or better in **95 %** of all fresh games (every
  level ≥ 84 %: only level 59 Gleichgewicht, old 29, which was 83 % in „Die Schöpfung“ too) and in 94 % of the
  carried-world games (97 % with the net; the thresholds of levels 16, 29, 37, 49, 52 were raised by 1–3 steps so
  the carried worlds reach 85 % where the cap 3 × ★★★ + 4 allows it). The good bot gets ★★★ in 60 % (40–70 % in 52
  of 60 levels; outliers 3 and 20 with 72–74 %, 9, 22 and 34 with 86–96 % where the good solutions cluster on one step
  count, 4 and 12 with 34 %), ★★ or better in 99.7 % (every level ≥ 97 %). The casual player gets ★★ or better in
  47 % (levels 1–5 about 58 %).
- **Points** (model averages with the final thresholds): good 74 per level, average 66, casual 46, so about
  4 400 / 4 000 / 2 750 points over the 60 levels (twice „Die Schöpfung“, matching twice the days).
- **Difficulty curve:** the good-bot median stays at 3–7 steps per level and the casual median at 8–20, as in „Die
  Schöpfung“ (lasting supply makes satt goals quick); the difficulty grows with the number of systems in play (1 in
  the Urerde → 3–4 in the Saurier/Eiszeit eras: hunger + hunt / glacier + thaw + snow → 6–7 in Industrie and
  Gleichgewicht), and every era starts with one level whose new thing is the only new rule.
- **Farmers never beat honest play:** the oracle farmer earns 3–66 points per level against the good bot's 69–79;
  it is faster than the good bot on at most 4 of 200 boards (level 60, where ping-pong „rests“), its ★★★ share is
  above 10 % only in levels 7, 9, 13, 34, 38, 39, 42, 48, 54, 55 (single-slice play = honest play on one slice;
  level 34 is the story level with a fixed impact) and the exported pools exclude every board where the farmer gets
  ★★★ or is faster (64 boards rejected).
- **Dangers are avoidable and are consequences:** the good bot loses 0.00 made goal fields per game in every level
  but 3 (0.03, the lesson board of the volcano) and 4 (0.01); danger hits on goal-kind fields stay ≤ 0.5 per good
  game everywhere except level 3 (2.5 eruptions over not-yet-made Fels: the lesson board) and 59 (1.1: smog and hunger,
  as old level 29). The new dangers:
  Jagd hits 0.01–0.13 goal fields per good game (32, 33, 38, 39), the glacier 0.03 (40) and ≤ 0.01 elsewhere; the
  average player meets them a little more (hunt ≤ 0.12, ice ≤ 0.03, hunger ≤ 1.6), the casual player much more
  (eruptions, fires, hunger, hunts, freezes) – the intended consequence of careless play.
- **The scripted impact works as a turning point:** 15 dinosaur fields become ash in every game of level 34, never a
  loss; the meadows are built from that ash (good median 4, casual 8).
- **Carry-over works** (11.4): carried worlds are as fast as fresh boards (medians ± 1). The pool board is used
  instead in level 52 (40 %: yesterday's Hütten stand fed next to food, as level 25 of „Die Schöpfung“ with 58 %), 47
  (18 %: the Feuerstellen of level 46 keep the Frühmenschen warm, which the start rules forbid) and 35 (7 %);
  elsewhere 0–2 %.

---

## 12. Godot cross-check

As `GDPD_SCHOEPFUNG.md` 16: `b6/xcheck10.py gen cases10.json` writes cases for the 30 new levels (and the 10
re-skinned ones; the 20 unchanged old levels keep their `xcheck9` cases): random twists, ping-pong, good-bot
actions, many tools, plus the 1 200 pool solutions. The record adds `glac`, `glac_rest`, `hunt_warn`, `impact_done`.
`tests/xcheck9.gd` plays them through the real `GameState` with `engine9_mode` (Build 12 late pass off, as for the
existing cases) and must report 0 mismatches. Port order: kinds/CODE → needs/sources → rain kind condition → generic
hunt (old level 23 cases must still match) → spread step (old volcano cases must still match) with the glacier
params → thaw → impact → reach9/gift recipes → next_action branches.

---

## 13. Test plan (`tests/test_rules.gd`, must end with „ 0 Fehler“; `tests/test_models.gd` „OK test_models“)

1. **kinds10**: `KIND_COUNT` 40, names/plurals/articles/icons of 27–39, `CODE` ends with `qtibedxpcjkyF`, water
   family includes Quallen/Trilobiten, `decode(encode(b)) == b` for every pool board.
2. **sources10**: 🌲 from Wald, 🐞 from Insekten, ❄ from Eis, 🔥 from Feuerstelle, 🌾 from Farn, 🍖 from Saurier,
   🦶 from Moos; the old levels' supply values unchanged on their xcheck9 cases.
3. **hunt_generic**: level 38 (old 23) cases match `xcheck9`; a Raubsaurier group of 3 warns the Saurier next to it,
   splitting it cancels; with `herd = 3` a Saurier in a group of 3 is not warned, a single one is; a hunted made goal
   field sends `goal_loss`.
4. **glacier**: an Eis group of 4 warns; still ≥ 4 next round → ≤ 2 neighbours freeze (crater first, by id),
   Mammut and Feuerstelle never, nothing next to a Feuerstelle; rest 2 rounds; Eis on face 0 thaws after 2 round ends;
   the old volcano cases still match (shared spread step).
5. **impact**: level 34: `impact_warn` at the start, after twist 1 every Saurier/Raubsaurier/Flugsaurier is Erde, no
   `goal_loss`, rows through the new Erde grow in the late pass, `impact` only once (undo restores `impact_done`).
6. **rain_kind_cond**: rain on a Wald next to Farn makes Saurier (28–33), next to Wiese Tiere (40–42), else not
   offered (`rain_ok9` false).
7. **thrive_new**: Trilobit (⛰⛰), Insekten (🌲🌲), Flugsaurier (🐟🐟), Affen (🌲🌲), Feuerstelle (⛰ + 🌲), Wiese from
   ash (🌾🌾🌾), Landgang onto Moos, Amphibien starve to Moos only while 🐞 was never supplied (lasting seals).
8. **pool_replay10**: every pool solution of `kampagne_erde.json` wins at exactly `solved_in` with its stars in
   `engine9_mode`; under the game rules (late pass) it wins with ≥ its stars or the hint wins with ★★+.
9. **carry10 / ensure10**: carrying within an era gives exactly the comp and the start rules or the pool board;
   the first level of an era always starts on a pool board; `ensure` splits ice clumps > 5.
10. **reach10 / gift10**: every pool board of all 60 levels is reachable; for each new goal kind a constructed dead
    end is detected and the gift makes +1 progress (make, group, satt).
11. **next_action_all**: section 7 (every pool board, every step of the solution, ≤ 6 words, the named move does
    what it says, the impact line before twist 1 of level 34).
12. **stars_erde**: `stars`/`par` of every level equal the data; points of the pool solutions match.
13. **texts10**: every new player text ≤ 6 words (hard limit 8); no Genesis words anywhere in the player texts
    (`Tag 1…7`, `Schöpfung`, `siebte`, `Und es war gut`); era titles never shown before the era is reached.
14. **migrate_erde**: section 9 (every row; `POS_OF_OLD`; „Nachholen“; hidden won levels beyond `P`).
15. **unlock60**: one new level per Spieltag up to 60, already-won levels skipped the same day, clock rules unchanged;
    WdT only from won levels (no spoiler), template list of section 10.

`tests/test_models.gd`: the 13 new kinds build a model at every LOD within the vertex budget, ice sheets merge
across edges (seam rule), the Feuerstelle has its light.

---

## 14. Tour checks (`main.gd`, the names are required in `.github/workflows/gdpd.yml`)

The campaign tour runs on a clean profile (`--only=<section>`: `camp`, `acts`, `erde`, `erde_look`, `b12`, `migrate`,
…). Implemented checks of the Erdgeschichte (the rules behind the old draft names `herd_safe`, `camp_stops_ice`,
`trilo_thrive`, `insects_buzz`, `landgang_moss`, `frog_hunger`, `mammoth_cold`, `dust_clears` are unit tests in
`test_rules.gd`: `test_hunt10`, `test_glacier10`, `test_thrive10`, `test_impact10`):

| name | what it checks (real input) |
|---|---|
| `camp_overview`, `no_spoiler_campaign`, `era_overview_no_spoiler` | overview at level 1: one era tile „Urerde“ + one „?“; no other era title, no locked level title, no Genesis word (`Tag 1–7`, `Schöpfung`, `siebte`, `Akt`, `Ruhe`, `ruhen`) |
| `era_look_on_card` | level 2 from the overview: the start card already shows the level's look (`glut`), no 2 s blend from the beige win mood |
| `dino_era` | level 28 era card „Saurierzeit“, ≥ 3 Saurier on the cube; level 32: a Raubsaurier pack warns „Raubsaurier jagen!“, the line's move cancels it |
| `meteor_transition` | level 34: „Meteor kommt!“, line „Dreh, der Meteor kommt“; after twist 1 every dinosaur is ash, the sky `asche`, no loss on the chip |
| `ice_age` | level 40: „Gletscher wächst!“ and „Teil das Eis!“; the line's move calms it |
| `apes_climb` | level 43: Tiere between two Wäldern become Affen |
| `early_humans_fire` | level 46: a Frühmensch next to Fels and Wald becomes a Feuerstelle (light on) |
| `next_action_line` | levels 1, 12, 25, 32, 34, 40, 46, 55, 60 at the start: the top line names a concrete move or tool (never the generic „Dreh weiter, Regen kommt“ / „Dreh eine Scheibe“), equals the rules' line, is centred with ≥ 16 px margin |
| `era_levels_visit` | levels 12, 54, 56, 57 get their era card and a concrete line; every era was started once in the tour |
| `era_models`, `era_blanket`, `ice_seam`, `era_transition`, `meteor_era` | look tour: the right creatures per era, snow blanket, ice seams, the transition wave, the impact |
| `creature_size` | look tour: Saurier, T-Rex, Affen, Frühmenschen, Mammut are at least 14 px high on a 540 px wide screen |
| `perf` | look tour per era ≤ 900 draw calls and ≤ 290 k primitives; level 60 (`vollendet`, measured 425 / 171 k in the tour) ≤ 500 draws, ≤ 200 k primitives; frame time printed |
| `migration_from_schoepfung` | a v1 save loads: position, „Nachholen“, stars kept |
| `level3_solvable`, `carry_world`, `stars_generous`, `hud_central`, `water_turns_with_slice`, `need_seal_stays` (level 49), `hold_rest` (level 60, „Gleichgewicht“), `pack_warn` (level 38) | as before with the new level numbers (`OLD_TO_NEW`) |

---

## 15. Implementation map

| file | change |
|---|---|
| `scripts/field_data.gd` | kinds 27–39, `KIND_COUNT` 40, `CODE`, names/plurals/articles/icons/`DOWN`/`TIER`, `WATERS` + Quallen/Trilobiten, `LIVING` |
| `scripts/game_state.gd` | `SOURCES9` additions (3.1); `rain_to9` kind condition; `_pack_step9` → generic `_hunt_step9(cfg.hunt)`; `_volcano_step9` → `_spread_step9(params)` for Vulkan and Gletscher (+ Feuerstelle protection, immune kinds); thaw is data; `_impact_step9` (+ `impact_done` in save9/load9/undo/clone); round order 4.5; `reach9`/`gift_plan9` recipes (6); `next_action` branches (7); still reasons (4.6) |
| `scripts/campaign.gd` | reads `data/kampagne_erde.json` (eras, configs, pools); `COUNT` from the data; `era_of(n)`, era cards, `WDT` (10), `OLD_TO_NEW`/`POS_OF_OLD`; `retire` table (6); `ensure` ice clumps; `TEXT`/`PILL`/`THRIVE_PILL` additions; all Genesis texts removed (`act_caps` „Tag %d“ → era titles) |
| `scripts/eras.gd` | the new presets of `GDPD_ERDGESCHICHTE_GRAFIK.md` 2–3 (`kambrium`, `meer`, `landgang`, `karbon`, `saurier`, `asche`, `erholung`, `saeuger`, `eiszeit`, `savanne`, `feuer`, `jaeger`, `glaube`); `of(era_id, level)`; `dust_clear` |
| `scripts/game.gd` / `daily.gd` | arrays sized by `Campaign.count()`; migration `[kampagne] version 2` (9); „Nachholen“ unlock; already-won skip in the daily unlock; WdT templates |
| `scripts/day_ui.gd` / `ui.gd` | era tiles on the overview, era card, „Nachholen“ dots, impact camera + warning pill, new pills, help verbs |
| `scripts/world.gd`, `look.gd`, `field_view.gd`, `models.gd` | 13 new models, ice sheet merge, campfire light, impact FX, era looks of section 2 |
| `scripts/main.gd`, `.github/workflows/gdpd.yml` | tour checks of section 14 |
| `data/kampagne_erde.json` | from `b6/export_gd10.py` (configs + texts + pools of `b6/kampagne_erde_b6.json`) |
| `tests/test_rules.gd`, `tests/test_models.gd`, `tests/xcheck9.gd` | sections 12–13 |
| trailer (`gdpd/trailer/`) | unchanged until the new eras have art; then cut 3 s of the impact and the ice age |

## 16. Files (scratch) and how to re-run

Scratchpad: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/gdpd_sim/b6/`
(self-contained: copies of `engine.py`, `engine7.py`, `engine9.py` from `b4/`).

- **Model:** `engine10.py` (GS10 = GS9 + 13 kinds, generic hunt, glacier, impact, rain kind condition),
  `levels10.py` (eras, the 60 levels, `OLD_TO_NEW`, generator with the start rules, `STARS` from `stars12.json`),
  `texts10.py` (player texts, era cards), `bot10.py` (good / greedy / weak / weaklong; danger value knows hunt and
  glacier), `farm10.py` (pp / cyc / slice / farmer), `carry10.py` (carry within an era, `RETIRE` with the new kinds).
- **Runs:** `run10.py gen:200 all good,greedy,weak '{}' res_main.json` (the main run; `res_pre.json` + the re-runs
  `r1.json` (26, 27, 32, 40–42 after tuning) and `r2.json` (49) merged by `merge.py`), `stars12.py res_main.json
  stars12.json stars_table12.md`, the final run with the thresholds `run10.py gen:200 all good,greedy,weak '{}'
  res_final.json` (the tables of section 11), `final.sh` (chains `res_chain.json`, uncapped casual `res_weaklong.json`, pools
  `export10.py all kampagne_erde_b6.json`, farmers `res_farm.json`, cross-check cases `xcheck10.py`),
  `danger10.py` (danger hits on goal fields, `res_danger.json`), the safety-net runs (`bot10.play_net`, bots
  `weaknet`/`greedynet`: `run10.py gen:100 all weaknet,greedynet '{}' res_net.json`, `run10.py chain:100 all greedynet
  '{}' res_chain_net.json`, merged with `res_chain.json` into `res_chain_all.json`), `mk_valid.sh` (section 11), `tune10.py` (quick variant sweeps),
  `dbg.py` / `dbgw.py` (failed games), `mk_doc10.py` + `assemble.sh` (the tables and this spec).
- **Outputs:** pools `kampagne_erde_b6.json` (20 boards per level, one solution each, farm-proof) and the game data
  `kampagne_erde.json` (`export_gd10.py`: eras, configs with texts, WdT, `old_to_new`, `pos_of_old`, retire,
  sources, pools; every solution replayed), cross-check cases `cases10.json`, `cases10_pool.json`; logs `*.log`.
- Copy `kampagne_erde.json` to `gdpd/data/kampagne_erde.json` when the port starts (section 15).
