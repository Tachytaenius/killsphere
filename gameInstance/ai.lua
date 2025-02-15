local gameInstance = {}

function gameInstance:handleAi()
	local state = self.state

	for entity in state.entities:elements() do
		if entity == state.player then
			goto continue
		end
		if entity.guns then
			-- Skipping will system here I suppose
			for _, gun in ipairs(entity.guns) do
				assert(gun.triggered == nil, "Gun triggered state should be unset at this point in update (its triggered state was not cleared)")
				gun.triggered = true
			end
		end
	    ::continue::
	end
end

return gameInstance
