local vec3 = require("lib.mathsies").vec3

local class = require("lib.middleclass")
local Ship = require("classes.Ship")

local util = require("util")

local TestShip = class("TestShip", Ship)

TestShip.static.maxSpeed = 50
TestShip.static.acceleration = 150
TestShip.static.maxAngularSpeed = 2
TestShip.static.angularAcceleration = 10

TestShip.static.shape = util.loadShapeObj("assets/meshes/testShip.obj")
TestShip.static.colliderRadius = TestShip.static.shape.radius * 0.5
TestShip.cameraOffset = vec3(0, 0.5, 0.4)
TestShip.static.fov = math.rad(100)

function TestShip:initialize(args)
	TestShip.super.initialize(self, args)
	-- add to guns . . .
end

return TestShip
