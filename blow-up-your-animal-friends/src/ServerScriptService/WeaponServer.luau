--!strict
-- WeaponServer (STUB — Element "Waffenarsenal" fuellt diese Datei).
--
-- VERTRAG:
--   init(deps): verdrahtet sich mit { remotes, projectileServer, terrainWorld }.
--   fire(player, weaponId, direction, power): fuehrt einen validierten Schuss
--     der gewaehlten Waffe aus (Projektile via ProjectileServer, Krater via
--     TerrainWorld.carveCrater, Schaden + Knockback via DamageEvent).
--   getSelectedWeapon(player): string — vom FireHandler abgefragt.
--   Hoert auf Remotes.WeaponSelect (Client waehlt Waffe; validieren + Munition).
--
-- Datengetrieben ueber Shared/WeaponDefs. Explosionsschaden mit Distanz-Falloff,
-- Knockback via ApplyImpulse (KEINE BodyMover). Alle Zahlen in Config/Weapons
-- bzw. WeaponDefs.

local WeaponServer = {}

function WeaponServer.init(_deps: { [string]: any })
	-- Stub: noch keine Waffenlogik — v11-Standardschuss laeuft ueber
	-- FireHandler/ProjectileServer weiter.
end

return WeaponServer
