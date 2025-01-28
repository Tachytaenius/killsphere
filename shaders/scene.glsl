#line 1

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
	float nullifyStart = arenaRadius * 0.125;
	// float nullificationFactor = min(1, distanceToSurface / nullifyStart);
	float nullificationFactor = distanceToSurface < nullifyStart ? sin(tau / 4.0 * distanceToSurface / nullifyStart) : 1.0;

	vec3 rayPosition = rayStart;
	vec3 rayDirection = rayStartDirection;
	float influence = 1.0;
	int teleports = 0;
	int maxTeleports = 3;
	for (int rayBounce = 0; rayBounce < maxRaySegments; rayBounce++) {
		float teleportFactor = mix(
			0.5,
			1.0 / float(6.0 * teleports + 1.0),
			nullificationFactor
		);
		PhysicalRayHit closestHit = getClosestHit(rayPosition, rayDirection);
		ConvexRaycastResult arenaBoundaryResult = sphereRaycast(vec3(0.0), arenaRadius, rayPosition, rayPosition + rayDirection);
		if (arenaBoundaryResult.hit && (closestHit.sky || closestHit.t > arenaBoundaryResult.t2)) {
			vec3 hitPosition = rayPosition + rayDirection * arenaBoundaryResult.t2;
			vec3 hitNormal = normalize(hitPosition);
			if (dot(rayDirection, hitNormal) > 0.0 || true) {
				if (
					mod(abs(hitNormal.x), 0.2) < 0.0075 ||
					mod(abs(hitNormal.y), 0.2) < 0.0075 ||
					mod(abs(hitNormal.z), 0.2) < 0.0075
				) {
					// vec3 boundaryColour = hitNormal * 0.5 + 0.5;
					vec3 boundaryColour = vec3(0.2, 0.0, 0.0);
					outColour += boundaryColour * teleportFactor * influence;
					break;
				}
				rayPosition = -hitPosition;
				vec3 directionWind = vec3(0.0, 0.0, 0.5) * rayDirection * nullificationFactor;
				rayDirection = normalize(rayDirection + directionWind);
				teleports += 1;
				if (teleports > maxTeleports) {
					break;
				}
			}
		} else if (!closestHit.sky) {
			// float formShadowFactor = max(0.0, dot(normalize(vec3(1.0, 1.0, 1.0));
			float formShadowFactor = dot(normalize(vec3(1.0, 1.0, 1.0)), closestHit.normal) * 0.5 + 0.5;

			vec3 incomingLight = vec3(1.0, 1.0, 1.0) * formShadowFactor;
			outColour += closestHit.colour * incomingLight * teleportFactor * influence;
			if (closestHit.reflectivity == 0.0) {
				break;
			}
			if (dot(closestHit.normal, rayDirection) < 0.0) {
				rayDirection = reflect(rayDirection, closestHit.normal);
				rayPosition = closestHit.position + rayDirection * 0.0001;
				influence *= closestHit.reflectivity;
			}
		} else {
			// Sky
			outColour = closestHit.colour * influence;
			break;
		}
	}
	return outColour;
}

vec4 effect(vec4 loveColour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	vec3 direction = normalize(directionPreNormalise);

	// I could just do a circle with the texture coordinates but I'm too cool for that
	if (angleBetween(cameraForwardVector, direction) > cameraFOV / 2.0) {
		discard;
	}

	vec3 outColour = getRayColour(cameraPosition, direction);
	return loveColour * vec4(outColour, 1.0);
}

#endif
