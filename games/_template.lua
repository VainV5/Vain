-- Vain — Game Module Template
-- Copy this file and rename it to the game's PlaceId (e.g. 606849621.lua).
-- It will be auto-loaded by main.lua when that game is detected.
-- The Vain API is available via shared.vain

local vain = shared.vain
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local runService     = cloneref(game:GetService('RunService'))
local lplr = playersService.LocalPlayer

-- ── Create a category for this game ───────────────────────────────────────────
local MyCategory = vain:CreateCategory({
	Name = 'My Game',   -- Tab name shown in the GUI
	Icon = '',          -- Optional: rbxassetid:// icon
})

-- ── Add modules / toggles ─────────────────────────────────────────────────────
local myToggle = MyCategory:CreateModule({
	Name     = 'My Feature',
	Bind     = {},        -- Default keybind (e.g. {'F'})
	Function = function(enabled)
		-- called every time the toggle is switched
	end,
})

-- ── Add sub-options to a module ───────────────────────────────────────────────
myToggle:CreateSlider({
	Name    = 'Speed',
	Min     = 1,
	Max     = 100,
	Default = 16,
	Function = function(val)
		-- called when slider value changes
	end,
})

-- ── Game loop (runs while injected) ───────────────────────────────────────────
vain:Clean(runService.Heartbeat:Connect(function()
	if not myToggle.Enabled then return end
	-- your per-frame logic here
end))
