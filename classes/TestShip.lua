local vec3 = require("lib.mathsies").vec3

local class = require("lib.middleclass")
local Laser = require("classes.Laser")
local Ship = require("classes.Ship")

local util = require("util")

local TestShip = class("TestShip", Ship)

TestShip.static.maxSpeed = 25
TestShip.static.acceleration = 100
TestShip.static.maxAngularSpeed = 2
TestShip.static.angularAcceleration = 10

TestShip.static.shape = util.loadShapeObj("assets/meshes/testShip.obj")
TestShip.static.colliderRadius = TestShip.static.shape.radius * 0.5
TestShip.static.cameraOffset = vec3(0, 0.5, 0.4)
TestShip.static.fov = math.rad(100)

TestShip.static.maxHealth = 400

function TestShip:initialize(args)
	TestShip.super.initialize(self, args)

	self.guns[#self.guns + 1] = Laser({
		offset = vec3(0, -0.081461 - 0.1, 2.618913 - 0.1), -- Based on the ship's geometry
		beamColour = {0.1, 0.9, 1},
		beamEmissionStrength = 250,
		damagePerSecond = 200,
		beamRange = 500,
		beamRadius = 0.125
	})
end

return TestShip
