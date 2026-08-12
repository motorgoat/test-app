--!strict
-- DamageNumbers (STUB — Element "Trefferfeedback" fuellt diese Datei).
--
-- VERTRAG:
--   init(remotes): hoert auf DamageEvent(wurm, schaden, istKritisch, position)
--   und laesst BillboardGui-Zahlen aus dem Getroffenen aufsteigen —
--   Groesse skaliert mit Schaden, kritische Treffer fett.
--   Alle Zahlen in Config/Effects.

local DamageNumbers = {}

function DamageNumbers.init(_remotes: { [string]: RemoteEvent })
	-- Stub: bewusst leer.
end

return DamageNumbers
