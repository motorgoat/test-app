#!/bin/bash
# usage: render.sh mode out.png [zoom] [frames]
S=/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad
P=$S/schoepfung_art/proj
G=$S/godot/Godot_v4.3-stable_linux.x86_64
mkdir -p $S/schoepfung_art/xdg
cd $P && XDG_DATA_HOME=$S/schoepfung_art/xdg timeout 300 xvfb-run -a -s "-screen 0 1100x2400x24" $G --rendering-driver opengl3 --resolution 1080x2340 --position 0,0 res://lookdev/era.tscn -- --mode=$1 --out=$2 --zoom=${3:-1.0} --frames=${4:-120} 2>&1 | grep -E "ERROR|SCRIPT|LOOKDEV|Shader|error|Parse" | grep -v "ALSA\|status < 0" | head -30
