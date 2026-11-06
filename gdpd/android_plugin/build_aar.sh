#!/usr/bin/env bash
# Builds the gdpd reminder plugin (Android v2 plugin "GdpdReminder", docs/GDPD_TAEGLICH_CHARAKTER.md 6) as an AAR,
# without Android Gradle Plugin: javac + jar. Gradle of the app (Godot's build template) dexes it and merges the
# manifest and resources. Needs only a JDK (8+), an android.jar (any platform >= 26) and Godot's godot-lib 4.3.
#
#   android_plugin/build_aar.sh <android.jar> <godot-lib.aar|classes.jar> [out_dir]
#
# out_dir defaults to ../addons/gdpd_reminder/bin; writes debug/gdpd_reminder-debug.aar and
# release/gdpd_reminder-release.aar (same content – the plugin has no debug-only code).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_JAR="${1:?android.jar fehlt}"
GODOT_LIB="${2:?godot-lib (aar oder classes.jar) fehlt}"
OUT="${3:-$HERE/../addons/gdpd_reminder/bin}"

test -s "$ANDROID_JAR" || { echo "android.jar nicht gefunden: $ANDROID_JAR"; exit 1; }
test -s "$GODOT_LIB" || { echo "godot-lib nicht gefunden: $GODOT_LIB"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

case "$GODOT_LIB" in
	*.aar)
		unzip -q -o "$GODOT_LIB" classes.jar -d "$WORK/godot"
		GODOT_CLASSES="$WORK/godot/classes.jar" ;;
	*)
		GODOT_CLASSES="$GODOT_LIB" ;;
esac

mkdir -p "$WORK/classes" "$WORK/aar/res"
find "$HERE/src" -name '*.java' | sort > "$WORK/sources.txt"
echo "javac: $(wc -l < "$WORK/sources.txt") Dateien gegen $ANDROID_JAR"
# Java 8 bytecode: every D8 version reads it. android.jar on the classpath (not the boot classpath), so this works
# with any JDK from 9 on; the JDK's own java.* classes win over android.jar's copies.
javac --release 8 -encoding UTF-8 -Xlint:all,-options,-classfile,-deprecation \
	-classpath "$ANDROID_JAR:$GODOT_CLASSES" -d "$WORK/classes" @"$WORK/sources.txt"

(cd "$WORK/classes" && jar cfM "$WORK/aar/classes.jar" .)
cp "$HERE/AndroidManifest.xml" "$WORK/aar/AndroidManifest.xml"
cp -r "$HERE/res/." "$WORK/aar/res/"
# R.txt lists the library's resources (the code looks them up by name, so the ids here are placeholders)
: > "$WORK/aar/R.txt"
for f in "$HERE"/res/drawable/*.xml; do
	echo "int drawable $(basename "$f" .xml) 0x7f080001" >> "$WORK/aar/R.txt"
done
mkdir -p "$WORK/aar/META-INF/com/android/build/gradle"
printf 'aarFormatVersion=1.0\naarMetadataVersion=1.0\nminCompileSdk=1\n' \
	> "$WORK/aar/META-INF/com/android/build/gradle/aar-metadata.properties"

mkdir -p "$OUT/debug" "$OUT/release"
(cd "$WORK/aar" && jar cfM "$OUT/debug/gdpd_reminder-debug.aar" .)
cp "$OUT/debug/gdpd_reminder-debug.aar" "$OUT/release/gdpd_reminder-release.aar"
echo "AAR gebaut:"
ls -la "$OUT/debug" "$OUT/release"
unzip -l "$OUT/debug/gdpd_reminder-debug.aar"
