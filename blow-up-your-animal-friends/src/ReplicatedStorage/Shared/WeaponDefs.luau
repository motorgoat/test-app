--!strict
-- WeaponDefs (STUB — Element "Waffenarsenal" fuellt diese Datei).
-- Datengetriebene Waffenliste, geteilt zwischen Server (Ausfuehrung) und
-- Client (Waffenrad, Vorschau-Art). KEINE Logik hier — nur Daten.
--
-- SCHEMA je Eintrag (Reihenfolge = Anzeige im Waffenrad):
-- {
--   id: string,              -- stabiler Schluessel ("bazooka")
--   name: string,            -- Anzeigename ("Bazooka")
--   icon: string,            -- Emoji/Icon-Text ("🚀")
--   projectile: string,      -- "arc" | "bounce" | "hitscan" | "drop" | "placed" | "walker" | "airstrike" | "melee" | "utility"
--   damage: number,          -- Maximalschaden im Zentrum
--   craterRadius: number,    -- studs (0 = kein Krater)
--   windFactor: number,      -- 0 = stur, 1 = voll windanfaellig
--   restitution: number?,    -- Abpraller-Energieerhalt (bounce)
--   fuseSeconds: number?,    -- Zuendzeit (bounce/drop/placed/walker)
--   clusterCount: number?,   -- Zerfall in N Cluster
--   shots: number?,          -- Salvengroesse (hitscan)
--   spreadDeg: number?,      -- Streuung
--   ammo: number?,           -- nil = unbegrenzt
--   previewKind: string,     -- "arc" | "ray" | "marker" | "none" (Zielsystem)
-- }
--
-- Ziel: mindestens 14 Waffen mit eigenem Charakter (Bazooka, Moerser, Granate,
-- Splittergranate, Heilige Granate, Banane, Schrotflinte, Uzi, Dynamit, Mine,
-- Luftschlag, Ziegenbombe, Baseballschlaeger, Teleport).

export type WeaponDef = {
	id: string,
	name: string,
	icon: string,
	projectile: string,
	damage: number,
	craterRadius: number,
	windFactor: number,
	restitution: number?,
	fuseSeconds: number?,
	clusterCount: number?,
	shots: number?,
	spreadDeg: number?,
	ammo: number?,
	previewKind: string,
}

local defs: { WeaponDef } = {}

return defs
