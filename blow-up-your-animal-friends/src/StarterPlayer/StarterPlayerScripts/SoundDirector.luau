--!strict
-- SoundDirector (STUB — Element "Sound und Sprueche" fuellt diese Datei).
--
-- VERTRAG:
--   init(remotes): hoert auf ProjectileFired/ProjectileImpact/DamageEvent/
--   MatchEvent und spielt das Ereignis->Sound-Mapping aus Config/Sound ab —
--   mit Pitch-/Volume-Variation gegen Monotonie.
--   NUR rbxasset://-Builtins als Basis (Audio-Privacy: fremde rbxassetid
--   koennen stumm sein; riskante IDs nur dokumentiert als Option).
--
-- SOLANGE STUB: ImpactEffects spielt die bisherigen v11-Sounds weiter.

local SoundDirector = {}

function SoundDirector.init(_remotes: { [string]: RemoteEvent })
	-- Stub: bewusst leer.
end

return SoundDirector
