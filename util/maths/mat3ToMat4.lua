local mat4 = require("lib.mathsies").mat4

return function(m, use1InCorner)
	assert(use1InCorner ~= nil, "Must state whether to use a 1 in the bottom right corner of the matrix (true as second argument) or a zero (false)")
	return mat4(
		m[1], m[2], m[3], 0,
		m[4], m[5], m[6], 0,
		m[7], m[8], m[9], 0,
		0, 0, 0, use1InCorner and 1 or 0
	)
end
