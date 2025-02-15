local mathsies = require("lib.mathsies")
local vec3 = mathsies.vec3
local quat = mathsies.quat

local consts = {}

consts.loveIdentity = "killsphere"
consts.loveVersion = "12.0"
consts.windowTitle = "† †  K  I  L  L  S  P  H  E  R  E  † †"

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
consts.maxBoundingSpheres = 64
consts.maxObjectTriangles = 1024
consts.maxLights = 2
consts.maxParticles = 256
consts.maxSpherePortalPairs = 4

consts.loadObjCoordMultiplier = vec3(1, 1, -1) -- Export OBJs from Blender with +Y up and +Z forward -- TODO: Why is this needed?
consts.objectVertexFormat = {
	{name = "VertexPosition", location = 0, format = "floatvec3"},
	{name = "VertexTexCoord", location = 1, format = "floatvec2"},
	{name = "VertexNormal", location = 2, format = "floatvec3"}
}

consts.cubemapOrientations = {
	quat.fromAxisAngle(consts.upVector * consts.tau * 0.25),
	quat.fromAxisAngle(consts.upVector * consts.tau * -0.25),
	quat.fromAxisAngle(consts.rightVector * consts.tau * 0.25),
	quat.fromAxisAngle(consts.rightVector * consts.tau * -0.25),
	quat(),
	quat.fromAxisAngle(consts.upVector * consts.tau * 0.5)
}
consts.cubemapOrientationsYFlip = {}
for i, v in ipairs(consts.cubemapOrientations) do
	consts.cubemapOrientationsYFlip[i] = v
end
consts.cubemapOrientationsYFlip[3], consts.cubemapOrientationsYFlip[4] = consts.cubemapOrientationsYFlip[4], consts.cubemapOrientationsYFlip[3]

consts.shadowMapSideLength = 1024

consts.fogDistancePerDatum = 0.7 -- Higher means lower resolution fog
consts.fogSampleCountMultiplier = 1 -- Higher means more samples per ray
consts.tickFogModeCount = 6 -- This is not a setting to be tweaked. Tick fog's algorithm cycles between XYZ modes and then offset XYZ modes
consts.tickFogSkipCycleLength = 8 -- Higher numbers mean fog ticking is spread out more over time, 1 means ticking every frame. Continuous effects will flicker a bit
consts.fogDoAllModes = true -- Go through both sets of XYZ modes in one frame

consts.boundarySphereBounciness = 0.25
consts.gunSparkTimerLength = 1 / 45

return consts
