#!/bin/bash
# usage: render_v2.sh <out dir> <WxH> <fps> [cues.json]
# Rendert die Trailer-Szene als verlustfreie PNG-Folge (Movie Maker, deterministisch).
S=/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad
P=$S/trailer_proj/gdpd
G=$S/godot/Godot_v4.3-stable_linux.x86_64
mkdir -p "$1"; rm -f "$1"/f*.png
EXTRA=""
[ -n "$4" ] && EXTRA="-- --cues=$4"
cd $P && XDG_DATA_HOME=$S/trailer_proj/xdg timeout ${TMO:-4000} xvfb-run -a -s "-screen 0 1100x2400x24" $G --rendering-driver opengl3 --resolution $2 --position 0,0 --write-movie "$1/f.png" --fixed-fps $3 res://trailer/trailer.tscn $EXTRA 2>&1 | grep -v "ALSA\|status < 0\|^$" | grep -v "is_inside_tree\|get_global_transform\|node_3d.cpp" | tail -${LINES_OUT:-40}
