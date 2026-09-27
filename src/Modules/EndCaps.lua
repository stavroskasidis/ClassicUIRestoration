--[[
	Classic UI Restoration - Action Bar End Caps

	Puts the vanilla stone gryphons (Interface\MainMenuBar\UI-MainMenuBar-
	EndCap-Dwarf) back at the two ends of the main action bar in place of the
	retail gryphon/wyvern atlases (ui-hud-actionbar-gryphon-*/-wyvern-*).

	Classic (1.12 through Wrath) showed the same gryphon file to both
	factions: the left cap draws the texture as is (gryphon facing the bar),
	the right cap draws it mirrored (TexCoords 1..0). The file is 128x128 with
	the art in its lower 76 rows, so it is cropped to the art; the retail
	buttons are 45px where classic had 36px, so the art is scaled by 1.25
	(160x95) to keep the classic gryphon-to-button proportion. The Horde
	wyvern only appeared in Battle for Azeroth and is not classic.

	Blizzard (MainActionBarMixin:UpdateEndCaps) puts the faction atlas back
	on the caps whenever the bar is shown, Edit Mode refreshes the bar art or
	a neutral Pandaren picks a faction; that method is hooked so the classic
	art is re-applied afterwards.

	Two client layouts are handled (the difference is structural, not by
	flavor): on retail the caps (MainActionBar.EndCaps.LeftEndCap/RightEndCap)
	are plain textures anchored to the bar's bottom corners and are re-anchored
	here; on WoW Forever each cap is an Edit Mode system frame (movable, with
	its own visibility setting) holding a .Texture that fills it, so only that
	texture is swapped and the frame's position is left to Edit Mode.

	Everything touched is widget state on the caps (no Lua fields are written
	on Blizzard's frames), so this module can be toggled live: the retail
	atlas, size and anchors are recorded the first time the classic art is
	applied and put back on disable.
]]

local _, ns = ...
local T = ns.T

T.ENDCAP_GRYPHON = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf"

local module = ns:RegisterModule({
	key = "endcaps",
	name = "Action Bar Gryphons",
	tooltip = "Restores the vanilla stone gryphons at the ends of the main action bar (classic showed gryphons to both factions).",
	live = true,
})

-- 128x128 file, art in rows 52..128 (76 px), scaled to the retail 45px
-- buttons (classic: 36px) -> 160x95.
local ART_TOP = 52 / 128
local CAP_WIDTH, CAP_HEIGHT = 160, 95
-- Retail anchors its caps 9px into the bar and 22px below it; classic sat
-- the gryphon's base 4px (x1.25 = 5) under the buttons with its paw at the
-- first button's edge. The caps draw above the buttons on retail, so the
-- classic 24px paw overlap (which the buttons covered in classic) is not
-- reproduced.
local CAP_INSET_X, CAP_OFFSET_Y = 9, -5

local enabled = false
local hooked = false
local retail = setmetatable({}, { __mode = "k" }) -- cap texture -> retail state

local function GetCaps()
	local endCaps = MainActionBar and MainActionBar.EndCaps
	if not endCaps then return nil end
	return endCaps, endCaps.LeftEndCap, endCaps.RightEndCap
end

-- The texture that carries the cap art, and whether it is a bare texture
-- anchored by Blizzard to the bar (retail) or fills an Edit Mode frame
-- (Forever), see the header.
local function GetCapTexture(cap)
	if not cap then return nil end
	if cap.GetObjectType and cap:GetObjectType() == "Texture" then
		return cap, true
	end
	if cap.Texture then
		return cap.Texture, false
	end
	return nil
end

-- Records the retail look of a cap once, so it can be restored on disable.
local function RememberRetail(texture)
	if retail[texture] then return end
	local state = {
		atlas = texture:GetAtlas(),
		width = texture:GetWidth(),
		height = texture:GetHeight(),
		points = {},
	}
	for i = 1, texture:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = texture:GetPoint(i)
		state.points[i] = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
	end
	retail[texture] = state
end

local function ApplyClassic(cap, side)
	local texture, anchored = GetCapTexture(cap)
	if not texture then return end
	RememberRetail(texture)

	texture:SetTexture(T.ENDCAP_GRYPHON)
	if side == "left" then
		texture:SetTexCoord(0, 1, ART_TOP, 1)
	else
		texture:SetTexCoord(1, 0, ART_TOP, 1)
	end
	texture:SetSize(CAP_WIDTH, CAP_HEIGHT)
	texture:ClearAllPoints()
	if anchored then
		local parent = texture:GetParent()
		if side == "left" then
			texture:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", CAP_INSET_X, CAP_OFFSET_Y)
		else
			texture:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", -CAP_INSET_X, CAP_OFFSET_Y)
		end
	else
		-- Forever: the art is 6px wider than the 154x95 Edit Mode frame;
		-- centre it on the frame's bottom edge rather than stretch it.
		texture:SetPoint("BOTTOM", cap, "BOTTOM", 0, 0)
	end
end

local function RestoreRetail(cap)
	local texture = GetCapTexture(cap)
	local state = texture and retail[texture]
	if not state then return end

	texture:SetTexCoord(0, 1, 0, 1)
	if state.atlas then
		texture:SetAtlas(state.atlas)
	end
	texture:SetSize(state.width, state.height)
	texture:ClearAllPoints()
	if #state.points == 0 then
		texture:SetAllPoints(cap) -- a texture without anchors fills its frame
	else
		for _, p in ipairs(state.points) do
			texture:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
		end
	end
end

local function ApplyAll()
	local _, left, right = GetCaps()
	ApplyClassic(left, "left")
	ApplyClassic(right, "right")
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

function module:Enable()
	if not GetCaps() then return end
	if not ns.HasTexture(T.ENDCAP_GRYPHON) then
		ns.Print("This client does not ship the classic action bar gryphon texture; the retail end caps are kept.")
		return
	end
	enabled = true
	if not hooked then
		hooked = true
		-- Runs after Blizzard re-applied its atlas (bar shown, Edit Mode bar
		-- art refresh, faction chosen).
		ns.Hook(MainActionBar, "UpdateEndCaps", function()
			if enabled then ApplyAll() end
		end)
	end
	ApplyAll()
end

function module:Disable()
	enabled = false
	local _, left, right = GetCaps()
	RestoreRetail(left)
	RestoreRetail(right)
end
