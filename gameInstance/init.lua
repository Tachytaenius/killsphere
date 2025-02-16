local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3

local list = require("lib.list")

local util = require("util")
local consts = require("consts")
local classes = require("classes")

local gameInstance = {}

for _, moduleName in ipairs({
	"update",
	"motion",
	"ai",
	"playerInput",
	"misc",
	"fireGuns",
	"particles",
	"damage"
}) do
	for k, v in pairs(require("gameInstance." .. moduleName)) do
		gameInstance[k] = v
	end
end

function gameInstance:init()
	local state = {}
	self.state = state
	state.time = 0
	state.worldRadius = 50
	state.ambientLightAmount = 0.02
	state.ambientLightColour = {1, 1, 1}
	state.paused = false

	state.entities = list()
	state.player = classes.TestShip({
		position = vec3(0, 0, 20)
	})
	state.entities:add(state.player)
	for _=1, 1 do
		state.entities:add(classes.TestShip({
			position = util.randomInSphereVolume(state.worldRadius)
		}))
	end
	state.entities:add(classes.Light({
		position = vec3(0, 0, 0),
		lightIntensity = 100,
		lightColour = {1, 0.75, 0.75}
	}))

	state.spherePortalPairs = {}
	local portalRadius = 4
	state.spherePortalPairs[#state.spherePortalPairs + 1] = {
		aPosition = util.randomInSphereVolume(state.worldRadius - portalRadius * 1.01),
		bPosition = util.randomInSphereVolume(state.worldRadius - portalRadius * 1.01),
		aColour = {0, 1, 0},
		bColour = {0, 0, 1},
		radius = portalRadius
	}

	state.gunSparkTimer = consts.gunSparkTimerLength
	state.portalEmissionTimer = consts.portalEmissionTimerLength
	state.particles = list()
end

return gameInstance
