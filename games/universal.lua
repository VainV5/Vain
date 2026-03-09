-- Vain — Universal Module
-- This file runs on EVERY game, before any game-specific module.
-- Use it for cross-game features (e.g. auto-reject friend requests, custom UI panels, etc.)
-- The Vain API is available via shared.vain

local vain = shared.vain

-- Example: add a universal "Utility" category with a test button
--[[
local Utility = vain:CreateCategory({
	Name = 'Utility',
	Icon = '',
})

Utility:CreateButton({
	Name = 'Test Notification',
	Function = function()
		vain:CreateNotification('Vain', 'Hello from the universal module!', 3, 'info')
	end,
})
--]]
