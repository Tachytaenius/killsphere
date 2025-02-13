local vec3 = require("lib.mathsies").vec3

return function(a, b) -- Both vectors should be normalised
	return math.acos(
		math.max(-1, math.min(1, -- Clamped to prevent NaN
			vec3.dot(a, b)
		))
	);
end
