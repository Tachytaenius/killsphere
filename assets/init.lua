local util = require("util")

local assets = {}

function assets.load()
	assets.images = {}
	assets.images.bayer8 = love.graphics.newImage("assets/images/bayer8.png")
end

return assets
