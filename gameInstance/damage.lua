local vec3 = require("lib.mathsies").vec3

local consts = require("consts")
local util = require("util")

local gameInstance = {}

local rygcbm = {
	{1, 0, 0},
	{1, 1, 0},
	{0, 1, 0},
	{0, 1, 1},
	{0, 0, 1},
	{1, 0, 1},
}

function gameInstance:handleDamage()
	local state = self.state
	local i = 1
	while i <= state.entities.size do
		local entity = state.entities:get(i)
		if not entity.health then
			i = i + 1
			goto continue
		end

		if entity.health <= 0 then
			state.entities:remove(entity)

			-- Explode
			local radius = entity.class.colliderRadius
			local volume = 2 / 3 * consts.tau * radius
			local particlePerVolume = 128
			for _=1, math.floor(particlePerVolume * volume) do
				local extra = love.math.random() < 0.4
				local power = util.randomRange(0.1, 0.9)
				local lifetime = 1.8 * (1 - power) * (extra and 0.5 or 1) / 5
				local relativePositionUnitSphere = util.randomInSphereVolume(1)
				local relativePosition = relativePositionUnitSphere * radius * 0.25
				local speed = (#relativePositionUnitSphere) ^ 0.7 * 40 * (extra and 1.5 or 1) * 1.5
				local relativeVelocity = util.normaliseOrZero(relativePositionUnitSphere) * speed

				local glow = love.math.random() < 0.95
				local smoke = love.math.random() < (glow and 0.2 or 0.9)
				if not glow then
					smoke = true
				end
				if not smoke then
					glow = true
				end

				local draw = love.math.random() < 0.2

				local particle = {
					position = entity.position + relativePosition,
					velocity = entity.velocity + relativeVelocity,

					lifetimeLength = lifetime,
					volumetricTimeLength = lifetime * 0.5,
					timeExisted = 0
				}

				if draw then
					particle.draw = true
					particle.drawRadius = (power * 0.4 + 0.6) * 1.2
					particle.radiusFalloff = true
					particle.radiusFalloffPower = 0.2
					particle.drawStrength = 1.2
				end

				if smoke then
					if draw then
						particle.drawColour = "fog"
					end
					particle.scatterance = 25
					particle.absorption = 150
					particle.fogColour = {0, 0, 0}
					particle.scatteranceFalloff = true
					particle.absorptionFalloff = true
				end

				if glow then
					if draw then
						particle.drawColour = "emission" -- Overrides fog-type
					end
					local col = love.math.random()
					-- if love.math.random() < 0.075 then
					if false then
						-- Colourful!!
						particle.emissionColour = rygcbm[love.math.random(1, 6)]
						particle.emission = 160000
						particle.velocity = particle.velocity * 2
					else
						particle.emissionColour = {1, 0.5 * col, 0.1 * col ^ 2}
						particle.whiteAtStart = true
						particle.emission = 80000
					end
					particle.emissionFalloff = true
				end

				state.particles:add(particle)
			end
		else
			i = i + 1
		end

	    ::continue::
	end
end

return gameInstance
