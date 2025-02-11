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
	self:fireGuns(dt)
	self:handleParticles(dt)

	state.time = state.time + dt

	self.lastUpdateDt = dt
end

return gameInstance
