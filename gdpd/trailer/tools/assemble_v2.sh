#!/bin/bash
# Baut aus den gerenderten PNG-Folgen und den Zeitmarken die fertigen MP4s (Tonspur, Lautheit, Kurzfassung).
# usage: assemble_v2.sh [portrait|square|cut15|all]
set -e
S=/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad
T=$S/trailer
P=$S/trailer_proj/gdpd
MA=$P/trailer/tools/make_audio.py
what=${1:-all}

norm() {  # norm <in.wav> <out.wav>: zwei Durchgänge loudnorm auf -14 LUFS, -1 dBTP
  local j
  j=$(ffmpeg -hide_banner -nostats -i "$1" -af loudnorm=I=-14:TP=-2.0:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
  local mi mtp mlra mth off
  mi=$(echo "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["input_i"])')
  mtp=$(echo "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["input_tp"])')
  mlra=$(echo "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["input_lra"])')
  mth=$(echo "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["input_thresh"])')
  off=$(echo "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["target_offset"])')
  ffmpeg -hide_banner -nostats -loglevel error -y -i "$1" -af "loudnorm=I=-14:TP=-2.0:LRA=11:measured_I=$mi:measured_TP=$mtp:measured_LRA=$mlra:measured_thresh=$mth:offset=$off:linear=true,aresample=48000" -c:a pcm_s16le "$2"
}

enc() {  # enc <frames dir or concat list> <wav> <out.mp4>
  ffmpeg -hide_banner -nostats -loglevel error -y -framerate 30 -i "$1/f%08d.png" -i "$2" \
    -map 0:v -map 1:a -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p -profile:v high -level 4.2 \
    -r 30 -c:a aac -b:a 192k -ar 48000 -shortest -movflags +faststart "$3"
}

if [ "$what" = portrait ] || [ "$what" = all ]; then
  python3 -I $MA $T/cues_v2.json $T/v2_mix_raw.wav
  norm $T/v2_mix_raw.wav $T/v2_mix.wav
  enc $T/raw_v2 $T/v2_mix.wav $T/gdpd_trailer_v2.mp4
fi
if [ "$what" = square ] || [ "$what" = all ]; then
  python3 -I $MA $T/cues_v2_square.json $T/v2sq_mix_raw.wav
  norm $T/v2sq_mix_raw.wav $T/v2sq_mix.wav
  enc ${SQDIR:-$T/raw_v2_square} $T/v2sq_mix.wav $T/gdpd_trailer_v2_square.mp4
fi
if [ "$what" = cut15 ] || [ "$what" = all ]; then
  # Kurzfassung 15 s: Haken -> 4 Montage-Schnitte -> Meteor -> fertige Welt -> Abspann
  SEG=${SEG:-"0-1.8,8.82-10.22,10.66-12.06,12.49-13.89,14.32-15.72,16.82-18.82,26.16-28.06,29.66-33.36"}
  rm -rf $T/cut15_frames; mkdir -p $T/cut15_frames
  python3 - "$SEG" $T/raw_v2 $T/cut15_frames <<'PY'
import os, sys
segs = [tuple(float(x) for x in s.split("-")) for s in sys.argv[1].split(",")]
src, dst = sys.argv[2], sys.argv[3]
k = 0
for a, b in segs:
    for i in range(int(round(a * 30)), int(round(b * 30))):
        os.symlink(os.path.join(src, "f%08d.png" % i), os.path.join(dst, "f%08d.png" % k))
        k += 1
print("frames", k, k / 30.0)
PY
  python3 -I $MA $T/cues_v2.json $T/cut15_mix_raw.wav --segments "$SEG"
  norm $T/cut15_mix_raw.wav $T/cut15_mix.wav
  enc $T/cut15_frames $T/cut15_mix.wav $T/gdpd_trailer_v2_15s.mp4
fi
echo done
