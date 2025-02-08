local mathsies = require("lib.mathsies")
local vec2 = mathsies.vec2
local vec3 = mathsies.vec3
local quat = mathsies.quat
local mat4 = mathsies.mat4

local util = require("util")
util.load()
local settings = require("settings")
local consts = require("consts")
local assets = require("assets")

local outputCanvas
local fogScatteranceAbsorptionCanvas, fogColourCanvas, fogEmissionCanvas
local dummyTexture
local sceneShader
local tickFogShader
local drawLaserShader
local lightShadowMaps
local shadowMapShader

local fogDistancePerDatum = 1 -- Higher means lower resolution fog
local fogSampleCountMultiplier = 2 -- Higher means more samples per ray
local lastUpdateDt
local tickFogMode
local tickFogModeCount = 6 -- This is not a setting to be tweaked. Tick fog's algorithm cycles between XYZ modes and then offset XYZ modes
local tickFogSkipCyclePosition
local tickFogSkipCycleLength = 8 -- Higher numbers mean fog ticking is spread out more over time, 1 means ticking every frame. Continuous effects will flicker a bit
local fogDoAllModes = true -- Go through both sets of XYZ modes in one frame

local state

function love.load()
	util.remakeWindow()

	love.graphics.setDefaultFilter("nearest", "nearest")

	assets.load()
	local cw, ch = consts.canvasWidth, consts.canvasHeight
	outputCanvas = love.graphics.newCanvas(cw, ch)
	sceneShader = love.graphics.newShader(
		"#pragma language glsl4\n" ..

		love.filesystem.read("shaders/include/simplex4d.glsl") ..
		love.filesystem.read("shaders/include/raycasts.glsl") ..

		"const int maxSpheres = " .. consts.maxSpheres .. ";\n" ..
		"const int maxPlanes = " .. consts.maxPlanes .. ";\n" ..
		"const int maxBoundingSpheres = " .. consts.maxBoundingSpheres .. ";\n" ..
		"const int maxObjectTriangles = " .. consts.maxObjectTriangles .. ";\n" ..
		"const int maxLights = " .. consts.maxLights .. ";\n" ..
		love.filesystem.read("shaders/include/objects.glsl") ..

		love.filesystem.read("shaders/scene.glsl")
	)
	dummyTexture = love.graphics.newImage(love.image.newImageData(1, 1))

	local testShipShape = util.newShape("shapes/testShip.obj")

	state = {}
	state.time = 0
	state.worldRadius = 100
	state.ambientLightAmount = 0.02
	state.ambientLightColour = {1, 1, 1}
	state.paused = false
	state.player = {
		type = "ship",
		allegience = "player",

		position = vec3(),
		velocity = vec3(),
		orientation = quat(),
		angularVelocity = vec3(),
		maxSpeed = 50,
		acceleration = 150,
		maxAngularSpeed = 2,
		angularAcceleration = 10,

		fov = math.rad(100)
	}
	state.entities = {state.player}
	for _=1, 1 do
		state.entities[#state.entities + 1] = {
			type = "ship",
			allegience = "enemy",

			position = vec3(0, 0, 20),
			velocity = vec3(),
			orientation = quat(),
			angularVelocity = vec3(),
			maxSpeed = 1,
			acceleration = 2,
			maxAngularSpeed = 0.1,
			angularAcceleration = 0.2,

			fov = math.rad(100),
			shape = testShipShape,
			scale = 2
		}
	end
	state.entities[#state.entities + 1] = {
		type = "light",
		position = vec3(0, 0, 0),
		velocity = vec3(0, 0.05, 0),
		lightColour = {1, 0.5, 0.5},
		lightIntensity = 400
	}

	local fogTextureSideLength = math.floor(state.worldRadius * 2.0 / fogDistancePerDatum)

	-- Colour is filtered manually so that voxels(?) without any scatterance don't influence anything during raytracing

	fogScatteranceAbsorptionCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rg16f",
		linear = true
	})
	fogScatteranceAbsorptionCanvas:setWrap("clamp", "clamp", "clamp")
	fogScatteranceAbsorptionCanvas:setFilter("linear", "linear")

	fogColourCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rgba16f"
	})
	fogColourCanvas:setWrap("clamp", "clamp", "clamp")

	fogEmissionCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rgba16f",
		linear = true -- TODO: Mixing colour and amount might need handling
	})
	fogEmissionCanvas:setWrap("clamp", "clamp", "clamp")
	fogScatteranceAbsorptionCanvas:setFilter("linear", "linear")

	local initialiseFogShader = love.graphics.newComputeShader(
		love.filesystem.read("shaders/include/simplex4d.glsl") ..
		love.filesystem.read("shaders/compute/initialiseFog.glsl")
	)
	initialiseFogShader:send("fogScatteranceAbsorption", fogScatteranceAbsorptionCanvas)
	initialiseFogShader:send("fogColour", fogColourCanvas)
	-- initialiseFogShader:send("fogEmission", fogEmissionCanvas)
	initialiseFogShader:send("worldRadius", state.worldRadius)
	local groupCount = math.ceil(fogTextureSideLength / initialiseFogShader:getLocalThreadgroupSize())
	-- love.graphics.dispatchThreadgroups(initialiseFogShader, groupCount, groupCount, groupCount)

	tickFogShader = love.graphics.newComputeShader(
		love.filesystem.read("shaders/include/simplex4d.glsl") ..
		love.filesystem.read("shaders/compute/tickFog.glsl")
	)
	tickFogMode = 0
	tickFogSkipCyclePosition = 0

	drawLaserShader = love.graphics.newComputeShader("shaders/compute/drawLaser.glsl")

	shadowMapShader = love.graphics.newShader("shaders/shadowMap.glsl")
	lightShadowMaps = {}
	for i = 1, consts.maxLights do
		lightShadowMaps[i] = love.graphics.newCanvas(consts.shadowMapSideLength, consts.shadowMapSideLength, {
			type = "cube",
			format = "r32f",
			linear = true
		})
	end
end

local function updateState(dt)
	local player = state.player

	if player then
		local translation = vec3()
		if love.keyboard.isDown("d") then translation = translation + consts.rightVector end
		if love.keyboard.isDown("a") then translation = translation - consts.rightVector end
		if love.keyboard.isDown("e") then translation = translation + consts.upVector end
		if love.keyboard.isDown("q") then translation = translation - consts.upVector end
		if love.keyboard.isDown("w") then translation = translation + consts.forwardVector end
		if love.keyboard.isDown("s") then translation = translation - consts.forwardVector end
		-- TODO: Way better movement system
		local targetVelocity = vec3.rotate(util.normaliseOrZero(translation), player.orientation) * player.maxSpeed
		player.velocity = util.moveVectorToTarget(player.velocity, targetVelocity, player.acceleration, dt)

		local rotation = vec3()
		if love.keyboard.isDown("k") then rotation = rotation + consts.rightVector end
		if love.keyboard.isDown("i") then rotation = rotation - consts.rightVector end
		if love.keyboard.isDown("l") then rotation = rotation + consts.upVector end
		if love.keyboard.isDown("j") then rotation = rotation - consts.upVector end
		if love.keyboard.isDown("u") then rotation = rotation + consts.forwardVector end
		if love.keyboard.isDown("o") then rotation = rotation - consts.forwardVector end
		-- TODO: Way better movement system
		local targetAngularVelocity = util.normaliseOrZero(rotation) * player.maxAngularSpeed
		player.angularVelocity = util.moveVectorToTarget(player.angularVelocity, targetAngularVelocity, player.angularAcceleration, dt)

		if love.keyboard.isDown("space") then
			local num = 2
			for i = 0, num - 1 do
				local x = util.lerp(-2, 2, i / (num - 1))
				local relativeOffset = vec3(x, -2, 2)
				local rotation = player.orientation
				local laserStart = vec3.clone(player.position + vec3.rotate(relativeOffset, rotation))
				local laserLength = 200
				local laserDirection = vec3.rotate(consts.forwardVector, rotation)
				local laserEnd = laserStart + laserLength * laserDirection
				local laserSteps = 1024
				drawLaserShader:send("fogEmission", fogEmissionCanvas)
				drawLaserShader:send("worldRadius", state.worldRadius)
				drawLaserShader:send("lineStart", {vec3.components(laserStart)})
				drawLaserShader:send("lineEnd", {vec3.components(laserEnd)})
				drawLaserShader:send("lineSteps", laserSteps)
				local r, g, b = 0.1, 1, 1
				local strength = 2000
				drawLaserShader:send("lineColour", {r * strength * dt, g * strength * dt, b * strength * dt})
				love.graphics.dispatchThreadgroups(drawLaserShader, math.ceil(laserSteps / drawLaserShader:getLocalThreadgroupSize()))
			end
		end
	end

	for _, entity in ipairs(state.entities) do
		-- Extremely TODO/TEMP:
		if entity ~= player and entity.type == "ship" then
			local translation = vec3(0, 0, 1)
			local targetVelocity = vec3.rotate(util.normaliseOrZero(translation), entity.orientation) * entity.maxSpeed
			entity.velocity = util.moveVectorToTarget(entity.velocity, targetVelocity, entity.acceleration, dt)
			local rotation = vec3.normalise(vec3(1, 1, 0.2))
			local targetAngularVelocity = util.normaliseOrZero(rotation) * entity.maxAngularSpeed
			entity.angularVelocity = util.moveVectorToTarget(entity.angularVelocity, targetAngularVelocity, entity.angularAcceleration, dt)
		end

		entity.position = entity.position + entity.velocity * dt
		if #entity.position >= state.worldRadius then
			local difference = #entity.position - state.worldRadius
			entity.position = -vec3.normalise(entity.position) * (state.worldRadius - difference)
		end
		if entity.orientation then
			entity.orientation = quat.normalise(entity.orientation * quat.fromAxisAngle(entity.angularVelocity * dt))
		end
	end

	state.time = state.time + dt
end

function love.update(dt)
	if not state.paused then
		updateState(dt)
	end
	lastUpdateDt = dt -- For draw
end

local function sendTriangles(set)
	-- sceneShader:send("objectTriangleCount", #set)
	for i, triangle in ipairs(set) do
		local glslI = i - 1
		local prefix = "objectTriangles[" .. glslI .. "]."
		sceneShader:send(prefix .. "v1", {vec3.components(triangle.v1)})
		sceneShader:send(prefix .. "v2", {vec3.components(triangle.v2)})
		sceneShader:send(prefix .. "v3", {vec3.components(triangle.v3)})
		sceneShader:sendColor(prefix .. "colour", triangle.colour)
		sceneShader:send(prefix .. "reflectivity", triangle.reflectivity)
		sceneShader:sendColor(prefix .. "outlineColour", triangle.outlineColour)
	end
end

local function getObjectUniforms(tris)
	local spheres, lights = {}, {}
	for _, entity in ipairs(state.entities) do
		if entity.type == "light" then
			lights[#lights + 1] = {
				position = vec3.clone(entity.position),
				intensity = entity.lightIntensity,
				colour = util.shallowClone(entity.lightColour)
			}
		else
			if entity == state.player then
				goto continue
			end
			if not entity.shape then
				goto continue
			end
			spheres[#spheres + 1] = {
				position = vec3.clone(entity.position),
				radius = entity.scale * entity.shape.radius,
				triangleStart = #tris, -- Starts at 0
				triangleCount = #entity.shape.triangles
			}
			local modelToWorld = mat4.transform(entity.position, entity.orientation, entity.scale)
			for _, triangle in ipairs(entity.shape.triangles) do
				tris[#tris + 1] = {
					v1 = modelToWorld * triangle.v1,
					v2 = modelToWorld * triangle.v2,
					v3 = modelToWorld * triangle.v3,
					colour = util.shallowClone(triangle.colour),
					reflectivity = triangle.reflectivity,
					outlineColour = util.shallowClone(triangle.outlineColour)
				}
			end
		end
	    ::continue::
	end
	return spheres, lights
end

local function sendBoundingSpheres(set)
	sceneShader:send("boundingSphereCount", #set)
	for i, boundingSphere in ipairs(set) do
		local glslI = i - 1
		local prefix = "boundingSpheres[" .. glslI .. "]."
		sceneShader:send(prefix .. "position", {vec3.components(boundingSphere.position)})
		sceneShader:send(prefix .. "radius", boundingSphere.radius)
		sceneShader:send(prefix .. "triangleStart", boundingSphere.triangleStart)
		sceneShader:send(prefix .. "triangleCount", boundingSphere.triangleCount)
	end
end

local function sendLights(set)
	sceneShader:send("lightCount", #set)
	for i, light in ipairs(set) do
		local glslI = i - 1
		local prefix = "lights[" .. glslI .. "]."
		sceneShader:send(prefix .. "position", {vec3.components(light.position)})
		sceneShader:sendColor(prefix .. "colour", light.colour)
		sceneShader:send(prefix .. "intensity", light.intensity)
	end
end

local function sendObjects()
	local trisSet = {}
	local objectBoundingSpheres, lights = getObjectUniforms(trisSet)
	sendTriangles(trisSet)
	sendBoundingSpheres(objectBoundingSpheres)
	sendLights(lights)
end

local function drawAndSendLightShadowMaps()
	love.graphics.push("all")
	love.graphics.setShader(shadowMapShader)
	love.graphics.setBlendMode("darken", "premultiplied") -- Closer is saved
	local i = 1
	for _, entity in ipairs(state.entities) do
		if entity.type ~= "light" then
			goto continue
		end
		local cameraToClip = mat4.perspectiveLeftHanded(
			1,
			consts.tau / 4,
			consts.farPlaneDistance,
			consts.nearPlaneDistance
		)
		shadowMapShader:send("cameraPosition", {vec3.components(entity.position)})
		for side, orientation in ipairs(consts.cubemapOrientationsYFlip) do
			love.graphics.setCanvas(lightShadowMaps[i], side)
			love.graphics.clear(math.huge, 0, 0)
			local worldToCamera = mat4.camera(
				entity.position,
				orientation
			)
			local worldToClip = cameraToClip * worldToCamera
			for _, entityToDraw in ipairs(state.entities) do
				if not entityToDraw.shape then
					goto continue
				end
				local modelToWorld = mat4.transform(entityToDraw.position, entityToDraw.orientation, entityToDraw.scale)
				local modelToClip = worldToClip * modelToWorld
				shadowMapShader:send("modelToWorld", {mat4.components(modelToWorld)})
				shadowMapShader:send("modelToClip", {mat4.components(modelToClip)})
				love.graphics.draw(entityToDraw.shape.mesh)
			    ::continue::
			end
		end
		i = i + 1
		if i > consts.maxLights then
			break
		end
	    ::continue::
	end
	sceneShader:send("lightShadowMaps", unpack(lightShadowMaps))
	love.graphics.pop()
end

local function drawState(lastUpdateDt)
	local drawTime = state.time - lastUpdateDt

	local camera = state.player

	local worldToCamera = mat4.camera(camera.position, camera.orientation)
	local worldToCameraStationary = mat4.camera(vec3(), camera.orientation)
	local cameraToClip = mat4.perspectiveLeftHanded(
		outputCanvas:getWidth() / outputCanvas:getHeight(),
		camera.fov,
		consts.farPlaneDistance,
		consts.nearPlaneDistance
	)
	local worldToClip = cameraToClip * worldToCamera
	local clipToSky = mat4.inverse(cameraToClip * worldToCameraStationary)
	local cameraForwardVector = vec3.rotate(consts.forwardVector, camera.orientation)

	love.graphics.setCanvas(outputCanvas)
	love.graphics.clear()

	sendObjects()
	drawAndSendLightShadowMaps()
	sceneShader:send("arenaRadius", state.worldRadius)
	sceneShader:send("clipToSky", {mat4.components(clipToSky)})
	sceneShader:send("cameraPosition", {vec3.components(camera.position)})
	sceneShader:send("cameraForwardVector", {vec3.components(cameraForwardVector)})
	sceneShader:send("cameraFOV", camera.fov)
	sceneShader:send("maxRaySegments", 5)
	sceneShader:send("outlineThicknessFactor", 0.1 + 0.01 * math.sin(state.time * 10.0))
	sceneShader:send("fogScatteranceAbsorption", fogScatteranceAbsorptionCanvas)
	sceneShader:send("fogColour", fogColourCanvas)
	sceneShader:send("fogEmission", fogEmissionCanvas)
	sceneShader:send("fogDistancePerSample", fogDistancePerDatum / fogSampleCountMultiplier)
	sceneShader:sendColor("ambientLightColour", state.ambientLightColour)
	sceneShader:send("ambientLightAmount", state.ambientLightAmount)
	-- sceneShader:send("time", state.time)
	love.graphics.setShader(sceneShader)
	-- sceneShader:send("bayerMatrixSize", 8)
	-- sceneShader:send("bayerMatrix", love.graphics.newImage("bayer8.png"))
	love.graphics.draw(dummyTexture, 0, 0, 0, outputCanvas:getDimensions())

	tickFogShader:send("fogScatteranceAbsorption", fogScatteranceAbsorptionCanvas)
	tickFogShader:send("fogEmission", fogEmissionCanvas)
	tickFogShader:send("fogColour", fogColourCanvas)
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
	local fogTextureSideLength = fogScatteranceAbsorptionCanvas:getWidth()
	local w, h, d = tickFogShader:getLocalThreadgroupSize()
	tickFogSkipCyclePosition = (tickFogSkipCyclePosition + 1) % tickFogSkipCycleLength
	tickFogShader:send("workGroupIdMultiply", {tickFogSkipCycleLength, 1, 1})
	tickFogShader:send("workGroupIdAdd", {tickFogSkipCyclePosition, 0, 0})
	local x, y, z =
		math.ceil(fogTextureSideLength / (w * tickFogSkipCycleLength)),
		math.ceil(fogTextureSideLength / h),
		math.ceil(fogTextureSideLength / (d * 2))
	local fogDt = lastUpdateDt * tickFogSkipCycleLength
	if fogDoAllModes then
		fogDt = fogDt / tickFogModeCount
		tickFogShader:send("dt", fogDt)
		for i = 0, tickFogModeCount - 1 do
			tickFogShader:send("tickFogMode", i)
			love.graphics.dispatchThreadgroups(tickFogShader, x, y, z)
		end
	else
		tickFogShader:send("dt", fogDt)
		tickFogMode = (tickFogMode + 1) % tickFogModeCount
		tickFogShader:send("tickFogMode", tickFogMode)
		love.graphics.dispatchThreadgroups(tickFogShader, x, y, z)
	end

	love.graphics.setShader()
	love.graphics.setCanvas()
end

function love.draw()
	drawState(lastUpdateDt)
	local x, y =
		(love.graphics.getWidth() - consts.canvasWidth * settings.graphics.canvasScale) / 2,
		(love.graphics.getHeight() - consts.canvasHeight * settings.graphics.canvasScale) / 2
	love.graphics.draw(outputCanvas, x, y, 0, settings.graphics.canvasScale)
	love.graphics.print(love.timer.getFPS())
end
