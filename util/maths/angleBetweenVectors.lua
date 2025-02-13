local vec3 = require("lib.mathsies").vec3

return function(a, b)
	return math.acos(
		math.max(-1, math.min(1, -- Clamped to prevent NaN
			vec3.dot(
				vec3.normalise(a),
				vec3.normalise(b)
			)
		))
	);
end
