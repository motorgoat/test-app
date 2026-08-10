--!strict
-- Client-Bootstrap: wartet auf die Remotes des Servers und initialisiert
-- die Client-Module in Abhängigkeitsreihenfolge. Danach ist Zielen aktiv.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	FireRequest = remotesFolder:WaitForChild("FireRequest") :: RemoteEvent,
	ProjectileFired = remotesFolder:WaitForChild("ProjectileFired") :: RemoteEvent,
	ProjectileImpact = remotesFolder:WaitForChild("ProjectileImpact") :: RemoteEvent,
}

local PowerBar = require(script.Parent.PowerBar)
local TrajectoryPreview = require(script.Parent.TrajectoryPreview)
local ImpactEffects = require(script.Parent.ImpactEffects)
local ProjectileVisual = require(script.Parent.ProjectileVisual)
local AimController = require(script.Parent.AimController)

PowerBar.init()
TrajectoryPreview.init()
ImpactEffects.init(remotes) -- Einschlags-Gewicht: Shake, Partikel, Sound
ProjectileVisual.init(remotes) -- kosmetisches Projektil, client-gerendert (kein Input-Lag)
AimController.init(remotes)

-- Seam für die spätere Zustandsmaschine: enable()/disable() steuern das Zielen.
AimController.enable()
