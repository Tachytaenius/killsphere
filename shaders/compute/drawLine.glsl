uniform layout(rg16f) image3D fogScatteranceAbsorption;
uniform layout(rgba16f) image3D fogColour;
uniform layout(rgba16f) image3D fogEmission;
uniform float worldRadius;
uniform vec3 lineStart;
uniform vec3 lineEnd;
uniform int lineSteps;
uniform vec3 lineColour;
uniform float lineEmissionAdd;
uniform float lineScatteranceAdd;
uniform float lineAbsorptionAdd;
uniform vec3 lineFogColour;

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
	emission += lineColour * lineEmissionAdd * stepSize;
	imageStore(fogEmission, xyz, vec4(emission, 1.0));

	vec4 scatteranceAbsorptionSample = imageLoad(fogScatteranceAbsorption, xyz);
	float scatterance = scatteranceAbsorptionSample[0];
	float absorption = scatteranceAbsorptionSample[1];

	vec3 colour = imageLoad(fogColour, xyz).rgb;

	// TODO: Proper handling of colour and scatterance. Absorption is easy enough
	scatterance += lineScatteranceAdd;
	absorption += lineAbsorptionAdd;
	colour = lineFogColour;

	imageStore(fogColour, xyz, vec4(colour, 1.0));
	imageStore(fogScatteranceAbsorption, xyz, vec4(scatterance, absorption, 0.0, 1.0));
}
