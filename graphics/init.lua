local consts = require("consts")

local graphics = {}

for _, moduleName in ipairs({
	"draw",
	"send",
	"updateVolumetrics"
}) do
	for k, v in pairs(require("graphics." .. moduleName)) do
		graphics[k] = v
	end
end

function graphics:init(state)
	love.graphics.setDefaultFilter("nearest", "nearest")
	local cw, ch = consts.canvasWidth, consts.canvasHeight
	self.outputCanvas = love.graphics.newCanvas(cw, ch)
	self.sceneShader = love.graphics.newShader(
		"#pragma language glsl4\n" ..

		love.filesystem.read("shaders/include/simplex4d.glsl") ..
		love.filesystem.read("shaders/include/raycasts.glsl") ..

		"const int maxSpheres = " .. consts.maxSpheres .. ";\n" ..
		"const int maxPlanes = " .. consts.maxPlanes .. ";\n" ..
		"const int maxBoundingSpheres = " .. consts.maxBoundingSpheres .. ";\n" ..
		"const int maxObjectTriangles = " .. consts.maxObjectTriangles .. ";\n" ..
		"const int maxLights = " .. consts.maxLights .. ";\n" ..
		"const int maxParticles = " .. consts.maxParticles .. ";\n" ..
		love.filesystem.read("shaders/include/objects.glsl") ..

		love.filesystem.read("shaders/scene.glsl")
	)
	self.dummyTexture = love.graphics.newImage(love.image.newImageData(1, 1))

	local fogTextureSideLength = math.floor(state.worldRadius * 2.0 / consts.fogDistancePerDatum)
	-- Colour is filtered manually so that voxels(?) without any scatterance don't influence anything during raytracing
	self.fogScatteranceAbsorptionCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rg16f",
		linear = true
	})
	self.fogScatteranceAbsorptionCanvas:setWrap("clamp", "clamp", "clamp")
	self.fogScatteranceAbsorptionCanvas:setFilter("linear", "linear")
	self.fogColourCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rgba16f"
	})
	self.fogColourCanvas:setWrap("clamp", "clamp", "clamp")
	self.fogEmissionCanvas = love.graphics.newCanvas(fogTextureSideLength, fogTextureSideLength, fogTextureSideLength, {
		type = "volume",
		computewrite = true,
		format = "rgba16f",
		linear = true -- TODO: Mixing colour and amount might need handling
	})
	self.fogEmissionCanvas:setWrap("clamp", "clamp", "clamp")
	self.fogEmissionCanvas:setFilter("linear", "linear")

	self.initialiseFogShader = love.graphics.newComputeShader(
		love.filesystem.read("shaders/include/simplex4d.glsl") ..
		love.filesystem.read("shaders/compute/initialiseFog.glsl")
	)
	self.initialiseFogShader:send("fogScatteranceAbsorption", self.fogScatteranceAbsorptionCanvas)
	self.initialiseFogShader:send("fogColour", self.fogColourCanvas)
	-- initialiseFogShader:send("fogEmission", fogEmissionCanvas)
	self.initialiseFogShader:send("worldRadius", state.worldRadius)
	local groupCount = math.ceil(fogTextureSideLength / self.initialiseFogShader:getLocalThreadgroupSize())
	-- love.graphics.dispatchThreadgroups(initialiseFogShader, groupCount, groupCount, groupCount)

	self.tickFogShader = love.graphics.newComputeShader(
		love.filesystem.read("shaders/include/simplex4d.glsl") ..
		love.filesystem.read("shaders/compute/tickFog.glsl")
	)
	self.tickFogMode = 0
	self.tickFogSkipCyclePosition = 0

	self.drawLineShader = love.graphics.newComputeShader("shaders/compute/drawLine.glsl")

	self.shadowMapShader = love.graphics.newShader("shaders/shadowMap.glsl")
	self.lightShadowMaps = {}
	for i = 1, consts.maxLights do
		self.lightShadowMaps[i] = love.graphics.newCanvas(consts.shadowMapSideLength, consts.shadowMapSideLength, {
			type = "cube",
			format = "r32f",
			linear = true
		})
	end
end

return graphics
