local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local mat4 = mathsies.mat4

local consts = require("consts")

local graphics = {}

function graphics:drawState(state, lastUpdateDt)
	-- lastUpdateDt = lastUpdateDt or 0
	local drawTime = state.time - lastUpdateDt

	local orientation = state.player.orientation
	local camera = {
		position = state.player.position + vec3.rotate(state.player.shape.cameraOffset, orientation),
		orientation = orientation,
		fov = state.player.fov
	}

	local worldToCamera = mat4.camera(camera.position, camera.orientation)
	local worldToCameraStationary = mat4.camera(vec3(), camera.orientation)
	local cameraToClip = mat4.perspectiveLeftHanded(
		self.outputCanvas:getWidth() / self.outputCanvas:getHeight(),
		camera.fov,
		consts.farPlaneDistance,
		consts.nearPlaneDistance
	)
	local worldToClip = cameraToClip * worldToCamera
	local clipToSky = mat4.inverse(cameraToClip * worldToCameraStationary)
	local cameraForwardVector = vec3.rotate(consts.forwardVector, camera.orientation)

	love.graphics.setCanvas(self.outputCanvas)
	love.graphics.clear()

	self:sendObjects(state)
	self:drawAndSendLightShadowMaps(state)
	local sceneShader = self.sceneShader
	sceneShader:send("arenaRadius", state.worldRadius)
	sceneShader:send("clipToSky", {mat4.components(clipToSky)})
	sceneShader:send("cameraPosition", {vec3.components(camera.position)})
	sceneShader:send("cameraForwardVector", {vec3.components(cameraForwardVector)})
	sceneShader:send("cameraFOV", camera.fov)
	sceneShader:send("maxRaySegments", 5)
	sceneShader:send("outlineThicknessFactor", 0.1 + 0.01 * math.sin(state.time * 10.0))
	sceneShader:send("fogScatteranceAbsorption", self.fogScatteranceAbsorptionCanvas)
	sceneShader:send("fogColour", self.fogColourCanvas)
	sceneShader:send("fogEmission", self.fogEmissionCanvas)
	sceneShader:send("fogDistancePerSample", consts.fogDistancePerDatum / consts.fogSampleCountMultiplier)
	sceneShader:sendColor("ambientLightColour", state.ambientLightColour)
	sceneShader:send("ambientLightAmount", state.ambientLightAmount)
	-- sceneShader:send("time", state.time)
	love.graphics.setShader(sceneShader)
	-- sceneShader:send("bayerMatrixSize", 8)
	-- sceneShader:send("bayerMatrix", love.graphics.newImage("bayer8.png"))
	love.graphics.draw(self.dummyTexture, 0, 0, 0, self.outputCanvas:getDimensions())

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
	local fogDt = lastUpdateDt * consts.tickFogSkipCycleLength
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

	love.graphics.setShader()
	love.graphics.setCanvas()
end

function graphics:draw(state, paused, lastUpdateDt)
	if not paused then
		self:drawState(state, lastUpdateDt)
	end
end

return graphics
