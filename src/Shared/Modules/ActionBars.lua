--[[
	Classic UI Restoration - Action Bar Art

	Puts the vanilla art back on the action bars (the main bar, the extra
	MultiBars and the pet / stance / possess bars); the legacy files still
	ship with the client:

	  * Buttons: the square UI-Quickslot2 border (the dark UI-Quickslot
	    square on an empty slot of an art-less bar while the grid is shown),
	    the UI-Quickslot-Depress pushed art,
	    the square highlight / checked glows, the red UI-QuickslotRed attack
	    flash and the green UI-ActionButton-Border equipped border, all at the
	    vanilla proportions (66x66 frame on a 36px button, 54x54 on a 30px pet
	    button). The retail rounded icon mask is removed, so the icons are
	    square like they were, and the icon is inset in its button to
	    vanilla's icon-to-slot proportion (36 in 42) so the border fits
	    between neighbouring buttons instead of overlapping them.
	  * Bar art: the retail UI-HUD-ActionBar-Frame plate behind the main bar
	    and the dividers between its buttons are replaced with the embossed
	    gryphon slots of the vanilla UI-MainMenuBar-Dwarf strip. The strip is
	    drawn as one cell per button, like retail's own per-button SlotArt, so
	    Edit Mode's rows / padding / orientation / icon size settings keep
	    working and "hide bar art" hides it exactly as it hides retail's.
	  * The main bar's page arrows get the vanilla
	    UI-MainMenu-Scroll*Button art.

	Blizzard puts its atlases back from UpdateButtonArt (on load and on Edit
	Mode's "hide bar art") and from the button's Update (on every action
	change, which is also where an empty slot is told apart from a filled
	one), and re-creates the dividers in UpdateDividers; those are hooked so
	the vanilla art is re-applied afterwards. The action buttons are
	protected frames, but only their textures are touched: nothing here
	moves or resizes a frame, and no Lua field is written on Blizzard's
	frames. Blizzard's own art cannot be restored from every one of those
	paths at runtime, so the module needs a reload to switch off.
]]

local _, ns = ...
local T = ns.T
local SetTexture = ns.SetTexture

T.MAINMENUBAR_STRIP = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
T.QUICKSLOT         = "Interface\\Buttons\\UI-Quickslot"
T.QUICKSLOT2        = "Interface\\Buttons\\UI-Quickslot2"
T.QUICKSLOT_PUSHED  = "Interface\\Buttons\\UI-Quickslot-Depress"
T.QUICKSLOT_FLASH   = "Interface\\Buttons\\UI-QuickslotRed"
T.BUTTON_HIGHLIGHT  = "Interface\\Buttons\\ButtonHilight-Square"
T.BUTTON_CHECKED    = "Interface\\Buttons\\CheckButtonHilight"
T.ACTION_BORDER     = "Interface\\Buttons\\UI-ActionButton-Border"
T.PAGE_UP           = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-"   -- + Up / Down / Disabled / Highlight
T.PAGE_DOWN         = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-" -- + Up / Down / Disabled / Highlight

local module = ns:RegisterModule({
	key = "actionbars",
	name = "Action Bar Art",
	tooltip = "Restores the vanilla action bar art: the square classic button borders (with square icons) on every action bar, the embossed vanilla slot art behind the main bar's buttons instead of the modern plate and dividers, and the classic page arrows.",
	live = false,
})

---------------------------------------------------------------------------
-- The vanilla bar strip
--
-- UI-MainMenuBar-Dwarf (256x256) holds the 1024x43 vanilla bar as four
-- 256px pieces, read left to right from the file's rows 213-256, 149-192,
-- 85-128 and 21-64 (the rows in between are the XP bar's frame). The
-- action slots are 42px cells separated by 3px metal columns; piece 2
-- holds six whole cells, their columns centred 2px in.
---------------------------------------------------------------------------

local PIECE_TOP = { 213, 149, 85, 21 }
local PIECE_HEIGHT = 43

local function PieceCoords(piece, x1, x2)
	local top = PIECE_TOP[piece]
	return x1 / 256, x2 / 256, top / 256, (top + PIECE_HEIGHT) / 256
end

local CELL_WIDTH, CELLS = 42, {}
for k = 0, 5 do
	CELLS[k + 1] = { PieceCoords(2, 2 + 42 * k, 44 + 42 * k) }
end

-- One strip cell behind a button, scaled to the button's width and keeping
-- the strip's 42:43 proportion; adjacent buttons' cells meet on their
-- shared metal column.
local function CreateCell(button, index)
	local width = button:GetWidth()
	local cell = button:CreateTexture(nil, "BACKGROUND", nil, -3)
	SetTexture(cell, T.MAINMENUBAR_STRIP, unpack(CELLS[(index - 1) % #CELLS + 1]))
	cell:SetSize(width, width * PIECE_HEIGHT / CELL_WIDTH)
	cell:SetPoint("CENTER", button, "CENTER", 0, 0)
	return cell
end

-- Fades every divider frame Blizzard acquired between the buttons (the
-- pools are re-filled on each layout; alpha sticks to the pooled frames).
local function HideDividers(bar)
	for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
		local pool = bar[key]
		if pool then
			for divider in pool:EnumerateActive() do
				divider:SetAlpha(0)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- Vanilla's 36px icons sat in the strip's 42px cells with the 66x66
-- UI-Quickslot2 frame (54x54 on the 30px pet/stance buttons) and the 62x62
-- equipped border drawn around them. Retail's
-- icon fills its whole 45px button (its rounded mask and frame hid the
-- edges) and the buttons touch, so the icon is inset to the vanilla
-- icon:cell proportion and the vanilla frames are sized from the icon;
-- otherwise every border would overlap the neighbouring icon.
local ICON_RATIO = 36 / 42
local NORMAL_RATIO, NORMAL_RATIO_SMALL = 66 / 36, 54 / 30
local BORDER_RATIO = 62 / 36
-- The UI-Quickslot frames' 39px ring sits at file pixels 12-50 of 64, half a
-- file pixel up and left of centre; the frame is shifted that half pixel (at
-- its drawn scale) the other way so it is centred on the icon. Sizes are
-- rounded to whole pixels so the inset stays the same on every side.
local FRAME_ART_BIAS = 0.5 / 64
-- UI-Quickslot (an empty slot with the grid shown) fills its square with
-- 60% black, which reads nearly opaque over a dark scene on the modern 45px
-- buttons; it is faded to keep the square readable but light.
local EMPTY_SLOT_ALPHA = 0.6

local cells = setmetatable({}, { __mode = "k" })        -- button -> strip cell texture
local smallButtons = setmetatable({}, { __mode = "k" }) -- pet/stance/possess buttons

-- Fills a texture over the (inset) icon.
local function FillIcon(texture, button)
	if not texture then return end
	texture:SetTexCoord(0, 1, 0, 1)
	texture:ClearAllPoints()
	texture:SetAllPoints(button.icon or button)
end

local function Round(x)
	return math.floor(x + 0.5)
end

local function IconSize(button)
	return Round(button:GetWidth() * ICON_RATIO)
end

-- Border art; runs after Blizzard's UpdateButtonArt / Update, which put the
-- retail atlases (and their 46x45 sizes) back. The slot cell follows
-- Blizzard's own SlotArt, which Edit Mode's "hide bar art" hides. An empty
-- slot over the bar art keeps only the transparent border, so the embossed
-- cell shows through like vanilla's main bar; without bar art it gets the
-- vanilla dark UI-Quickslot square.
local function ApplyButtonArt(button)
	local cell = cells[button]
	local hasBarArt = button.SlotArt ~= nil and button.SlotArt:IsShown()
	if cell then
		cell:SetShown(hasBarArt)
	end

	local size = Round(IconSize(button) * (smallButtons[button] and NORMAL_RATIO_SMALL or NORMAL_RATIO))
	local normal = button:GetNormalTexture()
	if normal then
		local empty = not (button.icon and button.icon:IsShown())
		if empty and not hasBarArt then
			SetTexture(normal, T.QUICKSLOT)
			normal:SetAlpha(EMPTY_SLOT_ALPHA)
		else
			SetTexture(normal, T.QUICKSLOT2)
			normal:SetAlpha(1)
		end
		local shift = size * FRAME_ART_BIAS
		normal:ClearAllPoints()
		normal:SetSize(size, size)
		normal:SetPoint("CENTER", button.icon or button, "CENTER", shift, -shift)
	end
	local pushed = button:GetPushedTexture()
	if pushed then
		SetTexture(pushed, T.QUICKSLOT_PUSHED)
		FillIcon(pushed, button)
	end
end

local function SkinButton(button, index, small)
	if not button or cells[button] then return end
	smallButtons[button] = small or nil

	-- Retail's slot art / plain background: replaced by the strip cell.
	if button.SlotArt then button.SlotArt:SetAlpha(0) end
	if button.SlotBackground then button.SlotBackground:SetAlpha(0) end
	cells[button] = CreateCell(button, index)
	ns.StripMask(button.IconMask, button.icon)
	-- The cooldowns and overlays are anchored to the icon and follow it.
	if button.icon then
		local size = IconSize(button)
		button.icon:ClearAllPoints()
		button.icon:SetSize(size, size)
		button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	end

	local highlight = button:GetHighlightTexture()
	if highlight then
		SetTexture(highlight, T.BUTTON_HIGHLIGHT)
		highlight:SetBlendMode("ADD")
		FillIcon(highlight, button)
	end
	local checked = button:GetCheckedTexture()
	if checked then
		SetTexture(checked, T.BUTTON_CHECKED)
		checked:SetBlendMode("ADD")
		FillIcon(checked, button)
	end
	if button.Flash then
		SetTexture(button.Flash, T.QUICKSLOT_FLASH)
		FillIcon(button.Flash, button)
	end
	if button.Border then
		local size = Round(IconSize(button) * BORDER_RATIO)
		SetTexture(button.Border, T.ACTION_BORDER)
		button.Border:SetBlendMode("ADD")
		button.Border:ClearAllPoints()
		button.Border:SetSize(size, size)
		button.Border:SetPoint("CENTER", button.icon or button, "CENTER", 0, 0)
	end
	-- The proc / new-spell pulse keeps its retail rounded shape otherwise.
	if button.SpellHighlightTexture then
		SetTexture(button.SpellHighlightTexture, T.BUTTON_HIGHLIGHT)
		FillIcon(button.SpellHighlightTexture, button)
	end

	ns.Hook(button, "UpdateButtonArt", ApplyButtonArt)
	ns.Hook(button, "Update", ApplyButtonArt) -- empty slot <-> filled slot border
	ApplyButtonArt(button)
end

-- Bar global name, and whether its buttons are the 30px SmallActionButtons.
local BARS = {
	{ "MainActionBar" }, { "MultiBarBottomLeft" }, { "MultiBarBottomRight" },
	{ "MultiBarRight" }, { "MultiBarLeft" }, { "MultiBar5" }, { "MultiBar6" }, { "MultiBar7" },
	{ "PetActionBar", true }, { "StanceBar", true }, { "PossessActionBar", true },
}

local function SkinBars()
	for _, entry in ipairs(BARS) do
		local bar = _G[entry[1]]
		if bar and type(bar.actionButtons) == "table" then
			for index, button in ipairs(bar.actionButtons) do
				SkinButton(button, index, entry[2])
			end
		end
	end
end

---------------------------------------------------------------------------
-- Main bar plate and page arrows
---------------------------------------------------------------------------

local function SkinPageButton(button, prefix)
	if not button then return end
	button:SetNormalTexture(prefix .. "Up")
	button:SetPushedTexture(prefix .. "Down")
	button:SetDisabledTexture(prefix .. "Disabled")
	button:SetHighlightTexture(prefix .. "Highlight", "ADD")
	-- The 32x32 files carry a 19x17 arrow; the retail buttons are 17x14.
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
		texture:ClearAllPoints()
		texture:SetSize(26, 26)
		texture:SetPoint("CENTER", button, "CENTER", 0, 0)
	end
end

local function SkinMainBar()
	local bar = MainActionBar
	if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
	if bar.UpdateDividers then
		ns.Hook(bar, "UpdateDividers", HideDividers)
		HideDividers(bar)
	end
	local page = bar.ActionBarPageNumber
	if page then
		if page.Text then page.Text:SetFontObject(GameFontNormalSmall) end
		SkinPageButton(page.UpButton, T.PAGE_UP)
		SkinPageButton(page.DownButton, T.PAGE_DOWN)
	end
end

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

function module:Apply()
	if not MainActionBar then return end
	if not ns.HasTexture(T.MAINMENUBAR_STRIP) or not ns.HasTexture(T.QUICKSLOT2) then
		ns.Print("This client does not ship the vanilla action bar art; the modern action bars are kept.")
		return
	end
	SkinBars()
	SkinMainBar()
end
