--!strict
-- QuipDefs (STUB — Element "Sound und Sprueche" fuellt diese Datei).
-- Die Worms-Identitaet OHNE Worms-Assets: eigene freche deutsche Sprueche.
-- KEINE Logik — nur Daten. Ausloesung: Server (MatchServer/WeaponServer)
-- schickt QuipEvent(situation, wurmName); QuipSystem (Client) waehlt eine
-- Variante und rendert die Sprechblase.
--
-- SCHEMA: [situation: string] = { string } — mindestens 4 Varianten je Situation.
-- Situationen (mindestens): "rundenstart", "volltreffer", "fehlschuss",
-- "eigenerSchaden", "beinaheTreffer", "langeweile", "sieg", "wasserTod".

local defs: { [string]: { string } } = {}

return defs
