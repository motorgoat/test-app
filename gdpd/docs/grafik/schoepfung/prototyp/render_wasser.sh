#!/bin/bash
# Wasser dreht mit (Prototyp): Projekt-Kopie mit wasser_mitdrehen.diff, Szene lookdev/wasser.tscn.
# usage: render_wasser.sh heute|neu out_dir   (für Standbilder TIME im Wasser-Teil von ground.gdshader einfrieren)
S=/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad
P=$S/schoepfung_art/wasser/proj
G=$S/godot/Godot_v4.3-stable_linux.x86_64
cd $P && XDG_DATA_HOME=$S/schoepfung_art/wasser/xdg timeout 300 xvfb-run -a -s "-screen 0 1100x2400x24" $G --rendering-driver opengl3 --resolution 1080x2340 --position 0,0 res://lookdev/wasser.tscn -- --mode=$1 --out=$2 2>&1 | grep -E "ERROR|SCRIPT|LOOKDEV|Shader" | grep -v "ALSA"
