return function(s, a)
	local ret = {}
	for i, v in ipairs(a) do
		ret[i] = s * v
	end
	return ret
end
