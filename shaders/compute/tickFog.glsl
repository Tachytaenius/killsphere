uniform layout(rg16f) image3D fogScatteranceAbsorption;
uniform layout(rgba8) image3D fogColour;
uniform layout(rgba16f) image3D fogEmission;
uniform float worldRadius;
uniform float dt;
uniform int mode;
uniform float scatteranceDifferenceDecay;
uniform float absorptionDifferenceDecay;
uniform float scatteranceDecay;
uniform float absorptionDecay;
uniform int tickFogMode;

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
	ivec3 whd2 = whd;
	int modeAxisNumber = int(mod(tickFogMode, 3));
	whd2[modeAxisNumber] /= 2;
	if (i > whd2.x * whd2.y * whd2.z) {
		return;
	}
	ivec3 xyz = getXyz(i, whd2);
	xyz[modeAxisNumber] *= 2;
	ivec3 xyz2 = xyz;
	if (tickFogMode >= 3) {
		xyz2[modeAxisNumber] += 1;
	};

	// Get coords
	ivec3 aCoord = xyz2;
	ivec3 bCoord = xyz2;
	bCoord[modeAxisNumber] -= 1;

	// Read extinction quantities for a and b
	vec4 aScatteranceAbsorptionSample = imageLoad(fogScatteranceAbsorption, aCoord);
	float aScatterance = aScatteranceAbsorptionSample[0];
	float aAbsorption = aScatteranceAbsorptionSample[1];
	vec4 bScatteranceAbsorptionSample = imageLoad(fogScatteranceAbsorption, bCoord);
	float bScatterance = bScatteranceAbsorptionSample[0];
	float bAbsorption = bScatteranceAbsorptionSample[1];

	// Fade distance between quantities
	float scatteranceDifference = bScatterance - aScatterance;
	float scatteranceMidpoint = aScatterance + scatteranceDifference / 2.0;
	// TODO: Involve distances in decay rates
	scatteranceDifference *= exp(-scatteranceDifferenceDecay * dt);
	aScatterance = scatteranceMidpoint - scatteranceDifference / 2.0;
	bScatterance = scatteranceMidpoint + scatteranceDifference / 2.0;
	float absorptionDifference = bAbsorption - aAbsorption;
	float absorptionMidpoint = aAbsorption + absorptionDifference / 2.0;
	absorptionDifference *= exp(-absorptionDifferenceDecay * dt);
	aAbsorption = absorptionMidpoint - absorptionDifference / 2.0;
	bAbsorption = absorptionMidpoint + absorptionDifference / 2.0;

	// Fade quantities
	aScatterance *= exp(-scatteranceDecay * dt);
	aAbsorption *= exp(-absorptionDecay * dt);
	bScatterance *= exp(-scatteranceDecay * dt);
	bAbsorption *= exp(-absorptionDecay * dt);

	// Write quantities
	imageStore(fogScatteranceAbsorption, aCoord, vec4(aScatterance, aAbsorption, 0.0, 1.0));
	imageStore(fogScatteranceAbsorption, bCoord, vec4(bScatterance, bAbsorption, 0.0, 1.0));
}
