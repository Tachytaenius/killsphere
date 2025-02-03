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

	// TODO: Filter colour and emission by adding scatterance into the weighted averaging so that you don't have to deal with no-scattering voxels of colour in the filtering
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

vec3 getIncomingLight(vec3 surfacePosition, int ignoreObjectId) {
	return vec3(1.0); // TODO
}

vec3 getIncomingLightSurface(vec3 surfacePosition, vec3 surfaceNormal, int ignoreObjectId) {
	return vec3(1.0); // TODO
}

struct PhysicalRayHit {
	bool sky;
	vec3 colour;
	float t;
	vec3 position;
	vec3 normal;
	float reflectivity;
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
		0.0
	);

	for (int j = 0; j < boundingSphereCount; j++) {
		BoundingSphere boundingSphere = boundingSpheres[j];
		ConvexRaycastResult boundingSphereResult = sphereRaycast(boundingSphere.position, boundingSphere.radius, rayStart, rayStart + rayDirection);
		if (!boundingSphereResult.hit) {
			// TODO: Also check t stuff (if needed)
			continue;
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
					triangleReflectivityHere
				));
			}
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

vec3 getRayColour(vec3 rayStart, vec3 rayStartDirection) {
	vec3 outColour = vec3(0.0);

	float distanceToSurface = arenaRadius - length(cameraPosition);
	float nullifyStart = arenaRadius * 0.2;
	// float nullificationFactor = min(1, distanceToSurface / nullifyStart);
	float nullificationFactor = distanceToSurface < nullifyStart ? sin(tau / 2.0 * (distanceToSurface / nullifyStart - 0.5)) * 0.5 + 0.5 : 1.0;

	vec3 rayPosition = rayStart;
	vec3 rayDirection = rayStartDirection;
	float influence = 1.0;
	int teleports = 0;
	int maxTeleports = 3;
	float distanceTraversedPrior = 0.0; // Before current ray segment
	float maxLightDistance = arenaRadius * maxTeleports;
	float lightDistanceFadeStart = arenaRadius * (maxTeleports - 1);
	for (int rayBounce = 0; rayBounce < maxRaySegments; rayBounce++) {
		float teleportFactor = mix(
			0.5,
			pow(1.0 - float(teleports) / float(maxTeleports), 6.0),
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
			while (fogStepsCompleted < maxFogSteps && currentDistance < totalDistance) {
				float stepSize = min(totalDistance, currentDistance + fogDistancePerSample) - currentDistance;
				vec3 position = fogStart + direction * currentDistance;
				FogSample fogSample = sampleFog(position);
				float fogExtinction = fogSample.absorption + fogSample.scatterance;
				float currentTotalDistance = distanceTraversedPrior + currentDistance;
				float rayEndDistance = 1.0 - clamp((currentTotalDistance - lightDistanceFadeStart) / (maxLightDistance - lightDistanceFadeStart), 0.0, 1.0);
				outColour += rayEndDistance * teleportFactor * influence * fogSample.colour * fogSample.scatterance * stepSize * getIncomingLight(position, -1);
				outColour += rayEndDistance * teleportFactor * influence * fogSample.emission * stepSize;
				influence *= exp(-fogExtinction * stepSize);
				currentDistance += stepSize;
				fogStepsCompleted += 1;
			}
		}
		if (arenaBoundaryHit) {
			vec3 hitPosition = arenaBoundaryHitPosition;
			vec3 hitNormal = normalize(hitPosition);
			if (dot(rayDirection, hitNormal) > 0.0 || true) {
				if (
					mod(abs(hitNormal.x), 0.2) < 0.0075 ||
					mod(abs(hitNormal.y), 0.2) < 0.0075 ||
					mod(abs(hitNormal.z), 0.2) < 0.0075
				) {
					// vec3 boundaryColour = hitNormal * 0.5 + 0.5;
					vec3 boundaryColour = vec3(0.2, 0.0, 0.0);
					float currentTotalDistance = distanceTraversedPrior + distance(rayPosition, arenaBoundaryHitPosition);
					float rayEndDistance = 1.0 - clamp((currentTotalDistance - lightDistanceFadeStart) / (maxLightDistance - lightDistanceFadeStart), 0.0, 1.0);
					outColour += boundaryColour * teleportFactor * influence;
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
				float formShadowFactor = dot(normalize(vec3(1.0, 1.0, 1.0)), closestHit.normal) * 0.5 + 0.5;
				vec3 incomingLight = vec3(1.0, 1.0, 1.0) * formShadowFactor;
				float currentTotalDistance = distanceTraversedPrior + distance(rayPosition, closestHit.position);
				float rayEndDistance = 1.0 - clamp((currentTotalDistance - lightDistanceFadeStart) / (maxLightDistance - lightDistanceFadeStart), 0.0, 1.0);
				outColour += closestHit.colour * incomingLight * teleportFactor * influence;
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

// uniform sampler2D bayerMatrix;
// uniform int bayerMatrixSize;

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
	// float bayerValue = texelFetch(bayerMatrix, ivec2(int(windowCoords.x) % bayerMatrixSize, int(windowCoords.y) % bayerMatrixSize), 0).r;
	// float steps = 8.0;
	// outColour = outColour + bayerValue / steps;
	// outColour = floor(outColour * steps) / steps;
	return fovFadeFactor * loveColour * vec4(outColour, 1.0);
}

#endif
