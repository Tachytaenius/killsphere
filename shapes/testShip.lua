local vec3 = require("lib.mathsies").vec3
local util = require("util")

local testShip = {}

testShip.geometry = util.loadShapeObj("assets/meshes/testShip.obj")
testShip.cameraOffset = vec3(0, 0.5, 0.4)
testShip.guns = {
	offset = vec3(0, 081461, 2.618913 + 0.01),
	damagePerSecond = 2,
	beamColour = {0.1, 0.9, 1},
	beamEmission = 10,
	beamRange = 100
}

return testShip
