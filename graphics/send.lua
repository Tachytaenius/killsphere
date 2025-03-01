local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local mat4 = mathsies.mat4

local util = require("util")
local consts = require("consts")

local graphics = {}

function graphics:getObjectUniforms(state)
	local triangles, spheres, lights, particles, spherePortalPairs = {}, {}, {}, {}, {}

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

			local triangleStart = #triangles -- Starts at 0

			local modelToWorld, render = entity:getModelToWorldMatrix()
			if not render then
				goto continue
			end
			for _, triangle in ipairs(shape.triangles) do
				if #triangles >= consts.maxObjectTriangles then
					break
				end

				local v1 = modelToWorld * triangle.v1
				local v2 = modelToWorld * triangle.v2
				local v3 = modelToWorld * triangle.v3

				triangles[#triangles + 1] = {
					v1.x, v1.y, v1.z,
					v2.x, v2.y, v2.z,
					v3.x, v3.y, v3.z,
					triangle.colour[1], triangle.colour[2], triangle.colour[3],
					triangle.reflectivity,
					triangle.outlineColour[1], triangle.outlineColour[2], triangle.outlineColour[3], triangle.outlineColour[4],
					triangle.emissionColour[1], triangle.emissionColour[2], triangle.emissionColour[3],
					triangle.emissionAmount
				}
			end

			spheres[#spheres + 1] = {
				position = vec3.clone(entity.position),
				radius = shape.radius * entity:getRadiusScalar(),
				triangleStart = triangleStart,
				triangleCount = #triangles - triangleStart
			}
		end
	    ::continue::
	end

	for _, line in ipairs(state.linesToDraw) do
		if not line.drawSolid then
			goto continue
		end
		local triangleStart = #triangles

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
			if #triangles >= consts.maxObjectTriangles then
				return
			end
			triangles[#triangles + 1] = {
				v1.x, v1.y, v1.z,
				v2.x, v2.y, v2.z,
				v3.x, v3.y, v3.z,
				0, 0, 0,
				0,
				0, 0, 0, 0,
				line.emissionColour[1], line.emissionColour[2], line.emissionColour[3],
				1
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

		spheres[#spheres + 1] = {
			drawAlways = true,
			triangleStart = triangleStart,
			triangleCount = #triangles - triangleStart
		}

	    ::continue::
	end

	for particle in state.particles:elements() do
		if particle.draw then
			if #particles >= consts.maxParticles then
				break
			end

			local timeFalloff = 1 - particle.timeExisted / particle.lifetimeLength

			local radius = particle.drawRadius
			if particle.radiusFalloff then
				radius = radius * timeFalloff ^ (particle.radiusFalloffPower or 1)
			end

			local strength = particle.drawStrength
			if particle.strengthDiameterDivide then
				strength = strength / (radius * 2)
			end

			local drawColour
			if particle.drawColour == "fog" then
				drawColour = particle.fogColour
			elseif particle.drawColour == "emission" then
				drawColour = particle.emissionColour
			else
				error("Need to supply a draw colour type to drawn particle")
			end

			particles[#particles+1] = {
				radius,
				drawColour[1], drawColour[2], drawColour[3],
				strength,
				particle.position.x, particle.position.y, particle.position.z
			}
		end
	end

	for _, portalPair in ipairs(state.spherePortalPairs) do
		-- Assume enabled for now
		spherePortalPairs[#spherePortalPairs + 1] = {
			aPosition = portalPair.aPosition,
			bPosition = portalPair.bPosition,
			aColour = portalPair.aColour,
			bColour = portalPair.bColour,
			radius = portalPair.radius
		}
	end

	return triangles, spheres, lights, particles, spherePortalPairs
end

function graphics:sendSpherePortalPairs(set)
	local sceneShader = self.sceneShader
	sceneShader:send("spherePortalPairCount", math.min(consts.maxSpherePortalPairs, #set))
	for i, pair in ipairs(set) do
		if i > consts.maxSpherePortalPairs then
			break
		end
		local glslI = i - 1
		local prefix = "spherePortalPairs[" .. glslI .. "]."
		sceneShader:send(prefix .. "aPosition", {vec3.components(pair.aPosition)})
		sceneShader:send(prefix .. "bPosition", {vec3.components(pair.bPosition)})
		sceneShader:sendColor(prefix .. "aColour", pair.aColour)
		sceneShader:sendColor(prefix .. "bColour", pair.bColour)
		sceneShader:send(prefix .. "radius", pair.radius)
	end
end

function graphics:sendBoundingSpheres(set)
	local sceneShader = self.sceneShader
	sceneShader:send("boundingSphereCount", math.min(consts.maxBoundingSpheres, #set))
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
	sceneShader:send("lightCount", math.min(consts.maxLights, #set))
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
	local triangles, objectBoundingSpheres, lights, particles, spherePortalPairs = self:getObjectUniforms(state)

	if #triangles > 0 then
		self.objectTrianglesBuffer:setArrayData(triangles)
	end
	self.sceneShader:send("ObjectTriangles", self.objectTrianglesBuffer)

	self:sendBoundingSpheres(objectBoundingSpheres)
	self:sendLights(lights)

	if #particles > 0 then
		self.particlesBuffer:setArrayData(particles)
	end
	self.sceneShader:send("particleCount", #particles)
	self.sceneShader:send("Particles", self.particlesBuffer)

	self:sendSpherePortalPairs(spherePortalPairs)
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
				local modelToWorld, render = entityToDraw:getModelToWorldMatrix()
				if not render then
					goto continue
				end
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
