uniform layout(rgba16f) image3D fogEmission;
uniform float worldRadius;
uniform vec3 lineStart;
uniform vec3 lineEnd;
uniform int lineSteps;
uniform vec3 lineColour;

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void computemain() {
	int i = int(gl_GlobalInvocationID.x);
	if (i >= lineSteps) {
		return;
	}
	
	float t = float(i) / float(lineSteps);
	float stepSize = 1.0 / float(lineSteps);
	vec3 position = mix(lineStart, lineEnd, t);
	vec3 textureCoords = position / worldRadius * 0.5 + 0.5;
	ivec3 whd = imageSize(fogEmission);
	ivec3 xyz = ivec3(vec3(whd) * textureCoords);
	if (!(
		0 <= xyz.x && xyz.x < whd.x &&
		0 <= xyz.y && xyz.y < whd.y &&
		0 <= xyz.z && xyz.z < whd.z
	)) {
		return;
	}
	vec3 emission = imageLoad(fogEmission, xyz).rgb;
	emission += lineColour * stepSize;
	imageStore(fogEmission, xyz, vec4(emission, 1.0));
}
