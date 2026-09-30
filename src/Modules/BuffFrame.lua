--[[
	Forevermore Classic UI - Buffs

	1.x's buffs had no collapse arrow: the modern buff frame
	(BuffFrame.CollapseAndExpandButton, a CheckButton with the "bag-arrow"
	atlas) folds long and permanent buffs away behind it. This option takes
	the arrow away while the buffs are expanded, so they always show.

	The arrow is faded (alpha 0) and deaf to the mouse, never hidden:
	Blizzard shows and hides it on every buff update
	(RefreshConsolidationFrameVisibility, edit mode), but never touches its
	alpha or mouse, so both widget calls stick without a hook. Its size and
	anchors are left alone: the icons stay anchored to it (15px from the
	frame's edge, as they are with the game's collapse setting off), and
	re-sizing it would be undone on every buff update, in combat too. The
	other ways were not taken: the collapseExpandBuffs CVar and
	SetBuffsExpandedState run Blizzard's buff update from addon code, and
	its right-click cancel (CancelUnitBuff) reads the button info that
	update writes.

	The expanded state is not saved (BuffFrame starts expanded), so a
	collapsed frame only happens when the option is turned on after the
	player collapsed it: the arrow is then left as it is until the player
	expands the buffs with it.
]]

local _, ns = ...

local module = ns:RegisterModule({
	key = "buffs",
	name = "Buffs",
	tooltip = "Removes the modern arrow that collapses your buffs; classic had none, so every buff shows.",
	live = true,
})

local enabled = false
local hooked = false

local function Arrow()
	return BuffFrame and BuffFrame.CollapseAndExpandButton
end

-- Checked is expanded (CollapseAndExpandButtonMixin:OnClick).
local function Refresh()
	local arrow = Arrow()
	if not arrow then return end
	local hide = enabled and arrow:GetChecked()
	arrow:SetAlpha(hide and 0 or 1)
	arrow:EnableMouse(not hide)
end

function module:Enable()
	local arrow = Arrow()
	if not arrow then return end
	enabled = true
	if not hooked then
		hooked = true
		-- Collapsed when the option was turned on: gone once expanded.
		arrow:HookScript("OnClick", Refresh)
	end
	Refresh()
end

function module:Disable()
	enabled = false
	Refresh()
end
