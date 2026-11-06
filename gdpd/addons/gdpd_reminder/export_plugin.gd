@tool
extends EditorPlugin
## Hängt beim Android-Export (nur mit „Gradle-Build verwenden“) die Erinnerungs-Bibliothek „GdpdReminder“ an
## (docs/GDPD_TAEGLICH_CHARAKTER.md 6.2–6.4). Die AARs baut android_plugin/build_aar.sh nach bin/debug und bin/release
## (in CI; git-ignoriert). Fehlen sie, wird ohne Plugin exportiert – das Spiel plant dann nur Protokoll-Zeilen.
## PC-Exporte sind nicht betroffen.

var _export: GdpdReminderExport


func _enter_tree() -> void:
	_export = GdpdReminderExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class GdpdReminderExport extends EditorExportPlugin:
	const PLUGIN_NAME := "GdpdReminder"

	func _get_name() -> String:
		return PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## Pfad relativ zu res://addons/ (so löst Godot 4.3 ihn auf).
	static func aar_path(debug: bool) -> String:
		var kind := "debug" if debug else "release"
		return "gdpd_reminder/bin/%s/gdpd_reminder-%s.aar" % [kind, kind]

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var rel := aar_path(debug)
		if not FileAccess.file_exists("res://addons/" + rel):
			push_warning("GdpdReminder: %s fehlt (android_plugin/build_aar.sh) – Export ohne Erinnerungen" % rel)
			return PackedStringArray()
		print("GdpdReminder: Android-Bibliothek res://addons/" + rel)
		return PackedStringArray([rel])
