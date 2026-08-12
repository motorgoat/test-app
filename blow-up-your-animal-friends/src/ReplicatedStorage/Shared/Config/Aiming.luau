--!strict
-- Config-Bereich: Zielsystem (Element "Zielsystem" besitzt diese Datei).
-- Aiming: Eingabe/Projektion. Preview: Flugbahn-Vorschau (DAS Lesbarkeits-Element).

return {
	Aiming = {
		MaxAimDistance = 2000, -- Länge des Kamera-Raycasts zum Zielpunkt unter der Maus
		-- Vom Element zu fuellen: Projektion auf die Spielebene z=0 (2.5D).
	},

	Preview = {
		PointCount = 60,
		TimeStep = 0.06, -- Sekunden Flugzeit zwischen zwei Punkten
		DotDiameter = 0.6,
		DotColor = Color3.fromRGB(255, 235, 130),
		DotTransparencyNear = 0.05,
		DotTransparencyFar = 0.55,
		EndMarkerDiameter = 1.6,
		EndMarkerColor = Color3.fromRGB(255, 90, 60),
		EndMarkerTransparency = 0.15,
	},
}
