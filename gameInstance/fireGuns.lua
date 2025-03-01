local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat
local mat4 = mathsies.mat4

local classes = require("classes")
local util = require("util")
local consts = require("consts")

local gameInstance = {}

local function fireBeam(state, entity, gun, pulse, dt, throwSpark)
	local closestHitT, closestHitEntity, closestHitNormal
	local rayStart = entity:getModelToWorldMatrix() * gun.offset
	local gunOrientation = entity.orientation -- TODO: Pivoting turrets
	local rayFullLengthStartToEnd = vec3.rotate(consts.forwardVector, gunOrientation) * gun.beamRange
	local rayFullLengthEnd = rayStart + rayFullLengthStartToEnd

	for targetEntity in state.entities:elements() do
		if targetEntity == entity or not targetEntity.class.shape then
			goto continue
		end

		-- Do a sphere raycast to determine whether triangles should be checked against
		local t1, t2 = util.sphereRaycast(rayStart, rayFullLengthEnd, targetEntity.position, targetEntity.class.shape.radius * targetEntity:getRadiusScalar())
		local checkTriangles = false
		if t1 and t2 then -- Always returned together
			if 0 <= t1 and t1 <= 1 and (not closestHitT or t1 < closestHitT) then
				checkTriangles = true
			-- Unless we're inside the sphere or the sphere is behind us, t2 should not be less than t1
			-- elseif 0 <= t2 and t2 <= 1 and (not closestHitT or t2 < closestHitT) then
				-- checkTriangles = true
			elseif
				t1 <= 0 and 0 <= t2
				or t2 <= 0 and 0 <= t1 -- t2 should never be less than t1, but idk what limited precision can bring about
			then
				-- rayStart is inside sphere
				checkTriangles = true
			end
		end

		if checkTriangles then
			local modelToWorld = targetEntity:getModelToWorldMatrix()
			local worldToModel = mat4.inverse(modelToWorld)
			local rayStartTransformed = worldToModel * rayStart
			local rayEndTransformed = worldToModel * rayFullLengthEnd
			for _, triangle in ipairs(targetEntity.class.shape.triangles) do
				local t, normal = util.triangleRaycast(rayStartTransformed, rayEndTransformed, triangle.v1, triangle.v2, triangle.v3)
				if t and 0 <= t and t <= 1 and (not closestHitT or t < closestHitT) then
					closestHitT = t
					closestHitEntity = targetEntity
					closestHitNormal = normal
				end
			end
		end

	    ::continue::
	end

	local arenaT1, arenaT2 = util.sphereRaycast(rayStart, rayFullLengthEnd, vec3(), state.worldRadius)
	if not closestHitT or arenaT2 < closestHitT then -- We're always inside the sphere, so check t2
		closestHitT = arenaT2
		closestHitEntity = nil
		closestHitNormal = -vec3.normalise(rayStart + rayFullLengthStartToEnd * closestHitT)
	end

	-- Done checking for ray hits

	local endPosition = rayStart + rayFullLengthStartToEnd * (closestHitT or 1)

	if closestHitT then
		-- Add spark(s)
		local sparksDirection = vec3.reflect(vec3.normalise(rayFullLengthStartToEnd), closestHitNormal)
		-- local sparksCount = 1
		-- for _=1, sparksCount do
		if throwSpark then
			local power = util.randomRange(0.1, 0.9)
			local speed = power * 5
			local lifetime = 2 * (1 - power)
			local extra = false
			if love.math.random() < 0.4 then
				extra = true
				speed = speed * 10
				lifetime = lifetime / 4
			end
			-- local rotation = util.randomInSphereVolume(consts.tau / 8)
			-- local direction = vec3.rotate(sparksDirection, quat.fromAxisAngle(rotation))
			local directionPreNormalise = util.randomInSphereVolume(0.7) + sparksDirection * 0.9
			-- speed = speed / #directionPreNormalise
			local direction = vec3.normalise(directionPreNormalise)

			state.particles:add({
				position = endPosition,
				velocity = direction * speed,
				emissionColour = {1, 0.5, 0.1},
				emission = 500 * (extra and 6 or 1),
				lifetimeLength = lifetime,
				timeExisted = 0,
				emissionFalloff = true,

				draw = true,
				drawRadius = 0.15,
				strengthDiameterDivide = true,
				radiusFalloff = true,
				drawStrength = 1 * (extra and 1.5 or 1),
				drawColour = "emission"
			})
		end

		-- Add glow if player
		if entity == state.player then
			state.entities:add(classes.Light({
				worldState = state,
				position = endPosition + closestHitNormal * 0.2,
				lightIntensity = 20 * math.cos(state.time * 80) ^ 4,
				lightColour = {1, 1, 1},
				deleteNextUpdate = true
			}))
		end
	end

	if closestHitEntity then
		-- Damage entity
		if pulse then
			closestHitEntity.health = math.max(0, closestHitEntity.health - gun.damage)
		else
			closestHitEntity.health = math.max(0, closestHitEntity.health - gun.damagePerSecond * dt)
		end
	end

	state.linesToDraw[#state.linesToDraw + 1] = {
		startPosition = rayStart,
		endPosition = endPosition,
		emissionAdd = gun.beamEmissionStrength * dt,
		emissionColour = util.shallowClone(gun.beamColour),

		drawSolid = true,
		solidRadius = gun.beamRadius,
		solidUpVector = vec3.rotate(consts.upVector, gunOrientation)
	}
end

function gameInstance:fireGuns(dt)
	local state = self.state

	state.gunSparkTimer = state.gunSparkTimer - dt
	local throwSpark = false
	if state.gunSparkTimer <= 0 then
		state.gunSparkTimer = consts.gunSparkTimerLength
		throwSpark = true
	end

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
					fireBeam(state, entity, gun, gun.class.pulse, dt, throwSpark)
				end -- TODO: else bullet gun
			end
		end
	    ::continue::
	end
end

return gameInstance
