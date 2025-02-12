#line 1

float snoise(vec3 p) { // HACK
	return snoise(vec4(p, 0.0));
}

const float tau = 6.28318530718;

varying vec3 directionPreNormalise;

uniform mat4 clipToSky;

#ifdef VERTEX

vec4 position(mat4 loveTransform, vec4 vertexPosition) {
	directionPreNormalise = (
		clipToSky * vec4(
			(VertexTexCoord.xy * 2.0 - 1.0) * vec2(1.0, -1.0),
			-1.0,
			1.0
		)
	).xyz;
	return loveTransform * vertexPosition;
}

#endif

#ifdef PIXEL

uniform int maxRaySegments;
uniform vec3 cameraPosition;
uniform vec3 cameraForwardVector;
uniform float cameraFOV;
uniform float arenaRadius;
uniform float outlineThicknessFactor;
uniform sampler3D fogScatteranceAbsorption;
uniform sampler3D fogColour;
uniform sampler3D fogEmission;
uniform float fogDistancePerSample;
uniform float ambientLightAmount;
uniform vec3 ambientLightColour;
uniform float time;
uniform sampler2D bayerMatrix;
uniform int bayerMatrixSize;

const float lightRadius = 0.25;
const float lightRadiusSizeExtra = 1.25;

float angleBetween(vec3 a, vec3 b) {
	return acos(
		clamp( // To prevent NaN
			dot(
				normalize(a),
				normalize(b)
			),
			-1.0, 1.0
		)
	);
}

vec3 sampleSky(vec3 direction) {
	// return (direction * 0.5 + 0.5) * 0.5 + 0.25;
	return vec3(0.0);
}

struct FogSample {
	float scatterance;
	float absorption;
	vec3 colour;
	vec3 emission;
};

FogSample sampleFog(vec3 position) {
	ivec3 whd = textureSize(fogScatteranceAbsorption, 0);
	vec3 textureCoords = position / arenaRadius * 0.5 + 0.5;
	ivec3 textureCoordsInt = ivec3(vec3(whd) * textureCoords);

	// TODO: Filter colour by adding scatterance into the weighted averaging so that you don't have to deal with no-scattering voxels of colour in the filtering
	// Emission is kept as-is for stylistic reasons
	vec4 scatteranceAbsorptionSample = Texel(fogScatteranceAbsorption, textureCoords);
	vec4 colourSample = texelFetch(fogColour, textureCoordsInt, 0);
	vec4 emissionSample = texelFetch(fogEmission, textureCoordsInt, 0);

	return FogSample (
		scatteranceAbsorptionSample[0],
		scatteranceAbsorptionSample[1],
		colourSample.rgb,
		emissionSample.rgb
	);
}

bool inShadow(int i, vec3 lightPosition, vec3 position) {
	vec3 lightToPosition = position - lightPosition;
	float dist = length(lightToPosition);
	float shadowMapValue = Texel(lightShadowMaps[i], lightToPosition).r;
	if (shadowMapValue < 0.0) {
		return false;
	}
	return shadowMapValue < dist;
}

vec3 getIncomingLight(vec3 position) { // , int ignoreObjectId, int ignoreSubObjectId) {
	vec3 incomingLight = vec3(0.0);
	for (int lightI = 0; lightI < lightCount; lightI++) {
		Light light = lights[lightI];
		// if (inShadow(light.position, position, ignoreObjectId, ignoreSubObjectId)) {
		// 	continue;
		// }
		if (inShadow(lightI, light.position, position)) {
			continue;
		}
		vec3 positionToLight = light.position - position;
		incomingLight += light.colour * light.intensity * pow(max(0.01, length(positionToLight)), -2.0);
	}
	return incomingLight + ambientLightAmount * ambientLightColour;
}

vec3 getIncomingLightSurface(vec3 surfacePosition, vec3 surfaceNormal) { // , int ignoreObjectId, int ignoreSubObjectId) {
	vec3 incomingLight = vec3(0.0);
	for (int lightI = 0; lightI < lightCount; lightI++) {
		Light light = lights[lightI];
		// if (inShadow(light.position, surfacePosition, ignoreObjectId, ignoreSubObjectId)) {
		// 	continue;
		// }
		if (inShadow(lightI, light.position, surfacePosition + surfaceNormal * 0.1)) {
			continue;
		}
		vec3 positionToLight = light.position - surfacePosition;
		float formShadowFactor = max(0.0, dot(surfaceNormal, normalize(positionToLight)));
		// float formShadowFactor = dot(surfaceNormal, normalize(positionToLight)) * 0.5 + 0.5;
		incomingLight += light.colour * light.intensity * pow(max(lightRadius, length(positionToLight)), -2.0) * formShadowFactor;
	}
	return incomingLight + ambientLightAmount * ambientLightColour;
}

struct PhysicalRayHit {
	bool sky;
	vec3 colour;
	float t;
	vec3 position;
	vec3 normal;
	float reflectivity;
	vec3 emission;
};

void tryNewClosestHit(inout PhysicalRayHit closestForwardHit, PhysicalRayHit newHit) {
	if (newHit.t >= 0.0 && (closestForwardHit.sky || newHit.t < closestForwardHit.t)) {
		closestForwardHit = newHit;
	}
}

PhysicalRayHit getClosestHit(vec3 rayStart, vec3 rayDirection) {
	PhysicalRayHit closestForwardHit = PhysicalRayHit (
		true, // It's sky
		sampleSky(rayDirection), // Colour
		// Don't care variables:
		0.0,
		vec3(0.0),
		vec3(0.0),
		0.0,
		vec3(0.0)
	);

	for (int j = 0; j < boundingSphereCount; j++) {
		BoundingSphere boundingSphere = boundingSpheres[j];
		if (!boundingSphere.drawAlways) {
			ConvexRaycastResult boundingSphereResult = sphereRaycast(boundingSphere.position, boundingSphere.radius, rayStart, rayStart + rayDirection);
			if (!boundingSphereResult.hit) {
				// TODO: Also check t stuff (if needed)
				continue;
			}
		}

		for (int i = boundingSphere.triangleStart; i < boundingSphere.triangleStart + boundingSphere.triangleCount; i++) {
			ObjectTriangle triangle = objectTriangles[i];
			TriangleRaycastResult triangleResult = triangleRaycast(triangle.v1, triangle.v2, triangle.v3, rayStart, rayStart + rayDirection);
			vec3 position = rayStart + rayDirection * triangleResult.t;
			vec3 normal = triangleResult.normal;
			vec3 barycentric = triangleResult.barycentric;

			float outlineFactor = min(min(barycentric[0], barycentric[1]), barycentric[2]) < outlineThicknessFactor ? 1.0 : 0.0;
			vec3 triangleColourHere = mix(triangle.colour, triangle.outlineColour.rgb, outlineFactor * triangle.outlineColour.a);
			float outlineReflectivity = 0.0;
			float triangleReflectivityHere = mix(triangle.reflectivity, outlineReflectivity, outlineFactor);
			if (triangleResult.hit) {
				tryNewClosestHit(closestForwardHit, PhysicalRayHit (
					false,
					triangleColourHere,
					triangleResult.t,
					position,
					normal,
					triangleReflectivityHere,
					triangle.emissionAmount * triangle.emissionColour
				)); 
			}
		}
	}

	// Now try particles between camera and current closest hit. If it's bright enough (with dithering) then we use it. It will be situated at the closest particle hit
	vec3 particleColour = vec3(0.0);
	float particlePower = 0.0;
	bool hitParticle = false;
	float closestParticleT;
	for (int i = 0; i < particleCount; i++) {
		Particle particle = particles[i];
		ConvexRaycastResult particleRaycast = sphereRaycast(particle.position, particle.radius, rayStart, rayStart + rayDirection);
		if (!particleRaycast.hit) {
			continue;
		}
		float t1 = max(0.0, particleRaycast.t1);
		float t2 = particleRaycast.t2;
		if (!closestForwardHit.sky) {
			t2 = min(closestForwardHit.t, t2); // If a particle is midway thru the boundary sphere, then it won't be considered. Getting boundary sphere hit result before this code would be better. So, TODO!
		}
		if (t2 < t1) {
			continue;
		}
		closestParticleT = hitParticle ? min(t1, closestParticleT) : t1;
		hitParticle = true;
		particleColour += particle.colour;
		particlePower += particle.strength * (t2 - t1); // rayDirection length is 1
	}

	if (hitParticle) { // Probably not necessary since particlePower starts at 0
		float noise = snoise(vec4(rayDirection * 50.0, time * 40.0));
		float particlePowerWarp = (cos(2.0 * tau * noise) * 0.5 + 0.5) * 0.8 + 0.2;
		float warpedParticlePower = particlePower * particlePowerWarp;

		float bayerValue = texelFetch(bayerMatrix, ivec2(int(love_PixelCoord.x) % bayerMatrixSize, int(love_PixelCoord.y) % bayerMatrixSize), 0).r;
		float steps = 2.0;
		// vec3 bayerColour = floor((particleColour + bayerValue / steps) * steps) / steps;
		// if (bayerColour.r >= 1.0 || bayerColour.g >= 1.0 || bayerColour.b >= 1.0) {
		if (warpedParticlePower >= bayerValue) {
			// Not using bayerColour here, it's just for the dithering
			closestForwardHit = PhysicalRayHit (
				false,
				vec3(0.0),
				closestParticleT,
				rayStart + rayDirection * closestParticleT,
				vec3(1.0), // Don't care value
				0.0,
				particleColour * (1.0 + warpedParticlePower * 4.0)
			);
		}
	}

	return closestForwardHit;
}

vec3 multiplyVectorInDirection(vec3 v, vec3 d, float m) { // d should be normalised
	vec3 parallel = d * dot(v, d);
	vec3 perpendicular = v - parallel;
	vec3 parallelScaled = parallel * m;
	return parallelScaled + perpendicular;
}

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

vec2 rotate(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}

float pingPong(float x, float height) {
	return height - abs(height - mod(x, 2.0 * height));
}

vec3 getRayColour(vec3 rayStart, vec3 rayStartDirection) {
	vec3 outColour = vec3(0.0);

	float distanceToSurface = arenaRadius - length(cameraPosition);
	float nullifyStart = arenaRadius * 0.2;
	// float nullificationFactor = min(1, distanceToSurface / nullifyStart);
	float nullificationFactor = distanceToSurface < nullifyStart ? sin(tau / 2.0 * (distanceToSurface / nullifyStart - 0.5)) * 0.5 + 0.5 : 1.0;

	int maxTeleports = 2;
	float lastTeleportVisibilityProportion = 0.25;

	vec3 rayPosition = rayStart;
	vec3 rayDirection = rayStartDirection;
	float influence = 1.0;
	int teleports = 0;
	float distanceTraversedPrior = 0.0; // Before current ray segment
	float arenaDiameter = 2.0 * arenaRadius;
	float maxLightDistance = arenaDiameter * (float(maxTeleports + 1) - lastTeleportVisibilityProportion);
	float lightDistanceFadeStart = arenaDiameter * float(maxTeleports);
	for (int rayBounce = 0; rayBounce < maxRaySegments; rayBounce++) {
		float teleportFactor = mix(
			0.5,
			pow(1.0 - float(teleports) / float(maxTeleports + 1), 2.0),
			nullificationFactor
		);
		if (teleportFactor == 0.0 || influence == 0.0) {
			break;
		}
		PhysicalRayHit closestHit = getClosestHit(rayPosition, rayDirection);
		ConvexRaycastResult arenaBoundaryResult = sphereRaycast(vec3(0.0), arenaRadius, rayPosition, rayPosition + rayDirection);
		bool arenaBoundaryHit = false;
		vec3 arenaBoundaryHitPosition;
		if (arenaBoundaryResult.hit && (closestHit.sky || closestHit.t > arenaBoundaryResult.t2)) {
			arenaBoundaryHit = true;
			arenaBoundaryHitPosition = rayPosition + rayDirection * arenaBoundaryResult.t2;
		}
		if (!closestHit.sky || arenaBoundaryHit) {
			vec3 fogStart = rayPosition;
			vec3 fogEnd = arenaBoundaryHit ? arenaBoundaryHitPosition : closestHit.position;
			float totalDistance = distance(fogStart, fogEnd);
			vec3 direction = normalize(fogEnd - fogStart);
			float currentDistance = 0.0;
			int fogStepsCompleted = 0;
			int maxFogSteps = 1000;
			// Get lights to check for going directly through
			Light fogLights[maxLights];
			int fogLightCount = 0;
			for (int i = 0; i < lightCount; i++) {
				Light light = lights[i];
				ConvexRaycastResult lightRaycastResult = sphereRaycast(light.position, lightRadius + lightRadiusSizeExtra, fogStart, fogEnd);
				if (!lightRaycastResult.hit) {
					continue;
				}
				fogLights[fogLightCount] = light;
				fogLightCount += 1;
			}
			// Step fog
			while (fogStepsCompleted < maxFogSteps && currentDistance < totalDistance) {
				float stepSize = min(totalDistance, currentDistance + fogDistancePerSample) - currentDistance;
				vec3 position = fogStart + direction * currentDistance;
				FogSample fogSample = sampleFog(position);
				float fogExtinction = fogSample.absorption + fogSample.scatterance;
				float currentTotalDistance = distanceTraversedPrior + currentDistance;
				float rayEndFactor = 1.0 - clamp((currentTotalDistance - lightDistanceFadeStart) / (maxLightDistance - lightDistanceFadeStart), 0.0, 1.0);
				if (rayEndFactor <= 0.0) {
					break;
				}
				vec3 insideLightsHere = vec3(0.0);
				for (int i = 0; i < fogLightCount; i++) {
					Light light = fogLights[i];
					float extra = 4.0;
					insideLightsHere += /*light.intensity * */ extra * light.colour * pow(max(0.0, 1.0 - distance(light.position, position) / (lightRadius + lightRadiusSizeExtra)), 4.0);
				}
				outColour +=
					rayEndFactor * teleportFactor * influence * stepSize * (
						fogSample.colour * fogSample.scatterance * getIncomingLight(position) +
						fogSample.emission + insideLightsHere
					);
				influence *= exp(-fogExtinction * stepSize);
				currentDistance += stepSize;
				fogStepsCompleted += 1;
			}
		}
		if (arenaBoundaryHit) {
			vec3 hitPosition = arenaBoundaryHitPosition;
			vec3 hitNormal = normalize(hitPosition);
			if (dot(rayDirection, hitNormal) > 0.0 || true) {
				// bool grid =
				// 	mod(abs(hitNormal.x), 0.2) < 0.0075 ||
				// 	mod(abs(hitNormal.y), 0.2) < 0.0075 ||
				// 	mod(abs(hitNormal.z), 0.2) < 0.0075;
				vec3 gridIn = hitNormal;
				float size = 0.2;
				float edge = size * 0.04;
				gridIn.xz = rotate(gridIn.xz, pingPong(gridIn.y - size * 0.5, size) * tau * 0.1);
				vec3 gridV = mod(abs(gridIn), size);
				float grid = min(min(
					min(1.0, min((gridV.x - edge) / edge, (size - (gridV.x + edge)) / edge)),
					min(1.0, min((gridV.y - edge) / edge, (size - (gridV.y + edge)) / edge))),
					min(1.0, min((gridV.z - edge) / edge, (size - (gridV.z + edge)) / edge))
				);
				// grid is between 0 and 1

				float ditherSize = 0.01;
				if (
					grid > (
						mod(hitNormal.x, ditherSize) / ditherSize +
						mod(hitNormal.y + time * ditherSize * 0.01, ditherSize) / ditherSize +
						mod(hitNormal.z + time * ditherSize * 0.01 * 3.0, ditherSize) / ditherSize 
					) / 3.0
				) {
					// vec3 boundaryColour = hitNormal * 0.5 + 0.5;
					// vec3 boundaryColour = hsv2rgb(vec3(float(teleports) / float(maxTeleports + 1), 1.0, 1.0));
					float noiseA = snoise(vec4(
						hitPosition / arenaRadius * 4.0,
						time * 0.1
					));
					float noiseB = pow(
						// noiseA,
						mod(noiseA, 0.5),
						// noiseA * 0.5 + 0.5,
						1.5
					);
					vec3 boundaryColour = mix(
						noiseB * vec3(0.3, 0.0, 0.0),
						vec3(0.0, 1.0, 1.0),
						max(0.0, 1.0 - (noiseA * 0.5 + 0.5) / 0.1)
					);
					float currentTotalDistance = distanceTraversedPrior + distance(rayPosition, arenaBoundaryHitPosition);
					float rayEndFactor = 1.0 - clamp((currentTotalDistance - lightDistanceFadeStart) / (maxLightDistance - lightDistanceFadeStart), 0.0, 1.0);
					outColour += boundaryColour * teleportFactor * influence * rayEndFactor;
					break;
				} else {
					distanceTraversedPrior += distance(rayPosition, hitPosition);
					rayPosition = -hitPosition;
					vec3 directionWind = vec3(0.0, 0.0, 0.5) * rayDirection * nullificationFactor;
					rayDirection = normalize(rayDirection + directionWind);
					teleports += 1;
					if (teleports > maxTeleports) {
						break;
					}
				}
			}
		} else {
			if (!closestHit.sky) {
				// float formShadowFactor = max(0.0, dot(normalize(vec3(1.0, 1.0, 1.0));
				vec3 incomingLight = getIncomingLightSurface(closestHit.position, closestHit.normal);
				float currentTotalDistance = distanceTraversedPrior + distance(rayPosition, closestHit.position);
				float rayEndFactor = 1.0 - clamp((currentTotalDistance - lightDistanceFadeStart) / (maxLightDistance - lightDistanceFadeStart), 0.0, 1.0);
				outColour += rayEndFactor * (closestHit.colour * incomingLight + closestHit.emission) * teleportFactor * influence;
				if (closestHit.reflectivity == 0.0) {
					break;
				} else if (dot(closestHit.normal, rayDirection) < 0.0) {
					rayDirection = reflect(rayDirection, closestHit.normal);
					distanceTraversedPrior += distance(rayPosition, closestHit.position);
					rayPosition = closestHit.position + rayDirection * 0.0001;
					influence *= closestHit.reflectivity;
				}
			} else {
				// Sky
				outColour = closestHit.colour * teleportFactor * influence;
				break;
			}
		}
	}
	return outColour;
}

vec4 effect(vec4 loveColour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	vec3 direction = normalize(directionPreNormalise);

	// I could just do a circle with the texture coordinates but I'm too cool for that
	float angle = angleBetween(cameraForwardVector, direction);
	float end = cameraFOV / 2.0;
	float start = end * 0.95;
	float fovFadeFactor = 1.0 - (angle < start ? 0.0 : end < angle ? 1.0 : sin(tau / 2.0 * ((angle - start) / (end - start) - 0.5)) * 0.5 + 0.5);
	if (fovFadeFactor <= 0.0) {
		return vec4(vec3(0.0), 1.0);
	}

	vec3 outColour = getRayColour(cameraPosition, direction);
	return fovFadeFactor * loveColour * vec4(outColour, 1.0);
}

#endif
