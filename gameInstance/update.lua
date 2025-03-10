local gameInstance = {}

function gameInstance:update(dt)
	if self.paused then
		self.lastUpdateDt = nil
		return
	end

	local state = self.state

	self:handleTemporaryVariables()

	self:handlePlayerInput()
	self:handleAi()
	self:executeWills(dt)

	self:handleMotion(dt)
	self:fireGuns(dt)
	self:handleDamage()

	self:emitParticlesFromPortals(dt)
	self:handleParticles(dt)

	state.time = state.time + dt

	self.lastUpdateDt = dt
end

return gameInstance
