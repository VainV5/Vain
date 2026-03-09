-- Vain main — loads the GUI, universal module, and game-specific scripts

repeat task.wait() until game:IsLoaded()
if shared.vain then shared.vain:Uninject() end

local cloneref = cloneref or function(obj) return obj end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end

local function getCommit()
	return isfile('vain/profiles/commit.txt') and readfile('vain/profiles/commit.txt') or 'main'
end

local function downloadFile(path, func)
	local remotePath = path:gsub('vain/', '')
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/VainV5/Vain/' .. getCommit() .. '/' .. remotePath, true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--[vain cache]\n' .. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

-- Load GUI
local vain = loadstring(downloadFile('vain/guis/new.lua'), 'gui')()
shared.vain = vain

-- Load universal module (runs on every game)
loadstring(downloadFile('vain/games/universal.lua'), 'universal')()

-- Load game-specific module if available
local gameFile = 'vain/games/' .. game.PlaceId .. '.lua'
if isfile(gameFile) then
	loadstring(readfile(gameFile), tostring(game.PlaceId))()
else
	local suc, res = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/VainV5/Vain/' .. getCommit() .. '/games/' .. game.PlaceId .. '.lua')
	end)
	if suc and res ~= '404: Not Found' then
		writefile(gameFile, res)
		loadstring(res, tostring(game.PlaceId))()
	end
end

-- Finish loading
vain:Load()
task.wait(0.5)
vain:CreateNotification('Vain', 'Press ' .. table.concat(vain.Keybind, ' + '):upper() .. ' to open GUI', 5)
