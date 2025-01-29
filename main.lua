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

local fogTextureCoordScale
local lastUpdateDt
local tickFogMode
local tickFogModeCount = 6

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
		love.filesystem.read("shaders/include/objects.glsl") ..

		love.filesystem.read("shaders/scene.glsl")
	)
	dummyTexture = love.graphics.newImage(love.image.newImageData(1, 1))

	local testShipShape = util.newShape("shapes/testShip.obj")

	state = {}
	state.time = 0
	state.worldRadius = 250
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

			position = vec3(20),
			velocity = vec3(),
			orientation = quat(),
			angularVelocity = vec3(),
			maxSpeed = 50,
			acceleration = 150,
			maxAngularSpeed = 2,
			angularAcceleration = 10,

			fov = math.rad(100),
			shape = testShipShape,
			scale = 5
		}
	end

	fogTextureCoordScale = 2
	local fogTextureSideLength = math.floor(state.worldRadius * 2.0 / fogTextureCoordScale)
	fogScatteranceAbsorptionCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rg16f"
	})
	fogScatteranceAbsorptionCanvas:setWrap("clamp", "clamp", "clamp")
	fogScatteranceAbsorptionCanvas:setFilter("linear", "linear")
	fogColourCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rgba8"
	})
	fogColourCanvas:setWrap("clamp", "clamp", "clamp")
	fogColourCanvas:setFilter("linear", "linear")
	fogEmissionCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rgba16f"
	})
	fogEmissionCanvas:setWrap("clamp", "clamp", "clamp")
	fogEmissionCanvas:setFilter("linear", "linear")

	local initialiseFogShader = love.graphics.newComputeShader(
		love.filesystem.read("shaders/include/simplex4d.glsl") ..
		love.filesystem.read("shaders/compute/initialiseFog.glsl")
	)
	initialiseFogShader:send("fogScatteranceAbsorption", fogScatteranceAbsorptionCanvas)
	initialiseFogShader:send("fogColour", fogColourCanvas)
	initialiseFogShader:send("worldRadius", state.worldRadius)
	local groupCount = math.ceil(fogTextureSideLength ^ 3 / initialiseFogShader:getLocalThreadgroupSize())
	love.graphics.dispatchThreadgroups(initialiseFogShader, groupCount)

	tickFogShader = love.graphics.newComputeShader("shaders/compute/tickFog.glsl")
	tickFogMode = 0
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
	end

	player.position = player.position + player.velocity * dt
	if #player.position >= state.worldRadius then
		local difference = #player.position - state.worldRadius
		player.position = -vec3.normalise(player.position) * (state.worldRadius - difference)
	end
	player.orientation = quat.normalise(player.orientation * quat.fromAxisAngle(player.angularVelocity * dt))

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
	local spheres = {}
	for _, entity in ipairs(state.entities) do
		if entity == state.player then
			goto continue
		end
		if not entity.shape then
			goto continue
		end
		spheres[#spheres + 1] = {
			position = entity.position,
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
	    ::continue::
	end
	return spheres
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

local function sendObjects()
	local trisSet = {}
	local objectBoundingSpheres = getObjectUniforms(trisSet)
	sendTriangles(trisSet)
	sendBoundingSpheres(objectBoundingSpheres)
end

local function drawState(lastUpdateDt)
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
	love.graphics.setShader(sceneShader)
	love.graphics.draw(dummyTexture, 0, 0, 0, outputCanvas:getDimensions())

	tickFogShader:send("fogScatteranceAbsorption", fogScatteranceAbsorptionCanvas)
	-- tickFogShader:send("fogColour", fogColourCanvas)
	-- tickFogShader:send("worldRadius", state.worldRadius)
	tickFogShader:send("dt", lastUpdateDt)
	tickFogShader:send("scatteranceDifferenceDecay", 6)
	tickFogShader:send("absorptionDifferenceDecay", 6)
	tickFogShader:send("scatteranceDecay", 1)
	tickFogShader:send("absorptionDecay", 1)
	tickFogShader:send("tickFogMode", tickFogMode)
	local fogTextureSideLength = fogScatteranceAbsorptionCanvas:getWidth()
	local groupCount = math.ceil(fogTextureSideLength ^ 3 / 1 / tickFogShader:getLocalThreadgroupSize())
	love.graphics.dispatchThreadgroups(tickFogShader, groupCount)
	tickFogMode = (tickFogMode + 1) % tickFogModeCount

	love.graphics.setShader()
	love.graphics.setCanvas()
end

function love.draw()
	drawState(lastUpdateDt)
	local x, y =
		(love.graphics.getWidth() - consts.canvasWidth * settings.graphics.canvasScale) / 2,
		(love.graphics.getHeight() - consts.canvasHeight * settings.graphics.canvasScale) / 2
	love.graphics.draw(outputCanvas, x, y, 0, settings.graphics.canvasScale)
end
