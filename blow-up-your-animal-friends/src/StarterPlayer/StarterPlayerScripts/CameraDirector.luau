--!strict
-- CameraDirector (STUB — Element "Kamera-Regie" fuellt diese Datei).
--
-- VERTRAG:
--   init(remotes): setzt Camera.CameraType = Scriptable und uebernimmt die Regie.
--   Standard: weiches Follow des aktiven Wurms (Deadzone, Lookahead).
--   Schuss: Projektilverfolgung (ProjectileFired) mit Vorhalt und Zoom-Out.
--   Einschlag: kurzes Framing + Verweilen (CameraCue vom Server).
--   Rundenwechsel: weiche Fahrt zum naechsten Wurm (MatchEvent), nie Schnitte.
--   Zielphase: freies Umsehen (Randscrollen/mittlere Maustaste), Ruecksprung bei Aktion.
--   Kamera bleibt IMMER vor den Waenden (z deutlich negativ), Blick +Z.
--   Alle Zahlen in Config/Camera.
--
-- SOLANGE STUB: Standardkamera von Roblox bleibt aktiv (init tut nichts).

local CameraDirector = {}

function CameraDirector.init(_remotes: { [string]: RemoteEvent })
	-- Stub: bewusst leer.
end

return CameraDirector
