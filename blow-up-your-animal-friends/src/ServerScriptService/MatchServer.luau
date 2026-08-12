--!strict
-- MatchServer (STUB — Element "Rundenmanagement und Match-Fluss" fuellt diese Datei).
--
-- VERTRAG (Herzstueck des Spiels):
--   init(deps): { remotes, terrainWorld, fireHandler, weaponServer, projectileServer }
--   Zustandsmaschine: Warten -> Matchstart (Teams, Bot-Ziegen im Solo, Spawns
--   via TerrainWorld.getSpawnPoints) -> Runde: Windwurf, MatchEvent(Phase,
--   aktiverSpieler, Wind, Timer) an alle, Zielphase (FireHandler.setCanFire nur
--   fuer aktiven), Aufloesung (Projektile zu Ende), Schadensabrechnung (HP,
--   Fallschaden, Wasser=Tod), Rueckzugszeit -> Siegpruefung -> Neustart.
--   Bots (BotBrain) nutzen dieselben Server-Pfade wie Spieler.
--
-- SOLANGE STUB: kein Rundensystem — jeder darf jederzeit feuern (v11-Verhalten),
-- damit das Live-Spiel testbar bleibt.

local MatchServer = {}

function MatchServer.init(_deps: { [string]: any })
	-- Stub: bewusst leer.
end

return MatchServer
