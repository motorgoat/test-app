--!strict
-- Config: Sammelpunkt ALLER Zahlenwerte, aufgeteilt in Bereichs-Kindmodule
-- (ein Kind pro Element des Vollausbaus — siehe ARCHITECTURE.md).
-- Exportiert dieselbe flache Form wie das fruehere Einzelmodul
-- (Config.Ballistics.Gravity usw.), bestehende Requires bleiben gueltig.
--
-- Kinder werden per WaitForChild geholt: auch Kinder eines statischen
-- ModuleScripts treffen beim Client-Join progressiv ein (eiserne Regel 3).

local CHILDREN = {
	"Ballistics",
	"Terrain",
	"Aiming",
	"Weapons",
	"Effects",
	"Camera",
	"Sound",
	"Match",
	"UI",
}

local Config: { [string]: any } = {}

for _, name in CHILDREN do
	local child = require(script:WaitForChild(name) :: ModuleScript) :: { [string]: any }
	for key, section in child do
		assert(Config[key] == nil, "Config-Schluessel doppelt definiert: " .. key)
		Config[key] = section
	end
end

return Config
