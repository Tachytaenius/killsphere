local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local class = require("lib.middleclass")

local Entity = class("Entity")

function Entity:initialize(args)
	assert(args.worldState)
	self.worldState = args.worldState

	assert(args.position)
	self.position = vec3.clone(args.position)

	self.orientation = self.orientation and quat.clone(self.orientation) or quat()
	self.velocity = args.velocity and vec3.clone(args.velocity) or vec3()
	self.angularVelocity = args.angularVelocity and vec3.clone(args.angularVelocity) or vec3()

	self.deleteNextUpdate = args.deleteNextUpdate
end

function Entity:clearTemporaryFields()

end

return Entity
