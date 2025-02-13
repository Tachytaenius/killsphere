local util = require("util")

local gameInstance = {}

function gameInstance:handleParticles(dt)
	local state = self.state
	local particles = state.particles
	local i = 1
	while i <= particles.size do
		local particle = particles:get(i)

		local steps = 1 -- Really just to deal with whiteAtStart's core being too big in an explosion
		if particle.whiteAtStart then
			if  particle.timeExisted / (particle.volumetricTimeLength or particle.lifetimeLength) <= 0.2 then
				steps = 4
			end
		end
		local stepDt = dt / steps
		for stepI = 0, steps - 1 do
			local oldPosition = particle.position -- No need to clone
			local newPosition = particle.position + particle.velocity * stepDt

			local timeFalloffVolumetric = math.max(0, 1 - particle.timeExisted / (particle.volumetricTimeLength or particle.lifetimeLength))

			local emissionAdd = (particle.emission or 0) * stepDt
			if particle.emissionFalloff then
				emissionAdd = emissionAdd * timeFalloffVolumetric
			end

			local scatteranceAdd = (particle.scatterance or 0) * stepDt
			if particle.scatteranceFalloff then
				scatteranceAdd = scatteranceAdd * timeFalloffVolumetric
			end

			local absorptionAdd = (particle.absorption or 0) * stepDt
			if particle.absorptionFalloff then
				absorptionAdd = absorptionAdd * timeFalloffVolumetric
			end

			local emissionColour
			if particle.whiteAtStart then
				local t = 1 - timeFalloffVolumetric ^ 10
				emissionColour = {
					util.lerp(1, particle.emissionColour[1], t),
					util.lerp(1, particle.emissionColour[2], t),
					util.lerp(1, particle.emissionColour[3], t)
				}
			else
				emissionColour = particle.emissionColour
			end

			state.linesToDraw[#state.linesToDraw + 1] = {
				emissionColour = emissionColour,
				emissionAdd = emissionAdd,
				startPosition = oldPosition,
				endPosition = newPosition, -- No need to clone
				fogColour = particle.fogColour or {0, 0, 0},
				scatteranceAdd = scatteranceAdd,
				absorptionAdd = absorptionAdd
			}

			particle.position = newPosition
			particle.timeExisted = particle.timeExisted + stepDt
		end

		if particle.timeExisted >= particle.lifetimeLength then
			particles:remove(particle)
		else
			i = i + 1
		end
	end
end

return gameInstance
