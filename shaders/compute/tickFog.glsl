#line 1

uniform layout(rg16f) image3D fogScatteranceAbsorption;
uniform layout(rgba16f) image3D fogColour;
uniform layout(rgba16f) image3D fogEmission;
uniform float worldRadius;
uniform float dt;
uniform int mode;
uniform float scatteranceDifferenceDecay;
uniform float absorptionDifferenceDecay;
uniform float emissionDifferenceDecay;
uniform float colourDifferenceDecay;
uniform float scatteranceDecay;
uniform float absorptionDecay;
uniform float emissionDecay;
uniform int tickFogMode;
uniform float time;
uniform float fogCloudPositionScale;
uniform float fogCloudTimeRate;
uniform float fogCloudPower;

bool inBounds(ivec3 xyz) {
	ivec3 whd = imageSize(fogScatteranceAbsorption);
	return
		0 <= xyz.x && xyz.x < whd.x &&
		0 <= xyz.y && xyz.y < whd.y &&
		0 <= xyz.z && xyz.z < whd.z;
}

vec3 getPosition(ivec3 xyz) {
	ivec3 whd = imageSize(fogScatteranceAbsorption);
	return (vec3(xyz) / vec3(whd) * 2.0 - 1.0) * worldRadius;
}

layout(local_size_x = 4, local_size_y = 4, local_size_z = 2) in;
void computemain() {
	int modeAxisNumber = int(mod(tickFogMode, 3));
	int otherAxisA = int(mod(tickFogMode + 1, 3));
	int otherAxisB = int(mod(tickFogMode + 2, 3));
	ivec3 xyz;
	xyz[modeAxisNumber] = int(gl_GlobalInvocationID.z) * 2;
	xyz[otherAxisA] = int(gl_GlobalInvocationID.x);
	xyz[otherAxisB] = int(gl_GlobalInvocationID.y);
	if (tickFogMode >= 3) {
		xyz[modeAxisNumber] += 1;
	};

	// Get coords
	ivec3 aCoord = xyz;
	ivec3 bCoord = xyz;
	bCoord[modeAxisNumber] -= 1;

	// Check coords
	if (!inBounds(aCoord) || !inBounds(bCoord)) {
		return;
	}

	vec3 aPosition = getPosition(aCoord);
	vec3 bPosition = getPosition(bCoord);

	// Read extinction quantities for a and b
	vec4 aScatteranceAbsorptionSample = imageLoad(fogScatteranceAbsorption, aCoord);
	float aScatterance = aScatteranceAbsorptionSample[0];
	float aAbsorption = aScatteranceAbsorptionSample[1];
	vec4 bScatteranceAbsorptionSample = imageLoad(fogScatteranceAbsorption, bCoord);
	float bScatterance = bScatteranceAbsorptionSample[0];
	float bAbsorption = bScatteranceAbsorptionSample[1];

	// Get weighting to add cloudy effect
	vec3 positionMiddle = mix(aPosition, bPosition, 0.5);
	vec3 currentDirectionPreNormalise = vec3(
		snoise(vec4(positionMiddle * fogCloudPositionScale, time * fogCloudTimeRate)),
		snoise(vec4(positionMiddle * fogCloudPositionScale, time * fogCloudTimeRate)),
		snoise(vec4(positionMiddle * fogCloudPositionScale, time * fogCloudTimeRate))
	);
	vec3 currentDirection = length(currentDirectionPreNormalise) > 0.0 ? normalize(currentDirectionPreNormalise) : currentDirectionPreNormalise;
	vec3 movementDirection = vec3(0.0);
	movementDirection[modeAxisNumber] = 1.0;
	float dotResult = dot(currentDirection, movementDirection);
	float cloudinessAOrB = pow(min(1.0, abs(dotResult)), fogCloudPower) * sign(dotResult) * 0.5 + 0.5;

	// Read fog colour for a and b
	vec3 aColour = imageLoad(fogColour, aCoord).rgb;
	vec3 bColour = imageLoad(fogColour, bCoord).rgb;

	// Mix colours
	float divisor = aScatterance + bScatterance;
	if (divisor != 0.0) {
		float colourAOrBPreMix = aScatterance / divisor; // 1 = 100% a, 0 = 100% b
		// float colourAOrB = cloudinessAOrB < 0.5 ? // Mix both weights so that colour spreading is affected by the same directionality as extinction. Both are in the 0 to 1 range, where 0.5 is neutral
		// 	2.0 * cloudinessAOrB * colourAOrBPreMix :
		// 	1.0 - 2.0 * (1.0 - cloudinessAOrB) * (1.0 - colourAOrBPreMix);
		// Mixing the weights is not necessary as colour follow the noise-affected scatterance anyway
		float colourAOrB = colourAOrBPreMix;
		vec3 colourDifference = bColour - aColour;
		vec3 colourAnchorPoint = mix(bColour, aColour, colourAOrBPreMix);
		float timeDivisor = clamp(1.0 - 2.0 * abs(colourAOrB - 0.5), 0.0, 1.0);
		if (timeDivisor == 0.0) {
			aColour = colourAnchorPoint;
			bColour = colourAnchorPoint;
		} else {
			colourDifference *= exp(-colourDifferenceDecay * dt / timeDivisor);
			aColour = colourAnchorPoint - colourDifference * (1.0 - colourAOrB);
			bColour = colourAnchorPoint + colourDifference * colourAOrB;
		}
		aColour = clamp(aColour, 0.0, 1.0);
		bColour = clamp(bColour, 0.0, 1.0);
		// Write quantities
		imageStore(fogColour, aCoord, vec4(aColour, 1.0));
		imageStore(fogColour, bCoord, vec4(bColour, 1.0));
	}

	// Fade distance between quantities (mix them together)
	// TODO: Involve distances in decay rates
	float scatteranceDifference = bScatterance - aScatterance;
	float scatteranceAnchorPoint = mix(bScatterance, aScatterance, cloudinessAOrB);
	scatteranceDifference *= exp(-scatteranceDifferenceDecay * dt);
	aScatterance = scatteranceAnchorPoint - scatteranceDifference * (1.0 - cloudinessAOrB);
	bScatterance = scatteranceAnchorPoint + scatteranceDifference * cloudinessAOrB;
	float absorptionDifference = bAbsorption - aAbsorption;
	float absorptionAnchorPoint = mix(bAbsorption, aAbsorption, cloudinessAOrB);
	absorptionDifference *= exp(-absorptionDifferenceDecay * dt);
	aAbsorption = absorptionAnchorPoint - absorptionDifference * (1.0 - cloudinessAOrB);
	bAbsorption = absorptionAnchorPoint + absorptionDifference * cloudinessAOrB;

	// Fade quantities
	aScatterance *= exp(-scatteranceDecay * dt);
	aAbsorption *= exp(-absorptionDecay * dt);
	bScatterance *= exp(-scatteranceDecay * dt);
	bAbsorption *= exp(-absorptionDecay * dt);

	// Write quantities
	imageStore(fogScatteranceAbsorption, aCoord, vec4(aScatterance, aAbsorption, 0.0, 1.0));
	imageStore(fogScatteranceAbsorption, bCoord, vec4(bScatterance, bAbsorption, 0.0, 1.0));

	// Handle emission
	// Load
	vec3 aEmission = imageLoad(fogEmission, aCoord).rgb;
	vec3 bEmission = imageLoad(fogEmission, bCoord).rgb;
	// Mix (with simpler maths)
	float distanceMultiplier = exp(-emissionDifferenceDecay * dt);
	vec3 aEmissionOut = mix(aEmission, bEmission, cloudinessAOrB * (1.0 - distanceMultiplier));
	bEmission = mix(bEmission, aEmission, (1.0 - cloudinessAOrB) * (1.0 - distanceMultiplier));
	aEmission = aEmissionOut;
	// Fade
	aEmission *= exp(-emissionDecay * dt);
	bEmission *= exp(-emissionDecay * dt);
	// Store
	imageStore(fogEmission, aCoord, vec4(aEmission, 1.0));
	imageStore(fogEmission, bCoord, vec4(bEmission, 1.0));
}
