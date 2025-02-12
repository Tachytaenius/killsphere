local vec3 = require("lib.mathsies").vec3

local gameInstance = {}

function gameInstance:handleTemporaryVariables()
	local state = self.state
	local i = 1
	while i <= state.entities.size do
		local entity = state.entities:get(i)
		if entity.deleteNextUpdate then
			state.entities:remove(entity)
		else
			entity:clearTemporaryFields()
			entity.will = {}
			i = i + 1
		end
	end
	state.linesToDraw = {}
end

function gameInstance:executeWills(dt)
	local state = self.state
	for entity in state.entities:elements() do
		if not entity.will then
			goto continue
		end
		self:handleThrust(entity, dt)
		-- TODO: handle guns, etc
	    ::continue::
	end
end

return gameInstance
