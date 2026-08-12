--!strict
-- HudController (STUB — Element "UI und HUD" fuellt diese Datei).
--
-- VERTRAG:
--   init(remotes): baut das HUD (ScreenGui zur Laufzeit, ResetOnSpawn=false,
--   IgnoreGuiInset): Rundentimer (Farbwechsel bei knapper Zeit), Windanzeige
--   (Pfeilbalken), Team-Leisten mit Summen-HP, Ereignis-Banner, Steuerungs-
--   hinweis-Zeile (uebernimmt den BootHud-Dauerhinweis). Gespeist aus
--   MatchEvent/DamageEvent. Alle Layoutwerte in Config/UI.

local HudController = {}

function HudController.init(_remotes: { [string]: RemoteEvent })
	-- Stub: bewusst leer.
end

return HudController
