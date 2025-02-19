#line 1

struct BoundingSphere {
	vec3 position;
	float radius;
	int triangleStart;
	int triangleCount;
	bool drawAlways;
};

struct ObjectTriangle {
	vec3 v1;
	vec3 v2;
	vec3 v3;
	vec3 colour;
	float reflectivity;
	vec4 outlineColour;
	vec3 emissionColour;
	float emissionAmount;
};

struct Light {
	float intensity;
	vec3 colour;
	vec3 position;
};

struct Particle {
	float radius;
	vec3 colour;
	float strength;
	vec3 position;
};

struct SpherePortalPair {
	vec3 aPosition;
	vec3 bPosition;
	vec3 aColour;
	vec3 bColour;
	float radius;
};

// maxLights, maxSpherePortalPairs etc definitions should be concatenated before

uniform int boundingSphereCount;
uniform BoundingSphere[maxBoundingSpheres] boundingSpheres;

readonly buffer ObjectTriangles {
	ObjectTriangle objectTriangles[];
};

uniform int lightCount;
uniform Light[maxLights] lights;
uniform samplerCube[maxLights] lightShadowMaps;

uniform int particleCount;
readonly buffer Particles {
	Particle particles[];
};

uniform int spherePortalPairCount;
uniform SpherePortalPair[maxSpherePortalPairs] spherePortalPairs;
