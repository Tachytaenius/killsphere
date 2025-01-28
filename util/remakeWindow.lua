local consts = require("consts")
local settings = require("settings")

return function()
	local _, _, flags = love.window.getMode()
	local currentDisplay = flags.display

	love.window.setMode(
		consts.canvasWidth * settings.graphics.canvasScale,
		consts.canvasHeight * settings.graphics.canvasScale,
		{
			fullscreen = settings.graphics.fullscreen,
			borderless = settings.graphics.fullscreen,
			display = currentDisplay
		}
	)
	-- TODO: Set icon
	love.window.setTitle(consts.windowTitle)
end
