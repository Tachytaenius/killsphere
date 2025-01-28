local consts = require("consts")

local vec3 = require("lib.mathsies").vec3

local mul = consts.loadObjCoordMultiplier

return function(path)
	local geometry = {}
	local uv = {}
	local normal = {}
	local outVerts = {}

	local highestVertexDistance
	for line in love.filesystem.lines(path) do
		local item
		local isTri = false
		for word in line:gmatch("%S+") do
			if item then
				if isTri then
					local iterator = word:gmatch("%d+")
					local v = geometry[tonumber(iterator())]
					local vt = uv[tonumber(iterator())]
					local vn = normal[tonumber(iterator())]

					local pos = vec3(v[1], v[2], v[3]) * consts.loadObjCoordMultiplier
					local distance = #pos
					if not highestVertexDistance or highestVertexDistance < distance then
						highestVertexDistance = distance
					end
					local vert = { -- see consts.vertexFormat
						pos.x, pos.y, pos.z,
						vt[1], vt[2],
						vn[1] * mul.x, vn[2] * mul.y, vn[3] * mul.z
					}
					outVerts[#outVerts+1] = vert
				else
					item[#item+1] = tonumber(word)
				end
			elseif word == "#" then
				break
			elseif word == "s" then
				break
			elseif word == "v" then
				item = {}
				geometry[#geometry+1] = item
			elseif word == "vt" then
				item = {}
				uv[#uv+1] = item
			elseif word == "vn" then
				item = {}
				normal[#normal+1] = item
			elseif word == "f" then
				item = {}
				isTri = true
			else
				-- error("idk what \"" .. word .. "\" in \"" .. line .. "\" is, sorry")
			end
		end
	end

	local triangles = {}
	for i = 1, #outVerts, 3 do
		local triangle = {}

		local v1 = outVerts[i]
		local v2 = outVerts[i + 1]
		local v3 = outVerts[i + 2]
		triangle.v1 = vec3(v1[1], v1[2], v1[3])
		triangle.v2 = vec3(v2[1], v2[2], v2[3])
		triangle.v3 = vec3(v3[1], v3[2], v3[3])

		triangle.colour = {0, 0.5, 1}
		triangle.reflectivity = 0.4
		triangle.outlineColour = {1, 1, 1, 0.5}

		triangles[#triangles + 1] = triangle
	end

	return {
		geometry = geometry,
		uv = uv,
		normal = normal,
		vertices = outVerts,
		triangles = triangles,
		mesh = love.graphics.newMesh(consts.objectVertexFormat, outVerts, "triangles"),
		radius = highestVertexDistance
	}
end
