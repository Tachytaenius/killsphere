local mat4 = require("lib.mathsies").mat4

return function(a, b)
	return mat4(
		a._00 + b._00,
		a._01 + b._01,
		a._02 + b._02,
		a._03 + b._03,
		a._10 + b._10,
		a._11 + b._11,
		a._12 + b._12,
		a._13 + b._13,
		a._20 + b._20,
		a._21 + b._21,
		a._22 + b._22,
		a._23 + b._23,
		a._30 + b._30,
		a._31 + b._31,
		a._32 + b._32,
		a._33 + b._33
	)
end
