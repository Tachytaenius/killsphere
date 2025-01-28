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
		vec3(0.0)
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
			PlaneRaycastResult triangleResult = triangleRaycast(triangle.v1, triangle.v2, triangle.v3, rayStart, rayStart + rayDirection);
			vec3 position = rayStart + rayDirection * triangleResult.t;
			vec3 normal = triangleResult.normal;

			if (triangleResult.hit) {
				tryNewClosestHit(closestForwardHit, PhysicalRayHit (
					false,
					triangle.colour,
					triangleResult.t,
					position,
					normal
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
	for (int rayBounce = 0; rayBounce < maxRaySegments; rayBounce++) {
		float teleportFactor = mix(
			0.5,
			1.0 / float(2.0 * rayBounce + 1.0),
			nullificationFactor
		);
		PhysicalRayHit closestHit = getClosestHit(rayPosition, rayDirection);
		ConvexRaycastResult arenaBoundaryResult = sphereRaycast(vec3(0.0), arenaRadius, rayPosition, rayPosition + rayDirection);
		if (arenaBoundaryResult.hit && (closestHit.sky || closestHit.t > arenaBoundaryResult.t2)) {
			vec3 hitPosition = rayPosition + rayDirection * arenaBoundaryResult.t2;
			vec3 hitNormal = normalize(hitPosition);
			if (dot(rayDirection, hitNormal) > 0.0 || true) {
				if (
					mod(abs(hitNormal.x), 0.2) < 0.02 ||
					mod(abs(hitNormal.y), 0.2) < 0.02 ||
					mod(abs(hitNormal.z), 0.2) < 0.02
				) {
					vec3 boundaryColour = hitNormal * 0.5 + 0.5;
					outColour = boundaryColour * teleportFactor;
					break;
				}
				rayPosition = -hitPosition;
				vec3 directionWind = vec3(0.0, 0.0, 1.0) * rayDirection * nullificationFactor;
				rayDirection = normalize(rayDirection + directionWind);
			}
		} else if (!closestHit.sky) {
			outColour = closestHit.colour * (max(0.0, dot(normalize(vec3(1.0, 1.0, 1.0)), closestHit.normal)) * 0.75 + 0.25) * teleportFactor;
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
