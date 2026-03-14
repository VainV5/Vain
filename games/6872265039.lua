-- Vain — Bedwars (6872265039)
-- Ported from CatV6 by MaxlaserTech

local vain = shared.vain
local cloneref = cloneref or function(obj) return obj end

local playersService    = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService        = cloneref(game:GetService('RunService'))
local inputService      = cloneref(game:GetService('UserInputService'))
local lplr              = playersService.LocalPlayer

-- ── Bedwars internals (Knit / Flamework) ──────────────────────────────────────
local bedwars = nil

task.spawn(function()
	local ok, err = pcall(function()
		-- Wait for Knit framework to initialize
		local KnitInit, Knit
		repeat
			KnitInit, Knit = pcall(function()
				return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
			end)
			if KnitInit then break end
			task.wait()
		until KnitInit

		if not debug.getupvalue(Knit.Start, 1) then
			repeat task.wait() until debug.getupvalue(Knit.Start, 1)
		end

		local Flamework = require(
			replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out
		).Flamework
		local Client = require(replicatedStorage.TS.remotes).default.Client

		bedwars = setmetatable({
			Client       = Client,
			CrateItemMeta = debug.getupvalue(
				Flamework.resolveDependency(
					'client/controllers/global/reward-crate/crate-controller@CrateController'
				).onStart, 3
			),
			Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		}, {
			__index = function(self, ind)
				rawset(self, ind, Knit.Controllers[ind])
				return rawget(self, ind)
			end,
		})

		vain:Clean(function() if bedwars then table.clear(bedwars) end end)
	end)

	if not ok then
		vain:CreateNotification('Bedwars', 'Init failed: ' .. tostring(err), 6, 'alert')
	end
end)

-- Polls until bedwars is ready (max `timeout` seconds). Returns true/false.
local function waitBedwars(timeout)
	local elapsed = 0
	while not bedwars and elapsed < (timeout or 12) do
		task.wait(0.5)
		elapsed = elapsed + 0.5
	end
	return bedwars ~= nil
end

-- ── Categories ─────────────────────────────────────────────────────────────────
local Combat  = vain.Categories.Combat
local Utility = vain.Categories.Utility
local Render  = vain.Categories.Render

-- ── Sprint ─────────────────────────────────────────────────────────────────────
-- Forces SprintController to always be sprinting. Saves / restores the original
-- stopSprinting function so it can be cleanly undone.
local Sprint
Sprint = Combat:CreateModule({
	Name    = 'Sprint',
	Tooltip = 'Forces your character to always sprint',
	Bind    = {},
	Function = function(enabled)
		if not waitBedwars(12) then
			vain:CreateNotification('Bedwars', 'Sprint: not loaded yet', 3, 'alert')
			Sprint:Toggle()
			return
		end

		if enabled then
			if inputService.TouchEnabled then
				pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = false end)
			end

			-- Monkey-patch stopSprinting so calling it immediately re-starts sprinting
			local orig = bedwars.SprintController.stopSprinting
			Sprint._orig = orig
			bedwars.SprintController.stopSprinting = function(...)
				local call = orig(...)
				bedwars.SprintController:startSprinting()
				return call
			end

			-- Re-apply after respawn
			vain:Clean(lplr.CharacterAdded:Connect(function()
				task.wait(0.5)
				if Sprint.Enabled then
					bedwars.SprintController:stopSprinting()
				end
			end))

			bedwars.SprintController:stopSprinting()
		else
			if inputService.TouchEnabled then
				pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end)
			end
			if Sprint._orig then
				bedwars.SprintController.stopSprinting = Sprint._orig
				Sprint._orig = nil
			end
			bedwars.SprintController:stopSprinting()
		end
	end,
})

-- ── Auto Gamble ────────────────────────────────────────────────────────────────
-- Iterates your crate inventory and opens each crate automatically.
-- Notifies you what you won via the CrateOpened remote event.
local AutoGamble
AutoGamble = Utility:CreateModule({
	Name    = 'Auto Gamble',
	Tooltip = 'Automatically opens lucky crates from your inventory',
	Bind    = {},
	Function = function(enabled)
		if not enabled then return end
		if not waitBedwars(12) then
			vain:CreateNotification('Bedwars', 'Auto Gamble: not loaded yet', 3, 'alert')
			return
		end

		-- Notify on win
		vain:Clean(
			bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
				if data.openingPlayer == lplr then
					local meta = bedwars.CrateItemMeta[data.reward.itemType]
					local name = meta and meta.displayName or (data.reward.itemType or 'Unknown')
					vain:CreateNotification('Auto Gamble', 'Won ' .. name, 5)
				end
			end)
		)

		task.spawn(function()
			repeat
				if not bedwars.CrateAltarController.activeCrates[1] then
					for _, v in bedwars.Store:getState().Consumable.inventory do
						if v.consumable:find('crate') then
							bedwars.CrateAltarController:pickCrate(v.consumable, 1)
							task.wait(1.2)
							local active = bedwars.CrateAltarController.activeCrates[1]
							if active and active[2] then
								bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
									crateId = active[2].attributes.crateId,
								})
							end
							break
						end
					end
				end
				task.wait(1)
			until not AutoGamble.Enabled
		end)
	end,
})

-- ── Stream Proof ───────────────────────────────────────────────────────────────
-- Replaces every TextLabel that shows your username (TabList, KillFeed, nametag)
-- with "Me" so your name doesn't appear on screen when streaming.
local StreamProof
local streamOrigNames = {}
local streamNTConn

local function modifyLabel(lbl)
	if not lbl:IsA('TextLabel') then return end
	local watch = {PlayerName = true, EntityName = true, DisplayName = true}
	if not watch[lbl.Name] then return end
	if lbl.Text:find(lplr.Name) or lbl.Text:find(lplr.DisplayName) then
		if not streamOrigNames[lbl] then streamOrigNames[lbl] = lbl.Text end
		lbl.Text = 'Me'
	end
end

local function restoreLabel(lbl)
	if streamOrigNames[lbl] then
		lbl.Text = streamOrigNames[lbl]
		streamOrigNames[lbl] = nil
	end
end

local function scanGui(gui)
	for _, desc in gui:GetDescendants() do modifyLabel(desc) end
end

local function patchNametag(char)
	if not char then return end
	local head = char:FindFirstChild('Head')
	if not head then return end
	local tag = head:FindFirstChild('Nametag')
	if not tag then return end
	local container = tag:FindFirstChild('DisplayNameContainer')
	if not container then return end
	local lbl = container:FindFirstChild('DisplayName')
	if lbl then modifyLabel(lbl) end
end

local function restoreNametag(char)
	if not char then return end
	local head = char:FindFirstChild('Head')
	if not head then return end
	local tag = head:FindFirstChild('Nametag')
	if not tag then return end
	for _, desc in tag:GetDescendants() do restoreLabel(desc) end
end

StreamProof = Render:CreateModule({
	Name    = 'Stream Proof',
	Tooltip = 'Hides your username in TabList, KillFeed, and nametags',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			-- Process existing target GUIs
			for _, guiName in {'TabListScreenGui', 'KillFeedGui'} do
				local g = lplr.PlayerGui:FindFirstChild(guiName)
				if g then
					scanGui(g)
					vain:Clean(g.DescendantAdded:Connect(modifyLabel))
				end
			end

			-- Watch for those GUIs appearing later
			vain:Clean(lplr.PlayerGui.ChildAdded:Connect(function(g)
				if g.Name == 'TabListScreenGui' or g.Name == 'KillFeedGui' then
					scanGui(g)
					vain:Clean(g.DescendantAdded:Connect(modifyLabel))
				end
			end))

			-- Nametag patch
			if lplr.Character then patchNametag(lplr.Character) end
			vain:Clean(lplr.CharacterAdded:Connect(function(char)
				task.wait(0.5)
				if StreamProof.Enabled then patchNametag(char) end
			end))

			streamNTConn = runService.RenderStepped:Connect(function()
				if lplr.Character then pcall(patchNametag, lplr.Character) end
			end)
		else
			if streamNTConn then streamNTConn:Disconnect(); streamNTConn = nil end

			for _, guiName in {'TabListScreenGui', 'KillFeedGui'} do
				local g = lplr.PlayerGui:FindFirstChild(guiName)
				if g then
					for _, desc in g:GetDescendants() do restoreLabel(desc) end
				end
			end

			restoreNametag(lplr.Character)
			table.clear(streamOrigNames)
		end
	end,
})
