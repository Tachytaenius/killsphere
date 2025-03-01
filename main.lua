require("monkeypatch")

local util = require("util")
util.load()
local settings = require("settings")
local consts = require("consts")
local assets = require("assets")
local classes = require("classes")

local gameInstance = require("gameInstance")
local graphics = require("graphics")

function love.load()
	util.remakeWindow()
	classes.load()
	gameInstance:init()
	graphics:init(gameInstance.state)
	assets.load()
end

function love.update(dt)
	gameInstance:update(dt)
	graphics:updateVolumetrics(gameInstance.state, dt)
end

function love.draw()
	graphics:draw(gameInstance.state, gameInstance.paused, gameInstance.lastUpdateDt)
	local x, y =
		(love.graphics.getWidth() - consts.canvasWidth * settings.graphics.canvasScale) / 2,
		(love.graphics.getHeight() - consts.canvasHeight * settings.graphics.canvasScale) / 2
	love.graphics.draw(graphics.outputCanvas, x, y, 0, settings.graphics.canvasScale)
	love.graphics.print(love.timer.getFPS())
end
