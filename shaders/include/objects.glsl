#line 1

struct Sphere {
	vec3 position;
	float radius;
	vec3 colour;
	float emission;
};

struct Plane {
	vec3 normal;
	float dist;
	vec3 colour;
};

struct BoundingSphere {
	vec3 position;
	float radius;
	int triangleStart;
	int triangleCount;
};

struct ObjectTriangle { // Not tested against directly
	vec3 v1;
	vec3 v2;
	vec3 v3;
	vec3 colour;
	float reflectivity;
	vec4 outlineColour;
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

// maxSpheres, maxPlanes, etc definitions should be concatenated before

uniform int sphereCount;
uniform Sphere[maxSpheres] spheres;

uniform int planeCount;
uniform Plane[maxPlanes] planes;

uniform int boundingSphereCount;
uniform BoundingSphere[maxBoundingSpheres] boundingSpheres;

uniform int objectTriangleCount;
uniform ObjectTriangle[maxObjectTriangles] objectTriangles;

uniform int lightCount;
uniform Light[maxLights] lights;
uniform samplerCube[maxLights] lightShadowMaps;

uniform int particleCount;
uniform Particle[maxParticles] particles;
