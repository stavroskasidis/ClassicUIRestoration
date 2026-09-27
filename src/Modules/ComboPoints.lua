--[[
	Forevermore Classic UI - Combo Points (WoW Forever only)

	Forever keeps vanilla's combo points, which belong to the target, so they
	are drawn on the target frame (ComboFrame, with the classic ComboPoint
	art). Retail's combo points stay with the character and are shown on the
	player frame, which is why retail has no such option. The camelot overlay
	lays the points out in an arc over the top of the target's portrait: its
	ComboFrame.xml moves every point along the arc, and its
	ComboFrame_ApplyOverrides re-anchors the frame at the end of every update.
	Classic runs the five points down the right side of the portrait.

	Blizzard's frames, art, fading and show/hide logic are kept; only anchors
	change. Blizzard never re-anchors the points themselves, so they are set
	once, and the frame is put back after each override. ComboFrame and its
	points are plain frames (not protected), so this also works in combat.
]]

local _, ns = ...
if not ns.IS_FOREVER then return end
local Point = ns.Point

local module = ns:RegisterModule({
	key = "combopoints",
	name = "Combo Points",
	tooltip = "Restores the classic combo point layout on the target frame: the points run down the right side of the target's portrait instead of over its top.",
	live = true,
})

-- TOPRIGHT offsets in ComboFrame per ComboPoints index, from retail's
-- ComboFrame.xml, which still has the vanilla/Wrath arc: 2-6 are the five
-- classic points, 1 leads the row when the maximum is 6 or 9 (Blizzard then
-- starts at index 1 instead of 2) and 7-9 are the talent extras.
local CLASSIC_POINTS = {
	{ -9, 6 }, { 0, 0 }, { 7, -8 }, { 12, -19 }, { 14, -30 },
	{ 12, -41 }, { 24, -33 }, { 24, -22 }, { 20, -12 },
}

-- Vanilla put the frame's top right corner 2px left of and 3px above the
-- 64px portrait's (TargetFrame TOPRIGHT -44,-9 against -42,-12), which
-- centres the arc on the portrait. Anchored to the portrait's centre, it
-- stays centred on the camelot portrait while the Unit Frames option is off.
local FRAME_X, FRAME_Y = 30, 35

local enabled = false
local hooked = false
local blizzardAnchors = {} -- ComboPoints index -> Blizzard's anchor, for Disable

local function AnchorFrame()
	if not enabled then return end
	local portrait = TargetFrame.TargetFrameContainer and TargetFrame.TargetFrameContainer.Portrait
	if portrait then
		Point(ComboFrame, "TOPRIGHT", portrait, "CENTER", FRAME_X, FRAME_Y)
	end
end

function module:Enable()
	if not ComboFrame or not ComboFrame.ComboPoints or not TargetFrame then return end
	enabled = true
	for i, comboPoint in ipairs(ComboFrame.ComboPoints) do
		local offset = CLASSIC_POINTS[i]
		if offset then
			if not blizzardAnchors[i] then
				blizzardAnchors[i] = { comboPoint:GetPoint(1) }
			end
			Point(comboPoint, "TOPRIGHT", ComboFrame, "TOPRIGHT", offset[1], offset[2])
		end
	end
	AnchorFrame()
	if not hooked then
		hooked = ns.Hook("ComboFrame_ApplyOverrides", AnchorFrame)
	end
end

function module:Disable()
	enabled = false
	if not ComboFrame then return end
	for i, anchor in pairs(blizzardAnchors) do
		local comboPoint = ComboFrame.ComboPoints[i]
		comboPoint:ClearAllPoints()
		comboPoint:SetPoint(unpack(anchor))
	end
	-- Blizzard's own anchor for the frame (it only sets points on ComboFrame).
	if type(ComboFrame_ApplyOverrides) == "function" then
		ComboFrame_ApplyOverrides(ComboFrame)
	end
end
