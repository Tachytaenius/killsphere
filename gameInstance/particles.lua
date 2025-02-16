local vec3 = require("lib.mathsies").vec3

local consts = require("consts")
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

function gameInstance:emitParticlesFromPortals(dt)
	local state = self.state
	state.portalEmissionTimer = state.portalEmissionTimer - dt
	if state.portalEmissionTimer <= 0 then
		state.portalEmissionTimer = consts.portalEmissionTimerLength
	end
	for _, pair in ipairs(state.spherePortalPairs) do
		for _=1, 12 do -- 12 pairs of particles, coming out of...
			for i = 0, 1 do -- ...two portals
				local colour = util.shallowClone(i == 0 and pair.aColour or pair.bColour)
				local position = i == 0 and pair.aPosition or pair.bPosition -- No need to clone
				local relativePosition = util.randomOnSphereSurface(pair.radius)
				local particlePosition = relativePosition + position
				local particleVelocity = util.randomOnHemisphereSurface(pair.radius, relativePosition) * util.randomRange(0.1, 1) -- No need to normalise relativePosition due to how randomOnHemisphereSurface works

				state.particles:add({
					position = particlePosition,
					velocity = particleVelocity,
					emissionColour = colour,
					emission = 200,
					lifetimeLength = util.randomRange(0.2, 2),
					timeExisted = 0,
					emissionFalloff = true,

					draw = love.math.random() < 0.03,
					drawRadius = 0.15,
					strengthDiameterDivide = true,
					radiusFalloff = true,
					drawStrength = 1,
					drawColour = "emission"
				})
			end
		end
	end
end

return gameInstance
