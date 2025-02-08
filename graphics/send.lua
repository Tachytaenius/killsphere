local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local mat4 = mathsies.mat4

local util = require("util")
local consts = require("consts")

local graphics = {}

function graphics:sendTriangles(set)
	local sceneShader = self.sceneShader
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

function graphics:getObjectUniforms(state, tris)
	local spheres, lights = {}, {}
	for _, entity in ipairs(state.entities) do
		if entity.type == "light" then
			lights[#lights + 1] = {
				position = vec3.clone(entity.position),
				intensity = entity.lightIntensity,
				colour = util.shallowClone(entity.lightColour)
			}
		else
			-- if entity == state.player then
			-- 	goto continue
			-- end
			if not entity.shape then
				goto continue
			end
			spheres[#spheres + 1] = {
				position = vec3.clone(entity.position),
				radius = entity.shape.geometry.radius,
				triangleStart = #tris, -- Starts at 0
				triangleCount = #entity.shape.geometry.triangles
			}
			local modelToWorld = mat4.transform(entity.position, entity.orientation)
			for _, triangle in ipairs(entity.shape.geometry.triangles) do
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

function graphics:sendBoundingSpheres(set)
	local sceneShader = self.sceneShader
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

function graphics:sendLights(set)
	local sceneShader = self.sceneShader
	sceneShader:send("lightCount", #set)
	for i, light in ipairs(set) do
		local glslI = i - 1
		local prefix = "lights[" .. glslI .. "]."
		sceneShader:send(prefix .. "position", {vec3.components(light.position)})
		sceneShader:sendColor(prefix .. "colour", light.colour)
		sceneShader:send(prefix .. "intensity", light.intensity)
	end
end

function graphics:sendObjects(state)
	local trisSet = {}
	local objectBoundingSpheres, lights = self:getObjectUniforms(state, trisSet)
	self:sendTriangles(trisSet)
	self:sendBoundingSpheres(objectBoundingSpheres)
	self:sendLights(lights)
end

function graphics:drawAndSendLightShadowMaps(state)
	love.graphics.push("all")
	love.graphics.setShader(self.shadowMapShader)
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
		self.shadowMapShader:send("cameraPosition", {vec3.components(entity.position)})
		for side, orientation in ipairs(consts.cubemapOrientationsYFlip) do
			love.graphics.setCanvas(self.lightShadowMaps[i], side)
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
				local modelToWorld = mat4.transform(entityToDraw.position, entityToDraw.orientation)
				local modelToClip = worldToClip * modelToWorld
				self.shadowMapShader:send("modelToWorld", {mat4.components(modelToWorld)})
				self.shadowMapShader:send("modelToClip", {mat4.components(modelToClip)})
				love.graphics.draw(entityToDraw.shape.geometry.mesh)
			    ::continue::
			end
		end
		i = i + 1
		if i > consts.maxLights then
			break
		end
	    ::continue::
	end
	self.sceneShader:send("lightShadowMaps", unpack(self.lightShadowMaps))
	love.graphics.pop()
end

return graphics
