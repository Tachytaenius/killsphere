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
		if i > consts.maxObjectTriangles then
			break
		end
		local glslI = i - 1
		local prefix = "objectTriangles[" .. glslI .. "]."
		sceneShader:send(prefix .. "v1", {vec3.components(triangle.v1)})
		sceneShader:send(prefix .. "v2", {vec3.components(triangle.v2)})
		sceneShader:send(prefix .. "v3", {vec3.components(triangle.v3)})
		sceneShader:sendColor(prefix .. "colour", triangle.colour)
		sceneShader:send(prefix .. "reflectivity", triangle.reflectivity)
		sceneShader:sendColor(prefix .. "outlineColour", triangle.outlineColour)
		sceneShader:sendColor(prefix .. "emissionColour", triangle.emissionColour)
		sceneShader:send(prefix .. "emissionAmount", triangle.emissionAmount)
	end
end

function graphics:getObjectUniforms(state, tris)
	local spheres, lights, particles = {}, {}, {}

	for entity in state.entities:elements() do
		if entity.class.type == "light" then
			lights[#lights + 1] = {
				position = vec3.clone(entity.position),
				intensity = entity.lightIntensity,
				colour = util.shallowClone(entity.lightColour)
			}
		else
			-- if entity == state.player then
			-- 	goto continue
			-- end
			local shape = entity.class.shape
			if not shape then
				goto continue
			end
			spheres[#spheres + 1] = {
				position = vec3.clone(entity.position),
				radius = shape.radius,
				triangleStart = #tris, -- Starts at 0
				triangleCount = #shape.triangles
			}
			local modelToWorld = mat4.transform(entity.position, entity.orientation)
			for _, triangle in ipairs(shape.triangles) do
				tris[#tris + 1] = {
					v1 = modelToWorld * triangle.v1,
					v2 = modelToWorld * triangle.v2,
					v3 = modelToWorld * triangle.v3,
					colour = util.shallowClone(triangle.colour),
					reflectivity = triangle.reflectivity,
					outlineColour = util.shallowClone(triangle.outlineColour),
					emissionColour = util.shallowClone(triangle.emissionColour),
					emissionAmount = triangle.emissionAmount
				}
			end
		end
	    ::continue::
	end

	for _, line in ipairs(state.linesToDraw) do
		if not line.drawSolid then
			goto continue
		end
		spheres[#spheres + 1] = {
			drawAlways = true,
			triangleStart = #tris,
			triangleCount = 2 + 3 * 2 -- 2 end triangles, connected by 3 rectangles with 2 triangles each
		}
		local forwards = vec3.normalise(line.endPosition - line.startPosition)
		local up = line.solidUpVector
		local right = vec3.cross(forwards, up)
		local r = line.solidRadius

		-- Top vertex
		local v1 =
			line.startPosition +
			right * 0 + -- x
			up * r -- y

		-- Bottom vertex 1
		local v2 =
			line.startPosition +
			right * r * math.sin(consts.tau / 3) + -- x
			up * r * math.cos(consts.tau / 3) -- y

		-- Bottom vertex 2
		local v3 =
			line.startPosition +
			right * r * math.sin(2 * consts.tau / 3) + -- x
			up * r * math.cos(2 * consts.tau / 3) -- y

		local z = line.endPosition - line.startPosition
		local function addTri(v1, v2, v3)
			tris[#tris + 1] = {
				v1 = v1,
				v2 = v2,
				v3 = v3,
				colour = {0, 0, 0},
				reflectivity = 0,
				outlineColour = {0, 0, 0, 0},
				emissionColour = line.emissionColour,
				emissionAmount = 1
			}
		end
		addTri(v1, v2, v3)
		addTri(v1 + z, v2 + z, v3 + z)
		addTri(v1, v1 + z, v2)
		addTri(v1 + z, v2 + z, v2)
		addTri(v2, v2 + z, v3)
		addTri(v2 + z, v3 + z, v3)
		addTri(v3, v3 + z, v1)
		addTri(v3 + z, v1 + z, v1)

	    ::continue::
	end

	for particle in state.particles:elements() do
		if particle.draw then
			local strength = particle.drawStrength
			if particle.strengthDiameterDivide then
				strength = strength / (particle.drawRadius * 2)
			end
			local radius = particle.drawRadius
			if particle.radiusFalloff then
				radius = radius * (1 - particle.timeExisted / particle.lifetimeLength)
			end
			particles[#particles+1] = {
				strength = strength,
				radius = radius,
				colour = particle.emissionColour,
				position = particle.position
			}
		end
	end

	return spheres, lights, particles
end

function graphics:sendParticles(set)
	local sceneShader = self.sceneShader
	sceneShader:send("particleCount", #set)
	for i, particle in ipairs(set) do
		if i > consts.maxParticles then
			break
		end
		local glslI = i - 1
		local prefix = "particles[" .. glslI .. "]."
		sceneShader:send(prefix .. "position", {vec3.components(particle.position)})
		sceneShader:send(prefix .. "radius", particle.radius)
		sceneShader:send(prefix .. "strength", particle.strength)
		sceneShader:sendColor(prefix .. "colour", particle.colour)
	end
end

function graphics:sendBoundingSpheres(set)
	local sceneShader = self.sceneShader
	sceneShader:send("boundingSphereCount", #set)
	for i, boundingSphere in ipairs(set) do
		if i > consts.maxBoundingSpheres then
			break
		end
		local glslI = i - 1
		local prefix = "boundingSpheres[" .. glslI .. "]."
		if boundingSphere.drawAlways then
			sceneShader:send(prefix .. "drawAlways", true)
		else
			sceneShader:send(prefix .. "drawAlways", false)
			sceneShader:send(prefix .. "position", {vec3.components(boundingSphere.position)})
			sceneShader:send(prefix .. "radius", boundingSphere.radius)
		end
		sceneShader:send(prefix .. "triangleStart", boundingSphere.triangleStart)
		sceneShader:send(prefix .. "triangleCount", boundingSphere.triangleCount)
	end
end

function graphics:sendLights(set)
	local sceneShader = self.sceneShader
	sceneShader:send("lightCount", #set)
	for i, light in ipairs(set) do
		if i > consts.maxLights then
			break
		end
		local glslI = i - 1
		local prefix = "lights[" .. glslI .. "]."
		sceneShader:send(prefix .. "position", {vec3.components(light.position)})
		sceneShader:sendColor(prefix .. "colour", light.colour)
		sceneShader:send(prefix .. "intensity", light.intensity)
	end
end

function graphics:sendObjects(state)
	local trisSet = {}
	local objectBoundingSpheres, lights, particles = self:getObjectUniforms(state, trisSet)
	self:sendTriangles(trisSet)
	self:sendBoundingSpheres(objectBoundingSpheres)
	self:sendLights(lights)
	self:sendParticles(particles)
end

function graphics:drawAndSendLightShadowMaps(state)
	love.graphics.push("all")
	love.graphics.setShader(self.shadowMapShader)
	love.graphics.setBlendMode("darken", "premultiplied") -- Closer is saved
	local i = 1
	local cameraToClip = mat4.perspectiveLeftHanded(
		1,
		consts.tau / 4,
		consts.farPlaneDistance,
		consts.nearPlaneDistance
	)
	for entity in state.entities:elements() do
		if entity.class.type ~= "light" then
			goto continue
		end
		self.shadowMapShader:send("cameraPosition", {vec3.components(entity.position)})
		for side, orientation in ipairs(consts.cubemapOrientationsYFlip) do
			love.graphics.setCanvas(self.lightShadowMaps[i], side)
			love.graphics.clear(math.huge, 0, 0)
			local worldToCamera = mat4.camera(
				entity.position,
				orientation
			)
			local worldToClip = cameraToClip * worldToCamera
			for entityToDraw in state.entities:elements() do
				if not entityToDraw.class.shape then
					goto continue
				end
				local modelToWorld = mat4.transform(entityToDraw.position, entityToDraw.orientation)
				local modelToClip = worldToClip * modelToWorld
				self.shadowMapShader:send("modelToWorld", {mat4.components(modelToWorld)})
				self.shadowMapShader:send("modelToClip", {mat4.components(modelToClip)})
				love.graphics.draw(entityToDraw.class.shape.mesh)
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
