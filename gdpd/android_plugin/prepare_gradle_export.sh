#!/usr/bin/env bash
# Prepares the gdpd project for a Gradle Android export (docs/GDPD_TAEGLICH_CHARAKTER.md 6.5/6.6):
#  1. installs the Android build template into res://android (what Godot's „Projekt → Android-Build-Vorlage
#     installieren…“ does in 4.3: android/build = android_source.zip, android/.build_version, android/build/.gdignore),
#  2. builds the reminder plugin AAR (android_plugin/build_aar.sh) into addons/gdpd_reminder/bin/.
#
#   android_plugin/prepare_gradle_export.sh [templates_dir] [android_sdk]
#
# templates_dir: Godot's export templates of this version (default ~/.local/share/godot/export_templates/4.3.stable)
# android_sdk:   the SDK (default $ANDROID_HOME or /usr/lib/android-sdk); android.jar = highest platforms/android-N.
# ANDROID_JAR=... overrides the android.jar (any platform >= 26 works for compiling the plugin).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
GODOT_VERSION="4.3.stable"
TEMPLATES="${1:-$HOME/.local/share/godot/export_templates/$GODOT_VERSION}"
SDK="${2:-${ANDROID_HOME:-/usr/lib/android-sdk}}"
SOURCE_ZIP="$TEMPLATES/android_source.zip"

test -s "$SOURCE_ZIP" || { echo "Android-Quellvorlage fehlt: $SOURCE_ZIP"; exit 1; }

echo "== Android-Bauvorlage nach $PROJECT/android"
rm -rf "$PROJECT/android"
mkdir -p "$PROJECT/android/build"
unzip -q "$SOURCE_ZIP" -d "$PROJECT/android/build"
echo "$GODOT_VERSION" > "$PROJECT/android/.build_version"
touch "$PROJECT/android/build/.gdignore"
chmod +x "$PROJECT/android/build/gradlew"
grep -E "androidGradlePlugin|compileSdk|buildTools|ndkVersion" "$PROJECT/android/build/config.gradle" || true
grep distributionUrl "$PROJECT/android/build/gradle/wrapper/gradle-wrapper.properties" || true

if [ -z "${ANDROID_JAR:-}" ]; then
	ANDROID_JAR=""
	best=0
	for j in "$SDK"/platforms/android-*/android.jar; do
		n="$(basename "$(dirname "$j")")"
		n="${n#android-}"
		if [[ "$n" =~ ^[0-9]+$ ]] && [ -s "$j" ] && [ "$n" -gt "$best" ]; then
			best="$n"
			ANDROID_JAR="$j"
		fi
	done
fi
test -n "$ANDROID_JAR" && test -s "$ANDROID_JAR" || { echo "kein android.jar unter $SDK/platforms"; exit 1; }

GODOT_LIB="$PROJECT/android/build/libs/release/godot-lib.template_release.aar"
test -s "$GODOT_LIB" || { echo "godot-lib fehlt in der Vorlage: $GODOT_LIB"; exit 1; }

echo "== Erinnerungs-Plugin (android.jar: $ANDROID_JAR)"
bash "$HERE/build_aar.sh" "$ANDROID_JAR" "$GODOT_LIB" "$PROJECT/addons/gdpd_reminder/bin"
