local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local shapes = require("shapes")

local gameInstance = {}

for _, moduleName in ipairs({
	"update"
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
	state.player = {
		type = "ship",
		allegience = "player",

		position = vec3(),
		velocity = vec3(),
		orientation = quat(),
		angularVelocity = vec3(),
		maxSpeed = 50,
		acceleration = 150,
		maxAngularSpeed = 2,
		angularAcceleration = 10,

		fov = math.rad(100),
		shape = shapes.testShip
	}
	state.entities = {state.player}
	for _=1, 1 do
		state.entities[#state.entities + 1] = {
			type = "ship",
			allegience = "enemy",

			position = vec3(0, 0, 20),
			velocity = vec3(),
			orientation = quat(),
			angularVelocity = vec3(),
			maxSpeed = 1,
			acceleration = 2,
			maxAngularSpeed = 0.1,
			angularAcceleration = 0.2,

			fov = math.rad(100),
			shape = shapes.testShip
		}
	end
	state.entities[#state.entities + 1] = {
		type = "light",
		position = vec3(0, 0, 0),
		velocity = vec3(0, 0.05, 0),
		lightColour = {1, 0.5, 0.5},
		lightIntensity = 400
	}
end

return gameInstance
