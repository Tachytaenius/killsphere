local vec3 = require("lib.mathsies").vec3

local settings = require("settings")
local consts = require("consts")
local util = require("util")

local gameInstance = {}

function gameInstance:handlePlayerInput()
	local state = self.state
	local player = state.player
	if not player then
		return
	end

	local translation = vec3()
	if love.keyboard.isDown(settings.controls.moveBackwards) then translation = translation - consts.forwardVector end
	if love.keyboard.isDown(settings.controls.moveForwards) then translation = translation + consts.forwardVector end
	if love.keyboard.isDown(settings.controls.moveLeft) then translation = translation - consts.rightVector end
	if love.keyboard.isDown(settings.controls.moveRight) then translation = translation + consts.rightVector end
	if love.keyboard.isDown(settings.controls.moveDown) then translation = translation - consts.upVector end
	if love.keyboard.isDown(settings.controls.moveUp) then translation = translation + consts.upVector end
	player.will.targetVelocity = vec3.rotate(util.normaliseOrZero(translation), player.orientation) * player.class.maxSpeed

	local rotation = vec3()
	if love.keyboard.isDown(settings.controls.yawLeft) then rotation = rotation - consts.upVector end
	if love.keyboard.isDown(settings.controls.yawRight) then rotation = rotation + consts.upVector end
	if love.keyboard.isDown(settings.controls.pitchUp) then rotation = rotation - consts.rightVector end
	if love.keyboard.isDown(settings.controls.pitchDown) then rotation = rotation + consts.rightVector end
	if love.keyboard.isDown(settings.controls.rollClockwise) then rotation = rotation - consts.forwardVector end
	if love.keyboard.isDown(settings.controls.rollAnticlockwise) then rotation = rotation + consts.forwardVector end
	player.will.targetAngularVelocity = util.normaliseOrZero(rotation) * player.class.maxAngularSpeed

	local shooting = love.keyboard.isDown(settings.controls.shoot)
	if player.guns then
		-- Skipping will system here I suppose
		for _, gun in ipairs(player.guns) do
			assert(gun.triggered == nil, "Gun triggered state should be unset at this point in update (its triggered state was not cleared)")
			gun.triggered = shooting
		end
	end
end

return gameInstance
