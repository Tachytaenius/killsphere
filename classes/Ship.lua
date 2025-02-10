local class = require("lib.middleclass")

local Entity = require("classes.Entity")

local Ship = class("Ship", Entity)

Ship.static.solid = true
Ship.static.type = "ship"

function Ship:initialize(args)
	Ship.super.initialize(self, args)

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

return Ship
