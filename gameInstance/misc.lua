local vec3 = require("lib.mathsies").vec3

local gameInstance = {}

function gameInstance:handleTemporaryVariables()
	local state = self.state
	for entity in state.entities:elements() do
		entity:clearTemporaryFields()
		entity.will = {}
	end
	state.beamsToDraw = {}
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
