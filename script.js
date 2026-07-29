'use strict';

/* ============================================================================
 * ELFMETER ROULETTE — a punishingly difficult retro penalty shootout
 * ----------------------------------------------------------------------------
 * Rendering : single <canvas>, fixed logical resolution (VIEW), scaled to fit.
 * Controls  : SPACE (desktop) / tap (mobile). Two presses per shot.
 *
 * Coordinate systems used throughout this file
 * --------------------------------------------
 *   view space : 0..VIEW.W x 0..VIEW.H pixels. Everything is drawn in this
 *                space; the canvas transform handles DPI + responsive scaling.
 *
 *   aim space  : the goal mouth, normalised.
 *                  ax = -1 .. +1   left post .. right post
 *                  ay =  0 .. +1   ground line .. crossbar
 *                Values outside that range are off target (wide / over).
 *                aimToX() / aimToY() convert aim space to view space.
 *
 * Swapping in your own artwork
 * ----------------------------
 *   Drop file paths into ASSETS (see below). Every drawing routine tries the
 *   bitmap first via drawSprite() and only falls back to the vector cartoon if
 *   no image is configured or loaded. No other code changes are required.
 * ==========================================================================*/


/* ==========================================================================
 * 1. TUNING — everything that changes how the game *feels* lives here
 * ========================================================================*/

const VIEW = { W: 960, H: 600 };          // logical canvas size (16:10)

const CONFIG = {
  /* --- round structure --- */
  shotsPerRound:   10,

  /* --- gauge speed: "cycles" per second, 1 cycle = there *and* back ---
     These are deliberately brutal. Lower them if playtesters cry.          */
  hBarSpeed:       1.90,
  vBarSpeed:       2.15,
  speedRamp:       0.05,                  // +5% per shot taken, compounding pressure

  /* --- the aiming model (see aimH / aimV) ---
     sweetZone : half-width of the perfect band, in signed bar units (0..1).
                 Stop inside it and the shot goes EXACTLY where aimed.
     wildH/V   : how violently the error is amplified outside the sweet zone.
     wildCurve : exponent — higher means the punishment ramps up later but
                 harder, which is what makes near-misses so infuriating.     */
  sweetZone:       0.055,
  wildCurve:       1.70,
  wildH:           2.90,
  wildV:           2.40,
  /* vBase is deliberately set to the keeper's head height: a perfect stop on
     BOTH gauges is a dead-centre, face-high shot. If he has dived, it rolls
     into his gloves; if he froze, it is +50 straight in the mush. */
  vBase:           0.62,
  vSpan:           0.50,                  // how far the gauge travels before amplification

  /* --- timings (seconds) --- */
  readyTime:       0.60,                  // run-up before the first gauge appears
  flightTime:      0.62,                  // ball travel time to the goal line
  resultTime:      1.70,                  // celebration / shame pause
  inputLock:       0.08,                  // debounce between accepted presses

  /* --- scoring --- */
  ptsGoal:         10,
  ptsTopCorner:    25,                    // total, not additive
  ptsHeadshot:     50,
  streakBonus:     5,                     // per consecutive scoring shot, capped
  streakCap:       5,

  /* --- keeper --- */
  gkDiveTime:      0.50,
  gkReadChance:    0.55,                  // odds he guesses the right side
  gkFreezeChance:  0.24,                  // odds he just stands there, bewildered
};

/* Goal geometry in view space. The mouth is the plane the ball arrives on. */
const GOAL = {
  cx:     480,
  halfW:  218,
  top:    138,
  bottom: 336,
};
GOAL.height = GOAL.bottom - GOAL.top;
GOAL.left   = GOAL.cx - GOAL.halfW;
GOAL.right  = GOAL.cx + GOAL.halfW;

/* Ball radius expressed in aim space — used for post / crossbar collisions. */
const BALL_AIM_RX = 0.035;
const BALL_AIM_RY = 0.038;

const PENALTY_SPOT = { x: 480, y: 520 };
const HORIZON      = 236;                 // where the stands meet the grass

/* Gauge geometry in view space. */
const HBAR = { x: 132, y: 548, w: 700, h: 26 };
const VBAR = { x: 884, y: 150, w: 26, h: 330 };


/* ==========================================================================
 * 2. PLACEHOLDER HOOKS — art and audio
 * ========================================================================*/

/**
 * Bitmap slots. Set a path (or a data URI) and that sprite replaces the
 * vector placeholder automatically, e.g.:
 *
 *     ASSETS.gk_idle = 'img/keeper-idle.png';
 *
 * Sprites are drawn centred on the anchor the vector version uses, so a
 * transparent PNG with roughly the same proportions will "just work".
 */
const ASSETS = {
  gk_idle:  null,   // targetGK standing, front view          (~180 x 260 px)
  gk_dive:  null,   // targetGK stretched out mid-dive        (~300 x 200 px)
  gk_hit:   null,   // targetGK after a face full of leather  (~180 x 260 px)
  ball:     null,   // the ball                               (square)
  striker:  null,   // the penalty taker, seen from behind    (~140 x 220 px)
  crowd:    null,   // tiled stand backdrop                   (any width)
};

const IMAGES = Object.create(null);       // key -> HTMLImageElement (loaded only)

/** Kick off loading for every configured asset. Missing files are ignored. */
function loadAssets() {
  for (const key of Object.keys(ASSETS)) {
    const src = ASSETS[key];
    if (!src) continue;
    const img = new Image();
    img.onload = () => { IMAGES[key] = img; };
    img.onerror = () => console.warn(`[elfmeter] could not load asset "${key}" (${src})`);
    img.src = src;
  }
}

/**
 * Draw a sprite centred at (cx, cy). Returns false when no bitmap is
 * available, which is the caller's cue to draw the vector fallback.
 */
function drawSprite(key, cx, cy, w, h) {
  const img = IMAGES[key];
  if (!img) return false;
  ctx.drawImage(img, cx - w / 2, cy - h / 2, w, h);
  return true;
}

/**
 * SOUND PLACEHOLDERS
 * ------------------
 * Every audible moment in the game funnels through playSound(). Right now it
 * only logs; to add audio, point each slot at a file and uncomment the body:
 *
 *     const SOUNDS = { crowd_cheer: new Audio('sfx/crowd_cheer.mp3'), ... };
 *
 * Remember that mobile browsers only allow playback after a user gesture —
 * the first tap/keypress is a good place to "unlock" the audio elements.
 */
const SOUND_KEYS = {
  whistle:      'referee whistle — new penalty / miss',
  kick:         'boot connecting with the ball',
  crowd_cheer:  'stadium erupts — goal scored',
  crowd_groan:  'stadium sighs — shot missed',
  cash:         'cash register ka-ching — headshot bonus',
  save:         'gloves slapping leather — keeper save',
  woodwork:     'hollow clang — post or crossbar',
  gauge_lock:   'short blip — gauge stopped',
  fanfare:      'end of round jingle',
};

const SOUNDS = {};                        // key -> HTMLAudioElement (fill me in)

function playSound(key) {
  if (!(key in SOUND_KEYS)) console.warn(`[elfmeter] unknown sound "${key}"`);
  // const a = SOUNDS[key];
  // if (a) { a.currentTime = 0; a.play().catch(() => {}); }
}


/* ==========================================================================
 * 3. CANVAS SETUP
 * ========================================================================*/

const canvas = document.getElementById('game');
const ctx    = canvas.getContext('2d');

/** Size the backing store for the device pixel ratio and letterbox the view. */
function resizeCanvas() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const cssW = canvas.clientWidth  || VIEW.W;
  const cssH = canvas.clientHeight || VIEW.H;

  canvas.width  = Math.round(cssW * dpr);
  canvas.height = Math.round(cssH * dpr);

  const s = Math.min(canvas.width / VIEW.W, canvas.height / VIEW.H);
  ctx.setTransform(s, 0, 0, s,
    (canvas.width  - VIEW.W * s) / 2,
    (canvas.height - VIEW.H * s) / 2);
}

window.addEventListener('resize', resizeCanvas);
window.addEventListener('orientationchange', () => setTimeout(resizeCanvas, 120));


/* ==========================================================================
 * 4. SMALL HELPERS
 * ========================================================================*/

const clamp  = (v, lo, hi) => v < lo ? lo : v > hi ? hi : v;
const lerp   = (a, b, t) => a + (b - a) * t;
const rand   = (a, b) => a + Math.random() * (b - a);
const randInt = (a, b) => Math.floor(rand(a, b + 1));
const pick   = arr => arr[Math.floor(Math.random() * arr.length)];
const easeOut = t => 1 - Math.pow(1 - t, 3);
const easeIn  = t => t * t;

/** Triangle wave: phase (in cycles) -> 0..1..0, i.e. one full round trip. */
function triangle(phase) {
  const u = phase - Math.floor(phase);
  return u < 0.5 ? u * 2 : 2 - u * 2;
}

/* aim space -> view space */
const aimToX = ax => GOAL.cx + ax * GOAL.halfW;
const aimToY = ay => GOAL.bottom - ay * GOAL.height;


/* ==========================================================================
 * 5. THE AIMING MODEL
 * --------------------------------------------------------------------------
 * Both gauges work the same way: the marker position maps directly onto a
 * target, and the further you stop from dead centre the more that target is
 * exaggerated. Inside the sweet zone there is no exaggeration at all, so a
 * perfect stop goes precisely where the arrow was pointing.
 *
 * The practical consequence — and the whole joke of the game — is that the
 * *perfect* stop sends the ball straight down the middle, into the keeper's
 * face (worth +50). To actually score you have to stop slightly off centre,
 * in the narrow window where the amplification widens the angle just enough
 * to beat him but not enough to send the ball into row Z.
 * ========================================================================*/

/** How badly a stop at `signed` (-1..1) gets punished. 0 inside the sweet zone. */
function wildness(signed, factor) {
  const off = Math.abs(signed);
  const excess = Math.max(0, off - CONFIG.sweetZone) / (1 - CONFIG.sweetZone);
  return Math.pow(excess, CONFIG.wildCurve) * factor;
}

/** Horizontal gauge value (0 = far left, 1 = far right) -> aim-space x. */
function aimH(m) {
  const s = (m - 0.5) * 2;
  return s * (1 + wildness(s, CONFIG.wildH));
}

/** Vertical gauge value (0 = bottom, 1 = top) -> aim-space y. */
function aimV(m) {
  const s = (m - 0.5) * 2;
  return CONFIG.vBase + s * CONFIG.vSpan * (1 + wildness(s, CONFIG.wildV));
}

/** Is this gauge value inside the perfect band? */
const isPerfect = m => Math.abs((m - 0.5) * 2) <= CONFIG.sweetZone;

/**
 * Pre-compute the colour bands painted onto each gauge so the player can
 * learn the model by looking at it. Derived from the functions above, so the
 * bars can never lie about the maths.
 */
function buildZones(axis) {
  const N = 180, out = [];
  for (let i = 0; i < N; i++) {
    const m = (i + 0.5) / N;
    if (isPerfect(m)) { out.push('perfect'); continue; }
    if (axis === 'h') {
      out.push(Math.abs(aimH(m)) <= 0.94 ? 'ok' : 'wild');
    } else {
      const ay = aimV(m);
      out.push(ay >= 0.06 && ay <= 0.94 ? 'ok' : 'wild');
    }
  }
  return out;
}

const ZONES = { h: buildZones('h'), v: buildZones('v') };
const ZONE_COLORS = {
  perfect: '#ffc94a',
  ok:      '#37c46a',
  wild:    '#c0303f',
};


/* ==========================================================================
 * 6. GAME STATE
 * ========================================================================*/

const STATE = {
  MENU:   'MENU',     // title card, waiting for kick off
  READY:  'READY',    // run-up, no gauge yet
  AIM_H:  'AIM_H',    // horizontal gauge running
  AIM_V:  'AIM_V',    // vertical gauge running
  FLIGHT: 'FLIGHT',   // ball is travelling
  RESULT: 'RESULT',   // outcome shown, ball rolling away
  OVER:   'OVER',     // full time
};

const game = {
  state: STATE.MENU,
  time: 0,            // seconds since boot, drives all idle animation
  stateTime: 0,       // seconds in the current state
  inputLock: 0,

  score: 0,
  best: 0,
  shot: 0,            // shots already taken this round
  streak: 0,
  tally: { goals: 0, headshots: 0, misses: 0 },

  /* current shot */
  mH: 0.5,            // horizontal gauge marker (0..1)
  mV: 0.5,            // vertical gauge marker
  phaseH: 0,          // gauge oscillator phases
  phaseV: 0,
  lockedH: null,      // gauge value captured in step 1
  lockedV: null,
  perfectH: false,
  perfectV: false,
  target: { ax: 0, ay: 0 },   // resolved aim point for the shot in flight

  outcome: null,      // { kind, points, label, colour, x, y }
  banner: '',         // commentary line shown across the top
  bannerColor: '#fff',
};

/* Ball: during FLIGHT it follows a parametric path; afterwards it becomes a
   simple physics object so it can bounce out of the net or sail into orbit. */
const ball = {
  x: PENALTY_SPOT.x, y: PENALTY_SPOT.y, r: 18,
  vx: 0, vy: 0, vr: 0,
  spin: 0, spinRate: 0,
  t: 0, curl: 0, loft: 0,
  from: { x: 0, y: 0 }, to: { x: 0, y: 0 },
  visible: true,
  trail: [],
};

/* The goalkeeper — internal name kept as `targetGK` per the design brief. */
const targetGK = {
  x: 0,               // aim-space centre
  headY: 0.70,        // aim-space head height
  mode: 'idle',       // idle | dive | beaten | hit
  diveT: 0,
  diveFrom: 0,
  diveTo: 0,
  diveType: 'stay',   // stay | low | high
  reachHalf: 0.30,
  reachTop: 0.80,
  lean: 0,            // radians, for the dive pose
  dizzy: 0,           // >0 while seeing stars
  taunt: 0,           // idle animation variant timer
};

const fx = {
  particles: [],      // coins + banknotes
  popups: [],         // floating score text
  shake: 0,
  flash: 0,
  netRipple: null,    // { x, y, t }
};


/* ==========================================================================
 * 7. DOM WIRING
 * ========================================================================*/

const el = {
  score:      document.getElementById('hud-score'),
  shot:       document.getElementById('hud-shot'),
  shotsTotal: document.getElementById('hud-shots-total'),
  best:       document.getElementById('hud-best'),
  overlay:    document.getElementById('overlay'),
  panelStart: document.getElementById('panel-start'),
  panelOver:  document.getElementById('panel-over'),
  finalScore: document.getElementById('final-score'),
  finalRank:  document.getElementById('final-rank'),
  breakdown:  document.getElementById('final-breakdown'),
  btnStart:   document.getElementById('btn-start'),
  btnAgain:   document.getElementById('btn-again'),
  hint:       document.getElementById('hint-text'),
};

const BEST_KEY = 'elfmeter.best';

function loadBest() {
  try { game.best = parseInt(localStorage.getItem(BEST_KEY), 10) || 0; }
  catch (e) { game.best = 0; }
}
function saveBest() {
  try { localStorage.setItem(BEST_KEY, String(game.best)); } catch (e) { /* private mode */ }
}

function syncHud(bump) {
  /* While a round is running the counter shows the shot being taken. */
  const playing = game.state !== STATE.MENU && game.state !== STATE.OVER;
  el.score.textContent = game.score;
  el.shot.textContent  = playing
    ? Math.min(game.shot + 1, CONFIG.shotsPerRound)
    : game.shot;
  el.best.textContent  = game.best;
  if (bump) {
    el.score.classList.remove('bump');
    void el.score.offsetWidth;          // restart the CSS animation
    el.score.classList.add('bump');
  }
}

const HINTS = {
  [STATE.MENU]:   'Stop the gauge. Twice. Good luck.',
  [STATE.READY]:  'Deep breath…',
  [STATE.AIM_H]:  'STEP 1 — stop the horizontal gauge!',
  [STATE.AIM_V]:  'STEP 2 — now the height!',
  [STATE.FLIGHT]: 'Nothing you can do now.',
  [STATE.RESULT]: '…',
  [STATE.OVER]:   'That was, generously, a performance.',
};

function setState(next) {
  game.state = next;
  game.stateTime = 0;
  if (el.hint && HINTS[next]) el.hint.textContent = HINTS[next];
}


/* ==========================================================================
 * 8. SATIRICAL COMMENTARY
 * ========================================================================*/

const LINES = {
  goal: [
    'TOOOR! The sponsors are delighted.',
    'Goal! Somewhere an agent renegotiates.',
    'In it goes — merchandising department high-fives.',
    'Scored! That is three yachts worth of bonus.',
  ],
  topCorner: [
    'TOP BINS! Absolute filth.',
    'Postage stamp! The keeper waves it goodbye.',
    'Into the roof of the net. Poster printers standby.',
  ],
  headshot: [
    'RIGHT IN THE FACE! Ka-ching!',
    'Direct hit! Sponsorship value: enormous.',
    'He never saw it. Neither did his dentist.',
    'FACE FIRST! That is going on a lunchbox.',
  ],
  save: [
    'Saved. He looks insufferably pleased.',
    'Straight at him. Again.',
    'Gloves of a man who wants a transfer.',
  ],
  post: [
    'PFOSTEN! Woodwork says no.',
    'Off the frame. Millimetres and heartbreak.',
    'The post has a better contract than you.',
  ],
  miss: [
    'Wide! The car park applauds.',
    'Over the bar. Row Z gets a souvenir.',
    'That is out for a throw-in. Somehow.',
    'The corner flag never stood a chance.',
    'Ambitious. Wrong sport, but ambitious.',
  ],
};

const RANKS = [
  { min: 300, name: 'Elfmetergott — statue pending' },
  { min: 200, name: 'Penalty Merchant, Global Brand' },
  { min: 130, name: 'Reliable From Twelve Yards' },
  { min:  80, name: 'Squad Player With Highlights' },
  { min:  40, name: 'Enthusiastic Amateur' },
  { min:  10, name: 'Sunday League Toe-Poker' },
  { min:   0, name: 'Banned From Set Pieces' },
];

const rankFor = score => (RANKS.find(r => score >= r.min) || RANKS[RANKS.length - 1]).name;


/* ==========================================================================
 * 9. ROUND / SHOT FLOW
 * ========================================================================*/

function startGame() {
  game.score = 0;
  game.shot = 0;
  game.streak = 0;
  game.tally = { goals: 0, headshots: 0, misses: 0 };
  game.outcome = null;
  game.banner = '';
  fx.particles.length = 0;
  fx.popups.length = 0;

  el.overlay.classList.add('hidden');
  syncHud(false);
  nextShot();
}

function nextShot() {
  game.lockedH = game.lockedV = null;
  game.perfectH = game.perfectV = false;
  game.outcome = null;

  /* Random start phase so the marker never begins in the same spot. */
  game.phaseH = Math.random();
  game.phaseV = Math.random();

  ball.x = PENALTY_SPOT.x;
  ball.y = PENALTY_SPOT.y;
  ball.r = 18;
  ball.spin = 0;
  ball.spinRate = 0;
  ball.visible = true;
  ball.trail.length = 0;

  targetGK.mode = 'idle';
  targetGK.lean = 0;
  targetGK.dizzy = 0;
  targetGK.diveT = 0;

  playSound('whistle');
  setState(STATE.READY);
  syncHud(false);
}

/** Marker speed grows as the round goes on — the pressure is the point. */
const speedMul = () => 1 + game.shot * CONFIG.speedRamp;

/** Step 1 committed: freeze the horizontal gauge. */
function lockHorizontal() {
  game.lockedH = game.mH;
  game.perfectH = isPerfect(game.mH);
  playSound('gauge_lock');
  setState(STATE.AIM_V);
}

/** Step 2 committed: freeze the vertical gauge and strike the ball. */
function lockVerticalAndShoot() {
  game.lockedV = game.mV;
  game.perfectV = isPerfect(game.mV);
  playSound('gauge_lock');

  const ax = aimH(game.lockedH);
  const ay = aimV(game.lockedV);
  game.target.ax = ax;
  game.target.ay = ay;

  /* Set up the flight path. The arc and curl both vanish at t = 1 so the ball
     always arrives exactly on the computed aim point. */
  ball.from = { x: PENALTY_SPOT.x, y: PENALTY_SPOT.y };
  ball.to   = { x: aimToX(ax),     y: aimToY(ay) };
  ball.t = 0;
  ball.loft = 18 + 46 * clamp(ay, 0, 1.6);
  ball.curl = -ax * 34;
  ball.spinRate = ax * 9 + 4;
  ball.trail.length = 0;

  decideDive(ax, ay);
  fx.shake = Math.max(fx.shake, 5);
  playSound('kick');
  setState(STATE.FLIGHT);
}

/**
 * The keeper commits the moment the ball is struck. He knows where it is
 * going (he is a professional) but only acts on that knowledge some of the
 * time — the rest is guesswork, or pure bewilderment.
 */
function decideDive(ax, ay) {
  targetGK.diveFrom = targetGK.x;
  targetGK.diveT = 0;
  targetGK.mode = 'dive';

  if (Math.random() < CONFIG.gkFreezeChance) {
    /* Rooted to the spot. Arms up, dignity intact, face exposed. */
    targetGK.diveType = 'stay';
    targetGK.diveTo   = targetGK.x + rand(-0.06, 0.06);
    targetGK.reachHalf = 0.30;
    targetGK.reachTop  = 0.80;
    return;
  }

  const readsIt = Math.random() < CONFIG.gkReadChance;
  const side = readsIt ? Math.sign(ax || rand(-1, 1)) : (Math.random() < 0.5 ? -1 : 1);
  const high = readsIt ? ay > 0.5 : Math.random() < 0.5;

  targetGK.diveType  = high ? 'high' : 'low';
  targetGK.diveTo    = side * rand(0.46, 0.62);
  targetGK.reachHalf = high ? 0.50 : 0.55;
  targetGK.reachTop  = high ? 0.88 : 0.42;
}


/* ==========================================================================
 * 10. RESOLVING THE SHOT
 * ========================================================================*/

function resolveShot() {
  const { ax, ay } = game.target;

  /* Keeper geometry frozen at the moment of impact. */
  const kx  = targetGK.x;
  const khy = targetGK.headY;

  const px = aimToX(ax);
  const py = aimToY(ay);

  /* --- 1. Face full of leather? Checked first: it outranks everything. --- */
  const dxh = (ax - kx) / 0.105;
  const dyh = (ay - khy) / 0.120;
  if (dxh * dxh + dyh * dyh <= 1) {
    return applyOutcome('headshot', CONFIG.ptsHeadshot, 'HEADSHOT +50', '#ffc94a', px, py);
  }

  /* --- 2. Within reach of the gloves? --- */
  const saved = Math.abs(ax - kx) <= targetGK.reachHalf &&
                ay <= targetGK.reachTop && ay >= -0.05;

  /* --- 3. Woodwork (checked before the goal so the frame actually exists) - */
  const hitsPost = Math.abs(Math.abs(ax) - 1) <= BALL_AIM_RX && ay <= 1 + BALL_AIM_RY && ay >= 0;
  const hitsBar  = Math.abs(ay - 1) <= BALL_AIM_RY && Math.abs(ax) <= 1 + BALL_AIM_RX;

  if (!saved && (hitsPost || hitsBar)) {
    return applyOutcome('post', 0, 'PFOSTEN!', '#e6ecf2', px, py);
  }

  if (saved) {
    return applyOutcome('save', 0, 'SAVED!', '#7fd7ff', px, py);
  }

  /* --- 4. Inside the frame? --- */
  const inside = Math.abs(ax) < 1 - BALL_AIM_RX && ay > 0 && ay < 1 - BALL_AIM_RY;
  if (inside) {
    const topCorner = Math.abs(ax) > 0.58 && ay > 0.62;
    return topCorner
      ? applyOutcome('topCorner', CONFIG.ptsTopCorner, 'TRAUMTOR +25', '#7fd7ff', px, py)
      : applyOutcome('goal', CONFIG.ptsGoal, 'GOAL +10', '#6ddc8b', px, py);
  }

  /* --- 5. Everything else is a very public failure. --- */
  return applyOutcome('miss', 0, 'MISSED!', '#ff5468', px, py);
}

function applyOutcome(kind, points, label, colour, px, py) {
  const scoring = points > 0;

  /* Streak bonus keeps good runs feeling dangerous to break. */
  let bonus = 0;
  if (scoring) {
    game.streak++;
    bonus = Math.min(game.streak - 1, CONFIG.streakCap) * CONFIG.streakBonus;
  } else {
    game.streak = 0;
  }

  const total = points + bonus;
  game.score += total;
  if (game.score > game.best) { game.best = game.score; saveBest(); }

  if (kind === 'headshot') game.tally.headshots++;
  else if (scoring)        game.tally.goals++;
  else                     game.tally.misses++;

  game.outcome = { kind, points: total, label, colour, x: px, y: py };
  game.banner = pick(LINES[kind] || LINES.miss);
  game.bannerColor = colour;

  /* --- feedback: sound, particles, popups, camera --- */
  /* Offset upward so the text never covers the impact itself — the keeper's
     reaction is half the joke. */
  spawnPopup(px, py - 52, label, colour, 34);
  if (bonus > 0) spawnPopup(px, py - 90, `STREAK x${game.streak}  +${bonus}`, '#ffc94a', 20);

  switch (kind) {
    case 'headshot':
      playSound('cash');
      spawnCash(px, py, 34);
      fx.shake = 16; fx.flash = 0.55;
      targetGK.mode = 'hit';
      targetGK.dizzy = 2.2;
      break;
    case 'topCorner':
    case 'goal':
      playSound('crowd_cheer');
      spawnCash(px, py, kind === 'topCorner' ? 26 : 18);
      fx.shake = 9; fx.flash = 0.3;
      fx.netRipple = { x: px, y: py, t: 0 };
      targetGK.mode = 'beaten';
      break;
    case 'save':
      playSound('save');
      fx.shake = 5;
      break;
    case 'post':
      playSound('woodwork');
      fx.shake = 11;
      break;
    default:
      playSound('crowd_groan');
      playSound('whistle');
      break;
  }

  syncHud(total > 0);
  setState(STATE.RESULT);
  handoffBallToPhysics(kind);
}

/** After impact the ball stops following its path and behaves like an object. */
function handoffBallToPhysics(kind) {
  const dirX = Math.sign(game.target.ax || 1);
  switch (kind) {
    case 'headshot':
      ball.vx = dirX * rand(-90, 90); ball.vy = -160; ball.vr = 12; break;
    case 'save':
      ball.vx = dirX * rand(120, 260); ball.vy = -60; ball.vr = 8; break;
    case 'post':
      ball.vx = dirX * rand(200, 340); ball.vy = -110; ball.vr = 14; break;
    case 'goal':
    case 'topCorner':
      ball.vx = 0; ball.vy = 40; ball.vr = 3; break;      // dies in the net
    default: {
      /* A miss keeps travelling along the line it was already on, so it
         disappears past the goal instead of dropping out of the sky. */
      const dx = ball.to.x - ball.from.x;
      const dy = ball.to.y - ball.from.y;
      const len = Math.hypot(dx, dy) || 1;
      ball.vx = (dx / len) * 300;
      ball.vy = (dy / len) * 300;
      ball.vr = 6;
      break;
    }
  }
}

function endRound() {
  playSound('fanfare');
  el.finalScore.textContent = game.score;
  el.finalRank.textContent  = rankFor(game.score);
  el.breakdown.innerHTML =
    `<div><b>${game.tally.goals}</b><span>Goals</span></div>` +
    `<div><b>${game.tally.headshots}</b><span>Headshots</span></div>` +
    `<div><b>${game.tally.misses}</b><span>Wasted</span></div>` +
    `<div><b>${game.best}</b><span>Best</span></div>`;

  el.panelStart.classList.add('hidden');
  el.panelOver.classList.remove('hidden');
  el.overlay.classList.remove('hidden');
  setState(STATE.OVER);
  syncHud(false);
}


/* ==========================================================================
 * 11. PARTICLES & POPUPS
 * ========================================================================*/

/**
 * Burst of tiny golden coins and banknotes. Coins are heavy and bounce,
 * notes flutter down slowly — together they read as "money everywhere".
 */
function spawnCash(x, y, count) {
  for (let i = 0; i < count; i++) {
    const note = Math.random() < 0.38;
    const a = rand(-Math.PI, 0);              // upward-ish hemisphere
    const sp = note ? rand(60, 190) : rand(140, 380);
    fx.particles.push({
      type: note ? 'note' : 'coin',
      x, y,
      vx: Math.cos(a) * sp + rand(-40, 40),
      vy: Math.sin(a) * sp - rand(30, 120),
      rot: rand(0, Math.PI * 2),
      vrot: rand(-8, 8),
      size: note ? rand(11, 17) : rand(7, 12),
      flutter: rand(0, Math.PI * 2),
      life: 0,
      ttl: note ? rand(2.4, 3.4) : rand(1.8, 2.8),
      glyph: Math.random() < 0.5 ? '€' : '$',
    });
  }
}

function spawnPopup(x, y, text, colour, size) {
  fx.popups.push({
    /* Kept inside the goal area: wild misses would otherwise drag the text
       off-screen or down on top of the penalty taker. */
    x: clamp(x, 110, VIEW.W - 110),
    y: clamp(y, 76, GOAL.bottom + 30),
    text, colour, size,
    life: 0, ttl: 1.5,
  });
}

function updateFx(dt) {
  /* particles */
  for (let i = fx.particles.length - 1; i >= 0; i--) {
    const p = fx.particles[i];
    p.life += dt;
    if (p.life > p.ttl) { fx.particles.splice(i, 1); continue; }

    if (p.type === 'note') {
      p.flutter += dt * 6;
      p.vy = Math.min(p.vy + 260 * dt, 90);            // notes reach terminal velocity fast
      p.vx *= 0.965;
      p.x += (p.vx + Math.sin(p.flutter) * 55) * dt;
      p.rot += Math.sin(p.flutter) * 3 * dt + p.vrot * dt * 0.15;
    } else {
      p.vy += 780 * dt;                                 // coins just fall
      p.vx *= 0.995;
      p.x += p.vx * dt;
      p.rot += p.vrot * dt;
    }
    p.y += p.vy * dt;

    /* Coins bounce once off the turf, then settle. */
    if (p.type === 'coin' && p.y > VIEW.H - 30 && p.vy > 0) {
      p.y = VIEW.H - 30;
      p.vy *= -0.42;
      p.vx *= 0.7;
      if (Math.abs(p.vy) < 40) p.vy = 0;
    }
  }

  /* popups */
  for (let i = fx.popups.length - 1; i >= 0; i--) {
    const t = fx.popups[i];
    t.life += dt;
    if (t.life > t.ttl) fx.popups.splice(i, 1);
    else t.y -= 46 * dt;
  }

  fx.shake = Math.max(0, fx.shake - dt * 34);
  fx.flash = Math.max(0, fx.flash - dt * 1.9);
  if (fx.netRipple) {
    fx.netRipple.t += dt;
    if (fx.netRipple.t > 1.1) fx.netRipple = null;
  }
}


/* ==========================================================================
 * 12. INPUT
 * ========================================================================*/

/** Single funnel for SPACE and taps so both platforms behave identically. */
function handleInput() {
  if (game.inputLock > 0) return;
  game.inputLock = CONFIG.inputLock;

  switch (game.state) {
    case STATE.MENU:
    case STATE.OVER:
      startGame();
      break;
    case STATE.AIM_H:
      lockHorizontal();
      break;
    case STATE.AIM_V:
      lockVerticalAndShoot();
      break;
    default:
      break;                    // READY / FLIGHT / RESULT ignore input
  }
}

window.addEventListener('keydown', e => {
  if (e.code === 'Space' || e.key === ' ' || e.code === 'Enter' || e.key === 'Enter') {
    if (e.repeat) return;       // holding the key must not spam the gauges
    e.preventDefault();
    handleInput();
  }
}, { passive: false });

/* pointerdown covers mouse, touch and pen with one listener and no 300ms delay */
document.getElementById('stage').addEventListener('pointerdown', e => {
  if (e.target.closest('.btn')) return;   // let the overlay buttons do their job
  e.preventDefault();
  handleInput();
});

el.btnStart.addEventListener('click', startGame);
el.btnAgain.addEventListener('click', startGame);


/* ==========================================================================
 * 13. UPDATE
 * ========================================================================*/

function update(dt) {
  game.time += dt;
  game.stateTime += dt;
  game.inputLock = Math.max(0, game.inputLock - dt);

  updateGK(dt);
  updateFx(dt);

  switch (game.state) {
    case STATE.READY:
      if (game.stateTime >= CONFIG.readyTime) setState(STATE.AIM_H);
      break;

    case STATE.AIM_H:
      game.phaseH += CONFIG.hBarSpeed * speedMul() * dt;
      game.mH = triangle(game.phaseH);
      break;

    case STATE.AIM_V:
      game.phaseV += CONFIG.vBarSpeed * speedMul() * dt;
      game.mV = triangle(game.phaseV);
      break;

    case STATE.FLIGHT:
      updateFlight(dt);
      break;

    case STATE.RESULT:
      updateLooseBall(dt);
      if (game.stateTime >= CONFIG.resultTime) {
        game.shot++;
        syncHud(false);
        if (game.shot >= CONFIG.shotsPerRound) endRound();
        else nextShot();
      }
      break;
  }
}

function updateFlight(dt) {
  ball.t += dt / CONFIG.flightTime;
  const t = Math.min(1, ball.t);

  /* Slight ease-in: the ball looks like it accelerates off the boot. */
  const e = lerp(t, easeIn(t), 0.25);
  const arc = Math.sin(Math.PI * e);

  ball.x = lerp(ball.from.x, ball.to.x, e) + ball.curl * arc;
  ball.y = lerp(ball.from.y, ball.to.y, e) - ball.loft * arc;
  ball.r = lerp(18, 6.5, e);
  ball.spin += ball.spinRate * dt;

  ball.trail.push({ x: ball.x, y: ball.y, r: ball.r });
  if (ball.trail.length > 9) ball.trail.shift();

  if (ball.t >= 1) resolveShot();
}

/** Free-flying ball during the RESULT beat. */
function updateLooseBall(dt) {
  const kind = game.outcome && game.outcome.kind;

  if (kind === 'goal' || kind === 'topCorner') {
    /* Caught in the netting, then drops to the goal line. */
    ball.vy += 420 * dt;
    ball.y = Math.min(ball.y + ball.vy * dt, GOAL.bottom - 6);
    ball.x += ball.vx * dt;
    ball.vx *= 0.9;
  } else if (kind === 'miss') {
    /* Off into the night, shrinking as it recedes. Barely any gravity —
       it is meant to look like it is still climbing away from the camera. */
    ball.vy += 40 * dt;
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    ball.r = Math.max(0, ball.r - dt * 7);
  } else {
    /* Rebounds back toward the camera, so it grows again. */
    ball.vy += 520 * dt;
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    ball.r = Math.min(18, ball.r + dt * 14);
    if (ball.y > VIEW.H - 24) { ball.y = VIEW.H - 24; ball.vy *= -0.45; ball.vx *= 0.8; }
  }
  ball.spin += ball.vr * dt;
  ball.trail.length = 0;
}

function updateGK(dt) {
  targetGK.taunt += dt;

  if (targetGK.mode === 'idle') {
    /* Idle shuffle: two out-of-sync sine waves so it never looks metronomic. */
    targetGK.x = Math.sin(game.time * 1.15) * 0.20 + Math.sin(game.time * 2.7) * 0.06;
    targetGK.headY = 0.70 + Math.sin(game.time * 3.4) * 0.012;
    targetGK.lean = Math.sin(game.time * 1.15) * 0.10;
  } else if (targetGK.mode === 'dive') {
    targetGK.diveT += dt;
    const p = easeOut(clamp(targetGK.diveT / CONFIG.gkDiveTime, 0, 1));
    targetGK.x = lerp(targetGK.diveFrom, targetGK.diveTo, p);

    if (targetGK.diveType === 'stay') {
      targetGK.headY = 0.70;
      targetGK.lean = Math.sin(targetGK.diveT * 9) * 0.06;
    } else {
      const dir = Math.sign(targetGK.diveTo - targetGK.diveFrom) || 1;
      targetGK.lean = dir * p * (targetGK.diveType === 'low' ? 1.15 : 0.85);
      targetGK.headY = lerp(0.70, targetGK.diveType === 'low' ? 0.34 : 0.58, p);
    }
  } else if (targetGK.mode === 'hit') {
    targetGK.dizzy = Math.max(0, targetGK.dizzy - dt);
    targetGK.lean += (0.5 - targetGK.lean) * dt * 3;
    targetGK.headY += (0.55 - targetGK.headY) * dt * 4;
    targetGK.x += Math.sin(game.time * 22) * 0.004;
  } else if (targetGK.mode === 'beaten') {
    targetGK.lean *= 1 - dt * 1.5;
    targetGK.headY += (0.62 - targetGK.headY) * dt * 3;
  }
}


/* ==========================================================================
 * 14. DRAWING — stadium
 * ========================================================================*/

/* Pre-generated crowd so the stands do not re-randomise every frame. */
const crowd = (() => {
  const dots = [];
  for (let i = 0; i < 420; i++) {
    dots.push({
      x: rand(-20, VIEW.W + 20),
      y: rand(24, HORIZON - 12),
      r: rand(2.2, 4.6),
      hue: randInt(0, 360),
      phase: rand(0, Math.PI * 2),
    });
  }
  return dots;
})();

const SPONSORS = ['KA-CHING BANK', 'GLOBO-SPORT', 'DUBIOUS AIRLINES', 'CRYPTO FC',
                  'MEGA GRIP GLOVES', 'YACHT & SONS'];

function drawStadium() {
  /* --- sky / far stand --- */
  const sky = ctx.createLinearGradient(0, 0, 0, HORIZON);
  sky.addColorStop(0, '#0b1c2b');
  sky.addColorStop(1, '#123a4d');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, VIEW.W, HORIZON);

  /* Optional tiled crowd bitmap replaces the procedural dots entirely. */
  if (!drawSprite('crowd', VIEW.W / 2, HORIZON / 2, VIEW.W, HORIZON)) {
    for (const d of crowd) {
      const bob = Math.sin(game.time * 2.2 + d.phase) * 1.8;
      ctx.fillStyle = `hsl(${d.hue} 55% ${38 + Math.sin(d.phase) * 12}%)`;
      ctx.beginPath();
      ctx.arc(d.x, d.y + bob, d.r, 0, Math.PI * 2);
      ctx.fill();
    }
    /* Darken the crowd so it never competes with the goal. */
    ctx.fillStyle = 'rgba(6, 18, 28, .62)';
    ctx.fillRect(0, 0, VIEW.W, HORIZON);
  }

  /* --- advertising hoardings: the actual satire budget ---
     Placed above the crossbar (upper tier) so the scrolling text never
     runs across the goal mouth and fights with the netting. */
  const bandY = GOAL.top - 52, bandH = 30, gap = 320;
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, bandY, VIEW.W, bandH);
  ctx.clip();
  ctx.fillStyle = '#0e2231';
  ctx.fillRect(0, bandY, VIEW.W, bandH);
  ctx.fillStyle = '#ffc94a';
  ctx.font = 'bold 15px "Trebuchet MS", sans-serif';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  const scroll = (game.time * 46) % gap;
  for (let i = -1; i <= Math.ceil(VIEW.W / gap); i++) {
    const name = SPONSORS[((i % SPONSORS.length) + SPONSORS.length) % SPONSORS.length];
    ctx.fillText(name, i * gap - scroll + 20, bandY + bandH / 2 + 1);
  }
  ctx.restore();

  /* --- turf --- */
  const grass = ctx.createLinearGradient(0, HORIZON, 0, VIEW.H);
  grass.addColorStop(0, '#0d6b3b');
  grass.addColorStop(1, '#0a4b2a');
  ctx.fillStyle = grass;
  ctx.fillRect(0, HORIZON, VIEW.W, VIEW.H - HORIZON);

  /* Mown stripes, widening toward the camera for a cheap sense of depth. */
  ctx.fillStyle = 'rgba(255, 255, 255, .035)';
  for (let i = 0; i < 9; i++) {
    const t0 = i / 9, t1 = (i + 0.5) / 9;
    const y0 = HORIZON + Math.pow(t0, 1.6) * (VIEW.H - HORIZON);
    const y1 = HORIZON + Math.pow(t1, 1.6) * (VIEW.H - HORIZON);
    ctx.fillRect(0, y0, VIEW.W, y1 - y0);
  }

  /* Six-yard box, drawn in loose perspective — wider than the goal, as it
     is in real life, otherwise the pitch markings look wrong. */
  ctx.strokeStyle = 'rgba(255, 255, 255, .55)';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(58, 492); ctx.lineTo(226, GOAL.bottom + 8);
  ctx.lineTo(734, GOAL.bottom + 8); ctx.lineTo(902, 492);
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(0, GOAL.bottom + 8); ctx.lineTo(VIEW.W, GOAL.bottom + 8);
  ctx.stroke();

  /* Penalty spot. */
  ctx.fillStyle = 'rgba(255, 255, 255, .75)';
  ctx.beginPath();
  ctx.ellipse(PENALTY_SPOT.x, PENALTY_SPOT.y + 16, 9, 3.4, 0, 0, Math.PI * 2);
  ctx.fill();
}

/** Goal frame + netting, with a fake back plane for depth. */
function drawGoal() {
  const { left: L, right: R, top: T, bottom: B } = GOAL;
  const bL = L + 42, bR = R - 42, bT = T + 12, bB = B - 32;   // receding back plane

  /* Net: back panel first, then the roof/side panels that connect to it. */
  ctx.save();
  ctx.strokeStyle = 'rgba(226, 240, 255, .30)';
  ctx.lineWidth = 1;

  for (let i = 0; i <= 12; i++) {
    const t = i / 12;
    ctx.beginPath();
    ctx.moveTo(lerp(bL, bR, t), bT);
    ctx.lineTo(lerp(bL, bR, t), bB);
    ctx.stroke();
  }
  for (let i = 0; i <= 9; i++) {
    const t = i / 9;
    ctx.beginPath();
    ctx.moveTo(bL, lerp(bT, bB, t));
    ctx.lineTo(bR, lerp(bT, bB, t));
    ctx.stroke();
  }

  /* Connecting strands: corners of the mouth to corners of the back plane. */
  ctx.strokeStyle = 'rgba(226, 240, 255, .22)';
  for (let i = 0; i <= 10; i++) {
    const t = i / 10;
    ctx.beginPath();                                  // roof
    ctx.moveTo(lerp(L, R, t), T);
    ctx.lineTo(lerp(bL, bR, t), bT);
    ctx.stroke();
  }
  for (let i = 0; i <= 6; i++) {
    const t = i / 6;
    ctx.beginPath();                                  // left side
    ctx.moveTo(L, lerp(T, B, t));
    ctx.lineTo(bL, lerp(bT, bB, t));
    ctx.stroke();
    ctx.beginPath();                                  // right side
    ctx.moveTo(R, lerp(T, B, t));
    ctx.lineTo(bR, lerp(bT, bB, t));
    ctx.stroke();
  }
  ctx.restore();

  /* Net ripple where a scoring shot hit the mesh. */
  if (fx.netRipple) {
    const p = fx.netRipple.t / 1.1;
    ctx.save();
    ctx.strokeStyle = `rgba(255, 255, 255, ${0.5 * (1 - p)})`;
    ctx.lineWidth = 2;
    for (let i = 0; i < 3; i++) {
      const rr = 10 + p * 70 + i * 14;
      ctx.beginPath();
      ctx.ellipse(fx.netRipple.x, fx.netRipple.y, rr, rr * 0.62, 0, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  /* Frame. */
  ctx.fillStyle = '#f2f6fb';
  ctx.fillRect(L - 8, T - 8, 8, B - T + 8);            // left post
  ctx.fillRect(R,     T - 8, 8, B - T + 8);            // right post
  ctx.fillRect(L - 8, T - 8, R - L + 16, 8);           // crossbar

  ctx.fillStyle = 'rgba(0, 0, 0, .18)';                // cheap round-bar shading
  ctx.fillRect(L - 3, T - 8, 3, B - T + 8);
  ctx.fillRect(R + 5, T - 8, 3, B - T + 8);
}


/* ==========================================================================
 * 15. DRAWING — characters
 * ========================================================================*/

/**
 * targetGK — cartoon goalkeeper caricature.
 * The whole figure is built around (cx, groundY) in view space so a PNG can
 * be dropped in over the top without touching the collision maths.
 */
function drawKeeper() {
  const cx = aimToX(targetGK.x);
  const groundY = GOAL.bottom;
  const headY = aimToY(targetGK.headY);
  const bodyH = groundY - headY;

  /* Shadow on the goal line. */
  ctx.fillStyle = 'rgba(0, 0, 0, .28)';
  ctx.beginPath();
  ctx.ellipse(cx, groundY + 4, 34, 8, 0, 0, Math.PI * 2);
  ctx.fill();

  /* Bitmap path — one of three poses depending on what he is doing. */
  const spriteKey = targetGK.mode === 'hit'  ? 'gk_hit'
                  : targetGK.mode === 'dive' && targetGK.diveType !== 'stay' ? 'gk_dive'
                  : 'gk_idle';
  if (drawSprite(spriteKey, cx, groundY - bodyH * 0.55, 180, bodyH * 1.25)) return;

  /* ---- vector placeholder ---- */
  ctx.save();
  ctx.translate(cx, groundY);
  ctx.rotate(-targetGK.lean * 0.55);       // dives read as a whole-body tilt

  const kitA = '#ff9f1c';                  // shirt
  const kitB = '#1f3b57';                  // shorts
  const skin = '#ffd7ab';

  /* legs */
  ctx.strokeStyle = kitB;
  ctx.lineWidth = 13;
  ctx.lineCap = 'round';
  const legSplay = targetGK.mode === 'dive' ? 26 : 12 + Math.sin(game.time * 3) * 3;
  ctx.beginPath();
  ctx.moveTo(-6, -bodyH * 0.42); ctx.lineTo(-legSplay, -4);
  ctx.moveTo( 6, -bodyH * 0.42); ctx.lineTo( legSplay, -4);
  ctx.stroke();

  /* torso */
  ctx.fillStyle = kitA;
  ctx.beginPath();
  ctx.roundRect(-24, -bodyH * 0.78, 48, bodyH * 0.40, 12);
  ctx.fill();
  ctx.fillStyle = 'rgba(0, 0, 0, .16)';    // a big satirical sponsor blob
  ctx.beginPath();
  ctx.roundRect(-14, -bodyH * 0.66, 28, 12, 4);
  ctx.fill();

  /* arms + gloves — spread wide while diving */
  const armUp = targetGK.mode === 'dive' || targetGK.mode === 'hit' ? 1 : 0;
  const wave = Math.sin(game.time * 4.5) * 6;
  const armY = -bodyH * (0.70 + armUp * 0.10);
  const armX = 38 + armUp * 26;

  ctx.strokeStyle = kitA;
  ctx.lineWidth = 11;
  ctx.beginPath();
  ctx.moveTo(-20, -bodyH * 0.72); ctx.lineTo(-armX, armY - armUp * 16 + wave);
  ctx.moveTo( 20, -bodyH * 0.72); ctx.lineTo( armX, armY - armUp * 16 - wave);
  ctx.stroke();

  ctx.fillStyle = '#39d98a';                // comically oversized gloves
  for (const sx of [-1, 1]) {
    ctx.beginPath();
    ctx.ellipse(sx * armX, armY - armUp * 16 + sx * wave, 13, 15, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  /* head */
  const hy = -bodyH * 0.90;
  ctx.fillStyle = skin;
  ctx.beginPath();
  ctx.ellipse(0, hy, 23, 25, 0, 0, Math.PI * 2);
  ctx.fill();

  /* silly hair + cap peak */
  ctx.fillStyle = '#3a2a1c';
  ctx.beginPath();
  ctx.ellipse(0, hy - 16, 24, 12, 0, Math.PI, 0);
  ctx.fill();
  ctx.fillRect(-30, hy - 18, 60, 5);

  /* face: normal, or thoroughly concussed */
  ctx.strokeStyle = '#20313f';
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  if (targetGK.mode === 'hit') {
    ctx.beginPath();                        // X eyes
    ctx.moveTo(-13, hy - 6); ctx.lineTo(-3, hy + 3);
    ctx.moveTo(-3, hy - 6);  ctx.lineTo(-13, hy + 3);
    ctx.moveTo(3, hy - 6);   ctx.lineTo(13, hy + 3);
    ctx.moveTo(13, hy - 6);  ctx.lineTo(3, hy + 3);
    ctx.stroke();
    ctx.fillStyle = '#20313f';              // gaping mouth
    ctx.beginPath();
    ctx.ellipse(0, hy + 13, 8, 6, 0, 0, Math.PI * 2);
    ctx.fill();
  } else {
    const look = clamp(targetGK.x * 1.2, -1, 1) * 4;
    ctx.fillStyle = '#fff';
    for (const sx of [-1, 1]) {
      ctx.beginPath();
      ctx.ellipse(sx * 9, hy - 3, 7, 8, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = '#20313f';
    for (const sx of [-1, 1]) {
      ctx.beginPath();
      ctx.ellipse(sx * 9 + look, hy - 2, 3.4, 4, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.strokeStyle = '#20313f';
    ctx.beginPath();                        // smug grin, or an "o" when beaten
    if (targetGK.mode === 'beaten') {
      ctx.ellipse(0, hy + 12, 6, 7, 0, 0, Math.PI * 2);
    } else {
      ctx.arc(0, hy + 6, 9, 0.25 * Math.PI, 0.75 * Math.PI);
    }
    ctx.stroke();
  }

  ctx.restore();

  /* Dizzy stars orbiting a freshly headshot keeper. */
  if (targetGK.dizzy > 0) {
    const n = 4;
    for (let i = 0; i < n; i++) {
      const a = game.time * 5 + (i / n) * Math.PI * 2;
      drawStar(cx + Math.cos(a) * 34, headY - 34 + Math.sin(a) * 11, 7, '#ffc94a');
    }
  }
}

function drawStar(x, y, r, colour) {
  ctx.save();
  ctx.translate(x, y);
  ctx.fillStyle = colour;
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const rr = i % 2 ? r * 0.45 : r;
    const a = (i / 10) * Math.PI * 2 - Math.PI / 2;
    i ? ctx.lineTo(Math.cos(a) * rr, Math.sin(a) * rr)
      : ctx.moveTo(Math.cos(a) * rr, Math.sin(a) * rr);
  }
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/** The penalty taker, seen from behind. Purely decorative. */
function drawStriker() {
  const aiming = game.state === STATE.AIM_H || game.state === STATE.AIM_V ||
                 game.state === STATE.READY;
  const kicking = game.state === STATE.FLIGHT || game.state === STATE.RESULT;
  if (!aiming && !kicking) return;

  /* Steps in as the shot is struck. */
  const stepT = game.state === STATE.FLIGHT ? clamp(ball.t * 3, 0, 1) : 0;
  const cx = 356 + stepT * 34;
  const groundY = 534;                       // kept clear of the horizontal gauge

  if (drawSprite('striker', cx, groundY - 62, 120, 186)) return;

  ctx.save();
  ctx.translate(cx, groundY);
  ctx.scale(0.86, 0.86);                     // he should not upstage the goal

  ctx.fillStyle = 'rgba(0, 0, 0, .3)';
  ctx.beginPath();
  ctx.ellipse(0, 4, 30, 8, 0, 0, Math.PI * 2);
  ctx.fill();

  /* kicking leg swings through on contact */
  const swing = kicking ? Math.sin(clamp(ball.t * 2.4, 0, 1) * Math.PI) : 0;
  ctx.strokeStyle = '#e8eef5';
  ctx.lineWidth = 15;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-8, -58); ctx.lineTo(-14, -2);
  ctx.moveTo(8, -58);  ctx.lineTo(16 + swing * 46, -2 - swing * 44);
  ctx.stroke();

  ctx.fillStyle = '#d92b4b';                 // shirt
  ctx.beginPath();
  ctx.roundRect(-27, -118, 54, 62, 14);
  ctx.fill();

  ctx.strokeStyle = '#d92b4b';               // arms out for balance
  ctx.lineWidth = 12;
  ctx.beginPath();
  ctx.moveTo(-24, -108); ctx.lineTo(-46 - swing * 12, -84 + swing * 10);
  ctx.moveTo( 24, -108); ctx.lineTo( 46 + swing * 12, -84 + swing * 10);
  ctx.stroke();

  ctx.fillStyle = '#ffd7ab';                 // back of the head
  ctx.beginPath();
  ctx.ellipse(0, -140, 21, 23, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#2b1d12';
  ctx.beginPath();
  ctx.ellipse(0, -146, 21, 18, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#f4f8ff';                 // shirt number
  ctx.font = 'bold 26px "Trebuchet MS", sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('9', 0, -88);

  ctx.restore();
}

/** The ball, with a stitched pattern so its spin is readable. */
function drawBall() {
  if (!ball.visible || ball.r <= 0.5) return;

  /* Motion trail. */
  for (let i = 0; i < ball.trail.length; i++) {
    const p = ball.trail[i];
    const a = (i / ball.trail.length) * 0.30;
    ctx.fillStyle = `rgba(255, 255, 255, ${a})`;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.r * 0.85, 0, Math.PI * 2);
    ctx.fill();
  }

  if (drawSprite('ball', ball.x, ball.y, ball.r * 2, ball.r * 2)) return;

  ctx.save();
  ctx.translate(ball.x, ball.y);
  ctx.rotate(ball.spin);

  ctx.fillStyle = '#ffffff';
  ctx.beginPath();
  ctx.arc(0, 0, ball.r, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#1d2733';
  const pr = ball.r * 0.34;
  ctx.beginPath();
  ctx.arc(0, 0, pr, 0, Math.PI * 2);
  ctx.fill();
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    ctx.beginPath();
    ctx.arc(Math.cos(a) * ball.r * 0.66, Math.sin(a) * ball.r * 0.66, pr * 0.72, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.strokeStyle = 'rgba(0, 0, 0, .25)';
  ctx.lineWidth = Math.max(1, ball.r * 0.09);
  ctx.beginPath();
  ctx.arc(0, 0, ball.r - ctx.lineWidth / 2, 0, Math.PI * 2);
  ctx.stroke();
  ctx.restore();
}


/* ==========================================================================
 * 16. DRAWING — HUD, gauges, particles
 * ========================================================================*/

/**
 * Arrow preview. It is driven straight off the live gauge value, so it whips
 * across the goal far faster than anyone can reliably read — which is the
 * intended cruelty.
 */
function drawAimPreview() {
  const showH = game.state === STATE.AIM_H;
  const showV = game.state === STATE.AIM_V;
  if (!showH && !showV) return;

  const ax = showH ? aimH(game.mH) : aimH(game.lockedH);
  const x  = clamp(aimToX(ax), 30, VIEW.W - 30);

  ctx.save();

  if (showH) {
    /* Step 1: a vertical sight line sweeping the goal. */
    ctx.strokeStyle = isPerfect(game.mH) ? '#ffc94a' : 'rgba(255, 255, 255, .75)';
    ctx.lineWidth = 3;
    ctx.setLineDash([9, 8]);
    ctx.beginPath();
    ctx.moveTo(x, GOAL.top - 24);
    ctx.lineTo(x, GOAL.bottom + 16);
    ctx.stroke();
    ctx.setLineDash([]);
    drawArrowHead(x, GOAL.top - 26, 0, ctx.strokeStyle);
  } else {
    /* Step 2: the full crosshair, now also moving up and down. */
    const ay = aimV(game.mV);
    const y  = clamp(aimToY(ay), 26, VIEW.H - 120);
    const hot = isPerfect(game.mV);
    const col = hot ? '#ffc94a' : 'rgba(255, 255, 255, .8)';

    ctx.strokeStyle = col;
    ctx.lineWidth = 3;
    ctx.setLineDash([9, 8]);
    ctx.beginPath();
    ctx.moveTo(x, GOAL.top - 24); ctx.lineTo(x, GOAL.bottom + 16);
    ctx.moveTo(x - 70, y);        ctx.lineTo(x + 70, y);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.beginPath();
    ctx.arc(x, y, 15, 0, Math.PI * 2);
    ctx.stroke();

    /* Trajectory hint from the spot to the crosshair. */
    ctx.strokeStyle = 'rgba(255, 255, 255, .28)';
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 10]);
    ctx.beginPath();
    ctx.moveTo(PENALTY_SPOT.x, PENALTY_SPOT.y);
    ctx.quadraticCurveTo((PENALTY_SPOT.x + x) / 2, (PENALTY_SPOT.y + y) / 2 - 70, x, y);
    ctx.stroke();
    ctx.setLineDash([]);
  }

  ctx.restore();
}

function drawArrowHead(x, y, rot, colour) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rot);
  ctx.fillStyle = colour;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(-11, -16);
  ctx.lineTo(11, -16);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/** Shared gauge chrome: frame, coloured zones, marker. */
function drawGauges() {
  const st = game.state;
  const showH = st === STATE.AIM_H;
  const showV = st === STATE.AIM_V;
  const lockedH = game.lockedH !== null && (showV || st === STATE.FLIGHT);

  /* ---------- horizontal ---------- */
  if (showH || lockedH) {
    const { x, y, w, h } = HBAR;
    gaugeFrame(x, y, w, h);

    const zones = ZONES.h, n = zones.length;
    for (let i = 0; i < n; i++) {
      ctx.fillStyle = ZONE_COLORS[zones[i]];
      ctx.globalAlpha = showH ? 0.85 : 0.35;
      ctx.fillRect(x + (i / n) * w, y + 3, w / n + 1, h - 6);
    }
    ctx.globalAlpha = 1;

    if (showH) gaugeMarker(x + game.mH * w, y, h, 'h', isPerfect(game.mH));
    if (game.lockedH !== null) {
      gaugeMarker(x + game.lockedH * w, y, h, 'h', game.perfectH, true);
    }
    /* Label sits at the left end of the bar, clear of the ball and taker. */
    gaugeLabel(x + 76, y - 12, showH ? 'ANGLE — HIT SPACE' : 'ANGLE LOCKED');
  }

  /* ---------- vertical ---------- */
  if (showV) {
    const { x, y, w, h } = VBAR;
    gaugeFrame(x, y, w, h);

    const zones = ZONES.v, n = zones.length;
    for (let i = 0; i < n; i++) {
      /* index 0 is the bottom of the bar (gauge value 0) */
      const yy = y + h - ((i + 1) / n) * h;
      ctx.fillStyle = ZONE_COLORS[zones[i]];
      ctx.globalAlpha = 0.85;
      ctx.fillRect(x + 3, yy, w - 6, h / n + 1);
    }
    ctx.globalAlpha = 1;

    gaugeMarker(x, y + h - game.mV * h, w, 'v', isPerfect(game.mV));

    ctx.save();
    ctx.translate(x - 26, y + h / 2);       // clear of the marker's arrow head
    ctx.rotate(-Math.PI / 2);
    gaugeLabel(0, 0, 'HEIGHT — HIT SPACE');
    ctx.restore();
  }
}

function gaugeFrame(x, y, w, h) {
  ctx.fillStyle = 'rgba(4, 14, 22, .78)';
  ctx.strokeStyle = 'rgba(255, 255, 255, .5)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.roundRect(x - 3, y - 3, w + 6, h + 6, 8);
  ctx.fill();
  ctx.stroke();
}

function gaugeMarker(px, py, size, axis, hot, ghost) {
  ctx.save();
  ctx.fillStyle = ghost ? 'rgba(255, 255, 255, .55)' : (hot ? '#ffffff' : '#f4f8ff');
  ctx.shadowColor = hot ? '#ffc94a' : 'rgba(0,0,0,.6)';
  ctx.shadowBlur = hot ? 16 : 6;

  if (axis === 'h') {
    ctx.beginPath();
    ctx.moveTo(px, py - 6);
    ctx.lineTo(px - 7, py - 18);
    ctx.lineTo(px + 7, py - 18);
    ctx.closePath();
    ctx.fill();
    ctx.fillRect(px - 2.5, py - 4, 5, size + 8);
  } else {
    ctx.beginPath();
    ctx.moveTo(px - 6, py);
    ctx.lineTo(px - 18, py - 7);
    ctx.lineTo(px - 18, py + 7);
    ctx.closePath();
    ctx.fill();
    ctx.fillRect(px - 4, py - 2.5, size + 8, 5);
  }
  ctx.restore();
}

function gaugeLabel(x, y, text) {
  ctx.fillStyle = 'rgba(255, 255, 255, .8)';
  ctx.font = 'bold 13px "Trebuchet MS", sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'bottom';
  ctx.fillText(text, x, y);
}

/** Coins and banknotes. */
function drawParticles() {
  for (const p of fx.particles) {
    const fade = clamp(1 - (p.life / p.ttl - 0.7) / 0.3, 0, 1);
    ctx.save();
    ctx.globalAlpha = fade;
    ctx.translate(p.x, p.y);
    ctx.rotate(p.rot);

    if (p.type === 'coin') {
      const squash = Math.abs(Math.cos(p.rot));       // spinning coin
      ctx.fillStyle = '#ffc94a';
      ctx.beginPath();
      ctx.ellipse(0, 0, p.size * (0.35 + squash * 0.65), p.size, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#c8860a';
      ctx.lineWidth = 1.5;
      ctx.stroke();
      if (squash > 0.55) {
        ctx.fillStyle = '#8a5a05';
        ctx.font = `bold ${p.size}px "Trebuchet MS", sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(p.glyph, 0, 0.5);
      }
    } else {
      const w = p.size * 2.1, h = p.size;
      const squash = 0.35 + Math.abs(Math.cos(p.flutter)) * 0.65;
      ctx.scale(1, squash);
      ctx.fillStyle = '#6ddc8b';
      ctx.fillRect(-w / 2, -h / 2, w, h);
      ctx.strokeStyle = '#2f8b4d';
      ctx.lineWidth = 1;
      ctx.strokeRect(-w / 2, -h / 2, w, h);
      ctx.fillStyle = '#2f8b4d';
      ctx.beginPath();
      ctx.arc(0, 0, h * 0.26, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
}

/** Floating score text. */
function drawPopups() {
  for (const t of fx.popups) {
    const p = t.life / t.ttl;
    const pop = p < 0.16 ? lerp(0.5, 1.12, p / 0.16)
              : p < 0.28 ? lerp(1.12, 1, (p - 0.16) / 0.12)
              : 1;
    ctx.save();
    ctx.globalAlpha = clamp((1 - p) * 1.6, 0, 1);
    ctx.translate(t.x, t.y);
    ctx.scale(pop, pop);
    ctx.font = `bold ${t.size}px "Trebuchet MS", sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.lineWidth = 6;
    ctx.strokeStyle = 'rgba(4, 12, 20, .85)';
    ctx.strokeText(t.text, 0, 0);
    ctx.fillStyle = t.colour;
    ctx.fillText(t.text, 0, 0);
    ctx.restore();
  }
}

/** Commentary banner + streak pill, drawn inside the canvas. */
function drawBanner() {
  if (game.state === STATE.RESULT && game.banner) {
    const w = 620, h = 42, x = VIEW.W / 2 - w / 2, y = 18;
    const slide = easeOut(clamp(game.stateTime / 0.25, 0, 1));
    ctx.save();
    ctx.globalAlpha = slide;
    ctx.translate(0, (1 - slide) * -30);
    ctx.fillStyle = 'rgba(4, 14, 22, .82)';
    ctx.strokeStyle = game.bannerColor;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, 10);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#f4f8ff';
    ctx.font = 'bold 19px "Trebuchet MS", sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(game.banner, VIEW.W / 2, y + h / 2 + 1);
    ctx.restore();
  }

  if (game.streak >= 2 && game.state !== STATE.MENU && game.state !== STATE.OVER) {
    const pulse = 1 + Math.sin(game.time * 8) * 0.05;
    ctx.save();
    ctx.translate(84, 78);
    ctx.scale(pulse, pulse);
    ctx.fillStyle = '#ffc94a';
    ctx.font = 'bold 24px "Trebuchet MS", sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.lineWidth = 5;
    ctx.strokeStyle = 'rgba(4, 12, 20, .8)';
    ctx.strokeText(`STREAK x${game.streak}`, 0, 0);
    ctx.fillText(`STREAK x${game.streak}`, 0, 0);
    ctx.restore();
  }

  /* "READY" countdown flourish before the gauges appear. */
  if (game.state === STATE.READY) {
    const a = 1 - clamp(game.stateTime / CONFIG.readyTime, 0, 1);
    ctx.save();
    ctx.globalAlpha = a;
    ctx.fillStyle = '#f4f8ff';
    ctx.font = 'bold 40px "Trebuchet MS", sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`ELFMETER ${game.shot + 1}`, VIEW.W / 2, 96);
    ctx.restore();
  }
}


/* ==========================================================================
 * 17. FRAME COMPOSITION
 * ========================================================================*/

function draw() {
  ctx.save();

  /* Camera shake, applied to the whole scene. */
  if (fx.shake > 0.2) {
    ctx.translate(rand(-fx.shake, fx.shake), rand(-fx.shake, fx.shake));
  }

  drawStadium();
  drawGoal();
  drawKeeper();
  drawStriker();
  drawBall();
  drawParticles();
  drawAimPreview();
  drawGauges();
  drawPopups();
  drawBanner();

  ctx.restore();

  /* Impact flash sits above everything. */
  if (fx.flash > 0.01) {
    ctx.fillStyle = `rgba(255, 255, 255, ${fx.flash * 0.45})`;
    ctx.fillRect(0, 0, VIEW.W, VIEW.H);
  }
}


/* ==========================================================================
 * 18. MAIN LOOP
 * ========================================================================*/

let lastTime = 0;

function frame(now) {
  /* dt is clamped so a backgrounded tab cannot teleport the ball. */
  const dt = Math.min(0.05, (now - lastTime) / 1000 || 0);
  lastTime = now;

  update(dt);
  draw();
  requestAnimationFrame(frame);
}

function boot() {
  el.shotsTotal.textContent = CONFIG.shotsPerRound;
  loadBest();
  loadAssets();
  resizeCanvas();
  syncHud(false);

  /* Idle attract mode behind the title card. */
  setState(STATE.MENU);
  requestAnimationFrame(t => { lastTime = t; frame(t); });
}

boot();
