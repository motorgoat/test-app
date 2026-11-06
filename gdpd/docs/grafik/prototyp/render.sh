#!/bin/bash
# usage: render.sh mode out [zoom] [frames]
P=/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/lookdev/proj
G=/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/godot/Godot_v4.3-stable_linux.x86_64
cd $P && timeout 600 xvfb-run -a -s "-screen 0 1100x2400x24" $G --rendering-driver opengl3 --resolution 1080x2340 --position 0,0 --script res://lookdev/lookdev.gd -- --mode=$1 --out=$2 --zoom=${3:-1.0} --frames=${4:-100} 2>&1 | grep -E "ERROR|SCRIPT|LOOKDEV|Shader|error" | grep -v "ALSA\|status < 0"
