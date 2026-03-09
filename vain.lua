-- Vain entry point
-- loadstring(game:HttpGet('https://raw.githubusercontent.com/VainV5/Vain/main/vain.lua'))()

repeat task.wait() until game:IsLoaded()

local cloneref = cloneref or function(obj) return obj end

if not isfolder('vain') then makefolder('vain') end
if not isfolder('vain/profiles') then makefolder('vain/profiles') end

local _, subbed = pcall(function()
	return game:HttpGet('https://github.com/VainV5/Vain')
end)

local commit = subbed and subbed:find('currentOid')
commit = commit and subbed:sub(commit + 13, commit + 52) or nil
commit = commit and #commit == 40 and commit or 'main'

local function downloadFile(path, func)
	local remotePath = path:gsub('vain/', '')
	if not isfile(path) or (not isfile('vain/profiles/commit.txt') or readfile('vain/profiles/commit.txt') ~= commit) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/VainV5/Vain/' .. commit .. '/' .. remotePath, true)
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

return loadstring(downloadFile('vain/loader.lua'), 'loader.lua')()
