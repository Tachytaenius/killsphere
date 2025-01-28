#line 1

struct PlaneRaycastResult {
	bool hit;
	float t;
	vec3 normal;
};
const PlaneRaycastResult planeRaycastMiss = PlaneRaycastResult (false, 0.0, vec3(0.0));

PlaneRaycastResult planeRaycast(vec3 planeNormal, float planeDistance, vec3 rayStart, vec3 rayEnd) {
	float p = dot(planeNormal, planeNormal * planeDistance);
	float ad = dot(rayStart, planeNormal);
	float bd = dot(rayEnd, planeNormal);
	float divisor = (bd - ad);
	if (divisor == 0.0) {
		return planeRaycastMiss;
	}
	return PlaneRaycastResult (true, (p - ad) / divisor, planeNormal);
}

PlaneRaycastResult triangleRaycast(vec3 v1, vec3 v2, vec3 v3, vec3 rayStart, vec3 rayEnd) {
	if (rayStart == rayEnd) {
		return planeRaycastMiss;
	}

	vec3 startToEnd = rayEnd - rayStart;
	vec3 rayDirection = normalize(startToEnd);

	vec3 v1ToV2 = v2 - v1;
	vec3 v2ToV3 = v3 - v2;
	vec3 v3ToV1 = v1 - v3;
	vec3 normal = normalize(cross(v1ToV2, v3ToV1));

	float d = -dot(normal, v1);
	float nDotDirection = dot(normal, rayDirection);
	if (nDotDirection == 0.0) {
		// Parallel to plane
		return planeRaycastMiss;
	}

	float tForDirection = -(dot(normal, rayStart) + d) / nDotDirection;
	vec3 p = rayStart + rayDirection * tForDirection;
	if (!(
		dot(normal, cross(v1ToV2, v1 - p)) > 0.0 &&
		dot(normal, cross(v2ToV3, v2 - p)) > 0.0 &&
		dot(normal, cross(v3ToV1, v3 - p)) > 0.0
	)) {
		return planeRaycastMiss;
	}
	return PlaneRaycastResult(true, tForDirection / length(startToEnd), normal);
}

struct ConvexRaycastResult {
	bool hit;
	float t1;
	float t2;
};
const ConvexRaycastResult convexRaycastMiss = ConvexRaycastResult (false, 0.0, 0.0);

ConvexRaycastResult sphereRaycast(vec3 spherePosition, float sphereRadius, vec3 rayStart, vec3 rayEnd) {
	if (rayStart == rayEnd) {
		return convexRaycastMiss;
	}

	vec3 startToEnd = rayEnd - rayStart;
	vec3 sphereToStart = rayStart - spherePosition;

	float a = dot(startToEnd, startToEnd);
	float b = 2.0 * dot(sphereToStart, startToEnd);
	float c = dot(sphereToStart, sphereToStart) - pow(sphereRadius, 2.0);
	float h = pow(b, 2.0) - 4.0 * a * c;
	if (h < 0.0) {
		return convexRaycastMiss;
	}
	float t1 = (-b - sqrt(h)) / (2.0 * a);
	float t2 = (-b + sqrt(h)) / (2.0 * a);
	return ConvexRaycastResult (true, t1, t2);
}

// Like sphereRaycast, but rayDirection is a direction (it's relative to the start, and it must be normalised). The return t's are in terms of actual distances. Inputting a non-normalised vector into direction breaks this function.
// This one doesn't break due to precision issues.
ConvexRaycastResult sphereRaycast2(vec3 spherePosition, float sphereRadius, vec3 rayStart, vec3 rayDirection) {
	vec3 sphereToStart = rayStart - spherePosition;
	float b = dot(sphereToStart, rayDirection);
	vec3 qc = sphereToStart - b * rayDirection;
	float h = sphereRadius * sphereRadius - dot(qc, qc);
	if (h < 0.0) {
		return convexRaycastMiss;
	}
	float sqrtH = sqrt(h);
	float t1 = -b - sqrtH;
	float t2 = -b + sqrtH;
	return ConvexRaycastResult (true, t1, t2);
}
