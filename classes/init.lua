local classes = {}

local function recurse(path)
	for _, itemName in ipairs(love.filesystem.getDirectoryItems(path)) do
		local itemPath = path .. itemName
		if itemPath ~= "classes/init.lua" then
			if love.filesystem.getInfo(itemPath, "directory") then
				recurse(itemPath .. "/")
			elseif love.filesystem.getInfo(itemPath, "file") then
				if itemName:match("%.lua$") then
					local key = itemName:gsub("%.lua$", "")
					if key == "load" then
						error("Can't call a class module reserved name \"load\"")
					elseif classes[key] then
						error("Duplicate class module name \"" .. key .. "\"")
					end
					classes[key] = require(itemPath:gsub("%.lua", ""):gsub("/", "."))
				end
			end
		end
	end
end

function classes.load()
	recurse("classes/")
end

return classes
