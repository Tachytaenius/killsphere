local shapes = {}

local function recurse(path)
	for _, itemName in ipairs(love.filesystem.getDirectoryItems(path)) do
		local itemPath = path .. itemName
		if itemPath ~= "shapes/init.lua" then
			if love.filesystem.getInfo(itemPath, "directory") then
				recurse(itemPath .. "/")
			elseif love.filesystem.getInfo(itemPath, "file") then
				if itemName:match("%.lua$") then
					local key = itemName:gsub("%.lua$", "")
					if key == "load" then
						error("Can't call a shape module reserved name \"load\"")
					elseif shapes[key] then
						error("Duplicate shape module name \"" .. key .. "\"")
					end
					shapes[key] = require(itemPath:gsub("%.lua", ""):gsub("/", "."))
				end
			end
		end
	end
end

function shapes.load()
	recurse("shapes/")
end

return shapes
