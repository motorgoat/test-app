class_name Notifier
extends Node
## Dünne Hülle um das Android-Plugin „GdpdReminder“ (docs/GDPD_TAEGLICH_CHARAKTER.md 6.3, 6.7): Erinnerungen als
## Handy-Benachrichtigung. WANN und WELCHER Text entscheidet ReminderPlan/Game – hier wird nur eingeplant.
## Ohne Plugin (PC, Editor, CI, ein APK ohne Gradle-Build) schreibt jeder Aufruf nur eine Zeile ins Protokoll
## („REMINDER …“), sonst passiert nichts.
##
## Benutzung (UI/Game):
##   var n := Notifier.attach(Game)   # einmal; hängt sich an Game, plant jeden Game.reminders_planned(plan) ein,
##                                    # setzt Game.remind_permission, mark_done nach jedem Serientag
##   n.request_permission()           # nach „Ja, gern“ (Android 13+: Systemdialog; Antwort → permission_changed)
##   n.notifications_enabled()        # Menü: „Benachrichtigungen sind am Handy ausgeschaltet.“ wenn false
##   n.open_settings()                # Knopf „Einstellungen öffnen“
##   Notifier.is_supported()          # false → Menü: „Erinnerungen gibt es nur auf dem Handy.“
## Direkt (ohne Game): schedule(at_unix, title, body, id), cancel(id), cancel_all(), mark_done(day_key).
## Zeiten sind immer Ortszeit als „lokale Unix-Sekunden“ (Datum/Uhrzeit der Wanduhr, als wäre es UTC – wie
## Game.now_local ohne die Test-Tage); das Plugin rechnet sie mit der Zeitzone des Handys um (Sommerzeit, Reisen).

## Die Erlaubnis hat sich geändert (Antwort auf den Systemdialog, oder in den Android-Einstellungen umgeschaltet).
signal permission_changed(granted: bool)

const SINGLETON := "GdpdReminder"
const PERMISSION := "android.permission.POST_NOTIFICATIONS"
## Großes Symbol je Stufe der Leiter (5.6): das Gesicht des Charakters, 256 × 256, von der Charakter-Ansicht gerendert.
const ICON_DIR := "user://erinnerung/"
const ICONS = {"A": "gesicht_happy.png", "B": "gesicht_worried.png", "C": "gesicht_smile.png", "F": "gesicht_sleepy.png"}

var log_enabled := true          # ohne Plugin: Zeilen „REMINDER …“ ausgeben
var log_lines: Array = []        # die letzten Protokoll-Zeilen (Tests)
var _plugin: Object = null
var _game: Node = null
var _permission := false


func _init() -> void:
	if Engine.has_singleton(SINGLETON):
		_plugin = Engine.get_singleton(SINGLETON)
	_permission = notifications_enabled()


func _ready() -> void:
	if _plugin != null and not get_tree().on_request_permissions_result.is_connected(_on_permission_result):
		get_tree().on_request_permissions_result.connect(_on_permission_result)


## Gibt es das Plugin (nur im Android-APK mit Gradle-Build)?
static func is_supported() -> bool:
	return Engine.has_singleton(SINGLETON)


## Eine Hülle anlegen und an Game hängen (als Kind, damit sie Rückkehr/Pause mitbekommt). Mehrfach aufrufen ist
## harmlos: es gibt dann die schon vorhandene zurück.
static func attach(game: Node) -> Notifier:
	var old := game.get_node_or_null("Notifier")
	if old is Notifier:
		return old as Notifier
	var n := Notifier.new()
	n.name = "Notifier"
	n._game = game
	if game.has_signal("reminders_planned"):
		game.connect("reminders_planned", n.schedule_plan)
	if game.has_signal("streak_changed"):
		game.connect("streak_changed", n._on_streak_changed)
	game.add_child.call_deferred(n)
	n._push_permission()
	if n._plugin != null and game.has_method("replan_reminders"):
		game.call_deferred("replan_reminders")    # der Plan vom Start ging noch an niemanden
	return n


# --- Einplanen -------------------------------------------------------------------------------------------------

## Eine Erinnerung zur Ortszeit at_unix (lokale Unix-Sekunden). id: 101 … 107 (ReminderPlan); icon_path: globaler
## Pfad eines PNG oder ""; day_key: der Spieltag (für mark_done; -1 = aus at_unix). true, wenn das Handy sie eingeplant
## hat (false: ohne Plugin, oder die Zeit ist schon vorbei).
func schedule(at_unix: int, title: String, body: String, id: int, icon_path: String = "", day_key: int = -1) -> bool:
	var f: Dictionary = Time.get_datetime_dict_from_unix_time(at_unix)
	var key := day_key if day_key >= 0 else Daily.day_key(at_unix)
	if _plugin == null:
		_log("REMINDER plan id=%d at=%04d-%02d-%02d %02d:%02d key=%d title=%s text=%s" % [id, int(f["year"]),
			int(f["month"]), int(f["day"]), int(f["hour"]), int(f["minute"]), key, title, body])
		return false
	return _schedule_fields(id, int(f["year"]), int(f["month"]), int(f["day"]), int(f["hour"]), int(f["minute"]),
		title, body, icon_path, key)


## Einen Eintrag von ReminderPlan.plan / Game.replan_reminders einplanen (nimmt die echte Uhrzeit „at_real“ und die
## Kalender-Felder des Eintrags, das Gesicht passend zur Stufe).
func schedule_entry(e: Dictionary) -> bool:
	var at := int(e.get("at_real", e.get("at", 0)))
	var f: Dictionary = Time.get_datetime_dict_from_unix_time(at)
	for k in ["year", "month", "day", "hour", "minute"]:
		if e.has(k):
			f[k] = int(e[k])
	var key := int(e.get("key", Daily.day_key(at)))
	var title := str(e.get("title", ""))
	var body := str(e.get("body", ""))
	if _plugin == null:
		if e.has("cat") and e.has("tpl"):
			_log(ReminderPlan.log_line(e))
		else:
			_log("REMINDER plan id=%d at=%04d-%02d-%02d %02d:%02d key=%d title=%s text=%s" % [int(e.get("id", 0)),
				int(f["year"]), int(f["month"]), int(f["day"]), int(f["hour"]), int(f["minute"]), key, title, body])
		return false
	return _schedule_fields(int(e.get("id", 0)), int(f["year"]), int(f["month"]), int(f["day"]), int(f["hour"]),
		int(f["minute"]), title, body, icon_for(str(e.get("cat", ""))), key)


## Den ganzen Plan einplanen: erst alles löschen, dann jeden Eintrag. Gibt zurück, wie viele das Handy angenommen hat.
func schedule_plan(plan: Array) -> int:
	cancel_all()
	var n := 0
	for e in plan:
		if e is Dictionary and schedule_entry(e as Dictionary):
			n += 1
	return n


func cancel(id: int) -> void:
	if _plugin == null:
		_log("REMINDER cancel id=%d" % id)
		return
	_plugin.call("cancel", id)


func cancel_all() -> void:
	if _plugin == null:
		_log("REMINDER cancel_all")
		return
	_plugin.call("cancel_all")


## Der Spieltag ist geschafft: eine Erinnerung für ihn (oder früher) fällt aus, auch wenn die App vorher beendet wurde.
func mark_done(day_key: int) -> void:
	if _plugin == null:
		_log("REMINDER mark_done key=%d" % day_key)
		return
	_plugin.call("mark_done", day_key)


# --- Erlaubnis und Einstellungen -------------------------------------------------------------------------------

## Um Erlaubnis fragen (Android 13+ zeigt den Systemdialog; darunter gibt es sie schon). true = schon erlaubt; sonst
## kommt die Antwort später als permission_changed. Ohne Plugin: false.
func request_permission() -> bool:
	if _plugin == null:
		_log("REMINDER request_permission (kein Plugin)")
		return false
	var ok := bool(_plugin.call("request_permission"))
	if ok:
		_refresh_permission()
	return ok


## POST_NOTIFICATIONS erteilt (unter Android 13 immer)?
func has_permission() -> bool:
	if _plugin == null:
		return false
	return bool(_plugin.call("has_permission"))


## Erlaubnis da und Benachrichtigungen für gdpd in Android eingeschaltet? Ohne Plugin: false.
func notifications_enabled() -> bool:
	if _plugin == null:
		return false
	return bool(_plugin.call("notifications_enabled"))


## Öffnet die Benachrichtigungs-Einstellungen von gdpd in Android.
func open_settings() -> void:
	if _plugin == null:
		_log("REMINDER open_settings (kein Plugin)")
		return
	_plugin.call("open_settings")


## Wurde die App über eine Erinnerung geöffnet? Ihre id (101 …), sonst -1 (nur einmal, danach -1).
func launch_notification_id() -> int:
	if _plugin == null:
		return -1
	return int(_plugin.call("launch_notification_id"))


## Globaler Pfad des Gesichts für die Stufe ("A", "B", "C", "F"), "" wenn es (noch) nicht gerendert ist.
static func icon_for(cat: String) -> String:
	if not ICONS.has(cat):
		return ""
	var p := ICON_DIR + str(ICONS[cat])
	if not FileAccess.file_exists(p):
		return ""
	return ProjectSettings.globalize_path(p)


# --- intern ----------------------------------------------------------------------------------------------------

func _schedule_fields(id: int, year: int, month: int, day: int, hour: int, minute: int, title: String, body: String,
		icon_path: String, key: int) -> bool:
	return bool(_plugin.call("schedule", id, year, month, day, hour, minute, title, body, icon_path, key))


func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 32:
		log_lines.pop_front()
	if not log_enabled:
		return
	if _game != null and "reminder_echo" in _game and not bool(_game.get("reminder_echo")):
		return
	print(line)


func _push_permission() -> void:
	if _game != null and "remind_permission" in _game:
		_game.set("remind_permission", _permission)


## Erlaubnis neu lesen; hat sie sich geändert, Game Bescheid geben und neu planen lassen.
func _refresh_permission() -> void:
	var now := notifications_enabled()
	if now == _permission:
		_push_permission()
		return
	_permission = now
	_push_permission()
	permission_changed.emit(now)
	if _game != null and _game.has_method("replan_reminders"):
		_game.call("replan_reminders")


func _on_permission_result(permission: String, _granted: bool) -> void:
	if permission == PERMISSION:
		_refresh_permission()


func _on_streak_changed(info: Dictionary) -> void:
	if not bool(info.get("counted", true)):
		return
	if _game != null and _game.has_method("today_key"):
		mark_done(int(_game.call("today_key")))


func _notification(what: int) -> void:
	# Game plant bei der Rückkehr selbst neu; hier nur prüfen, ob in Android etwas umgeschaltet wurde.
	if what == NOTIFICATION_APPLICATION_RESUMED and _plugin != null:
		_refresh_permission()
