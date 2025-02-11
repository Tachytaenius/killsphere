local class = require("lib.middleclass")

local Gun = require("classes.Gun")

local Laser = class("Laser", Gun)

Laser.static.beam = true

function Laser:initialize(args)
	Laser.super.initialize(self, args)

	assert(args.beamColour)
	self.beamColour = args.beamColour
	assert(args.damagePerSecond)
	self.damagePerSecond = args.damagePerSecond
	assert(args.beamRange)
	self.beamRange = args.beamRange
	assert(args.beamEmissionStrength)
	self.beamEmissionStrength = args.beamEmissionStrength

	self.beamHitT = nil
	self.beamHitEntity = nil
	self.beamHitPos = nil
	self.beamHitNormal = nil
end

function Laser:clearTemporaryFields()
	Laser.super.clearTemporaryFields(self)

	self.beamHitT = nil
	self.beamHitEntity = nil
	self.beamHitPos = nil
	self.beamHitNormal = nil
end

return Laser
