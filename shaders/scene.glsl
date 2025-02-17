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

float sigmoidAscending(float x) { // With x in the unit interval, sigmoidAscending(x) goes from 0 to 1 along a curve based on cosine
	return x < 0.0 ? 0.0 :
		x < 1.0 ? 0.5 - 0.5 * cos(tau / 2.0 * x) : 1.0;
}

float sigmoidDescending(float x) { // With x in the unit interval, sigmoidDescending(x) goes from 1 to 0 along a curve based on cosine
	return x < 0.0 ? 1.0 :
		x < 1.0 ? cos(tau / 2.0 * x) * 0.5 + 0.5 : 0.0;
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
	bool teleport;
	bool arenaTeleport;
	vec3 position;
	vec3 normal;
	float reflectivity;
	vec3 emission;
	vec3 teleportDestination;
	vec3 teleportRayDirection;
};

void tryNewClosestHit(inout PhysicalRayHit closestForwardHit, PhysicalRayHit newHit) {
	if (newHit.t >= 0.0 && (closestForwardHit.sky || newHit.t < closestForwardHit.t)) {
		closestForwardHit = newHit;
	}
}

PhysicalRayHit getClosestHit(vec3 rayStart, vec3 rayDirection, float nullificationFactor) {
	PhysicalRayHit closestForwardHit = PhysicalRayHit (
		true, // It's sky
		sampleSky(rayDirection), // Colour
		0.0, // Don't care variable
		false, // No teleport
		false,
		// Don't care variables:
		vec3(0.0),
		vec3(0.0),
		0.0,
		vec3(0.0),
		vec3(0.0),
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
					false,
					false,
					position,
					normal,
					triangleReflectivityHere,
					triangle.emissionAmount * triangle.emissionColour,
					vec3(0.0),
					vec3(0.0)
				));
			}
		}
	}

	for (int i = 0; i < spherePortalPairCount; i++) {
		SpherePortalPair pair = spherePortalPairs[i];
		for (int selector = 0; selector <= 1; selector++) {
			vec3 inPortalPosition = selector == 0 ? pair.aPosition : pair.bPosition;
			vec3 outPortalPosition = selector == 1 ? pair.aPosition : pair.bPosition;

			float radiusMultiplier = 1.5; 
			
			// Check outer shell
			ConvexRaycastResult inPortalShellResult = sphereRaycast(inPortalPosition, pair.radius * radiusMultiplier, rayStart, rayStart + rayDirection);
			if (!inPortalShellResult.hit) {
				continue;
			}
			// Check inside and outside layers of portal outer shell for cool effect
			vec3 portalColour = selector == 0 ? pair.aColour : pair.bColour;
			float outerShellPortalColourMultiplier = 0.5;
			// float portalTraversalColourMultiplier = 0.1;
			float portalTraversalColourMultiplier = 1.0;
			for (int shellSelector = 0; shellSelector <= 1; shellSelector++) {
				float t = shellSelector == 0 ? inPortalShellResult.t1 : inPortalShellResult.t2;
				vec3 position = rayStart + rayDirection * t;
				vec3 relativePosition = position - inPortalPosition;
				float noise = abs(snoise(vec4(relativePosition * 0.3, time * 0.8)));
				float threshold = 0.075;
				if (noise > threshold) {
					continue;
				}
				float fadeFactor = sigmoidDescending(noise / threshold);
				tryNewClosestHit(closestForwardHit, PhysicalRayHit (
					false,
					vec3(0.0),
					t,
					true, // Teleport for see-through effect
					false,
					position,
					normalize(relativePosition),
					1.0,
					portalColour * outerShellPortalColourMultiplier * fadeFactor,
					position + rayDirection * 0.001,
					rayDirection
				));
			}

			// Check portal (inside outer shell)
			ConvexRaycastResult inPortalResult = sphereRaycast(inPortalPosition, pair.radius, rayStart, rayStart + rayDirection);
			if (!inPortalResult.hit) {
				continue;
			}
			float t = inPortalResult.t1; // No extra processing with t2 or anything
			vec3 position = rayStart + rayDirection * t;
			vec3 relativePosition = position - inPortalPosition; // Relative to sphere centre
			vec3 normal = normalize(relativePosition);
			float fadeFactor = max(0.0, -dot(rayDirection, normal));
			float etaNoise = 1.0 - 0.6 * (snoise(vec4(relativePosition, time * 0.2)) * 0.5 + 0.5);
			vec3 newDirection = refract(rayDirection, normal, etaNoise);
			tryNewClosestHit(closestForwardHit, PhysicalRayHit (
				false,
				vec3(0.0),
				t,
				true, // Teleport!
				false,
				position,
				normal,
				fadeFactor * 0.75 + 0.25,
				portalColour * portalTraversalColourMultiplier * (1.0 - fadeFactor),
				outPortalPosition - relativePosition * 1.001,
				newDirection
			));
		}
	}

	ConvexRaycastResult arenaBoundaryResult = sphereRaycast(vec3(0.0), arenaRadius, rayStart, rayStart + rayDirection);
	if (arenaBoundaryResult.hit) {
		vec3 arenaBoundaryHitPosition = rayStart + rayDirection * arenaBoundaryResult.t2;
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
				tryNewClosestHit(closestForwardHit, PhysicalRayHit (
					false,
					vec3(0.0),
					arenaBoundaryResult.t2,
					false,
					false,
					arenaBoundaryHitPosition,
					hitNormal,
					0.0,
					boundaryColour,
					vec3(0.0),
					vec3(0.0)
				));
			} else {
				vec3 directionWind = vec3(0.0, 0.0, 0.5) * rayDirection * nullificationFactor;
				tryNewClosestHit(closestForwardHit, PhysicalRayHit (
					false,
					vec3(0.0),
					arenaBoundaryResult.t2,
					true,
					true,
					arenaBoundaryHitPosition,
					hitNormal,
					1.0,
					vec3(0.0),
					-hitPosition,
					normalize(rayDirection + directionWind)
				));
			}
		}
	}

	// Particles should come last!

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
			t2 = min(closestForwardHit.t, t2);
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
				false,
				false,
				rayStart + rayDirection * closestParticleT,
				vec3(1.0), // Don't care value
				0.0,
				particleColour * (1.0 + warpedParticlePower * 4.0),
				vec3(0.0),
				vec3(0.0)
			);
		}
	}

	return closestForwardHit;
}

vec3 getRayColour(vec3 rayStart, vec3 rayStartDirection) {
	vec3 outColour = vec3(0.0);

	float distanceToSurface = arenaRadius - length(cameraPosition);
	float nullifyStart = arenaRadius * 0.2;
	// float nullificationFactor = min(1, distanceToSurface / nullifyStart);
	float nullificationFactor = distanceToSurface < nullifyStart ? sin(tau / 2.0 * (distanceToSurface / nullifyStart - 0.5)) * 0.5 + 0.5 : 1.0;

	int maxArenaTeleports = 2;
	float lastArenaTeleportVisibilityProportion = 0.25;

	vec3 rayPosition = rayStart;
	vec3 rayDirection = rayStartDirection;
	float influence = 1.0;
	int arenaTeleports = 0;
	float distanceTraversedPrior = 0.0; // Before current ray segment
	float arenaDiameter = 2.0 * arenaRadius;
	float maxLightDistance = arenaDiameter * (float(maxArenaTeleports + 1) - lastArenaTeleportVisibilityProportion);
	float lightDistanceFadeStart = arenaDiameter * float(maxArenaTeleports);
	for (int rayBounce = 0; rayBounce < maxRaySegments; rayBounce++) {
		float arenaTeleportFactor = mix(
			0.5,
			pow(1.0 - float(arenaTeleports) / float(maxArenaTeleports + 1), 2.0),
			nullificationFactor
		);
		if (arenaTeleportFactor == 0.0 || influence == 0.0) {
			break;
		}
		PhysicalRayHit closestHit = getClosestHit(rayPosition, rayDirection, nullificationFactor);
		if (!closestHit.sky) {
			vec3 fogStart = rayPosition;
			vec3 fogEnd = closestHit.position;
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
					insideLightsHere += 0.25 * light.intensity * light.colour * pow(max(0.0, 1.0 - distance(light.position, position) / (lightRadius + lightRadiusSizeExtra)), 4.0);
				}
				vec3 colourScatterance = fogSample.colour * fogSample.scatterance;
				float threshold = 0.01;
				bool disableLight =
					colourScatterance.r > threshold &&
					colourScatterance.g > threshold &&
					colourScatterance.b > threshold;
				vec3 light = disableLight ? vec3(0.0) : getIncomingLight(position);
				outColour +=
					rayEndFactor * arenaTeleportFactor * influence * stepSize * (
						fogSample.colour * fogSample.scatterance * light +
						fogSample.emission + insideLightsHere
					);
				influence *= exp(-fogExtinction * stepSize);
				currentDistance += stepSize;
				fogStepsCompleted += 1;
			}
		}
		if (!closestHit.sky) {
			float currentTotalDistance = distanceTraversedPrior + distance(rayPosition, closestHit.position);
			float rayEndFactor = 1.0 - clamp((currentTotalDistance - lightDistanceFadeStart) / (maxLightDistance - lightDistanceFadeStart), 0.0, 1.0);
			distanceTraversedPrior += distance(rayPosition, closestHit.position);
			vec3 incomingLight = getIncomingLightSurface(closestHit.position, closestHit.normal);
			outColour += rayEndFactor * (closestHit.colour * incomingLight + closestHit.emission) * arenaTeleportFactor * influence;
			influence *= closestHit.reflectivity;
			if (closestHit.reflectivity == 0.0) {
				break;
			}
			if (!closestHit.teleport) {
				rayDirection = reflect(rayDirection, closestHit.normal);
				rayPosition = closestHit.position + rayDirection * 0.0001;
			} else { // Teleport
				rayPosition = closestHit.teleportDestination;
				rayDirection = closestHit.teleportRayDirection;
				if (closestHit.arenaTeleport) {
					arenaTeleports += 1;
					if (arenaTeleports > maxArenaTeleports) {
						break;
					}
				}
			}
		} else {
			// Sky
			outColour = closestHit.colour * arenaTeleportFactor * influence;
			break;
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
