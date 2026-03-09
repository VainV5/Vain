-- Vain loader — handles versioning, folder setup, and file downloads

repeat task.wait() until game:IsLoaded()

local cloneref = cloneref or function(obj) return obj end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

local function dbg(msg) warn('[Vain]', msg) end

dbg('loader started')

-- Create folder structure
for _, folder in {'vain', 'vain/profiles', 'vain/games', 'vain/guis', 'vain/libraries'} do
	if not isfolder(folder) then
		makefolder(folder)
		dbg('created folder: ' .. folder)
	end
end

-- Always fetch latest commit from GitHub so new pushes are picked up automatically
dbg('checking latest commit from GitHub...')
local _, subbed = pcall(function()
	return game:HttpGet('https://github.com/VainV5/Vain')
end)
local pos = subbed and subbed:find('currentOid')
local commit = pos and subbed:sub(pos + 13, pos + 52) or nil
commit = (commit and #commit == 40) and commit or 'main'
dbg('latest commit: ' .. commit)

local cachedCommit = isfile('vain/profiles/commit.txt') and readfile('vain/profiles/commit.txt') or ''
dbg('cached commit: ' .. (cachedCommit ~= '' and cachedCommit or '(none)'))

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
		local url = 'https://raw.githubusercontent.com/VainV5/Vain/' .. readfile('vain/profiles/commit.txt') .. '/' .. remotePath
		dbg('downloading: ' .. url)
		downloader.Text = 'Downloading ' .. remotePath
		local suc, res = pcall(function()
			return game:HttpGet(url, true)
		end)
		if not suc or res == '404: Not Found' then
			dbg('FAILED: ' .. remotePath .. ' — ' .. tostring(res))
			downloader.Text = 'Failed: ' .. remotePath
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
	downloader.Text = ''
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if isfolder(path) then
		for _, v in listfiles(path) do
			if isfile(v) and not v:find('/profiles') then
				dbg('wiping: ' .. v)
				pcall(delfile, v)
			end
		end
	end
end

-- Wipe stale cache when commit has changed
if cachedCommit ~= commit then
	dbg('commit changed — wiping cache')
	wipeFolder('vain')
	wipeFolder('vain/games')
	wipeFolder('vain/guis')
	wipeFolder('vain/libraries')
else
	dbg('commit unchanged — using cache')
end

writefile('vain/profiles/commit.txt', commit)

dbg('loading main.lua...')
local ok, err = pcall(function()
	return loadstring(downloadFile('vain/main.lua'), 'main.lua')()
end)
if not ok then
	dbg('main.lua ERROR: ' .. tostring(err))
	error(err)
end
