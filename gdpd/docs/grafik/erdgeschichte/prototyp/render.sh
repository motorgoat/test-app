#!/bin/bash
# usage: render.sh mode out.png [zoom] [frames] [extra args...]
S=/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad
P=$S/erd_art/proj
G=$S/godot/Godot_v4.3-stable_linux.x86_64
M=$1; O=$2; Z=${3:-1.0}; F=${4:-120}; shift 4
cd $P && XDG_DATA_HOME=$S/erd_art/xdg timeout 400 xvfb-run -a -s "-screen 0 1100x2400x24" $G --rendering-driver opengl3 --resolution ${RES:-1080x2340} --position 0,0 res://lookdev/erd.tscn -- --mode=$M --out=$O --zoom=$Z --frames=$F "$@" 2>&1 | grep -E "ERROR|SCRIPT|LOOKDEV|Shader|error|Parse|at:" | grep -v "ALSA\|status < 0" | head -30
