--[[
	Forevermore Classic UI - Bags (bags bar; the windows are in BagFrames.lua)

	Puts the vanilla bag slots back on the bags bar (the backpack, the four
	bag slots, the reagent bag slot and, on WoW Forever, the key ring); the
	legacy files still ship with the client:

	  * Vanilla's backpack and bag slots were equal square item buttons as
	    large as its action slots (37px icons, 5px apart, on the bar strip's
	    42px cells). Retail draws a 48px round backpack and 30px round bag
	    slots, so every slot is resized to the 45px of a retail action button
	    and gets a square icon (the round mask is removed) inset to vanilla's
	    37-in-42 proportion, inside ItemButtonTemplate's UI-Quickslot2 frame,
	    with the UI-Quickslot-Depress pushed art, the square highlight and
	    the CheckButtonHilight glow of an open bag.
	  * The backpack shows the vanilla Button-Backpack-Up icon and an empty
	    bag slot the paper doll's empty bag icon.
	  * Each slot sits on an embossed gryphon cell of the vanilla bar strip,
	    like the right end of vanilla's main bar. The client's copy of the
	    strip was redrawn in Cataclysm with small bag-shaped cells there (for
	    that expansion's 30px bag slots); the vanilla file had the same
	    gryphon cells as under the action slots, which are used here. On WoW
	    Forever the modern action bar plate and dividers behind the bags are
	    hidden.
	  * Forever's key ring gets the vanilla UI-Button-KeyRing art, spaced
	    from the bags like the bags from each other, on a narrow strip
	    cell: vanilla's bar had a narrow slot for it (UI-MainMenuBar-KeyRing),
	    but the client only ships the Cataclysm redraw of that file.

	Retail's expand arrow between the backpack and the bags has no vanilla
	counterpart; it is kept, since hiding it would leave collapsed bags with
	no way back.

	Blizzard puts its atlases back from each button's UpdateTextures (on
	every icon or bag change) and re-lays the bar out from BagsBar:Layout
	(Edit Mode orientation / padding); both are hooked. The bag buttons are
	not protected frames, but they are still only resized out of combat,
	and no Lua field is written on Blizzard's frames. The round retail art
	cannot be put back from every one of those paths at runtime, so the
	module needs a reload to switch off.
]]

local _, ns = ...
local T = ns.T
local SetTexture = ns.SetTexture

T.BACKPACK          = "Interface\\Buttons\\Button-Backpack-Up"
T.BAG_SLOT_EMPTY    = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
T.KEYRING           = "Interface\\Buttons\\UI-Button-KeyRing"
T.KEYRING_PUSHED    = "Interface\\Buttons\\UI-Button-KeyRing-Down"
T.KEYRING_HIGHLIGHT = "Interface\\Buttons\\UI-Button-KeyRing-Highlight"

-- The bag windows are a part of this option (BagFrames.lua).
local module = ns:RegisterModule({
	key = "bags",
	name = "Bags",
	tooltip = "Restores the vanilla bags: the bag slots on the bags bar as equal square buttons with the classic item frame, the vanilla backpack icon and the embossed bar slots behind them, and the vanilla bag and backpack windows (also for the combined backpack) instead of the modern frames.",
	live = false,
})

-- Vanilla's bag slots were as large as its action slots, so every slot
-- gets a retail action button's size; the icon keeps vanilla's 37px icon
-- to 42px cell proportion and the 64x64 UI-Quickslot2 frame
-- ItemButtonTemplate's 64:37 frame-to-icon proportion.
local SLOT_SIZE = 45
local ICON_RATIO = 37 / 42
local NORMAL_RATIO = 64 / 37
-- The frame's 39px ring sits half a file pixel up and left of centre (see
-- ActionBars.lua); it is shifted that half pixel the other way.
local FRAME_ART_BIAS = 0.5 / 64
-- Classic drew the backpack's free slot count 7px below the icon's centre.
local COUNT_X, COUNT_Y = 1, -7
-- UI-Button-KeyRing: an 18x39 key ring in the top left of a 32x64 file.
local KEYRING_WIDTH, KEYRING_HEIGHT = 18, 39
local KEYRING_COORDS = { 0, 18 / 32, 0, 39 / 64 }

local cells = setmetatable({}, { __mode = "k" }) -- slot button -> strip cell texture
local keyRingCell -- the key ring's narrow strip cell (Forever)

local function Round(x)
	return math.floor(x + 0.5)
end

local function IconSize()
	return Round(SLOT_SIZE * ICON_RATIO)
end

-- Fills a texture over the (inset) icon.
local function FillIcon(texture, button)
	if not texture then return end
	texture:ClearAllPoints()
	texture:SetAllPoints(button.icon)
end

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

-- Runs after Blizzard's UpdateTextures, which puts the round atlases back
-- (stretched over the whole button) on every icon or bag change.
local function ApplySlotArt(button)
	local icon = button.icon
	if button == MainMenuBarBackpackButton then
		icon:SetTexture(T.BACKPACK)
		icon:Show()
	elseif not GetInventoryItemTexture("player", button:GetID()) then
		icon:SetTexture(T.BAG_SLOT_EMPTY)
		icon:Show()
	end

	local normal = button:GetNormalTexture()
	if normal then
		local size = Round(IconSize() * NORMAL_RATIO)
		local shift = size * FRAME_ART_BIAS
		SetTexture(normal, T.QUICKSLOT2)
		normal:ClearAllPoints()
		normal:SetSize(size, size)
		normal:SetPoint("CENTER", icon, "CENTER", shift, -shift)
	end
	local pushed = button:GetPushedTexture()
	if pushed then
		SetTexture(pushed, T.QUICKSLOT_PUSHED)
		FillIcon(pushed, button)
	end
	local highlight = button:GetHighlightTexture()
	if highlight then
		SetTexture(highlight, T.BUTTON_HIGHLIGHT)
		highlight:SetBlendMode("ADD")
		highlight:SetAlpha(1)
		FillIcon(highlight, button)
	end
	-- Shown while the bag is open, where vanilla checked its button.
	local open = button.SlotHighlightTexture
	if open then
		SetTexture(open, T.BUTTON_CHECKED)
		open:SetBlendMode("ADD")
		FillIcon(open, button)
	end
end

-- Blizzard stretches the "not usable here" shade over the whole button.
local function FitContextOverlay(button)
	FillIcon(button.ItemContextOverlay, button)
end

local function SkinSlot(button, index)
	local icon = button.icon
	if not icon then return end

	button:SetSize(SLOT_SIZE, SLOT_SIZE)
	-- Retail's round mask, Forever's rounded-square one.
	ns.StripMask(button.CircleMask, icon, button.searchOverlay, button.ItemContextOverlay)
	ns.StripMask(button.SquareMask, icon)
	local size = IconSize()
	icon:ClearAllPoints()
	icon:SetSize(size, size)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	FillIcon(button.searchOverlay, button)
	FillIcon(button.ItemContextOverlay, button)
	FillIcon(button.AnimIcon, button)
	if button == MainMenuBarBackpackButton and button.Count then
		button.Count:ClearAllPoints()
		button.Count:SetPoint("CENTER", icon, "CENTER", COUNT_X, COUNT_Y)
	end

	cells[button] = ns.CreateStripCell(button, index)

	ns.Hook(button, "UpdateTextures", ApplySlotArt)
	ns.Hook(button, "UpdateItemContextOverlayTextures", FitContextOverlay)
	ApplySlotArt(button)
end

-- Vanilla's 18x39 key ring sat beside 37px bag icons; it is scaled with
-- the icons.
local function KeyRingSize()
	local scale = IconSize() / 37
	return KEYRING_WIDTH * scale, KEYRING_HEIGHT * scale
end

-- Forever's key ring slot is 33px along the bar, so the narrow ring stood
-- apart from the bags. Vanilla put it the same 5px from the last bag as
-- the bags from each other; the slot is narrowed to the ring plus the
-- bag slots' own margin around their icons, which gives the same spacing.
-- Runs after Blizzard's UpdateOrientation, which re-sizes the slot on
-- every bar layout before the bar measures its length.
local function SizeKeyRing(button, isHorizontal)
	local width, height = KeyRingSize()
	local margin = SLOT_SIZE - IconSize()
	if isHorizontal then
		button:SetSize(width + margin, SLOT_SIZE)
	else
		button:SetSize(SLOT_SIZE, height + margin)
	end
end

-- Forever's key ring: the vanilla key ring button art, centred on the slot,
-- in place of its small slot frame and key icon. Blizzard turns its art
-- sideways in a vertical bar; the vanilla ring stays upright.
local function ApplyKeyRingArt(button)
	if button.icon then button.icon:SetAlpha(0) end
	local width, height = KeyRingSize()
	local art = {
		{ button:GetNormalTexture(), T.KEYRING },
		{ button:GetPushedTexture(), T.KEYRING_PUSHED },
		{ button:GetHighlightTexture(), T.KEYRING_HIGHLIGHT, true },
		{ button.SlotHighlightTexture, T.KEYRING_HIGHLIGHT, true },
	}
	for _, entry in ipairs(art) do
		local texture = entry[1]
		if texture then
			SetTexture(texture, entry[2], unpack(KEYRING_COORDS))
			texture:SetRotation(0)
			if entry[3] then
				texture:SetBlendMode("ADD")
				texture:SetAlpha(1)
			end
			texture:ClearAllPoints()
			texture:SetSize(width, height)
			texture:SetPoint("CENTER", button, "CENTER", 0, 0)
		end
	end
end

---------------------------------------------------------------------------
-- Bar
---------------------------------------------------------------------------

-- The cells follow the bar's bag padding along the bar (see
-- ns.SizeStripCell); padding and orientation are Edit Mode settings.
local function LayoutCells()
	local padding = tonumber(BagsBar.bagPadding) or 0
	local vertical = BagsBar.isHorizontal == false
	for button, cell in pairs(cells) do
		ns.SizeStripCell(cell, button:GetWidth(), padding, vertical)
	end
	if keyRingCell then
		ns.SizeNarrowStripCell(keyRingCell, _G.KeyRingButton, padding, vertical)
	end
end

-- Blizzard measured the bar from the retail slot sizes when it first laid
-- it out; its later layouts (Edit Mode, expand arrow) measure the new ones.
local function FitBar()
	if not (BagsBar.GetBagBarLength and BagsBar.initialHeight) then return end
	local length = BagsBar:GetBagBarLength()
	if BagsBar.isHorizontal == false then
		BagsBar:SetSize(BagsBar.initialHeight, length)
	else
		BagsBar:SetSize(length, BagsBar.initialHeight)
	end
end

local function Skin()
	-- Forever lays the bags out like an action bar, on the modern plate.
	if BagsBar.BorderArt then BagsBar.BorderArt:SetAlpha(0) end
	if BagsBar.UpdateDividers then
		ns.Hook(BagsBar, "UpdateDividers", ns.HideBarDividers)
		ns.HideBarDividers(BagsBar)
	end

	for index, button in MainMenuBarBagManager:EnumerateBagButtons() do
		if button == _G.KeyRingButton then
			ns.Hook(button, "UpdateTextures", ApplyKeyRingArt)
			ns.Hook(button, "UpdateOrientation", function(self, isHorizontal)
				SizeKeyRing(self, isHorizontal)
				ApplyKeyRingArt(self)
			end)
			-- Blizzard's slot is taller than wide in a horizontal bar.
			SizeKeyRing(button, button:GetWidth() < button:GetHeight())
			ApplyKeyRingArt(button)
			keyRingCell = ns.CreateNarrowStripCell(button)
		else
			SkinSlot(button, index)
		end
	end
	LayoutCells()
	FitBar()
	ns.Hook(BagsBar, "Layout", LayoutCells)
end

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

function module:Apply()
	if not (BagsBar and MainMenuBarBagManager and MainMenuBarBackpackButton) then return end
	if not ns.HasTexture(T.QUICKSLOT2) or not ns.HasTexture(T.MAINMENUBAR_STRIP) then
		ns.Print("This client does not ship the vanilla bag slot art; the modern bags bar is kept.")
		return
	end
	ns:RunOutOfCombat(Skin)
end
