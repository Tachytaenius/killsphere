local class = require("lib.middleclass")

local util = require("util")

local Entity = require("classes.Entity")

local Light = class("Light", Entity)

Light.static.type = "light"

function Light:initialize(args)
	Light.super.initialize(self, args)
	assert(args.lightIntensity)
	assert(args.lightColour)
	self.lightIntensity = args.lightIntensity
	self.lightColour = util.shallowClone(args.lightColour)
end

function Light:clearTemporaryFields()
	Light.super:clearTemporaryFields()
end

return Light
