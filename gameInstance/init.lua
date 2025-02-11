local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local list = require("lib.list")

local classes = require("classes")

local gameInstance = {}

for _, moduleName in ipairs({
	"update",
	"motion",
	"ai",
	"playerInput",
	"misc",
	"fireGuns"
}) do
	for k, v in pairs(require("gameInstance." .. moduleName)) do
		gameInstance[k] = v
	end
end

function gameInstance:init()
	local state = {}
	self.state = state
	state.time = 0
	state.worldRadius = 100
	state.ambientLightAmount = 0.02
	state.ambientLightColour = {1, 1, 1}
	state.paused = false

	state.entities = list()
	state.player = classes.TestShip({
		position = vec3(0, 0, 20)
	})
	state.entities:add(state.player)
	state.entities:add(classes.TestShip({
		position = vec3(0, -20, 0)
	}))
	state.entities:add(classes.Light({
		position = vec3(0, 0, 0),
		lightIntensity = 100,
		lightColour = {1, 0.75, 0.75}
	}))
end

return gameInstance
