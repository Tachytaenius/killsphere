local mat4 = require("lib.mathsies").mat4

return function(m)
	return mat4(
		-m._00,
		-m._01,
		-m._02,
		-m._03,
		-m._10,
		-m._11,
		-m._12,
		-m._13,
		-m._20,
		-m._21,
		-m._22,
		-m._23,
		-m._30,
		-m._31,
		-m._32,
		-m._33
	)
end
