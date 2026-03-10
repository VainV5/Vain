-- Vain main — loads the GUI, universal module, and game-specific scripts

repeat task.wait() until game:IsLoaded()
if shared.vain then shared.vain:Uninject() end

local cloneref = cloneref or function(obj) return obj end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end

local function dbg(msg) warn('[Vain]', msg) end

local function getCommit()
	return isfile('vain/profiles/commit.txt') and readfile('vain/profiles/commit.txt') or 'main'
end

local function downloadFile(path, func)
	local remotePath = path:gsub('vain/', '')
	if not isfile(path) then
		local url = 'https://raw.githubusercontent.com/VainV5/Vain/' .. getCommit() .. '/' .. remotePath
		dbg('downloading: ' .. url)
		local suc, res = pcall(function()
			return game:HttpGet(url, true)
		end)
		if not suc or res == '404: Not Found' then
			dbg('FAILED: ' .. remotePath .. ' — ' .. tostring(res))
			error(res)
		end
		dbg('downloaded: ' .. remotePath .. ' (' .. #res .. ' bytes)')
		if path:find('.lua') then
			res = '--[vain cache]\n' .. res
		end
		writefile(path, res)
	else
		dbg('cached: ' .. path)
	end
	return (func or readfile)(path)
end

-- Load GUI
dbg('loading GUI...')
local ok, vain = pcall(function()
	return loadstring(downloadFile('vain/guis/new.lua'), 'gui')()
end)
if not ok then dbg('GUI ERROR: ' .. tostring(vain)) error(vain) end
dbg('GUI loaded')
shared.vain = vain

-- Load universal module
dbg('loading universal...')
local uok, uerr = pcall(function()
	loadstring(downloadFile('vain/games/universal.lua'), 'universal')()
end)
if not uok then dbg('universal ERROR: ' .. tostring(uerr)) end

-- Load game-specific module
local gameFile = 'vain/games/' .. game.PlaceId .. '.lua'
dbg('looking for game script: ' .. gameFile .. ' (PlaceId: ' .. game.PlaceId .. ')')
if isfile(gameFile) then
	dbg('loading cached game script...')
	local src = readfile(gameFile)
	local fn, lerr = loadstring(src, tostring(game.PlaceId))
	if not fn then
		dbg('game script SYNTAX ERROR: ' .. tostring(lerr))
	else
		local gok, gerr = pcall(fn)
		if not gok then dbg('game script ERROR: ' .. tostring(gerr)) end
	end
else
	local url = 'https://raw.githubusercontent.com/VainV5/Vain/' .. getCommit() .. '/games/' .. game.PlaceId .. '.lua'
	dbg('downloading game script: ' .. url)
	local suc, res = pcall(function()
		return game:HttpGet(url)
	end)
	if suc and res ~= '404: Not Found' then
		dbg('game script downloaded (' .. #res .. ' bytes), running...')
		writefile(gameFile, res)
		local fn, lerr = loadstring(res, tostring(game.PlaceId))
		if not fn then
			dbg('game script SYNTAX ERROR: ' .. tostring(lerr))
		else
			local gok, gerr = pcall(fn)
			if not gok then dbg('game script ERROR: ' .. tostring(gerr)) end
		end
	else
		dbg('no game script for PlaceId ' .. game.PlaceId .. ' (404 or error)')
	end
end

-- Finish loading
dbg('calling vain:Load()...')
vain:Load()
task.wait(0.5)
vain:CreateNotification('Vain', 'Press ' .. table.concat(vain.Keybind, ' + '):upper() .. ' to open GUI', 5)
dbg('done')
