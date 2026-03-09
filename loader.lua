-- Vain loader — handles versioning, folder setup, and file downloads

repeat task.wait() until game:IsLoaded()

local cloneref = cloneref or function(obj) return obj end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

-- Create folder structure
for _, folder in {'vain', 'vain/profiles', 'vain/games', 'vain/guis', 'vain/libraries'} do
	if not isfolder(folder) then makefolder(folder) end
end

-- Resolve commit
local commit
if isfile('vain/profiles/commit.txt') then
	commit = readfile('vain/profiles/commit.txt')
end
if not commit or commit == '' then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/VainV5/Vain')
	end)
	local pos = subbed and subbed:find('currentOid')
	commit = pos and subbed:sub(pos + 13, pos + 52) or 'main'
	commit = #commit == 40 and commit or 'main'
end

-- Download progress label
local downloader = Instance.new('TextLabel')
downloader.Size = UDim2.new(1, 0, 0, 40)
downloader.Position = UDim2.new(0, 0, 0.5, -20)
downloader.BackgroundTransparency = 1
downloader.TextStrokeTransparency = 0
downloader.Text = ''
downloader.TextSize = 20
downloader.TextColor3 = Color3.new(1, 1, 1)
downloader.Font = Enum.Font.Arimo
downloader.Parent = gethui and gethui() or cloneref(game:GetService('Players')).LocalPlayer:WaitForChild('PlayerGui', 9e9)

local function downloadFile(path, func)
	local remotePath = path:gsub('vain/', '')
	if not isfile(path) then
		downloader.Text = 'Downloading ' .. remotePath
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/VainV5/Vain/' .. readfile('vain/profiles/commit.txt') .. '/' .. remotePath, true)
		end)
		if not suc or res == '404: Not Found' then
			downloader.Text = 'Failed: ' .. remotePath
			error(res)
		end
		if path:find('.lua') then
			res = '--[vain cache]\n' .. res
		end
		writefile(path, res)
	end
	downloader.Text = ''
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if isfolder(path) then
		for _, v in listfiles(path) do
			if isfile(v) and not v:find('/profiles') then
				pcall(delfile, v)
			end
		end
	end
end

-- Wipe stale cache on update
if not isfile('vain/profiles/commit.txt') or readfile('vain/profiles/commit.txt') ~= commit then
	wipeFolder('vain')
	wipeFolder('vain/games')
	wipeFolder('vain/guis')
	wipeFolder('vain/libraries')
end

writefile('vain/profiles/commit.txt', commit)

return loadstring(downloadFile('vain/main.lua'), 'main.lua')()
