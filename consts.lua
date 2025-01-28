local vec3 = require("lib.mathsies").vec3

local consts = {}

consts.loveIdentity = "spaceshot"
consts.loveVersion = "12.0"
consts.windowTitle = "Spaceshot"

consts.tau = math.pi * 2

consts.rightVector = vec3(1, 0, 0)
consts.upVector = vec3(0, 1, 0)
consts.forwardVector = vec3(0, 0, 1)

consts.canvasWidth = 256
consts.canvasHeight = 256

consts.nearPlaneDistance = 0.001
consts.farPlaneDistance = 1000

consts.maxSpheres = 64
consts.maxPlanes = 8
consts.maxBoundingSpheres = 32
consts.maxObjectTriangles = 256

consts.loadObjCoordMultiplier = vec3(1, 1, -1) -- Export OBJs from Blender with +Y up and +Z forward -- TODO: Why is this needed?
consts.objectVertexFormat = {
	{name = "VertexPosition", format = "floatvec3"},
	{name = "VertexTexCoord", format = "floatvec2"},
	{name = "VertexNormal", format = "floatvec3"},
}

return consts
