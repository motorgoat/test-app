--!strict
-- QuipSystem (STUB — Element "Sound und Sprueche" fuellt diese Datei).
--
-- VERTRAG:
--   init(remotes): hoert auf QuipEvent(situation, wurmName), waehlt aus
--   Shared/QuipDefs eine Variante (nicht zweimal dieselbe hintereinander)
--   und rendert eine Sprechblase (BillboardGui ueber dem Kopf, Tween-Pop,
--   kurze Standzeit) plus tonalen Blip (Pitch nach Stimmung).
--   Alle Zahlen in Config/Sound.

local QuipSystem = {}

function QuipSystem.init(_remotes: { [string]: RemoteEvent })
	-- Stub: bewusst leer.
end

return QuipSystem
