#line 1

uniform layout(rg16f) writeonly image3D fogScatteranceAbsorption;
uniform layout(rgba8) writeonly image3D fogColour;
uniform layout(rgba16f) writeonly image3D fogEmission;
uniform float worldRadius;

ivec3 getXyz(int i, ivec3 whd) {
	int x = int(mod(i, whd.x));
	i /= whd.x;
	int y = int(mod(i, whd.y));
	i /= whd.y;
	int z = i;
	return ivec3(x, y, z);
}

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void computemain() {
	int i = int(love_GlobalThreadID.x);
	ivec3 whd = imageSize(fogScatteranceAbsorption);
	if (i > whd.x * whd.y * whd.z) {
		return;
	}
	ivec3 xyz = getXyz(i, whd);
	vec3 position = (vec3(xyz) / imageSize(fogScatteranceAbsorption) * 2.0 - 1.0) * worldRadius;

	// float density = pow(max(0.0, (snoise(vec4(position * 0.02, 10.0)) * 0.5 + 0.5)) * 0.9, 9.0);
	// float density = max(max(abs(position.x - 10.0), abs(position.y - 5.0)), abs(position.z - 30.0)) > 6.0 ? 0.0 : 1.0;
	float density = abs(position.z - 40.0) > 2.0 ? 0.0 : max(0.0, 1.0 - abs(length(position.xy - vec2(5.0, 10.0)) - 10.0) / 1.5);
	imageStore(fogScatteranceAbsorption, xyz, vec4(vec2(density), 0.0, 1.0));

	vec3 colour = vec3(
		(snoise(vec4(position * 0.01, 20.0)) * 0.5 + 0.5),
		(snoise(vec4(position * 0.02, 30.0)) * 0.5 + 0.5),
		(snoise(vec4(position * 0.03, 40.0)) * 0.5 + 0.5)
	);
	imageStore(fogColour, xyz, vec4(colour, 1.0));
}
