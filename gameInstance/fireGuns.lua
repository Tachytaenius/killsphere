local vec3 = require("lib.mathsies").vec3

local util = require("util")
local consts = require("consts")

local gameInstance = {}

local function fireBeam(state, entity, gun, dt)
	-- TODO: Collision (entities and arena), bouncing, etc

	local closestHitT, closestHitEntity, closestHitNormal
	local rayStart = entity.position + vec3.rotate(gun.offset, entity.orientation)
	local gunOrientation = entity.orientation -- TODO: Pivoting turrets
	local rayFullLengthStartToEnd = vec3.rotate(consts.forwardVector, gunOrientation) * gun.beamRange

	state.beamsToDraw[#state.beamsToDraw + 1] = {
		startPosition = rayStart,
		endPosition = rayStart + rayFullLengthStartToEnd * (closestHitT or 1),
		emissionAdd = gun.beamEmissionStrength * dt,
		emissionColour = util.shallowClone(gun.beamColour)
	}
end

function gameInstance:fireGuns(dt)
	local state = self.state
	for entity in state.entities:elements() do
		if not entity.guns then
			goto continue
		end
		for _, gun in ipairs(entity.guns) do
			assert(gun.firing == nil, "Gun firing state should not be set at this point in update (its firing state was not cleared)")
			if not gun.triggered then
				gun.firing = false
			else
				gun.firing = true -- For drawing
				if gun.class.beam then
					fireBeam(state, entity, gun, dt)
				end -- TODO: else bullet gun
			end
		end
	    ::continue::
	end
end

return gameInstance
