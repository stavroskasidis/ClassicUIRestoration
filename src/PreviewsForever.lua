--[[
	Forevermore Classic UI - Previews (WoW Forever only)

	Forever's modern look is the mainline UI with the camelot overlay, which
	redraws some of the frames the previews picture. Its "modern" pictures
	replace the retail ones here, drawn from the forever branch of Blizzard's
	source (the Camelot\ folders):
	  * nameplates: the name inside the health bar, the level in its box
	    (ui-hud-nameplates-levelindicator) to the right of the bar
	    (Blizzard_NamePlateLevelFrame.xml, Blizzard_NamePlateConstants.lua);
	  * gryphons: always gryphons, 154x95 (MainMenuBarEndCaps.xml);
	  * bags: square 45px slots in the action button frame
	    (ui-hud-actionbar-iconframe-bags) on the action bar plate, the
	    ui-hud-actionbar-bag backpack and the narrow key ring
	    (MainMenuBarBagButtons.xml / .lua);
	  * micro menu: the retail buttons on the action bar plate
	    (MainMenuBarMicroMenu.xml), with Forever's spellbook button;
	  * minimap: the UI-HUD-Minimap-Frame art around the map cut by its
	    generic mask (Skin.lua).
	The windows (character, spellbook, talents, trainer, auction house,
	professions, loot) are in-game screenshots of both looks instead, in
	Textures\Previews.
]]

local _, ns = ...
if not ns.IS_FOREVER then return end

local K = ns.PreviewKit
local Previews = ns.Previews

-- Forever's windows are shown as screenshots (see ns.PreviewImages in
-- Previews.lua); tools/make_previews.py makes the files and these entries.
local function Image(file, width, height, fileWidth, fileHeight)
	return { file = file, width = width, height = height, fileWidth = fileWidth, fileHeight = fileHeight }
end

ns.PreviewImages = {
	characterframe = {
		modern = Image("forever-characterframe-modern", 224, 256, 256, 256),
		classic = Image("forever-characterframe-classic", 188, 256, 256, 256),
	},
	spellbook = {
		modern = Image("forever-spellbook-modern", 285, 256, 512, 256),
		classic = Image("forever-spellbook-classic", 262, 256, 512, 256),
	},
	talents = {
		modern = Image("forever-talents-modern", 429, 256, 512, 256),
		classic = Image("forever-talents-classic", 228, 256, 256, 256),
	},
	trainer = {
		modern = Image("forever-trainer-modern", 208, 256, 256, 256),
		classic = Image("forever-trainer-classic", 202, 256, 256, 256),
	},
	auctionhouse = {
		modern = Image("forever-auctionhouse-modern", 381, 256, 512, 256),
		classic = Image("forever-auctionhouse-classic", 489, 256, 512, 256),
	},
	professions = {
		modern = Image("forever-professions-modern", 289, 256, 512, 256),
		classic = Image("forever-professions-classic", 207, 256, 256, 256),
	},
	lootframe = {
		modern = Image("forever-lootframe-modern", 220, 145, 256, 256),
		classic = Image("forever-lootframe-classic", 190, 245, 256, 256),
	},
}
local Atlas, At, Color, File, Fill, Layer, Mask = K.Atlas, K.At, K.Color, K.File, K.Fill, K.Layer, K.Mask

---------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------

-- Constants: 190 wide less 12 each side, the large bar 20 tall, the level
-- box 28 wide and 5px right of the bar.
local PLATE_WIDTH, PLATE_HEIGHT = 166, 20
local LEVEL_WIDTH, LEVEL_HEIGHT = 28, 23

Previews.nameplates.width = PLATE_WIDTH + 5 + LEVEL_WIDTH + 16
Previews.nameplates.modern = function(c)
	local barX, barY = 8, -14
	Color(c, 0, 0, 0, 1, PLATE_WIDTH + 2, PLATE_HEIGHT + 2, barX - 1, barY + 1, "BACKGROUND", -2)
	Color(c, 0.08, 0.08, 0.08, 1, PLATE_WIDTH, PLATE_HEIGHT, barX, barY, "BACKGROUND", -1)
	At(Fill(c, "UI-HUD-CoolDownManager-Bar", PLATE_WIDTH, PLATE_HEIGHT, 0.8, { 0.9, 0.1, 0.1 }, "ARTWORK"), "TOPLEFT", barX, barY)
	local name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetText(K.NAMEPLATE_NAME)
	name:SetShadowOffset(1, -1)
	name:SetPoint("LEFT", c, "TOPLEFT", barX + 6, barY - PLATE_HEIGHT / 2)
	local levelX = barX + PLATE_WIDTH + 5
	local box = Atlas(c, "ui-hud-nameplates-levelindicator", "ARTWORK", 0, LEVEL_WIDTH, LEVEL_HEIGHT)
	box:SetPoint("LEFT", c, "TOPLEFT", levelX, barY - PLATE_HEIGHT / 2)
	local level = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	level:SetText("11")
	level:SetTextColor(1, 0.82, 0)
	level:SetPoint("CENTER", box, "CENTER", 0, 0)
end

---------------------------------------------------------------------------
-- Action bar gryphons
---------------------------------------------------------------------------

Previews.endcaps.modern = function(c)
	local barX, barBottom = K.EndCapBar(c)
	local left = Atlas(c, "ui-hud-actionbar-gryphon-left", "OVERLAY", 1, 154, 95)
	left:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", barX + 9, barBottom - 5)
	local right = Atlas(c, "ui-hud-actionbar-gryphon-right", "OVERLAY", 1, 154, 95)
	right:SetPoint("BOTTOMLEFT", c, "TOPLEFT", barX + K.ENDCAP_BAR_WIDTH - 9, barBottom - 5)
end

---------------------------------------------------------------------------
-- Bags
---------------------------------------------------------------------------

local SLOT, PADDING, KEYRING_WIDTH = 45, 2, 33
local BAR_WIDTH = KEYRING_WIDTH + PADDING + 5 * SLOT + 4 * PADDING

local function BagSlot(c, x, y, width, icon, frameAtlas)
	local slot = CreateFrame("Frame", nil, c)
	slot:SetSize(width, SLOT)
	slot:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
	local texture = slot:CreateTexture(nil, "ARTWORK")
	texture:SetPoint("CENTER", slot, "CENTER", 0, 0)
	texture:SetSize(width, SLOT)
	if icon then
		texture:SetTexture(icon)
		local mask = slot:CreateMaskTexture()
		if ns.SetAtlas(mask, "UI-HUD-ActionBar-IconFrame-Mask") then
			mask:SetAllPoints(texture)
			texture:AddMaskTexture(mask)
		end
	else
		ns.SetAtlas(texture, "ui-hud-actionbar-iconframe-slot")
	end
	At(Atlas(slot, frameAtlas, "OVERLAY", 0, width + 1, SLOT + 1), "TOPLEFT")
	return slot
end

Previews.bags.width = BAR_WIDTH + 24
Previews.bags.height = 70
Previews.bags.modern = function(c)
	local x, y = 12, -12
	local plate = Atlas(c, "UI-HUD-ActionBar-Frame", "BACKGROUND", -3)
	plate:SetPoint("TOPLEFT", c, "TOPLEFT", x - 6, y + 6)
	plate:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", x + BAR_WIDTH + 5, y - SLOT - 5)
	-- The key ring, then bags 4..1, then the backpack at the right end.
	local keyring = BagSlot(c, x, y, KEYRING_WIDTH, nil, "UI-HUD-ActionBar-IconFrame-Small")
	local ring = Atlas(keyring, "UI-HUD-ActionBar-Keyring-Small", "OVERLAY", 1)
	ring:SetPoint("CENTER", keyring, "CENTER", 0, 0)
	x = x + KEYRING_WIDTH + PADDING
	for bag = 4, 1, -1 do
		BagSlot(c, x, y, SLOT, K.BagIcon(bag), "ui-hud-actionbar-iconframe-bags")
		x = x + SLOT + PADDING
	end
	BagSlot(c, x, y, SLOT, "Interface\\Icons\\ui-hud-actionbar-bag", "ui-hud-actionbar-iconframe-bags")
end

---------------------------------------------------------------------------
-- Micro menu
---------------------------------------------------------------------------

local MICRO = { "SpellbookAbilities", "SpecTalents", "Achievements", "Questlog", "GuildCommunities", "Groupfinder", "Collections", "GameMenu" }
local MICRO_STRIDE = 27 -- 32px buttons, 5px into each other
local MICRO_WIDTH = #MICRO * MICRO_STRIDE + 5

Previews.micromenu.width = MICRO_WIDTH + 60
Previews.micromenu.height = 70
Previews.micromenu.modern = function(c)
	local x, y = 30, -15
	local plate = Atlas(c, "UI-HUD-ActionBar-Frame", "BACKGROUND", -3)
	plate:SetPoint("TOPLEFT", c, "TOPLEFT", x - 8, y + 8)
	plate:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", x + MICRO_WIDTH + 8, y - 40 - 8)
	local background = Atlas(c, "UI-HUD-ActionBar-IconFrame-Background", "BACKGROUND", -4)
	background:SetPoint("TOPLEFT", plate, "TOPLEFT", -13, 0)
	background:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 14, 4)
	for i, name in ipairs(MICRO) do
		local centerX = x + 16 + (i - 1) * MICRO_STRIDE
		At(Atlas(c, "UI-HUD-MicroMenu-ButtonBG-Up", "BACKGROUND"), "CENTER", centerX, y - 20, c, "TOPLEFT")
		At(Atlas(c, "UI-HUD-MicroMenu-" .. name .. "-Up", "ARTWORK", 0, 32, 40), "CENTER", centerX, y - 20, c, "TOPLEFT")
	end
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------

Previews.minimap.modern = function(c)
	-- Skin.lua: the frame art at its own size centred on the 198px map,
	-- which its generic mask cuts to the frame's opening.
	local mapX, mapY = 105, -120
	K.MapDisc(c, 170, mapX, mapY, "ui-hud-minimap-frame-generic-mask")
	local art = Layer(c, 5)
	local frame = Atlas(art, "UI-HUD-Minimap-Frame", "ARTWORK")
	local width, height = frame:GetSize()
	if width and width > 0 then
		frame:SetSize(width * 170 / 198, height * 170 / 198)
	end
	frame:SetPoint("CENTER", art, "TOPLEFT", mapX, mapY)
	local header = Color(art, 0, 0, 0, 0.55, 160, 16, 25, -4, "ARTWORK", 1)
	local zone = art:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	zone:SetText(K.ZoneText())
	zone:SetPoint("LEFT", header, "LEFT", 6, 0)
	local tracking = Atlas(art, "ui-hud-minimap-tracking-up", "OVERLAY")
	tracking:SetPoint("RIGHT", header, "LEFT", -1, 0)
	local zoomIn = Atlas(art, "ui-hud-minimap-zoom-in", "OVERLAY")
	zoomIn:SetPoint("CENTER", art, "TOPLEFT", mapX + 72, mapY - 62)
	local zoomOut = Atlas(art, "ui-hud-minimap-zoom-out", "OVERLAY")
	zoomOut:SetPoint("CENTER", art, "TOPLEFT", mapX + 56, mapY - 76)
end
