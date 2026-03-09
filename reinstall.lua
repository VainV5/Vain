-- Vain reinstall — wipes all cached files and re-downloads everything fresh
-- Run this if Vain is broken or you want a clean reinstall

local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

local function wipeFolder(path)
	if isfolder(path) then
		for _, v in listfiles(path) do
			if isfile(v) and not v:find('/profiles') then
				pcall(delfile, v)
			end
		end
	end
end

wipeFolder('vain')
wipeFolder('vain/games')
wipeFolder('vain/guis')
wipeFolder('vain/libraries')

-- Also wipe commit.txt so the next run fetches fresh files
if isfile('vain/profiles/commit.txt') then
	pcall(delfile, 'vain/profiles/commit.txt')
end

print('[Vain] Cache wiped — reinstalling...')
loadstring(game:HttpGet('https://raw.githubusercontent.com/VainV5/Vain/main/vain.lua'))()
