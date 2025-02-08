local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local util = require("util")

local consts = require("consts")

local gameInstance = {}

function gameInstance:update(dt)
	if self.paused then
		return
	end

	local state = self.state

	local player = state.player

	if player then
		local translation = vec3()
		if love.keyboard.isDown("d") then translation = translation + consts.rightVector end
		if love.keyboard.isDown("a") then translation = translation - consts.rightVector end
		if love.keyboard.isDown("e") then translation = translation + consts.upVector end
		if love.keyboard.isDown("q") then translation = translation - consts.upVector end
		if love.keyboard.isDown("w") then translation = translation + consts.forwardVector end
		if love.keyboard.isDown("s") then translation = translation - consts.forwardVector end
		-- TODO: Way better movement system
		local targetVelocity = vec3.rotate(util.normaliseOrZero(translation), player.orientation) * player.maxSpeed
		player.velocity = util.moveVectorToTarget(player.velocity, targetVelocity, player.acceleration, dt)

		local rotation = vec3()
		if love.keyboard.isDown("k") then rotation = rotation + consts.rightVector end
		if love.keyboard.isDown("i") then rotation = rotation - consts.rightVector end
		if love.keyboard.isDown("l") then rotation = rotation + consts.upVector end
		if love.keyboard.isDown("j") then rotation = rotation - consts.upVector end
		if love.keyboard.isDown("u") then rotation = rotation + consts.forwardVector end
		if love.keyboard.isDown("o") then rotation = rotation - consts.forwardVector end
		-- TODO: Way better movement system
		local targetAngularVelocity = util.normaliseOrZero(rotation) * player.maxAngularSpeed
		player.angularVelocity = util.moveVectorToTarget(player.angularVelocity, targetAngularVelocity, player.angularAcceleration, dt)
	end

	for _, entity in ipairs(state.entities) do
		-- Extremely TODO/TEMP:
		if entity ~= player and entity.type == "ship" then
			local translation = vec3(0, 0, 1)
			local targetVelocity = vec3.rotate(util.normaliseOrZero(translation), entity.orientation) * entity.maxSpeed
			entity.velocity = util.moveVectorToTarget(entity.velocity, targetVelocity, entity.acceleration, dt)
			local rotation = vec3.normalise(vec3(1, 1, 0.2))
			local targetAngularVelocity = util.normaliseOrZero(rotation) * entity.maxAngularSpeed
			entity.angularVelocity = util.moveVectorToTarget(entity.angularVelocity, targetAngularVelocity, entity.angularAcceleration, dt)
		end

		entity.position = entity.position + entity.velocity * dt
		if #entity.position >= state.worldRadius then
			local difference = #entity.position - state.worldRadius
			entity.position = -vec3.normalise(entity.position) * (state.worldRadius - difference)
		end
		if entity.orientation then
			entity.orientation = quat.normalise(entity.orientation * quat.fromAxisAngle(entity.angularVelocity * dt))
		end
	end

	state.time = state.time + dt

	self.lastUpdateDt = dt
end

return gameInstance
