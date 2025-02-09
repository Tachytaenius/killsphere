local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local util = require("util")

local gameInstance = {}

function gameInstance:handleMotion(dt)
	local state = self.state
	for entity in state.entities:elements() do
		entity.position = entity.position + entity.velocity * dt
		entity.orientation = quat.normalise(entity.orientation * quat.fromAxisAngle(entity.angularVelocity * dt))

		-- Teleport
		if #entity.position >= state.worldRadius then
			local difference = #entity.position - state.worldRadius
			entity.position = -vec3.normalise(entity.position) * (state.worldRadius - difference)
		end
	end
end

function gameInstance:handleThrust(entity, dt)
	-- TODO: Wayy better movement system
	if entity.will.targetVelocity then
		entity.velocity = util.moveVectorToTarget(entity.velocity, entity.will.targetVelocity, entity.class.acceleration, dt)
	end
	if entity.will.targetAngularVelocity then
		entity.angularVelocity = util.moveVectorToTarget(entity.angularVelocity, entity.will.targetAngularVelocity, entity.class.angularAcceleration, dt)
	end
end

return gameInstance
