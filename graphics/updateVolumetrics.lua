local vec3 = require("lib.mathsies").vec3

local consts = require("consts")

local graphics = {}

function graphics:updateVolumetrics(state, dt)
	local drawTime = state.time - dt

	self:tickFog(state, drawTime, dt)
	self:addBeams(state)
end

function graphics:addBeams(state)
	for _, beam in ipairs(state.linesToDraw) do
		local drawLaserShader = self.drawLaserShader
		local laserSteps = 1024
		drawLaserShader:send("fogEmission", self.fogEmissionCanvas)
		drawLaserShader:send("worldRadius", state.worldRadius)
		drawLaserShader:send("lineStart", {vec3.components(beam.startPosition)})
		drawLaserShader:send("lineEnd", {vec3.components(beam.endPosition)})
		drawLaserShader:send("lineSteps", laserSteps)
		drawLaserShader:send("lineEmissionAdd", beam.emissionAdd)
		drawLaserShader:sendColor("lineColour", beam.emissionColour)
		love.graphics.dispatchThreadgroups(drawLaserShader, math.ceil(laserSteps / drawLaserShader:getLocalThreadgroupSize()))
	end
end

function graphics:tickFog(state, drawTime, dt)
	local tickFogShader = self.tickFogShader
	tickFogShader:send("fogScatteranceAbsorption", self.fogScatteranceAbsorptionCanvas)
	tickFogShader:send("fogEmission", self.fogEmissionCanvas)
	tickFogShader:send("fogColour", self.fogColourCanvas)
	tickFogShader:send("worldRadius", state.worldRadius)
	tickFogShader:send("time", drawTime)
	tickFogShader:send("scatteranceDifferenceDecay", 2)
	tickFogShader:send("absorptionDifferenceDecay", 2)
	tickFogShader:send("emissionDifferenceDecay", 2)
	tickFogShader:send("colourDifferenceDecay", 2)
	tickFogShader:send("scatteranceDecay", 0.5)
	tickFogShader:send("absorptionDecay", 0.5)
	tickFogShader:send("emissionDecay", 3)
	tickFogShader:send("fogCloudPositionScale", 0.2)
	tickFogShader:send("fogCloudTimeRate", 0.05)
	tickFogShader:send("fogCloudBias", 10)
	tickFogShader:send("fogCloudOutputScale", 10)
	local fogTextureSideLength = self.fogScatteranceAbsorptionCanvas:getWidth()
	local w, h, d = tickFogShader:getLocalThreadgroupSize()
	self.tickFogSkipCyclePosition = (self.tickFogSkipCyclePosition + 1) % consts.tickFogSkipCycleLength
	tickFogShader:send("workGroupIdMultiply", {consts.tickFogSkipCycleLength, 1, 1})
	tickFogShader:send("workGroupIdAdd", {self.tickFogSkipCyclePosition, 0, 0})
	local x, y, z =
		math.ceil(fogTextureSideLength / (w * consts.tickFogSkipCycleLength)),
		math.ceil(fogTextureSideLength / h),
		math.ceil(fogTextureSideLength / (d * 2))
	local fogDt = dt * consts.tickFogSkipCycleLength
	if consts.fogDoAllModes then
		fogDt = fogDt / consts.tickFogModeCount
		tickFogShader:send("dt", fogDt)
		for i = 0, consts.tickFogModeCount - 1 do
			tickFogShader:send("tickFogMode", i)
			love.graphics.dispatchThreadgroups(tickFogShader, x, y, z)
		end
	else
		tickFogShader:send("dt", fogDt)
		self.tickFogMode = (self.tickFogMode + 1) % consts.tickFogModeCount
		tickFogShader:send("tickFogMode", self.tickFogMode)
		love.graphics.dispatchThreadgroups(tickFogShader, x, y, z)
	end
end

return graphics
