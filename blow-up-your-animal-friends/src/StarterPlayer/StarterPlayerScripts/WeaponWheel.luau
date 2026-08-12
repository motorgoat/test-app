--!strict
-- WeaponWheel (STUB — Element "UI und HUD" fuellt diese Datei).
--
-- VERTRAG:
--   init(remotes): Waffenraster (Taste Q oder Button, Touch-tauglich) aus
--   Shared/WeaponDefs mit Munitionsanzeige; gewaehlte Waffe gross am unteren
--   Rand; Auswahl sendet Remotes.WeaponSelect(weaponId) — der Server bleibt
--   Autoritaet ueber Gueltigkeit und Munition. Alle Layoutwerte in Config/UI.

local WeaponWheel = {}

function WeaponWheel.init(_remotes: { [string]: RemoteEvent })
	-- Stub: bewusst leer.
end

return WeaponWheel
