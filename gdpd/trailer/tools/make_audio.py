#!/usr/bin/env python3
"""Tonspur für den gdpd-Trailer v2, nur aus Zahlen gebaut (numpy, keine fremden Samples).

Liest die Zeitpunkte, die trailer.gd mit --cues=<datei> schreibt, und baut daraus:
  Musik:  Dröhnen (Glut, Dunst) -> Puls in der Montage (ein Takt je Schnitt) -> Stille nach dem Meteor
          -> Puls kehrt zurück -> Anschwellen bei „Erschaffe deine Welt“ -> Schlussakkord im Abspann
  Klänge: Drehen (Klick + Steinmahlen + Einrasten), Wachsen (Glockenspiel), Bass-Schlag auf jedem Schnitt,
          Wisch-Rauschen, Regen, Stampfen der Riesen, Meteor (Rauschen, Einschlag, Grollen), Miau, Aufruf-Klick.

Aufruf:  make_audio.py cues.json out.wav [--snap 0.45]
         make_audio.py cues.json out.wav --segments "0-1.75,8.8-10.2,..."   (Kurzfassung: Ereignisse neu verteilt)
Die Lautheit (-14 LUFS, -1 dBTP) stellt danach ffmpeg loudnorm ein (siehe README.txt).
"""
import json
import sys
import wave

import numpy as np

SR = 48000
rng = np.random.default_rng(7)


def note(n):
    """MIDI-Nummer -> Hz"""
    return 440.0 * 2 ** ((n - 69) / 12.0)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    e = np.full(n, s, dtype=np.float64)
    a = min(a, n)
    e[:a] = np.linspace(0, 1, a, endpoint=False) if a > 0 else e[:a]
    d2 = min(d, n - a)
    if d2 > 0:
        e[a:a + d2] = np.linspace(1, s, d2, endpoint=False)
    r = min(r, n)
    if r > 0:
        e[n - r:] *= np.linspace(1, 0, r) ** 1.5
    return e


def lowpass(x, cutoff):
    """einfacher Ein-Pol-Tiefpass (vektorisiert über FFT-Filter wäre schärfer; hier per Rekursion in Blöcken)"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    h = 1.0 / np.sqrt(1.0 + (f / max(cutoff, 1.0)) ** 4)
    return np.fft.irfft(X * h, len(x))


def bandpass(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    h = 1.0 / np.sqrt(1.0 + (f / hi) ** 4) * (1.0 - 1.0 / np.sqrt(1.0 + (f / max(lo, 1.0)) ** 4))
    return np.fft.irfft(X * h, len(x))


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(dur, color="white"):
    n = int(dur * SR)
    w = rng.standard_normal(n)
    if color == "white":
        return w
    X = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1]
    X = X / (np.sqrt(f) if color == "pink" else f) * (30.0 if color == "brown" else 1.0)
    y = np.fft.irfft(X, n)
    return y / (np.abs(y).max() + 1e-9)


def saw(freq, t, harm=10, detune=(0.0,), bright=1.0):
    out = np.zeros_like(t)
    for dt in detune:
        f0 = freq * (1.0 + dt)
        for k in range(1, harm + 1):
            if f0 * k > SR * 0.45:
                break
            out += np.sin(2 * np.pi * f0 * k * t + k * 0.7 + dt * 100) / k * (bright ** (k - 1))
    return out / len(detune)


class Mix:
    def __init__(self, dur):
        self.n = int(dur * SR)
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)
        self.music_L = np.zeros(self.n)
        self.music_R = np.zeros(self.n)

    def add(self, sig, start, gain=1.0, pan=0.0, music=False):
        i = int(start * SR)
        if i >= self.n:
            return
        if i < 0:
            sig = sig[-i:]
            i = 0
        sig = sig[: self.n - i]
        gl = gain * np.cos((pan + 1) * np.pi / 4)
        gr = gain * np.sin((pan + 1) * np.pi / 4)
        if music:
            self.music_L[i:i + len(sig)] += sig * gl
            self.music_R[i:i + len(sig)] += sig * gr
        else:
            self.L[i:i + len(sig)] += sig * gl
            self.R[i:i + len(sig)] += sig * gr


# --------------------------------------------------------------------------------------------- Klänge

def sfx_click(bright=1.0):
    n = noise(0.012) * np.exp(-np.arange(int(0.012 * SR)) / (0.0018 * SR))
    knock = np.sin(2 * np.pi * 1150 * t_axis(0.05)) * np.exp(-t_axis(0.05) / 0.008)
    out = np.zeros(int(0.05 * SR))
    out[: len(n)] += highpass(n, 2500) * 0.7 * bright
    out += knock * 0.5
    return out


def sfx_grind(dur):
    g = bandpass(noise(dur, "brown"), 160, 1400)
    t = t_axis(dur)
    grain = 0.55 + 0.45 * np.abs(np.sin(2 * np.pi * 23 * t + 3 * np.sin(2 * np.pi * 3.1 * t)))
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    rumble = np.sin(2 * np.pi * 70 * t) * 0.25
    return (g / (np.abs(g).max() + 1e-9) * grain + rumble) * e


def sfx_twist(snap):
    dur = snap * 1.35
    out = np.zeros(int((dur + 0.15) * SR))
    c = sfx_click()
    out[: len(c)] += c * 0.9
    gr = sfx_grind(dur)
    out[: len(gr)] += gr * 0.5
    end = sfx_click(0.6) * 1.1
    i = int(dur * 0.92 * SR)
    out[i:i + len(end)] += end[: len(out) - i]
    return out


def sfx_chime(base=84, steps=(0, 4, 7, 12, 16), gap=0.055, dur=1.4):
    out = np.zeros(int((dur + gap * len(steps)) * SR))
    for k, s in enumerate(steps):
        f = note(base + s)
        t = t_axis(dur)
        tone = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.15)
                + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.05))
        tone *= np.exp(-t / (0.35 + 0.05 * k)) * (0.9 ** k)
        i = int(k * gap * SR)
        out[i:i + len(tone)] += tone
    sh = highpass(noise(0.5), 6000) * np.exp(-t_axis(0.5) / 0.12) * 0.12
    out[: len(sh)] += sh
    return out


def sfx_bass_hit(f0=62, dur=0.7):
    t = t_axis(dur)
    f = f0 * (1.0 + 1.2 * np.exp(-t / 0.03))
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.22)
    thump = lowpass(noise(dur), 300) * np.exp(-t / 0.03) * 2.0
    return np.tanh((body + thump) * 1.6)


def sfx_kick(f0=55):
    t = t_axis(0.35)
    f = f0 * (1.0 + 2.2 * np.exp(-t / 0.018))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.tanh(np.sin(ph) * np.exp(-t / 0.12) * 1.8)


def sfx_hat(dur=0.06):
    return highpass(noise(dur), 7000) * np.exp(-t_axis(dur) / 0.012)


def sfx_whoosh(dur=0.35, lo=400, hi=4000, rising=True):
    n = noise(dur, "pink")
    t = t_axis(dur)
    # Sweep: in Blöcken bandpassen
    out = np.zeros_like(n)
    blocks = 12
    for b in range(blocks):
        a, z = b * len(n) // blocks, (b + 1) * len(n) // blocks
        k = b / (blocks - 1)
        c = lo * (hi / lo) ** (k if rising else 1 - k)
        out[a:z] = bandpass(n, c * 0.6, c * 1.6)[a:z]
    e = np.sin(np.pi * t / dur) ** 1.5
    return out / (np.abs(out).max() + 1e-9) * e


def sfx_rain(dur=1.6):
    r = highpass(noise(dur, "pink"), 1500)
    drops = np.zeros(int(dur * SR))
    for _ in range(int(dur * 60)):
        i = rng.integers(0, len(drops) - 400)
        drops[i:i + 400] += np.sin(2 * np.pi * rng.uniform(2500, 5000) * t_axis(400 / SR)) * np.exp(-t_axis(400 / SR) / 0.002) * rng.uniform(0.2, 0.6)
    t = t_axis(dur)
    e = np.clip(t / 0.25, 0, 1) * np.clip((dur - t) / 0.5, 0, 1)
    thunder = lowpass(noise(dur, "brown"), 120) * np.exp(-t / 0.6) * 0.8
    return (r / (np.abs(r).max() + 1e-9) * 0.6 + drops * 0.5) * e + thunder


def sfx_stomp():
    t = t_axis(0.5)
    body = np.sin(2 * np.pi * 42 * t * (1 + 0.5 * np.exp(-t / 0.02))) * np.exp(-t / 0.13)
    dirt = lowpass(noise(0.5), 500) * np.exp(-t / 0.04) * 1.5
    return np.tanh((body + dirt) * 1.4)


def sfx_meteor_fly(dur):
    w = sfx_whoosh(dur, 200, 2600, True)
    t = t_axis(dur)
    roar = lowpass(noise(dur, "brown"), 400) * (t / dur) ** 1.5
    crackle = np.zeros(len(t))
    for _ in range(int(dur * 90)):
        i = rng.integers(0, len(t) - 200)
        crackle[i:i + 200] += rng.standard_normal(200) * np.exp(-np.arange(200) / 30) * (i / len(t)) ** 2
    rise = np.clip(t / dur, 0, 1) ** 1.2
    return (w * 0.8 + roar * 0.9 + highpass(crackle, 2000) * 0.25) * (0.25 + 0.75 * rise)


def sfx_impact():
    dur = 3.2
    t = t_axis(dur)
    f = 30 + 70 * np.exp(-t / 0.25)
    ph = 2 * np.pi * np.cumsum(f) / SR
    boom = np.sin(ph) * np.exp(-t / 0.9)
    burst = lowpass(noise(dur), 2500) * np.exp(-t / 0.12) * 1.6
    rumble = lowpass(noise(dur, "brown"), 110) * np.exp(-t / 1.1) * 1.4
    debris = highpass(noise(dur, "pink"), 1800) * np.exp(-t / 0.5) * 0.2
    return np.tanh((boom * 1.3 + burst + rumble + debris) * 1.3)


def sfx_meow():
    dur = 0.62
    t = t_axis(dur)
    k = t / dur
    f0 = np.interp(k, [0, 0.12, 0.45, 0.75, 1.0], [460, 720, 780, 600, 430]) * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))
    ph = 2 * np.pi * np.cumsum(f0) / SR
    F1 = np.interp(k, [0, 0.2, 0.6, 1.0], [500, 950, 850, 600])
    F2 = np.interp(k, [0, 0.2, 0.6, 1.0], [1300, 1800, 1500, 1050])
    out = np.zeros_like(t)
    for h in range(1, 16):
        fh = f0 * h
        a = (np.exp(-((fh - F1) / 260) ** 2) + 0.7 * np.exp(-((fh - F2) / 380) ** 2)
             + 0.25 * np.exp(-((fh - 3000) / 600) ** 2) + 0.05)
        out += np.sin(ph * h) * a / h ** 0.3
    e = np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.18, 0, 1) ** 1.3
    breath = bandpass(noise(dur), 1500, 6000) * 0.04
    return (out / (np.abs(out).max() + 1e-9) + breath) * e


def sfx_pop():
    t = t_axis(0.12)
    f = 600 + 900 * np.exp(-t / 0.02)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.035)


def sfx_swell(dur, base=60):
    """Rückwärts-Becken + Akkord-Anschwellen (vor dem großen Bild)"""
    t = t_axis(dur)
    cym = highpass(noise(dur, "pink"), 3000) * (t / dur) ** 2.5
    return cym / (np.abs(cym).max() + 1e-9)


# --------------------------------------------------------------------------------------------- Musik

def pad(chord, dur, bright=0.7, att=0.6, rel=0.8, octave_bass=True):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for n in chord:
        out += saw(note(n), t, harm=9, detune=(-0.004, 0.0, 0.005), bright=bright)
    if octave_bass:
        out += 0.8 * saw(note(chord[0] - 12), t, harm=5, detune=(0.0,), bright=0.6)
    out = lowpass(out, 1800 + 2500 * bright)
    return out / (len(chord) + 1) * env_adsr(len(t), att, 0.3, 0.85, rel)


def bass_line(root, dur, beat):
    t = t_axis(dur)
    out = np.zeros_like(t)
    nb = int(round(dur / beat))
    for b in range(nb):
        s = int(b * beat * SR)
        tt = t_axis(beat * 0.9)
        f = note(root - (0 if b % 2 == 0 else -12))
        tone = saw(f, tt, harm=6, bright=0.55) * env_adsr(len(tt), 0.005, 0.1, 0.6, 0.08)
        out[s:s + len(tone)] += tone[: len(out) - s]
    return lowpass(out, 900)


def arp(chord, dur, beat, octave=12):
    t = t_axis(dur)
    out = np.zeros_like(t)
    step = beat / 2
    seq = [chord[0], chord[1], chord[2], chord[1] + 12]
    for i in range(int(dur / step)):
        s = int(i * step * SR)
        tt = t_axis(step * 1.6)
        f = note(seq[i % len(seq)] + octave)
        tone = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)) * np.exp(-tt / 0.18)
        out[s:s + len(tone)] += tone[: len(out) - s]
    return out


def reverb(x, secs=1.8, mix=0.25):
    n = int(secs * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (secs / 6.9 * SR))
    ir = lowpass(ir, 6000)
    ir[: int(0.02 * SR)] = 0
    m = len(x) + n
    nfft = 1 << (m - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[: len(x)]
    y /= np.abs(ir).sum() ** 0.5 * 2.2
    return x * (1 - mix) + y * mix


AM, F, C, G, DM, E = [57, 60, 64], [53, 57, 60], [60, 64, 67], [55, 59, 62], [50, 53, 57], [52, 56, 59]


def build(cues, end, snap, out_path):
    mx = Mix(end + 0.05)
    cs = cues["cues"]
    whips = cues.get("whips", [])

    def times(name):
        return [float(c["t"]) for c in cs if c["c"] == name]

    t_imp = (times("impact") or [None])[0]
    t_met = (times("meteor") or [None])[0]
    t_dawn = (times("dawn") or [None])[0]
    t_hero = (times("hero") or [None])[0]
    t_end = (times("end") or [None])[0]
    beats = times("beat")
    # ---- Musik ----------------------------------------------------------------------------------
    first_beat = beats[0] if beats else 8.8
    # Dröhnen von 0 bis zur Montage (Am, dunkel, öffnet sich mit dem blauen Himmel)
    d = first_beat + 0.3
    t = t_axis(d)
    drone = (saw(note(33), t, harm=8, detune=(-0.003, 0.003), bright=0.5) * 0.9
             + saw(note(40), t, harm=6, detune=(0.0,), bright=0.5) * 0.5
             + saw(note(45), t, harm=6, detune=(0.002,), bright=0.5) * 0.4)
    sw = 0.6 + 0.4 * np.sin(2 * np.pi * t / 5.5 - 1.2)
    drone = lowpass(drone, 700) * sw * env_adsr(len(t), 0.02, 0.1, 1.0, 0.4)
    mx.add(drone * 0.16, 0.0, music=True)
    sky = times("sky")
    t_sky = sky[0] if sky else 6.3
    shimmer = pad([69, 72, 76, 81], first_beat - t_sky + 0.4, bright=0.9, att=1.2, rel=0.5, octave_bass=False)
    mx.add(shimmer * 0.16, t_sky, pan=0.2, music=True)
    mx.add(pad(AM, t_sky - 1.6, bright=0.55, att=1.0, rel=1.0) * 0.17, 1.6, music=True)
    # Montage-Takte: ein Takt je Schnitt, Puls mit Kick, Hi-Hat, Bass, Arpeggio
    prog = [AM, F, C, G, DM, E, F, G, AM]
    bar_starts = [b for b in beats if t_met is None or b < t_met]
    after = [b for b in beats if t_met is not None and b > t_met]
    def play_bars(starts, end_t, prog_list, intensity=1.0):
        for i, b0 in enumerate(starts):
            b1 = starts[i + 1] if i + 1 < len(starts) else end_t
            dur = b1 - b0
            beat = dur / 4.0 if dur < 2.2 else 0.45
            ch = prog_list[i % len(prog_list)]
            mx.add(pad(ch, dur + 0.3, bright=0.75, att=0.05, rel=0.35) * 0.16 * intensity, b0, music=True)
            mx.add(bass_line(ch[0] - 24, dur, beat) * 0.22 * intensity, b0, music=True)
            mx.add(arp(ch, dur, beat) * 0.05 * intensity, b0, pan=-0.25, music=True)
            nb = int(round(dur / beat))
            for k in range(nb):
                mx.add(sfx_kick() * 0.5 * intensity, b0 + k * beat, music=True)
                mx.add(sfx_hat() * 0.12 * intensity, b0 + k * beat + beat / 2, pan=0.3, music=True)
    play_bars(bar_starts, t_met if t_met else end, [AM, F, C, DM, E], 1.0)
    # Meteor: Steigerung ohne Schlagzeug (Ton steigt), dann Stille
    if t_met is not None and t_imp is not None:
        dur = t_imp - t_met
        tt = t_axis(dur)
        f = note(45) * (1 + 0.5 * (tt / dur) ** 2)
        riser = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(4 * np.pi * np.cumsum(f) / SR)
        mx.add(riser * (tt / dur) * 0.12, t_met, music=True)
    # Danach: leise Morgendämmerung, dann Puls zurück (ohne Kick im ersten Takt)
    if t_dawn is not None:
        ends = [b for b in after if b > t_dawn]
        first_after = ends[0] if ends else (t_hero or end)
        mx.add(pad(C, first_after - t_dawn + 0.4, bright=0.45, att=0.8, rel=0.4) * 0.14, t_dawn, music=True)
        play_bars(ends, t_hero if t_hero else end, [F, G, AM], 1.0)
    # Großes Bild: Anschwellen (C -> F -> G) und Schluss in C
    if t_hero is not None:
        mx.add(sfx_swell(0.9) * 0.25, t_hero - 0.9, music=True)
        tail = (t_end or end) - t_hero
        mx.add(pad([48, 60, 64, 67, 72], tail * 0.5 + 0.3, bright=0.9, att=0.05, rel=0.4) * 0.3, t_hero, music=True)
        mx.add(pad([53, 60, 65, 69, 72], tail * 0.5 + 0.3, bright=0.95, att=0.2, rel=0.4) * 0.34, t_hero + tail * 0.5, music=True)
        beat = 0.45
        for k in range(int(tail / beat)):
            mx.add(sfx_kick() * 0.55, t_hero + k * beat, music=True)
            if k % 2 == 1:
                mx.add(sfx_hat(0.12) * 0.16, t_hero + k * beat, pan=0.3, music=True)
        mx.add(arp([60, 64, 67], tail, beat) * 0.06, t_hero, pan=-0.25, music=True)
    if t_end is not None:
        dur = end - t_end + 0.05
        fin = pad([48, 55, 60, 64, 67, 72], dur, bright=0.85, att=0.08, rel=0.25)
        mx.add(fin * 0.42, t_end, music=True)
        mx.add(arp([60, 64, 67], dur, 0.45) * 0.07, t_end, pan=-0.25, music=True)
        mx.add(sfx_chime(84, (0, 7, 12, 16, 19, 24), 0.08, 2.2) * 0.22, t_end + 0.05, music=True)
    # Musik nach dem Einschlag stumm bis zur Dämmerung
    if t_imp is not None:
        a = int(t_imp * SR)
        b = int((t_dawn or t_imp + 1.2) * SR)
        g = np.ones(mx.n)
        g[a:b] = 0.0
        ramp = int(0.03 * SR)
        g[a:a + ramp] = np.linspace(1, 0, ramp)
        mx.music_L *= g
        mx.music_R *= g
    # ---- Klänge ----------------------------------------------------------------------------------
    for c in cs:
        tc, name = float(c["t"]), c["c"]
        if name == "twist":
            mx.add(sfx_twist(snap) * 0.55, tc, pan=0.1)
        elif name == "grow":
            mx.add(sfx_chime(rng.choice([79, 84, 86])) * 0.22, tc + 0.08, pan=rng.uniform(-0.3, 0.3))
        elif name == "beat":
            mx.add(sfx_bass_hit() * 0.6, tc)
        elif name == "title":
            mx.add(sfx_bass_hit(48, 1.2) * 0.35, tc)
        elif name == "reveal":
            mx.add(sfx_chime(72, (0, 4, 7, 12, 16, 19), 0.04, 1.6) * 0.3, tc)
            mx.add(sfx_bass_hit(52, 1.0) * 0.5, tc)
        elif name == "rain":
            mx.add(sfx_rain() * 0.2, tc)
        elif name == "sky":
            if tc < 8.0:
                mx.add(sfx_chime(76, (0, 7, 12, 19, 24), 0.12, 1.8) * 0.16, tc)
        elif name == "meow":
            mx.add(sfx_meow() * 0.4, tc + 0.05, pan=-0.2)
        elif name == "stomp":
            mx.add(sfx_stomp() * 0.7, tc)
        elif name == "meteor" and t_imp is not None:
            mx.add(sfx_meteor_fly(t_imp - tc + 0.05) * 0.55, tc, pan=-0.3)
        elif name == "impact":
            mx.add(sfx_impact() * 1.0, tc)
        elif name == "dawn":
            mx.add(sfx_chime(72, (0, 7, 12), 0.2, 2.0) * 0.12, tc + 0.2)
        elif name == "hero":
            mx.add(sfx_bass_hit(44, 1.4) * 0.6, tc)
            mx.add(sfx_chime(84, (0, 4, 7, 12), 0.05, 1.6) * 0.18, tc)
        elif name == "cta":
            mx.add(sfx_pop() * 0.3, tc)
            mx.add(sfx_pop() * 0.25, tc + 0.4)
    for w in whips:
        mx.add(sfx_whoosh(0.34, 500, 5000) * 0.28, float(w) - 0.17, pan=0.4)
    # ---- Mischen ---------------------------------------------------------------------------------
    musL, musR = reverb(mx.music_L, 1.6, 0.22), reverb(mx.music_R, 1.7, 0.22)
    sL, sR = reverb(mx.L, 1.2, 0.15), reverb(mx.R, 1.25, 0.15)
    L, R = highpass(musL * 0.9 + sL, 35), highpass(musR * 0.9 + sR, 35)
    peak = max(np.abs(L).max(), np.abs(R).max())
    L, R = np.tanh(L / peak * 1.4) / np.tanh(1.4), np.tanh(R / peak * 1.4) / np.tanh(1.4)
    fade = int(0.02 * SR)
    for ch in (L, R):
        ch[:fade] *= np.linspace(0, 1, fade)
        ch[-fade:] *= np.linspace(1, 0, fade)
    st = np.stack([L, R], 1) * 0.9
    with wave.open(out_path, "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes((st * 32767).astype("<i2").tobytes())


def remap(cues, segments):
    """Kurzfassung: nur Ereignisse in den Abschnitten behalten, auf die neue Zeitleiste schieben."""
    out, whips, pos = [], [], 0.0
    for a, b in segments:
        for c in cues["cues"]:
            if a <= float(c["t"]) < b:
                out.append({"t": float(c["t"]) - a + pos, "c": c["c"], "v": c.get("v", 1)})
        for w in cues.get("whips", []):
            if a < float(w) < b:
                whips.append(float(w) - a + pos)
        if pos > 0:
            whips.append(pos)          # jeder Schnitt der Kurzfassung bekommt ein Wisch-Rauschen
            out.append({"t": pos, "c": "cutbeat", "v": 1})
        pos += b - a
    return {"end": pos, "cues": sorted(out, key=lambda c: c["t"]), "whips": whips}


if __name__ == "__main__":
    cues = json.load(open(sys.argv[1]))
    snap = 0.45
    segs = None
    args = sys.argv[3:]
    for i, a in enumerate(args):
        if a == "--snap":
            snap = float(args[i + 1])
        if a == "--segments":
            segs = [tuple(float(x) for x in s.split("-")) for s in args[i + 1].split(",")]
    if segs:
        cues = remap(cues, segs)
        for c in cues["cues"]:
            if c["c"] == "cutbeat":
                c["c"] = "beat"
    build(cues, float(cues["end"]), snap, sys.argv[2])
    print("ok", sys.argv[2], cues["end"])
