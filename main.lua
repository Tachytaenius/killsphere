local mathsies = require("lib.mathsies")
local vec2 = mathsies.vec2
local vec3 = mathsies.vec3
local quat = mathsies.quat
local mat4 = mathsies.mat4

local util = require("util")
util.load()
local settings = require("settings")
local consts = require("consts")
local assets = require("assets")
local shapes = require("shapes")

local gameInstance = require("gameInstance")
local graphics = require("graphics")

function love.load()
	util.remakeWindow()
	shapes.load()
	gameInstance:init()
	graphics:init(gameInstance.state)
	assets.load()
end

function love.update(dt)
	gameInstance:update(dt)
end

function love.draw()
	graphics:draw(gameInstance.state, gameInstance.paused, gameInstance.lastUpdateDt)
	local x, y =
		(love.graphics.getWidth() - consts.canvasWidth * settings.graphics.canvasScale) / 2,
		(love.graphics.getHeight() - consts.canvasHeight * settings.graphics.canvasScale) / 2
	love.graphics.draw(graphics.outputCanvas, x, y, 0, settings.graphics.canvasScale)
	-- love.graphics.print(love.timer.getFPS())
end
