#line 1

uniform layout(rg16f) writeonly image3D fogScatteranceAbsorption;
uniform layout(rgba16f) writeonly image3D fogColour;
uniform layout(rgba16f) writeonly image3D fogEmission;
uniform float worldRadius;

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
void computemain() {
	ivec3 xyz = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 whd = imageSize(fogScatteranceAbsorption);
	if (xyz.x > whd.x || xyz.y > whd.y || xyz.z > whd.z) {
		return;
	}

	vec3 position = (vec3(xyz) / vec3(whd) * 2.0 - 1.0) * worldRadius;

	float density = pow(max(0.0, (snoise(vec4(position * 0.02, 10.0)) * 0.5 + 0.5)) * 0.9, 9.0);
	// float density = max(max(abs(position.x - 10.0), abs(position.y - 5.0)), abs(position.z - 30.0)) > 6.0 ? 0.0 : 100.0;
	// // float density = abs(position.z - 40.0) > 2.0 ? 0.0 : max(0.0, 1.0 - abs(length(position.xy - vec2(5.0, 10.0)) - 10.0) / 1.5);
	// // float density = max(0.0, 1.0 - abs(length(position) - 20.0) / 2.0);
	// // float density = int(mod(xyz.x, 8)) == 0 && int(mod(xyz.y, 8)) == 0 && int(mod(xyz.z, 8)) == 0 ? 1.0 : 0.0;
	// // float density = xyz.y == 50 ? 1.0 : 0.0;
	// // float density = 0.2;
	// // float density = max(max(abs(xyz.x - 50), abs(xyz.y - 100)), abs(xyz.z - 100)) < 4 ? 1.0 : 0.0;
	// // float density = (xyz.y == 90 && int(mod(xyz.x, 2)) == 0) ? 1.0 : 0.0;
	imageStore(fogScatteranceAbsorption, xyz, vec4(vec2(density), 0.0, 1.0));

	vec3 colour = vec3(
		(snoise(vec4(position * 0.01, 20.0)) * 0.5 + 0.5),
		(snoise(vec4(position * 0.02, 30.0)) * 0.5 + 0.5),
		(snoise(vec4(position * 0.03, 40.0)) * 0.5 + 0.5)
	);
	colour = density != 0.0 ? colour : vec3(0.0, 1.0, 0.0);
	imageStore(fogColour, xyz, vec4(colour, 1.0));

	// imageStore(fogScatteranceAbsorption, xyz, vec4(vec2(0.0), 0.0, 1.0));
	// imageStore(fogColour, xyz, vec4(vec3(0.0), 1.0));
	// imageStore(fogEmission, xyz, vec4(vec3(0.0), 1.0));
}
