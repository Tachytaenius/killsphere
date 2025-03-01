local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local util = require("util")
local consts = require("consts")

local gameInstance = {}

function gameInstance:handleMotion(dt)
	local state = self.state
	for entity in state.entities:elements() do
		entity.position = entity.position + entity.velocity * dt
		entity.orientation = quat.normalise(entity.orientation * quat.fromAxisAngle(entity.angularVelocity * dt))

		if #entity.position >= state.worldRadius then
			-- Teleport
			-- local difference = #entity.position - state.worldRadius
			-- entity.position = -vec3.normalise(entity.position) * (state.worldRadius - difference)
		end

		if entity.class.solid then
			local radiusScalar = entity:getRadiusScalar() -- I don't think we should have portals too close to the edge of the world
			if #entity.position + entity.class.colliderRadius * radiusScalar >= state.worldRadius then
				-- Bounce
				entity.position = util.limitVectorLength(entity.position, state.worldRadius - entity.class.colliderRadius * radiusScalar)
				local surfaceNormal = -vec3.normalise(entity.position)
				local parallel = surfaceNormal * vec3.dot(entity.velocity, surfaceNormal)
				local perpendicular = entity.velocity - parallel
				local parallellScaled = parallel * -consts.boundarySphereBounciness
				entity.velocity = parallellScaled + perpendicular
			end
		end

		for _, pair in ipairs(state.spherePortalPairs) do
			for i = 0, 1 do
				local inPosition = i == 0 and pair.aPosition or pair.bPosition
				local outPosition = i == 1 and pair.aPosition or pair.bPosition
				if vec3.distance(entity.position, inPosition) < pair.radius then
					local relativePosition = entity.position - inPosition
					entity.position = outPosition - vec3.normalise(relativePosition) * pair.radius * 1.001
				end
			end
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
