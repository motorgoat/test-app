/*
 * Zentrale Interaktionen der Website – ersetzt die Animations-Library des
 * Entwurfs durch schlankes Vanilla-JS (IntersectionObserver + rAF).
 * Jede Animation respektiert prefers-reduced-motion (Abnahmekriterium).
 */

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/* ---------- ScrollReveal ---------- */
function initReveal() {
  const elements = document.querySelectorAll<HTMLElement>('.iIT_reveal');
  if (reducedMotion) {
    elements.forEach((el) => el.classList.add('iIT_revealed'));
    return;
  }
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('iIT_revealed');
          observer.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.15, rootMargin: '0px 0px -50px 0px' }
  );
  elements.forEach((el) => observer.observe(el));
}

/* ---------- Typewriter (Hero-H1) ---------- */
function initTypewriter() {
  document.querySelectorAll<HTMLElement>('[data-typewriter]').forEach((el) => {
    const words: string[] = JSON.parse(el.dataset.typewriter ?? '[]');
    if (words.length === 0) return;
    const target = el.querySelector<HTMLElement>('.iIT_type-text');
    if (!target) return;
    if (reducedMotion) {
      target.textContent = words[0];
      return;
    }
    const typingSpeed = 70;
    const deletingSpeed = 40;
    const pauseDuration = 2500;
    let wordIndex = 0;
    let text = '';
    let deleting = false;

    const tick = () => {
      const word = words[wordIndex];
      if (!deleting) {
        if (text.length < word.length) {
          text = word.slice(0, text.length + 1);
          target.textContent = text;
          setTimeout(tick, typingSpeed);
        } else {
          deleting = true;
          setTimeout(tick, pauseDuration);
        }
      } else {
        if (text.length > 0) {
          text = text.slice(0, -1);
          target.textContent = text;
          setTimeout(tick, deletingSpeed);
        } else {
          deleting = false;
          wordIndex = (wordIndex + 1) % words.length;
          tick();
        }
      }
    };
    target.textContent = '';
    tick();
  });
}

/* ---------- AnimatedCounter (Zahlen zählen beim Scrollen hoch) ---------- */
function initCounters() {
  const counters = document.querySelectorAll<HTMLElement>('[data-counter]');
  if (counters.length === 0 || reducedMotion) return; // ohne JS/Animation steht der Endwert bereits im Markup

  const easeOutExpo = (t: number) => (t === 1 ? 1 : 1 - Math.pow(2, -10 * t));

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        observer.unobserve(entry.target);
        const el = entry.target as HTMLElement;
        const end = parseFloat(el.dataset.end ?? '0');
        const decimals = parseInt(el.dataset.decimals ?? '0', 10);
        const prefix = el.dataset.prefix ?? '';
        const suffix = el.dataset.suffix ?? '';
        const duration = 2000;
        let start: number | null = null;

        const step = (now: number) => {
          if (start === null) start = now;
          const progress = Math.min((now - start) / duration, 1);
          const value = easeOutExpo(progress) * end;
          // Deutsches Zahlenformat: Komma statt Punkt (wie im SSR-Markup)
          const formatted = decimals > 0 ? value.toFixed(decimals).replace('.', ',') : String(Math.round(value));
          el.textContent = `${prefix}${formatted}${suffix}`;
          if (progress < 1) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
      }
    },
    { threshold: 0.5 }
  );
  counters.forEach((el) => observer.observe(el));
}

/* ---------- Wort-für-Wort-Reveal (Über-uns-Sektion) ---------- */
function initWordReveal() {
  const containers = document.querySelectorAll<HTMLElement>('[data-word-reveal]');
  if (containers.length === 0 || reducedMotion) return;

  let ticking = false;
  const update = () => {
    ticking = false;
    for (const container of containers) {
      const rect = container.getBoundingClientRect();
      const start = window.innerHeight;
      const end = window.innerHeight * 0.3;
      const progress = Math.max(0, Math.min(1, (start - rect.top) / (start - end)));
      const words = container.querySelectorAll<HTMLElement>('.iIT_word');
      words.forEach((word, i) => {
        const p = Math.max(0, Math.min(1, (progress * words.length - i) * 2));
        word.style.setProperty('--word-p', String(p));
        if (word.dataset.highlight !== undefined) {
          word.classList.toggle('iIT_word--highlight', p > 0.5);
        }
      });
    }
  };
  const onScroll = () => {
    if (!ticking) {
      ticking = true;
      requestAnimationFrame(update);
    }
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  update();
}

/* ---------- 3D-Tilt auf Leistungs-Cards (nur Maus, nie Touch) ---------- */
function initTilt() {
  if (reducedMotion || !window.matchMedia('(pointer: fine)').matches) return;
  document.querySelectorAll<HTMLElement>('[data-tilt]').forEach((card) => {
    const maxTilt = 8;
    card.style.transformStyle = 'preserve-3d';
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width;
      const y = (e.clientY - rect.top) / rect.height;
      card.style.transition = 'transform 0.1s ease-out';
      card.style.transform = `perspective(1000px) rotateX(${(y - 0.5) * -maxTilt}deg) rotateY(${(x - 0.5) * maxTilt}deg) scale3d(1.02, 1.02, 1.02)`;
    });
    card.addEventListener('mouseleave', () => {
      card.style.transition = 'transform 0.5s cubic-bezier(0.16, 1, 0.3, 1)';
      card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg)';
    });
  });
}

/* ---------- Hero-Video: nur auf Desktop ohne Datensparmodus abspielen ----------
   Poster ist immer das LCP-Element; das Video (0,8 MB) lädt erst, wenn es
   wirklich abgespielt wird (BRIEFING.md, Abschnitt 14: mobil nur Poster). */
function initHeroVideo() {
  const video = document.querySelector<HTMLVideoElement>('video[data-hero]');
  if (!video) return;
  const saveData = (navigator as { connection?: { saveData?: boolean } }).connection?.saveData === true;
  const isDesktop = window.matchMedia('(min-width: 768px)').matches;
  if (reducedMotion || saveData || !isDesktop) return;
  video.preload = 'auto';
  video.autoplay = true;
  video.load();
  video.play().catch(() => {
    /* Autoplay blockiert → Poster bleibt stehen */
  });
}

/* ---------- Header: transparent über dem Hero, solide beim Scrollen ---------- */
function initHeaderScroll() {
  const header = document.getElementById('iIT_header');
  if (!header) return;
  const onScroll = () => header.classList.toggle('iIT_scrolled', window.scrollY > 50);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

initReveal();
initTypewriter();
initCounters();
initWordReveal();
initTilt();
initHeroVideo();
initHeaderScroll();
