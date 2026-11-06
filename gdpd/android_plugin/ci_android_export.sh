#!/usr/bin/env bash
# CI: Android APK with Gradle and the reminder plugin (docs/GDPD_TAEGLICH_CHARAKTER.md 6.6). Run from gdpd/.
# Exit code != 0 → the workflow falls back to the plain APK without the plugin.
#
#   bash android_plugin/ci_android_export.sh [apk_path]
#
# Env: GODOT (default godot), ANDROID_HOME (default /usr/lib/android-sdk), TEMPLATES (Godot export templates 4.3).
#
# Steps: SDK platform/build-tools of the 4.3 template (34 / 34.0.0), build template + plugin AAR
# (prepare_gradle_export.sh), enable the editor plugin only for this export (project.godot is restored afterwards:
# Godot 4.3 headless crashes on `--editor --quit` while files still need importing and an editor plugin is enabled,
# so the plugin is not enabled in the repository), export, then check that the APK really contains the plugin.
set -euo pipefail

GODOT="${GODOT:-godot}"
SDK="${ANDROID_HOME:-/usr/lib/android-sdk}"
TEMPLATES="${TEMPLATES:-$HOME/.local/share/godot/export_templates/4.3.stable}"
APK="${1:-build/gdpd.apk}"
PLUGIN_CFG="res://addons/gdpd_reminder/plugin.cfg"
NDK="ndk;23.2.8568313"
LOG="$(dirname "$APK")/android_export.log"

test -f project.godot || { echo "bitte aus gdpd/ starten"; exit 1; }
mkdir -p "$(dirname "$APK")"

SDKM="$(command -v sdkmanager || true)"
if [ -z "$SDKM" ]; then
	SDKM="$(ls "$SDK"/cmdline-tools/*/bin/sdkmanager "$SDK"/cmdline-tools/bin/sdkmanager 2>/dev/null | head -1 || true)"
fi
echo "== Android-SDK: $SDK (sdkmanager: ${SDKM:-fehlt})"
ls "$SDK" "$SDK/platforms" "$SDK/build-tools" 2>/dev/null || true
if [ -n "$SDKM" ]; then
	yes | "$SDKM" --sdk_root="$SDK" --licenses > /dev/null 2>&1 || true
	"$SDKM" --sdk_root="$SDK" "platforms;android-34" "build-tools;34.0.0" | tail -3
else
	echo "::warning::sdkmanager nicht gefunden – baue mit den vorhandenen SDK-Paketen"
fi

bash android_plugin/prepare_gradle_export.sh "$TEMPLATES" "$SDK"

cp project.godot project.godot.ci-backup
restore() { mv -f project.godot.ci-backup project.godot 2>/dev/null || true; }
trap restore EXIT
if ! grep -q "^\[editor_plugins\]" project.godot; then
	printf '\n[editor_plugins]\n\nenabled=PackedStringArray("%s")\n' "$PLUGIN_CFG" >> project.godot
fi
grep -A2 "^\[editor_plugins\]" project.godot
# Import anything still new with `--import` (waits for the import; safe with the plugin on, unlike `--editor --quit`)
timeout 600 "$GODOT" --headless --import 2>&1 | tail -5 || true

export_apk() {
	rm -f "$APK"
	echo "== Gradle-Export ($1)"
	# Gradle downloads the Gradle distribution and Maven artefacts on a cold cache (+3–6 min)
	set +e
	timeout 1500 "$GODOT" --headless --verbose --export-debug "Android" "$APK" > "$LOG" 2>&1
	local rc=$?
	set -e
	grep -nE "GdpdReminder|plugins_local_binaries|BUILD SUCCESSFUL|BUILD FAILED|FAILURE|What went wrong|ERROR" "$LOG" | head -60 || true
	tail -60 "$LOG"
	echo "Godot-Export beendet mit Code $rc"
	test -s "$APK"
}

if ! export_apk "1. Versuch"; then
	if grep -qiE "NDK (is )?not (configured|installed|found)|No version of NDK|NDK at |CXX1101" "$LOG" && [ -n "$SDKM" ]; then
		echo "== NDK fehlt offenbar: installiere $NDK und versuche es noch einmal"
		"$SDKM" --sdk_root="$SDK" "$NDK" | tail -3
		export_apk "2. Versuch mit NDK"
	else
		echo "Gradle-Export fehlgeschlagen"
		exit 1
	fi
fi

echo "== APK prüfen: $APK"
ls -la "$APK"
unzip -l "$APK" | grep -E "classes[0-9]*\.dex|AndroidManifest.xml|res/drawable.*/ic_gdpd_notify" || true
if ! unzip -p "$APK" 'classes*.dex' | grep -a -q "Lat/identit/gdpd/reminder/GdpdReminder;"; then
	echo "Die Klasse GdpdReminder fehlt im APK"
	exit 1
fi
# The binary manifest stores strings as UTF-16: drop the zero bytes, then search
if ! unzip -p "$APK" AndroidManifest.xml | tr -d '\000' | grep -a -q "org.godotengine.plugin.v2.GdpdReminder"; then
	echo "Der Plugin-Eintrag fehlt im Manifest"
	exit 1
fi
unzip -p "$APK" AndroidManifest.xml | tr -d '\000' | grep -a -o "android.permission.[A-Z_]*" | sort -u || true
echo "OK: APK mit Erinnerungs-Plugin GdpdReminder"
