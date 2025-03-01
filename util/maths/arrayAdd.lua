return function(a, b)
	assert(#a == #b, "a and b must have the same length")
	local ret = {}
	for i, aValue in ipairs(a) do
		local bValue = b[i]
		ret[i] = aValue + bValue
	end
	return ret
end
