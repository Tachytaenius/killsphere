local util = require("util")

local gameInstance = {}

function gameInstance:handleParticles(dt)
	local state = self.state
	local particles = state.particles
	local i = 1
	while i < particles.size do
		local particle = particles:get(i)

		local oldPosition = particle.position -- No need to clone
		local newPosition = particle.position + particle.velocity * dt

		local emissionAdd = particle.emission * dt
		if particle.emissionFalloff then
			emissionAdd = emissionAdd * (1 - particle.timeExisted / particle.lifetimeLength)
		end

		state.linesToDraw[#state.linesToDraw + 1] = {
			emissionColour = util.shallowClone(particle.emissionColour),
			emissionAdd = emissionAdd,
			startPosition = oldPosition,
			endPosition = newPosition -- No need to clone
		}

		particle.position = newPosition
		particle.timeExisted = particle.timeExisted + dt

		if particle.timeExisted >= particle.lifetimeLength then
			particles:remove(particle)
		else
			i = i + 1
		end
	end
end

return gameInstance
