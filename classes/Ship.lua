local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat
local mat4 = mathsies.mat4

local class = require("lib.middleclass")

local consts = require("consts")
local util = require("util")

local Entity = require("classes.Entity")

local Ship = class("Ship", Entity)

Ship.static.solid = true
Ship.static.type = "ship"

function Ship:initialize(args)
	Ship.super.initialize(self, args)

	assert(self.class.maxHealth)
	self.health = self.class.maxHealth

	self.guns = {}
end

function Ship:clearTemporaryFields()
	Ship.super:clearTemporaryFields()

	self.will = nil

	if self.guns then
		for _, gun in ipairs(self.guns) do
			gun:clearTemporaryFields()
		end
	end
end

function Ship:getPortalScaleFactors()
	-- Returns direction to scale in, scale factor in that direction, scale factor for all directions perpendicular, and whether to render the ship at all
	local closestRelativePosition, closestDistance = nil, math.huge
	local closestPortalPair, closestPortalPairSelector = nil, nil
	for _, pair in ipairs(self.worldState.spherePortalPairs) do
		for selector = 0, 1 do
			local difference = (selector == 0 and pair.aPosition or pair.bPosition) - self.position
			local distance = vec3.length(difference)
			if distance < closestDistance then
				closestRelativePosition = difference
				closestDistance = distance
				closestPortalPair = pair
				closestPortalPairSelector = selector
			end
		end
	end
	if closestRelativePosition then
		local pair = closestPortalPair
		local factor = math.min(1,
			(closestDistance - pair.radius) / (pair.radius * pair.shellRadiusMultiplier - pair.radius)
		)
		local render = true
		if factor <= 0 then
			factor = 0
			render = false
		end
		return
			vec3.normalise(closestRelativePosition),
			factor ^ 0.5,
			factor ^ 2.5,
			render
	end
	return consts.forwardVector, 1, 1, true -- Can use any normalised vector
end

function Ship:getRadiusScalar()
	local _, parallel, perpendicular = self:getPortalScaleFactors()
	return math.max(parallel, perpendicular)
end

local identityMat3 = {
	1, 0, 0,
	0, 1, 0,
	0, 0, 1
}

function Ship:getModelToWorldMatrix()
	local direction, parallell, perpendicular, render = self:getPortalScaleFactors()
	local scalingMatrix =
		-- (b - s) × outerProduct(v, v) + sI  where b is parallel, s is perpendicular, and v is direction, except the end result is a mat4 (its bottom right element is 1, not s)
		-- Mathsies does not have 3x3 matrices, so excuse the weirdness
		util.mat3ToMat4(
			util.arrayAdd(
				util.arrayMultiplyScalar(
					parallell - perpendicular,
					util.vec3OuterProduct(direction, direction)
				),
				util.arrayMultiplyScalar(
					perpendicular,
					identityMat3
				)
			),
			true -- To put a 1 in the bottom right element
		)
		-- Thanks a lot to vornicus! I would have rotated, scaled, then rotated back

	-- local axis, angle = util.axisAngleBetweenDirections(direction, consts.forwardVector)
	-- axis = axis or consts.upVector
	-- local q = quat.fromAxisAngle(axis * angle)
	-- local rotTo = mat4.rotate(q)
	-- local rotAway = mat4.rotate(quat.inverse(q))
	-- local scalingMatrix = rotAway * mat4.scale(vec3(perpendicular, perpendicular, parallell)) * rotTo

	-- Testing showed the two approaches as the same

	local rotationMatrix = mat4.rotate(self.orientation)
	local translationMatrix = mat4.translate(self.position)

	-- Rotate to world space orientation,
	-- scale (the scalingMatrix is in world space orientation),
	-- then translate
	return translationMatrix * scalingMatrix * rotationMatrix, render
end

return Ship
