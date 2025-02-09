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

	self:handleTemporaryVariables()

	self:handlePlayerInput()
	-- TODO: AI stuff
	self:executeWills(dt)

	self:handleMotion(dt)

	state.time = state.time + dt

	self.lastUpdateDt = dt
end

return gameInstance
