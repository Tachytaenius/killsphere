local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local mat4 = mathsies.mat4

local consts = require("consts")

local graphics = {}

function graphics:drawState(state)
	local orientation = state.player.orientation
	local camera = {
		position = state.player.position + vec3.rotate(state.player.class.cameraOffset, orientation),
		orientation = orientation,
		fov = state.player.class.fov
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
	sceneShader:send("time", state.time)
	love.graphics.setShader(sceneShader)
	-- sceneShader:send("bayerMatrixSize", 8)
	-- sceneShader:send("bayerMatrix", love.graphics.newImage("bayer8.png"))
	love.graphics.draw(self.dummyTexture, 0, 0, 0, self.outputCanvas:getDimensions())

	love.graphics.setShader()
	love.graphics.setCanvas()
end

function graphics:draw(state, paused)
	if not paused then
		self:drawState(state)
	end
end

return graphics
