--[[
	Forevermore Classic UI - Micro Menu

	Puts the classic micro button art back on the micro menu in place of the
	retail UI-HUD-MicroMenu-* atlases; the legacy files still ship with the
	client:

	  * Each button gets its classic Interface\Buttons\UI-MicroButton-<name>
	    Up / Down / Disabled files with the UI-MicroButton-Hilight glow
	    (added over the button like classic's, where retail swaps in a
	    whole mouseover picture), and the character button the empty
	    UI-MicroButtonCharacter frame with the player's portrait in it.
	  * Buttons are mapped to the classic button of the same window: the
	    spellbook and talents (retail's combined button gets the talents
	    art, it opens on the talents), achievements (also Forever's legacy
	    button, whose modern art is an achievement shield too), quest log,
	    socials for the guild button, the Wrath group finder eye, the MoP
	    mounts for collections, the dungeon journal, the shop, help and the
	    main menu. The client only ships the Cataclysm redraws of the main
	    menu, quest log and socials files (a question mark, an exclamation
	    mark and a banner, where vanilla had a computer, a goblet and a
	    speech bubble), so the vanilla ones are bundled in Textures\ (from
	    the Classic Era client); the client's files are the fallback.
	  * Professions and housing never had a micro button; they get the empty
	    portrait frame with an icon in it, like the classic character and
	    PvP buttons.
	  * The alert pulse flashes the classic Micro-Highlight glow; retail's
	    flashing mouseover picture and the guild tabard emblem are hidden.
	  * The buttons sit on the flat stone panel of the vanilla bar strip
	    (UI-MainMenuBar-Dwarf), where vanilla's micro buttons were, closed
	    at both ends by the strip's plain metal column. It follows Edit
	    Mode's orientation (turned a quarter for a vertical menu) and size,
	    and is hidden while a vehicle or pet battle bar borrows the menu
	    (OverrideMicroMenuPosition), since those bars have their own art.
	    On WoW Forever it replaces the modern action bar plate.

	The buttons keep Blizzard's size and Edit Mode layout (32x40, 5px
	overlap); the art is scaled so neighbouring frames overlap by vanilla's
	proportion (3px on its 29px buttons).

	Blizzard sets the button art from LoadMicroButtonTextures, SetPushed /
	SetNormal and, every second, the main menu button's OnUpdate (streaming
	status); all of them go through the buttons' Set*Atlas methods, which are
	hooked so the classic file is put back each time. Retail's hover hides
	the normal texture (its mouseover picture carries the shadow); the
	classic glow is drawn over it, so it is shown again. The micro buttons
	are not protected frames and nothing here writes a Lua field on them.
	Blizzard's atlases cannot be restored from every one of those paths at
	runtime, so the module needs a reload to switch off.
]]

local _, ns = ...
local T = ns.T
local SetTexture = ns.SetTexture

T.MICRO_BUTTON     = "Interface\\Buttons\\UI-MicroButton-"          -- + <name>-Up / -Down / -Disabled
T.MICRO_BUTTON_VANILLA = "Interface\\AddOns\\" .. ns.ADDON_NAME .. "\\Textures\\UI-MicroButton-" -- bundled, same names
T.MICRO_FRAME      = "Interface\\Buttons\\UI-MicroButtonCharacter-" -- + Up / Down (the empty portrait frame)
T.MICRO_HIGHLIGHT  = "Interface\\Buttons\\UI-MicroButton-Hilight"
T.MICRO_FLASH      = "Interface\\Buttons\\Micro-Highlight"
T.ICON_PROFESSIONS = "Interface\\Icons\\Trade_BlackSmithing"
T.ICON_HOUSING     = "Interface\\Icons\\INV_Misc_Rune_01"            -- the hearthstone

local module = ns:RegisterModule({
	key = "micromenu",
	name = "Micro Menu",
	tooltip = "Restores the classic micro menu buttons (character portrait, spellbook, talents, quest log, main menu, ...) with the classic highlight and alert glow instead of the modern buttons.",
	live = false,
})

-- Blizzard button -> classic art: a UI-MicroButton-<file> set, the portrait
-- (character) or an icon in the empty portrait frame.
local BUTTONS = {
	CharacterMicroButton    = { portrait = true },
	ProfessionMicroButton   = { icon = T.ICON_PROFESSIONS },
	PlayerSpellsMicroButton = { file = "Talents" },
	SpellbookMicroButton    = { file = "Spellbook" },   -- Forever
	TalentMicroButton       = { file = "Talents" },     -- Forever
	AchievementMicroButton  = { file = "Achievement" },
	LegacyMicroButton       = { file = "Achievement" }, -- Forever
	QuestLogMicroButton     = { file = "Quest", bundled = true },
	HousingMicroButton      = { icon = T.ICON_HOUSING },
	GuildMicroButton        = { file = "Socials", bundled = true },
	LFDMicroButton          = { file = "LFG" },
	CollectionsMicroButton  = { file = "Mounts" },
	EJMicroButton           = { file = "EJ" },
	HelpMicroButton         = { file = "Help" },
	StoreMicroButton        = { file = "BStore" },
	MainMenuMicroButton     = { file = "MainMenu", bundled = true },
}

-- The 32x64 files hold a 32x41 button in their bottom rows. Vanilla drew
-- them at 29px, 26px apart; the retail buttons are 27px apart, so the art is
-- drawn at 30px to keep vanilla's overlap between neighbours.
local ART_TOP = 23 / 64
local ART_SCALE = 30 / 32
local ART_WIDTH, ART_HEIGHT = 32 * ART_SCALE, 41 * ART_SCALE
-- Vanilla's portrait: 18x25, 28px below the top of its 29x58 button, i.e.
-- in file pixels (x32/29) 19.9x27.6 at row 30.9, 7.9 rows into the art.
local FILE_SCALE = 32 / 29
local INSET_WIDTH = 18 * FILE_SCALE * ART_SCALE
local INSET_HEIGHT = 25 * FILE_SCALE * ART_SCALE
local INSET_Y = ART_HEIGHT / 2 - (28 * FILE_SCALE - 23) * ART_SCALE
-- Vanilla's portrait crop, and the shift it got while the button was down
-- (with half alpha). Icons are cropped to the same tall window, inside
-- their border.
local PORTRAIT_COORDS = { 0.2, 0.8, 0.0666, 0.9 }
local ICON_COORDS = { 0.2, 0.8, 0.1, 0.92 }
local PUSHED_SHIFT = 0.0666
-- Micro-Highlight: a 34x42 glow in a 64x64 file, drawn 2px up and left of
-- the 29x37 classic button.
local FLASH_SCALE = ART_WIDTH / 29

local specs = setmetatable({}, { __mode = "k" })  -- button -> { up, down, disabled, coords, desaturate }
local insets = setmetatable({}, { __mode = "k" }) -- button -> portrait / icon texture

---------------------------------------------------------------------------
-- Button art
---------------------------------------------------------------------------

local function PlaceArt(texture, button)
	texture:SetTexCoord(0, 1, ART_TOP, 1)
	texture:SetVertexColor(1, 1, 1) -- the guild button is tinted with the tabard colour
	texture:ClearAllPoints()
	texture:SetSize(ART_WIDTH, ART_HEIGHT)
	texture:SetPoint("CENTER", button, "CENTER", 0, 0)
end

local function ApplyNormal(button)
	button:SetNormalTexture(specs[button].up)
	local texture = button:GetNormalTexture()
	if texture then PlaceArt(texture, button) end
end

local function ApplyPushed(button)
	button:SetPushedTexture(specs[button].down)
	local texture = button:GetPushedTexture()
	if texture then PlaceArt(texture, button) end
end

local function ApplyDisabled(button)
	local spec = specs[button]
	button:SetDisabledTexture(spec.disabled)
	local texture = button:GetDisabledTexture()
	if texture then
		PlaceArt(texture, button)
		texture:SetDesaturated(spec.desaturate)
	end
end

local function ApplyHighlight(button)
	button:SetHighlightTexture(T.MICRO_HIGHLIGHT, "ADD")
	local texture = button:GetHighlightTexture()
	if texture then PlaceArt(texture, button) end
end

-- The portrait / icon in the frame's window; pushed, it shifts and dims
-- like vanilla's portrait. Runs after Blizzard's SetPushed / SetNormal,
-- which re-anchor the character button's portrait.
local function UpdateInset(button)
	local inset = insets[button]
	if not inset then return end
	local l, r, t, b = unpack(specs[button].coords)
	if button:GetButtonState() == "PUSHED" then
		inset:SetTexCoord(l + PUSHED_SHIFT, r + PUSHED_SHIFT, t - PUSHED_SHIFT, b - PUSHED_SHIFT)
		inset:SetAlpha(0.5)
	else
		inset:SetTexCoord(l, r, t, b)
		inset:SetAlpha(1)
	end
	inset:ClearAllPoints()
	inset:SetSize(INSET_WIDTH, INSET_HEIGHT)
	inset:SetPoint("TOP", button, "CENTER", 0, INSET_Y)
end

-- Blizzard dims the highlight while the button is down (its pushed
-- picture is doubled as the highlight); the classic glow stays full.
local function OnButtonState(button)
	local highlight = button:GetHighlightTexture()
	if highlight then highlight:SetAlpha(1) end
	UpdateInset(button)
end

local function ApplyAll(button)
	ApplyNormal(button)
	ApplyPushed(button)
	ApplyDisabled(button)
	ApplyHighlight(button)
	OnButtonState(button)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

local function HideRegion(region)
	if region then region:SetAlpha(0) end
end

-- The alert pulse: Blizzard flashes FlashBorder (and FlashContent, a copy
-- of the mouseover picture) with UIFrameFlash, which drives their alpha.
local function SkinFlash(button)
	local flash = button.FlashBorder
	if flash then
		SetTexture(flash, T.MICRO_FLASH)
		flash:SetBlendMode("ADD")
		flash:ClearAllPoints()
		flash:SetSize(64 * FLASH_SCALE, 64 * FLASH_SCALE)
		flash:SetPoint("TOPLEFT", button, "CENTER", -ART_WIDTH / 2 - 2 * FLASH_SCALE, ART_HEIGHT / 2 + 2 * FLASH_SCALE)
	end
	if button.FlashContent then
		button.FlashContent:SetTexture(nil)
	end
end

local function CreateIcon(button, file)
	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture(file)
	-- Classic greyed out a disabled button's picture.
	button:HookScript("OnEnable", function() icon:SetDesaturated(false) end)
	button:HookScript("OnDisable", function() icon:SetDesaturated(true) end)
	icon:SetDesaturated(not button:IsEnabled())
	return icon
end

local function SkinButton(button, entry)
	local spec = {}
	if entry.file then
		local prefix = T.MICRO_BUTTON .. entry.file
		if entry.bundled and ns.HasTexture(T.MICRO_BUTTON_VANILLA .. entry.file .. "-Up") then
			prefix = T.MICRO_BUTTON_VANILLA .. entry.file
		elseif not ns.HasTexture(prefix .. "-Up") then
			return
		end
		spec.up, spec.down, spec.disabled = prefix .. "-Up", prefix .. "-Down", prefix .. "-Disabled"
		spec.desaturate = false
	else
		spec.up, spec.down, spec.disabled = T.MICRO_FRAME .. "Up", T.MICRO_FRAME .. "Down", T.MICRO_FRAME .. "Up"
		spec.desaturate = true
	end
	specs[button] = spec

	-- Retail's button background and portrait shadows.
	HideRegion(button.Background)
	HideRegion(button.PushedBackground)
	HideRegion(button.Shadow)
	HideRegion(button.PushedShadow)
	-- The guild tabard emblem sits on retail's banner art.
	HideRegion(button.Emblem)
	HideRegion(button.HighlightEmblem)
	SkinFlash(button)

	if entry.portrait and button.Portrait then
		ns.StripMask(button.PortraitMask, button.Portrait)
		button.Portrait:SetDrawLayer("OVERLAY")
		insets[button] = button.Portrait
		spec.coords = PORTRAIT_COORDS
	elseif entry.icon then
		insets[button] = CreateIcon(button, entry.icon)
		spec.coords = ICON_COORDS
	end

	ns.Hook(button, "SetNormalAtlas", ApplyNormal)
	ns.Hook(button, "SetPushedAtlas", ApplyPushed)
	ns.Hook(button, "SetDisabledAtlas", ApplyDisabled)
	ns.Hook(button, "SetHighlightAtlas", ApplyHighlight)
	ns.Hook(button, "SetPushed", OnButtonState)
	ns.Hook(button, "SetNormal", OnButtonState)
	-- The tabard colour is applied after the atlases.
	ns.Hook(button, "UpdateTabard", ApplyAll)
	button:HookScript("OnEnter", function(self)
		local normal = self:GetNormalTexture()
		if normal then normal:SetAlpha(1) end
	end)
	ApplyAll(button)
end

---------------------------------------------------------------------------
-- Bar strip panel
---------------------------------------------------------------------------

-- UI-MainMenuBar-Dwarf pieces (see Core.lua): the flat panel vanilla's
-- micro buttons sat on (piece 3, after the page number's column) and the
-- plain column where that panel ends (piece 4), mirrored for the other end.
local PANEL_FLAT = { 40 / 256, 256 / 256, 85 / 256, 128 / 256 }
local PANEL_END = { 82 / 256, 93 / 256, 21 / 256, 64 / 256 }
-- Scaled with the art (vanilla: 29px buttons on the 43px strip). Vanilla's
-- buttons sat 2px above the strip's bottom and 4px below its top, and 3px
-- from the column.
local STRIP_SCALE = ART_WIDTH / 29
local PANEL_DEPTH = 43 * STRIP_SCALE
local PANEL_END_LENGTH = 11 * STRIP_SCALE
local PANEL_SHIFT = 1 * STRIP_SCALE
local PANEL_MARGIN = 3 * STRIP_SCALE - (32 - ART_WIDTH) / 2

local panel -- { flat, first, last } textures on MicroMenu

-- File region l..r / t..b (l > r mirrors it), turned a quarter clockwise
-- for a vertical menu: the strip's left end at the top, its top edge right.
local function SetStripCoords(texture, coords, mirrored, vertical)
	local l, r, t, b = unpack(coords)
	if mirrored then l, r = r, l end
	if vertical then
		texture:SetTexCoord(l, b, r, b, l, t, r, t)
	else
		texture:SetTexCoord(l, t, l, b, r, t, r, b)
	end
end

-- Runs after every layout of the menu (Edit Mode orientation / order,
-- buttons shown or hidden) and when a vehicle or pet battle bar takes the
-- menu or gives it back.
local function LayoutPanel()
	local shown = MicroMenu:GetParent() == MicroMenuContainer
	local flat, first, last = unpack(panel)
	for _, texture in ipairs(panel) do
		texture:SetShown(shown)
		texture:ClearAllPoints()
	end
	if not shown then return end

	local vertical = MicroMenu.isHorizontal == false
	SetStripCoords(flat, PANEL_FLAT, false, vertical)
	SetStripCoords(first, PANEL_END, true, vertical)
	SetStripCoords(last, PANEL_END, false, vertical)
	if vertical then
		flat:SetPoint("TOPLEFT", MicroMenu, "TOP", PANEL_SHIFT - PANEL_DEPTH / 2, PANEL_MARGIN)
		flat:SetPoint("BOTTOMRIGHT", MicroMenu, "BOTTOM", PANEL_SHIFT + PANEL_DEPTH / 2, -PANEL_MARGIN)
		first:SetSize(PANEL_DEPTH, PANEL_END_LENGTH)
		first:SetPoint("BOTTOMLEFT", flat, "TOPLEFT")
		last:SetSize(PANEL_DEPTH, PANEL_END_LENGTH)
		last:SetPoint("TOPLEFT", flat, "BOTTOMLEFT")
	else
		flat:SetPoint("TOPLEFT", MicroMenu, "LEFT", -PANEL_MARGIN, PANEL_SHIFT + PANEL_DEPTH / 2)
		flat:SetPoint("BOTTOMRIGHT", MicroMenu, "RIGHT", PANEL_MARGIN, PANEL_SHIFT - PANEL_DEPTH / 2)
		first:SetSize(PANEL_END_LENGTH, PANEL_DEPTH)
		first:SetPoint("TOPRIGHT", flat, "TOPLEFT")
		last:SetSize(PANEL_END_LENGTH, PANEL_DEPTH)
		last:SetPoint("TOPLEFT", flat, "TOPRIGHT")
	end
end

local function CreatePanel()
	if not ns.HasTexture(T.MAINMENUBAR_STRIP) then return end
	panel = {}
	for i = 1, 3 do
		local texture = MicroMenu:CreateTexture(nil, "BACKGROUND", nil, -8)
		texture:SetTexture(T.MAINMENUBAR_STRIP)
		panel[i] = texture
	end
	ns.Hook(MicroMenu, "Layout", LayoutPanel)
	ns.Hook(MicroMenu, "OverrideMicroMenuPosition", LayoutPanel)
	ns.Hook(MicroMenu, "ResetMicroMenuPosition", LayoutPanel)
	LayoutPanel()
end

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

function module:Apply()
	if not MicroMenu then return end
	if not ns.HasTexture(T.MICRO_HIGHLIGHT) or not ns.HasTexture(T.MICRO_FRAME .. "Up") then
		ns.Print("This client does not ship the classic micro button art; the modern micro menu is kept.")
		return
	end
	for name, entry in pairs(BUTTONS) do
		local button = _G[name]
		if type(button) == "table" and button.GetNormalTexture then
			SkinButton(button, entry)
		end
	end
	-- Forever draws the modern action bar plate behind the menu.
	HideRegion(MicroMenu.BorderArt)
	HideRegion(MicroMenu.BackgroundArt)
	CreatePanel()
end
