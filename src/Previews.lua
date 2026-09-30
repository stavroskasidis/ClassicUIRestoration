--[[
	Forevermore Classic UI - Previews

	Small before / after pictures of every option, shown by the setup wizard
	(side by side, to pick from) and by the options page. They are drawn from
	the client's own art: the "Classic" side from the legacy files the
	modules put on Blizzard's frames (same files, coordinates and colours),
	the "Modern" side from the atlases and templates the retail frames use
	(taken from Blizzard's source), laid out at the frames' real sizes and
	scaled down to fit. The player's own portrait, name, level, action bar
	icons, bags and gear are used where the frame shows them.

	A preview never touches a Blizzard frame, so both looks can be shown
	whatever the option is currently set to (a reload-type module cannot be
	switched back and forth on the real frames). The only Blizzard templates
	instantiated (NineSlicePanelTemplate, InsetFrameTemplate,
	DialogBorderTemplate, DialogHeaderTemplate, BigRedThreeSliceButtonTemplate)
	have no $parent-named children, so they create no globals. Mouse input is
	turned off on every frame of a preview; the card around it takes clicks.

	The modern pictures show the retail (mainline) art; WoW Forever's camelot
	overlay changes a few of those frames slightly.
]]

local _, ns = ...
local T = ns.T

-- key -> { width, height, classic = function(canvas), modern = function(canvas) }
local Previews = {}
ns.Previews = Previews

local MAX_SCALE = 2

-- Classic difficulty / quality colours used in the list mock-ups.
local ORANGE = { 1, 0.5, 0.25 }
local YELLOW = { 1, 1, 0 }
local GREEN = { 0.25, 0.75, 0.25 }
local GREY = { 0.5, 0.5, 0.5 }
local WHITE = { 1, 1, 1 }
local HOTKEY = { 0.6, 0.6, 0.6 }

local FALLBACK_SPELLS = {
	{ "Interface\\Icons\\Spell_Fire_FlameBolt", "Fireball" },
	{ "Interface\\Icons\\Spell_Frost_FrostBolt02", "Frostbolt" },
	{ "Interface\\Icons\\Spell_Holy_HolyBolt", "Holy Light" },
	{ "Interface\\Icons\\Ability_Warrior_Charge", "Charge" },
	{ "Interface\\Icons\\Spell_Nature_HealingTouch", "Healing Touch" },
	{ "Interface\\Icons\\Spell_Shadow_ShadowBolt", "Shadow Bolt" },
	{ "Interface\\Icons\\Spell_Nature_Lightning", "Lightning Bolt" },
	{ "Interface\\Icons\\Spell_Holy_PowerWordShield", "Power Word: Shield" },
	{ "Interface\\Icons\\Spell_Nature_Starfall", "Starfire" },
	{ "Interface\\Icons\\Ability_Rogue_Eviscerate", "Eviscerate" },
	{ "Interface\\Icons\\Spell_Holy_Renew", "Renew" },
	{ "Interface\\Icons\\INV_Sword_04", "Attack" },
}

---------------------------------------------------------------------------
-- Drawing helpers (all positions are TOPLEFT offsets unless anchored)
---------------------------------------------------------------------------

local function Tex(parent, layer, sublevel)
	return parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
end

local function At(region, point, x, y, relativeTo, relativePoint)
	region:SetPoint(point, relativeTo or region:GetParent(), relativePoint or point, x or 0, y or 0)
	return region
end

local function File(parent, path, width, height, x, y, layer, sublevel, coords)
	local texture = Tex(parent, layer, sublevel)
	texture:SetTexture(path)
	if coords then texture:SetTexCoord(unpack(coords)) end
	texture:SetSize(width, height)
	texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	return texture
end

-- An atlas at its own size, or at the given one; hidden if the client lacks it.
local function Atlas(parent, name, layer, sublevel, width, height)
	local texture = Tex(parent, layer, sublevel)
	if ns.SetAtlas(texture, name, width == nil) then
		if width then texture:SetSize(width, height) end
	else
		texture:Hide()
	end
	return texture
end

local function Color(parent, r, g, b, a, width, height, x, y, layer, sublevel)
	local texture = Tex(parent, layer or "BACKGROUND", sublevel)
	texture:SetColorTexture(r, g, b, a or 1)
	texture:SetSize(width, height)
	texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	return texture
end

-- A bar's fill as one texture cropped to `value` of its width (a picture
-- never changes, so it needs no StatusBar). `source` is an atlas or a file.
local function Fill(parent, source, width, height, value, color, layer, sublevel)
	local texture = Tex(parent, layer or "BACKGROUND", sublevel)
	local left, right, top, bottom = 0, 1, 0, 1
	local info = C_Texture.GetAtlasInfo(source)
	if info then
		texture:SetTexture(info.file or info.filename)
		left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	elseif source:find("\\", 1, true) then
		texture:SetTexture(source)
	else
		texture:SetColorTexture(1, 1, 1)
	end
	texture:SetTexCoord(left, left + (right - left) * value, top, bottom)
	texture:SetSize(width * value, height)
	if color then texture:SetVertexColor(color[1], color[2], color[3]) end
	return texture
end

local function Text(parent, font, text, point, x, y, relativePoint, color)
	local fontString = parent:CreateFontString(nil, "OVERLAY", font)
	fontString:SetText(text or "")
	fontString:SetPoint(point, parent, relativePoint or point, x or 0, y or 0)
	if color then fontString:SetTextColor(color[1], color[2], color[3]) end
	return fontString
end

-- The player's portrait is rendered a moment after the loading screen goes
-- away; a texture set before that stays blank. Like Blizzard's unit frames,
-- the pictures' portraits are set again when the client reports portraits
-- ready, and once more a second after being drawn in case no event follows.
local portraits = setmetatable({}, { __mode = "k" })
local retryPending = false

local function RefreshPortraits()
	retryPending = false
	for texture, unit in pairs(portraits) do
		SetPortraitTexture(texture, unit)
	end
end

local portraitEvents = CreateFrame("Frame")
portraitEvents:RegisterEvent("PORTRAITS_UPDATED")
portraitEvents:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
portraitEvents:SetScript("OnEvent", RefreshPortraits)

local function Portrait(parent, size, x, y, layer, sublevel, unit)
	unit = unit or "player"
	local texture = Tex(parent, layer or "BACKGROUND", sublevel)
	texture:SetSize(size, size)
	texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	SetPortraitTexture(texture, unit)
	portraits[texture] = unit
	if not retryPending then
		retryPending = true
		C_Timer.After(1, RefreshPortraits)
	end
	return texture
end

local function Mask(parent, texture, file)
	local mask = parent:CreateMaskTexture()
	mask:SetTexture(file or T.PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
	return mask
end

local function RoundIcon(parent, path, size, x, y, layer, sublevel)
	local texture = File(parent, path, size, size, x, y, layer or "BACKGROUND", sublevel)
	Mask(parent, texture)
	return texture
end

-- An enemy's portrait: the player's target while it is hostile, else a
-- stock creature (named as in the nameplate pictures).
local ENEMY_NAME = "Murloc Forager"
local ENEMY_ICONS = { "Interface\\Icons\\INV_Misc_Head_Murloc_01", "Interface\\Icons\\Ability_Hunter_Pet_Wolf" }

local function HostileTarget()
	return UnitExists("target") and UnitCanAttack("player", "target")
end

local function EnemyPortrait(parent, size, x, y, layer, sublevel)
	if HostileTarget() then
		return Portrait(parent, size, x, y, layer, sublevel, "target")
	end
	for _, icon in ipairs(ENEMY_ICONS) do
		if ns.HasTexture(icon) then
			-- Cropped inside the icon's own bevelled border, which would
			-- otherwise show as a square edge inside the round mask.
			local texture = RoundIcon(parent, icon, size, x, y, layer, sublevel)
			texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			return texture
		end
	end
	return Portrait(parent, size, x, y, layer, sublevel)
end

-- A child frame covering its parent, drawn above the frames created before it.
local function Layer(parent, levels)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame:SetFrameLevel(parent:GetFrameLevel() + (levels or 10))
	return frame
end

---------------------------------------------------------------------------
-- The player's own things
---------------------------------------------------------------------------

local function PlayerName()
	return UnitName("player") or UNKNOWN or "Player"
end

local function PlayerLevel()
	local level = UnitLevel("player")
	return level and level > 0 and tostring(level) or "60"
end

-- The spells on the player's action bars ({ icon, name }), topped up with
-- stock spells.
local function PlayerSpells(count)
	local list, seen = {}, {}
	for slot = 1, 120 do
		if #list >= count then break end
		local actionType, id = GetActionInfo(slot)
		if actionType == "spell" and id and not seen[id] and C_Spell and C_Spell.GetSpellName then
			local name = C_Spell.GetSpellName(id)
			local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
			if name and icon then
				seen[id] = true
				list[#list + 1] = { icon, name }
			end
		end
	end
	for i = #list + 1, count do
		list[i] = FALLBACK_SPELLS[(i - 1) % #FALLBACK_SPELLS + 1]
	end
	return list
end

-- The icons of the main action bar's first buttons.
local function ActionIcons(count)
	local icons = {}
	for slot = 1, count do
		icons[slot] = GetActionTexture(slot) or FALLBACK_SPELLS[slot][1]
	end
	return icons
end

local function BagIcon(bag)
	local slot = C_Container and C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bag)
	return slot and GetInventoryItemTexture("player", slot)
end

local function CastName()
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(8690) -- Hearthstone
	return name or "Hearthstone"
end

---------------------------------------------------------------------------
-- Shared pieces
---------------------------------------------------------------------------

-- A classic item slot: the icon under UI-Quickslot2 (64:37, like
-- ItemButtonTemplate).
local function ClassicSlot(parent, icon, size, x, y)
	File(parent, icon, size, size, x, y, "ARTWORK")
	local frame = Tex(parent, "OVERLAY", -1)
	frame:SetTexture(T.QUICKSLOT2)
	local frameSize = size * 64 / 37
	frame:SetSize(frameSize, frameSize)
	frame:SetPoint("CENTER", parent, "TOPLEFT", x + size / 2, y - size / 2)
end

-- A retail action button: masked icon under the IconFrame border.
local function ModernActionButton(parent, icon, x, y, slotArt)
	if slotArt then
		At(Atlas(parent, "ui-hud-actionbar-iconframe-slot", "BACKGROUND", 0, 45, 45), "TOPLEFT", x, y)
	end
	local texture = File(parent, icon, 45, 45, x, y, "ARTWORK")
	local mask = parent:CreateMaskTexture()
	if ns.SetAtlas(mask, "UI-HUD-ActionBar-IconFrame-Mask") then
		mask:SetAllPoints(texture)
		texture:AddMaskTexture(mask)
	end
	At(Atlas(parent, "UI-HUD-ActionBar-IconFrame", "OVERLAY", 0, 46, 45), "TOPLEFT", x, y)
end

local STANDARD_PIECES = {
	{ "TopLeft", 256, 256, 0, 0 }, { "TopRight", 128, 256, 256, 0 },
	{ "BotLeft", 256, 256, 0, -256 }, { "BotRight", 128, 256, 256, -256 },
}

-- A vanilla 384x512 panel: its art pieces over a portrait.
local function ClassicWindow(c, prefix, pieces)
	for _, piece in ipairs(pieces or STANDARD_PIECES) do
		local path = piece.path or (prefix .. piece[1])
		File(c, path, piece[2], piece[3], piece[4], piece[5], "BORDER")
	end
end

-- The title of a vanilla panel, centred on its title bar.
local function ClassicTitle(c, title, centerX, y)
	local text = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetText(title)
	text:SetPoint("CENTER", c, "TOPLEFT", centerX, y)
	return text
end

-- A retail portrait panel (PortraitFrameTexturedBaseTemplate's art: the
-- rock background and the PortraitFrameTemplate nine-slice) with its
-- portrait and title. `portrait` draws into a 62px square at (-5, 7).
local function RockBackground(frame)
	local bg = Tex(frame, "BACKGROUND", -6)
	bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
	bg:SetHorizTile(true)
	bg:SetVertTile(true)
	bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
	bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
end

-- Also returns the nine-slice border, for pieces drawn over it.
local function ModernWindow(c, width, height, title, portrait)
	local frame = CreateFrame("Frame", nil, c)
	frame:SetSize(width, height)
	frame:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -8)
	RockBackground(frame)

	local border = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
	border:SetAllPoints(frame)
	NineSliceUtil.ApplyLayoutByName(border, "PortraitFrameTemplate")

	local top = Layer(frame, 20)
	if portrait then
		local texture = portrait(top)
		texture:SetSize(62, 62)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", top, "TOPLEFT", -5, 7)
	end
	Text(top, "GameFontNormal", title, "TOP", 17, -5)
	return frame, top, border
end

local function ModernInset(frame, left, top, right, bottom)
	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
	inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
	return inset
end

-- Rows of `icon name` in a list, `rows` of { icon, name, color }.
local function ListRows(parent, rows, x, y, stride, iconSize, font)
	for i, row in ipairs(rows) do
		local rowY = y - (i - 1) * stride
		if row[1] then
			File(parent, row[1], iconSize, iconSize, x, rowY, "ARTWORK")
		end
		local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
		text:SetText(row[2])
		text:SetPoint("LEFT", parent, "TOPLEFT", x + (row[1] and iconSize + 6 or 0), rowY - iconSize / 2)
		if row[3] then text:SetTextColor(row[3][1], row[3][2], row[3][3]) end
	end
end

local function PlayerPortrait(parent)
	return Portrait(parent, 62, 0, 0, "OVERLAY")
end

local function IconPortrait(path)
	return function(parent)
		local texture = File(parent, path, 62, 62, 0, 0, "OVERLAY")
		Mask(parent, texture)
		return texture
	end
end

---------------------------------------------------------------------------
-- Unit frames (the player frame)
---------------------------------------------------------------------------

Previews.unitframes = {
	width = 232, height = 100,
	classic = function(c)
		Color(c, 0, 0, 0, 0.5, 119, 41, 106, -22, "BACKGROUND", -8)
		Portrait(c, 64, 42, -12)
		Fill(c, T.STATUS_BAR, 119, 12, 1, { 0, 1, 0 }, "BACKGROUND", 2):SetPoint("TOPLEFT", c, "TOPLEFT", 106, -41)
		Fill(c, T.STATUS_BAR, 119, 12, 1, { 0, 0, 1 }, "BACKGROUND", 2):SetPoint("TOPLEFT", c, "TOPLEFT", 106, -52)
		File(c, T.TARGET_FRAME, 232, 100, 0, 0, "BORDER", 0, { 1, 0.09375, 0, 0.78125 })
		Text(c, "GameFontNormalSmall", PlayerName(), "CENTER", 50, 19)
		Text(c, "GameFontNormalSmall", PlayerLevel(), "CENTER", -63, -16)
	end,
	modern = function(c)
		Portrait(c, 60, 24, -19)
		At(Atlas(c, "UI-HUD-UnitFrame-Player-PortraitOn", "BORDER"), "CENTER")
		Fill(c, "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health", 124, 20, 1, nil, "ARTWORK"):SetPoint("TOPLEFT", c, "TOPLEFT", 85, -40)
		Fill(c, "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana", 124, 10, 1, nil, "ARTWORK"):SetPoint("TOPLEFT", c, "TOPLEFT", 85, -61)
		Text(c, "GameFontNormalSmall", PlayerName(), "TOPLEFT", 88, -27)
		Text(c, "GameFontNormalSmall", PlayerLevel(), "TOPRIGHT", -24.5, -28)
	end,
}

---------------------------------------------------------------------------
-- Combo points (Forever): around the target's portrait
---------------------------------------------------------------------------

local COMBO_POINT = "Interface\\ComboFrame\\ComboPoint"

local function ComboPoint(c, x, y, lit)
	-- Vanilla's ComboPoint: a 12x16 socket, the 8x16 gem 2px in.
	File(c, COMBO_POINT, 12, 16, x, y, "ARTWORK", 0, { 0, 0.375, 0, 1 })
	if lit then
		File(c, COMBO_POINT, 8, 16, x + 2, y, "ARTWORK", 1, { 0.375, 0.5625, 0, 1 })
	end
end

-- The classic target frame (UnitFrames.lua's layout: the 232x100 art, the
-- bars from 7px in, the 64px portrait at 126,-12) with a hostile unit, drawn
-- COMBO_MARGIN below the top to leave room for the modern arc. Returns a layer
-- above the frame for the points and the portrait's centre.
local COMBO_MARGIN = 12

local function ComboTargetFrame(c)
	local y = -COMBO_MARGIN
	local name, level = ENEMY_NAME, "11"
	if HostileTarget() then
		name = UnitName("target") or name
		local unitLevel = UnitLevel("target")
		level = unitLevel and unitLevel > 0 and tostring(unitLevel) or "??"
	end
	Color(c, 0, 0, 0, 0.5, 119, 41, 7, y - 22, "BACKGROUND", -8)
	-- The name background: Blizzard colours it with the unit's selection colour.
	File(c, T.LEVEL_BG, 119, 19, 7, y - 22, "BACKGROUND", -6):SetVertexColor(1, 0, 0)
	EnemyPortrait(c, 64, 126, y - 12)
	Fill(c, T.STATUS_BAR, 119, 12, 1, { 0, 1, 0 }, "BACKGROUND", 2):SetPoint("TOPLEFT", c, "TOPLEFT", 7, y - 41)
	Fill(c, T.STATUS_BAR, 119, 12, 1, { 0, 0, 1 }, "BACKGROUND", 2):SetPoint("TOPLEFT", c, "TOPLEFT", 7, y - 52)
	File(c, T.TARGET_FRAME, 232, 100, 0, y, "BORDER", 0, { 0.09375, 1, 0, 0.78125 })
	local top = Layer(c)
	Text(top, "GameFontNormalSmall", name, "CENTER", 66, y - 31, "TOPLEFT")
	Text(top, "GameFontNormalSmall", level, "CENTER", 177, y - 67, "TOPLEFT")
	return top, 126 + 32, y - 12 - 32
end

Previews.combopoints = {
	width = 232, height = 100 + COMBO_MARGIN,
	classic = function(c)
		local top, centerX, centerY = ComboTargetFrame(c)
		-- The module's anchors: the frame's top right corner at the portrait's
		-- centre + (30, 35), each point's top right corner offset from it.
		local frameX, frameY = centerX + 30, centerY + 35
		for i, offset in ipairs({ { 0, 0 }, { 7, -8 }, { 12, -19 }, { 14, -30 }, { 12, -41 } }) do
			ComboPoint(top, frameX + offset[1] - 12, frameY + offset[2], i <= 3)
		end
	end,
	modern = function(c)
		local top, centerX, centerY = ComboTargetFrame(c)
		-- An arc over the top of the portrait.
		for i = 1, 5 do
			local angle = math.rad(150 - (i - 1) * 30)
			ComboPoint(top, centerX + math.cos(angle) * 40 - 6, centerY + math.sin(angle) * 40 + 8, i <= 3)
		end
	end,
}

---------------------------------------------------------------------------
-- Cast bars (the player's)
---------------------------------------------------------------------------

Previews.castbars = {
	width = 256, height = 64,
	classic = function(c)
		local barX, barY = (256 - 195) / 2, -28
		Color(c, 0, 0, 0, 0.5, 195, 13, barX, barY, "BACKGROUND", -1)
		local fill = Fill(c, T.STATUS_BAR, 195, 13, 0.7, { 1, 0.7, 0 })
		fill:SetPoint("TOPLEFT", c, "TOPLEFT", barX, barY)
		File(c, T.CAST_BORDER, 256, 64, 0, 0, "ARTWORK")
		local spark = File(c, T.CAST_SPARK, 32, 32, 0, 0, "OVERLAY")
		spark:SetBlendMode("ADD")
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", fill, "RIGHT", 0, 0)
		local text = Text(c, "GameFontHighlight", CastName(), "CENTER", 0, 0)
		text:ClearAllPoints()
		text:SetPoint("CENTER", fill, "LEFT", 195 / 2, 0)
	end,
	modern = function(c)
		local barX, barY, width, height = (256 - 208) / 2, -18, 208, 11
		local bar = CreateFrame("Frame", nil, c)
		bar:SetSize(width, height)
		bar:SetPoint("TOPLEFT", c, "TOPLEFT", barX, barY)
		local box = Atlas(bar, "ui-castingbar-textbox", "BACKGROUND", 0)
		box:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -12)
		local background = Atlas(bar, "ui-castingbar-background", "BACKGROUND", 2)
		background:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
		background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
		At(Fill(bar, "ui-castingbar-filling-standard", width, height, 0.7, nil, "ARTWORK", 0), "TOPLEFT")
		local border = Atlas(bar, "ui-castingbar-frame", "ARTWORK", 2)
		border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
		border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
		Text(bar, "GameFontHighlightSmall", CastName(), "TOP", 0, -12)
	end,
}

---------------------------------------------------------------------------
-- Breath / fatigue timer bars
---------------------------------------------------------------------------

local BREATH = BREATH_LABEL or "Breath"

Previews.mirrortimers = {
	width = 256, height = 44,
	classic = function(c)
		local frameX, frameY = (256 - 206) / 2, -12
		local barX, barY = frameX + (206 - 195) / 2, frameY - 2
		Color(c, 0, 0, 0, 0.5, 195, 13, barX, barY, "BACKGROUND", -1)
		Fill(c, T.STATUS_BAR, 195, 13, 0.6, { 0, 0.5, 1 }):SetPoint("TOPLEFT", c, "TOPLEFT", barX, barY)
		File(c, T.CAST_BORDER, 256, 64, 0, frameY + 25, "ARTWORK")
		Text(c, "GameFontHighlight", BREATH, "TOP", 0, frameY)
	end,
	modern = function(c)
		local bar = CreateFrame("Frame", nil, c)
		bar:SetSize(195, 13)
		bar:SetPoint("TOP", c, "TOP", 0, -8)
		local box = Atlas(bar, "ui-castingbar-textbox", "BACKGROUND", 0)
		box:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -14)
		local background = Atlas(bar, "ui-castingbar-background", "BACKGROUND", 1)
		background:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
		background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
		At(Fill(bar, "ui-castingbar-filling-applyingcrafting", 195, 13, 0.6, nil, "ARTWORK", 0), "TOPLEFT")
		local border = Atlas(bar, "ui-castingbar-frame", "OVERLAY", 0)
		border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
		border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
		Text(bar, "GameFontHighlightSmall", BREATH, "TOP", 0, -1, "BOTTOM")
	end,
}

---------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------

local NAMEPLATE_NAME = ENEMY_NAME

Previews.nameplates = {
	width = 160, height = 48,
	classic = function(c)
		-- Nameplates.lua: the 136x17 border art (128 units wide), the bar from
		-- 4 units in to the level bubble, the level centred in the bubble.
		local borderX, borderY = 16, -20
		Color(c, 0, 0, 0, 0.5, 96, 8, borderX + 4, borderY - 5, "BACKGROUND")
		Fill(c, "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", 96, 8, 0.8, { 1, 0, 0 }):SetPoint("TOPLEFT", c, "TOPLEFT", borderX + 4, borderY - 5)
		File(c, "Interface\\Tooltips\\Nameplate-Border", 128, 17, borderX, borderY, "ARTWORK", 0, { 0, 136 / 256, 15 / 32, 1 })
		local level = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		level:SetText("11")
		level:SetTextColor(1, 1, 0)
		level:SetPoint("CENTER", c, "TOPLEFT", borderX + 128 * (120.5 / 136), borderY - 8.5)
		local name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		name:SetText(NAMEPLATE_NAME)
		name:SetTextColor(1, 1, 1)
		name:SetPoint("BOTTOM", c, "TOPLEFT", borderX + 64, borderY + 1)
	end,
	modern = function(c)
		local barX, barY, width, height = 20, -24, 120, 11
		local background = Atlas(c, "UI-HUD-CoolDownManager-Bar-BG", "BACKGROUND", 0, width, height)
		background:SetPoint("TOPLEFT", c, "TOPLEFT", barX, barY)
		if not background:IsShown() then
			Color(c, 0, 0, 0, 0.6, width, height, barX, barY, "BACKGROUND")
		end
		Fill(c, "UI-HUD-CoolDownManager-Bar", width, height, 0.8, { 1, 0, 0 }, "ARTWORK"):SetPoint("TOPLEFT", c, "TOPLEFT", barX, barY)
		local name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		name:SetText(NAMEPLATE_NAME)
		name:SetTextColor(1, 1, 1)
		name:SetPoint("BOTTOM", c, "TOPLEFT", barX + width / 2, barY + 2)
	end,
}

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------

local MAP_COLOR = { 0.23, 0.29, 0.17 }
local MINIMAP_ARROW = "Interface\\Minimap\\MinimapArrow"

-- The minimap's own terrain cannot be drawn a second time, so the picture's
-- map is the world map art around the player at the minimap's scale (its
-- outdoor zoom levels, in yards across), north up, with the player arrow;
-- a plain disc where there is no map position (instances).
local MINIMAP_YARDS = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }

local function DrawMapTiles(parent, mask, size)
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return end
	local position = C_Map.GetPlayerMapPosition(mapID, "player")
	local layer = (C_Map.GetMapArtLayers(mapID) or {})[1]
	local tiles = C_Map.GetMapArtLayerTextures(mapID, 1)
	if not position or not layer or not tiles then return end
	local x, y = position:GetXY()
	local worldWidth = C_Map.GetMapWorldSize and C_Map.GetMapWorldSize(mapID)
	local zoom = Minimap and Minimap:GetZoom() or 0
	local yards = MINIMAP_YARDS[zoom] or MINIMAP_YARDS[0]
	local fraction = (worldWidth and worldWidth > 0) and math.min(yards / worldWidth, 1) or 0.15
	local window = layer.layerWidth * fraction -- art pixels across the disc
	local scale = size / window
	local left, top = x * layer.layerWidth - window / 2, y * layer.layerHeight - window / 2
	local columns = math.ceil(layer.layerWidth / layer.tileWidth)
	for index, file in ipairs(tiles) do
		local tileX = ((index - 1) % columns) * layer.tileWidth - left
		local tileY = math.floor((index - 1) / columns) * layer.tileHeight - top
		if tileX < window and tileX + layer.tileWidth > 0 and tileY < window and tileY + layer.tileHeight > 0 then
			local tile = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
			tile:SetTexture(file)
			tile:SetSize(layer.tileWidth * scale, layer.tileHeight * scale)
			tile:SetPoint("TOPLEFT", parent, "TOPLEFT", tileX * scale, -tileY * scale)
			tile:AddMaskTexture(mask)
		end
	end
end

-- The map in a `size` square centred at (centerX, centerY), cut to a disc or
-- to the given mask atlas. The frame art goes on a Layer above it.
local function MapDisc(c, size, centerX, centerY, maskAtlas)
	local holder = CreateFrame("Frame", nil, c)
	holder:SetSize(size, size)
	holder:SetPoint("CENTER", c, "TOPLEFT", centerX, centerY)
	holder:SetClipsChildren(true)
	local map = CreateFrame("Frame", nil, holder)
	map:SetAllPoints(holder)
	local mask = map:CreateMaskTexture()
	mask:SetAllPoints(map)
	if not (maskAtlas and ns.SetAtlas(mask, maskAtlas)) then
		mask:SetTexture(T.PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
	local ground = map:CreateTexture(nil, "BACKGROUND")
	ground:SetAllPoints(map)
	ground:SetColorTexture(MAP_COLOR[1], MAP_COLOR[2], MAP_COLOR[3])
	ground:AddMaskTexture(mask)
	pcall(DrawMapTiles, map, mask, size)
	if ns.HasTexture(MINIMAP_ARROW) then
		local arrow = Tex(map, "ARTWORK")
		arrow:SetTexture(MINIMAP_ARROW)
		arrow:SetSize(32, 32)
		arrow:SetPoint("CENTER", map, "CENTER", 0, 0)
		local ok, facing = pcall(GetPlayerFacing)
		if ok and type(facing) == "number" then
			arrow:SetRotation(facing)
		end
	end
	return holder
end

local function ZoneText()
	local zone = GetMinimapZoneText and GetMinimapZoneText()
	return (zone and zone ~= "") and zone or "Elwynn Forest"
end

Previews.minimap = {
	width = 192, height = 212,
	classic = function(c)
		-- Minimap.lua: the header strip at the top, the map centred at
		-- (9, -92) from the top centre and the ring 20px lower.
		local mapX, mapY = 96 + 9, -92
		MapDisc(c, 140, mapX, mapY)
		local art = Layer(c, 5)
		File(art, T.MINIMAP_BORDER, 192, 32, 0, 0, "ARTWORK", 0, { 0.25, 1, 0, 0.125 })
		File(art, T.MINIMAP_BORDER, 192, 192, 0, -20, "ARTWORK", 0, { 0.25, 1, 0.125, 0.875 })
		local north = File(art, T.MINIMAP_NORTH_TAG, 16, 16, 0, 0, "OVERLAY")
		north:ClearAllPoints()
		north:SetPoint("CENTER", art, "TOPLEFT", mapX, mapY + 67)
		Text(art, "GameFontNormal", ZoneText(), "CENTER", 0, -13, "TOP")
		for _, zoom in ipairs({ { T.MINIMAP_ZOOM_IN, 72, -25 }, { T.MINIMAP_ZOOM_OUT, 50, -43 } }) do
			local button = File(art, zoom[1] .. "Up", 32, 32, 0, 0, "OVERLAY")
			button:ClearAllPoints()
			button:SetPoint("CENTER", art, "TOPLEFT", 96 + zoom[2], -116 + zoom[3])
		end
		local clock = File(art, T.CLOCK_BACKGROUND, 60, 28, 0, 0, "OVERLAY", 0, { 0.015625, 0.8125, 0.015625, 0.390625 })
		clock:ClearAllPoints()
		clock:SetPoint("CENTER", art, "TOPLEFT", mapX, mapY - 75)
		local time = art:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		time:SetText(date("%H:%M"))
		time:SetPoint("CENTER", clock, "CENTER", 0, 1)
	end,
	modern = function(c)
		-- Retail: a 198px map inside the 215x226 frame art (drawn here at
		-- 0.86), the zone name on the header bar over it.
		local mapX, mapY = 105, -120
		MapDisc(c, 170, mapX, mapY)
		local art = Layer(c, 5)
		local frame = Atlas(art, "ui-hud-minimap-frame", "ARTWORK", 0, 185, 194)
		frame:SetPoint("CENTER", art, "TOPLEFT", mapX, mapY)
		local header = Color(art, 0, 0, 0, 0.55, 160, 16, 25, -4, "ARTWORK", 1)
		local zone = art:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		zone:SetText(ZoneText())
		zone:SetPoint("LEFT", header, "LEFT", 6, 0)
		local tracking = Atlas(art, "ui-hud-minimap-tracking-up", "OVERLAY")
		tracking:SetPoint("RIGHT", header, "LEFT", -1, 0)
		local calendar = Atlas(art, "ui-hud-calendar-1-up", "OVERLAY")
		calendar:SetPoint("LEFT", header, "RIGHT", 1, 0)
		local zoomIn = Atlas(art, "ui-hud-minimap-zoom-in", "OVERLAY")
		zoomIn:SetPoint("CENTER", art, "TOPLEFT", mapX + 72, mapY - 62)
		local zoomOut = Atlas(art, "ui-hud-minimap-zoom-out", "OVERLAY")
		zoomOut:SetPoint("CENTER", art, "TOPLEFT", mapX + 56, mapY - 76)
	end,
}

---------------------------------------------------------------------------
-- Group finder eye
---------------------------------------------------------------------------

Previews.groupfindereye = {
	width = 56, height = 56,
	classic = function(c)
		-- Minimap.lua: the ring 1px into a 33px button, a 30px eye centred.
		local x, y = 11, -11
		File(c, T.MINIMAP_RING, 52, 52, x + 1, y - 1, "BORDER")
		local eye = File(c, T.LFG_EYE, 30, 30, 0, 0, "ARTWORK", 0, { 0, 64 / 512, 0, 64 / 256 })
		eye:ClearAllPoints()
		eye:SetPoint("CENTER", c, "TOPLEFT", x + 16.5, y - 16.5)
	end,
	modern = function(c)
		-- The first frame of the 11x5 "initial" flipbook.
		local eye = Tex(c, "ARTWORK")
		local info = C_Texture.GetAtlasInfo("groupfinder-eye-flipbook-initial")
		if info then
			local width = (info.rightTexCoord - info.leftTexCoord) / 11
			local height = (info.bottomTexCoord - info.topTexCoord) / 5
			eye:SetTexture(info.file or info.filename)
			eye:SetTexCoord(info.leftTexCoord, info.leftTexCoord + width, info.topTexCoord, info.topTexCoord + height)
		end
		eye:SetSize(44, 44)
		eye:SetPoint("CENTER", c, "CENTER", 0, 0)
	end,
}

---------------------------------------------------------------------------
-- Action bars: art, gryphons
---------------------------------------------------------------------------

local ACTION_COUNT = 6
local ACTION_SIZE, ACTION_PADDING = 45, 2

local function ClassicActionButton(c, icon, index, x, y)
	local button = CreateFrame("Frame", nil, c)
	button:SetSize(ACTION_SIZE, ACTION_SIZE)
	button:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
	local cell = ns.CreateStripCell(button, index)
	ns.SizeStripCell(cell, ACTION_SIZE, ACTION_PADDING)
	-- ActionBars.lua: the icon at 37/42 of the button, UI-Quickslot2 at 66/36 of the icon.
	local iconSize = math.floor(ACTION_SIZE * 37 / 42 + 0.5)
	local texture = Tex(button, "ARTWORK")
	texture:SetTexture(icon)
	texture:SetSize(iconSize, iconSize)
	texture:SetPoint("CENTER", button, "CENTER", 0, 0)
	local frame = Tex(button, "OVERLAY", -1)
	frame:SetTexture(T.QUICKSLOT2)
	local frameSize = math.floor(iconSize * 66 / 36 + 0.5)
	frame:SetSize(frameSize, frameSize)
	frame:SetPoint("CENTER", texture, "CENTER", 0, 0)
	Text(button, "GameFontHighlightSmall", tostring(index), "TOPRIGHT", -2, -3, nil, HOTKEY)
end

Previews.actionbars = {
	width = ACTION_COUNT * (ACTION_SIZE + ACTION_PADDING) + 8, height = 60,
	classic = function(c)
		for i, icon in ipairs(ActionIcons(ACTION_COUNT)) do
			ClassicActionButton(c, icon, i, 4 + (i - 1) * (ACTION_SIZE + ACTION_PADDING), -8)
		end
	end,
	modern = function(c)
		for i, icon in ipairs(ActionIcons(ACTION_COUNT)) do
			local x = 4 + (i - 1) * (ACTION_SIZE + ACTION_PADDING)
			ModernActionButton(c, icon, x, -8, true)
			Text(c, "GameFontHighlightSmall", tostring(i), "TOPRIGHT", x + ACTION_SIZE - 3, -11, "TOPLEFT", HOTKEY)
		end
	end,
}

-- The gryphons at the ends of a row of (modern) buttons; only the caps differ.
local ENDCAP_BUTTONS = 4
local ENDCAP_BAR_WIDTH = ENDCAP_BUTTONS * ACTION_SIZE + (ENDCAP_BUTTONS - 1) * ACTION_PADDING
local ENDCAP_WIDTH = ENDCAP_BAR_WIDTH + 2 * 150

-- The bar sits low enough for the classic caps (95px, their base 5px below
-- the buttons) and the retail ones (98px, 22px below) to fit whole.
local function EndCapBar(c)
	local barX, barY = (ENDCAP_WIDTH - ENDCAP_BAR_WIDTH) / 2, -60
	for i, icon in ipairs(ActionIcons(ENDCAP_BUTTONS)) do
		ModernActionButton(c, icon, barX + (i - 1) * (ACTION_SIZE + ACTION_PADDING), barY, true)
	end
	return barX, barY - ACTION_SIZE
end

Previews.endcaps = {
	width = ENDCAP_WIDTH, height = 135,
	classic = function(c)
		local barX, barBottom = EndCapBar(c)
		-- EndCaps.lua: 160x95 (rows 52..128 of the file), 9px into the bar,
		-- 5px below it; drawn over the buttons like retail's.
		local top = 52 / 128
		local left = File(c, "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf", 160, 95, 0, 0, "OVERLAY", 1, { 0, 1, top, 1 })
		left:ClearAllPoints()
		left:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", barX + 9, barBottom - 5)
		local right = File(c, "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf", 160, 95, 0, 0, "OVERLAY", 1, { 1, 0, top, 1 })
		right:ClearAllPoints()
		right:SetPoint("BOTTOMLEFT", c, "TOPLEFT", barX + ENDCAP_BAR_WIDTH - 9, barBottom - 5)
	end,
	modern = function(c)
		local barX, barBottom = EndCapBar(c)
		-- MainActionBar.xml: 104.5x98, 9px into the bar and 22px below it;
		-- wyverns for the Horde.
		local horde = UnitFactionGroup("player") == "Horde"
		local kind = horde and "wyvern" or "gryphon"
		local left = Atlas(c, "ui-hud-actionbar-" .. kind .. "-left", "OVERLAY", 1, 104.5, 98)
		if not left:IsShown() then left = Atlas(c, "ui-hud-actionbar-gryphon-left", "OVERLAY", 1, 104.5, 98) end
		left:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", barX + 9, barBottom - 22)
		local right = Atlas(c, "ui-hud-actionbar-" .. kind .. "-right", "OVERLAY", 1, 104.5, 98)
		if not right:IsShown() then right = Atlas(c, "ui-hud-actionbar-gryphon-right", "OVERLAY", 1, 104.5, 98) end
		right:SetPoint("BOTTOMLEFT", c, "TOPLEFT", barX + ENDCAP_BAR_WIDTH - 9, barBottom - 22)
	end,
}

---------------------------------------------------------------------------
-- Bags bar
---------------------------------------------------------------------------

Previews.bags = {
	width = 5 * (ACTION_SIZE + ACTION_PADDING) + 8, height = 60,
	classic = function(c)
		-- BagsBar.lua: equal 45px slots on strip cells, the backpack last.
		for i = 1, 5 do
			local bag = 5 - i -- 4..1, then the backpack (0)
			local icon = bag == 0 and "Interface\\Buttons\\Button-Backpack-Up" or BagIcon(bag) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
			local button = CreateFrame("Frame", nil, c)
			button:SetSize(ACTION_SIZE, ACTION_SIZE)
			button:SetPoint("TOPLEFT", c, "TOPLEFT", 4 + (i - 1) * (ACTION_SIZE + ACTION_PADDING), -8)
			ns.SizeStripCell(ns.CreateStripCell(button, i), ACTION_SIZE, ACTION_PADDING)
			local iconSize = math.floor(ACTION_SIZE * 37 / 42 + 0.5)
			ClassicSlot(button, icon, iconSize, (ACTION_SIZE - iconSize) / 2, -(ACTION_SIZE - iconSize) / 2)
		end
	end,
	modern = function(c)
		-- Retail: 30px round bag slots, then the 40px backpack.
		local x = 8
		for bag = 4, 1, -1 do
			local slot = CreateFrame("Frame", nil, c)
			slot:SetSize(30, 30)
			slot:SetPoint("LEFT", c, "TOPLEFT", x, -30)
			local icon = BagIcon(bag)
			if icon then
				local texture = Tex(slot, "ARTWORK")
				texture:SetTexture(icon)
				texture:SetAllPoints(slot)
				Mask(slot, texture)
			end
			Atlas(slot, icon and "bag-border" or "bag-border-empty", "OVERLAY"):SetAllPoints(slot)
			x = x + 34
		end
		local backpack = Atlas(c, "bag-main", "ARTWORK", 0, 44, 44)
		backpack:SetPoint("LEFT", c, "TOPLEFT", x + 4, -30)
	end,
}

---------------------------------------------------------------------------
-- XP & reputation bars
---------------------------------------------------------------------------

-- The left end of the reputation bar and of the XP bar under it (rested,
-- with its tick), at the real bars' scale; the canvas cuts off the rest.
-- Blizzard's containers are 17px tall and stacked, their bars 1px in from
-- the left and top edges. The fills end at the same distance from the left
-- on every layout.
local STATUS_HEIGHT, STATUS_X = 17, 4
local STATUS_REP_TOP, STATUS_XP_TOP = -12, -29
local REP_END, XP_END, RESTED_END = 52, 80, 112

-- StatusTrackingBar.xml / StatusTrackingManagerOverrides.lua (Mainline):
-- 571px containers with 565x11 bars, the rested tick 2px above the bar's
-- middle, one segment. Forever's is in PreviewsForever.lua.
local STATUS_LAYOUT = { width = 571, barWidth = 565, barHeight = 11, tickOffset = 2, segments = 1 }

local function BarCenter(layout, top)
	return top - 1 - layout.barHeight / 2
end

-- ExperienceBar.lua: the frame spans the bar, centred on it, at the
-- container's height for the XP frame's rows; the fill fills its window.
local function ClassicStatusBar(c, layout, name, top, fillEnd, color, restedEnd)
	local art = ns.StatusBarArt
	local style = art.STYLES[name]
	local scale = STATUS_HEIGHT / art.STYLES.xp.height
	local x, center = STATUS_X + 1, BarCenter(layout, top)
	local frameHeight, fillHeight = style.height * scale, style.fill * scale
	local fillTop = center + fillHeight / 2
	Color(c, 0, 0, 0, 0.5, layout.barWidth, fillHeight, x, fillTop, "BACKGROUND")
	if restedEnd then
		local rested = Fill(c, T.STATUS_BAR, restedEnd, fillHeight, 1, nil, "BORDER")
		rested:SetVertexColor(color[1], color[2], color[3], art.RESTED_FILL_ALPHA)
		rested:SetPoint("TOPLEFT", c, "TOPLEFT", x, fillTop)
	end
	Fill(c, T.STATUS_BAR, fillEnd, fillHeight, 1, color, "ARTWORK"):SetPoint("TOPLEFT", c, "TOPLEFT", x, fillTop)
	local pieceWidth = layout.barWidth / 4
	for i, row in ipairs(style.rows) do
		File(c, style.file, pieceWidth, frameHeight, x + (i - 1) * pieceWidth, center + frameHeight / 2, "OVERLAY", 0,
			{ 0, 1, row / style.fileHeight, (row + style.height) / style.fileHeight })
	end
	if restedEnd then
		local size = art.TICK_SIZE * scale
		File(c, T.EXHAUSTION_TICK, size, size, x + restedEnd - size / 2, center + size / 2, "OVERLAY", 1)
	end
end

-- The retail bar: the background, rested prediction and fill atlases on the
-- bar, the frame atlas over the container, Forever's dividers between its
-- segments and the pip at the end of the rested stretch.
local function ModernStatusBar(c, layout, top, fillAtlas, fillEnd, restedEnd)
	local x, barTop = STATUS_X + 1, top - 1
	local function OnBar(atlas, width, layer)
		At(Fill(c, atlas, layout.barWidth, layout.barHeight, width / layout.barWidth, nil, layer), "TOPLEFT", x, barTop)
	end
	OnBar("UI-HUD-ExperienceBar-Background", layout.barWidth, "BACKGROUND")
	if restedEnd then
		OnBar("UI-HUD-ExperienceBar-Fill-Prediction", restedEnd, "BORDER")
	end
	OnBar(fillAtlas, fillEnd, "ARTWORK")
	At(Atlas(c, "UI-HUD-ExperienceBar-Frame", "OVERLAY", 0, layout.width, STATUS_HEIGHT), "TOPLEFT", STATUS_X, top)
	for i = 1, layout.segments - 1 do
		local divider = Atlas(c, "ui-hud-experiencebar-divider", "OVERLAY", 1, 3, 10)
		divider:SetPoint("LEFT", c, "TOPLEFT", STATUS_X + layout.width / layout.segments * i, top - STATUS_HEIGHT / 2)
	end
	if restedEnd then
		local pip = Atlas(c, "UI-HUD-ExperienceBar-Frame-Pip", "OVERLAY", 2, 10, 14)
		pip:SetPoint("CENTER", c, "TOPLEFT", x + restedEnd, BarCenter(layout, top) + layout.tickOffset)
	end
end

-- Both looks of a layout: a Friendly reputation bar over a rested XP bar.
local function StatusBarPictures(layout)
	local function classic(c)
		local art = ns.StatusBarArt
		ClassicStatusBar(c, layout, "watch", STATUS_REP_TOP, REP_END, art.STANDING_COLORS[5])
		ClassicStatusBar(c, layout, "xp", STATUS_XP_TOP, XP_END, art.RESTED_COLOR, RESTED_END)
	end
	local function modern(c)
		ModernStatusBar(c, layout, STATUS_REP_TOP, "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green", REP_END)
		ModernStatusBar(c, layout, STATUS_XP_TOP, "UI-HUD-ExperienceBar-Fill-Rested", XP_END, RESTED_END)
	end
	return classic, modern
end

do
	local classic, modern = StatusBarPictures(STATUS_LAYOUT)
	Previews.xpbar = { width = 150, height = 64, classic = classic, modern = modern }
end

---------------------------------------------------------------------------
-- Micro menu
---------------------------------------------------------------------------

local CLASSIC_MICRO = {
	{ "Spellbook" }, { "Talents" }, { "Achievement" }, { "Quest", true },
	{ "Socials", true }, { "LFG" }, { "MainMenu", true }, { "Help" },
}
local MODERN_MICRO = { "SpecTalents", "Achievements", "Questlog", "GuildCommunities", "Groupfinder", "Collections", "AdventureGuide", "GameMenu" }

Previews.micromenu = {
	width = 8 * 27 + 16, height = 50,
	classic = function(c)
		-- MicroMenu.lua: the 32x41 art in the files' bottom rows at 30px, 27px apart.
		local art = 30 / 32
		for i, button in ipairs(CLASSIC_MICRO) do
			local prefix = button[2] and ("Interface\\AddOns\\" .. ns.ADDON_NAME .. "\\Textures\\UI-MicroButton-") or "Interface\\Buttons\\UI-MicroButton-"
			local texture = File(c, prefix .. button[1] .. "-Up", 32 * art, 41 * art, 0, 0, "ARTWORK", 0, { 0, 1, 23 / 64, 1 })
			texture:ClearAllPoints()
			texture:SetPoint("CENTER", c, "TOPLEFT", 8 + 13.5 + (i - 1) * 27, -25)
		end
	end,
	modern = function(c)
		-- MainMenuBarMicroButtons.xml: 32x40 buttons 5px into each other,
		-- the icon atlas over the ButtonBG plate.
		for i, name in ipairs(MODERN_MICRO) do
			local x = 8 + 13.5 + (i - 1) * 27
			At(Atlas(c, "UI-HUD-MicroMenu-ButtonBG-Up", "BACKGROUND"), "CENTER", x, -25, c, "TOPLEFT")
			At(Atlas(c, "UI-HUD-MicroMenu-" .. name .. "-Up", "ARTWORK", 0, 32, 40), "CENTER", x, -25, c, "TOPLEFT")
		end
	end,
}

---------------------------------------------------------------------------
-- Game menu
---------------------------------------------------------------------------

local function MenuLabels()
	return {
		GAMEMENU_OPTIONS or "Options", GAMEMENU_SUPPORT or "Support", MACROS or "Macros",
		ADDONS or "AddOns", LOG_OUT or "Log Out", EXIT_GAME or "Exit Game",
	}, RETURN_TO_GAME or "Return to Game"
end

-- The classic UI-Panel-Button art stretched over a button-sized region.
local function ClassicButtonArt(parent, width, height, x, y, text)
	File(parent, "Interface\\Buttons\\UI-Panel-Button-Up", width, height, x, y, "ARTWORK", 0, { 0, 0.625, 0, 0.6875 })
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetText(text)
	label:SetPoint("CENTER", parent, "TOPLEFT", x + width / 2, y - height / 2 - 1)
end

Previews.gamemenu = {
	width = 270, height = 250,
	classic = function(c)
		-- GameMenu.lua: 195 wide, the first button centred 42px below the top,
		-- 144x21 buttons 1px apart, 16px before the last group.
		local labels, back = MenuLabels()
		local frameHeight = 42 - 10.5 + #labels * 22 - 1 + 16 + 21 + 16
		local frame = CreateFrame("Frame", nil, c, "BackdropTemplate")
		frame:SetSize(195, frameHeight)
		frame:SetPoint("TOP", c, "TOP", 0, -14)
		frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		local top = Layer(frame, 5)
		local plate = Tex(top, "ARTWORK")
		plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
		plate:SetSize(256, 64)
		plate:SetPoint("TOP", top, "TOP", 0, 12)
		Text(top, "GameFontNormal", MAINMENU_BUTTON or "Main Menu", "TOP", 0, -2)
		local y = -(42 - 10.5)
		for _, label in ipairs(labels) do
			ClassicButtonArt(top, 144, 21, (195 - 144) / 2, y, label)
			y = y - 22
		end
		ClassicButtonArt(top, 144, 21, (195 - 144) / 2, y - 15, back)
	end,
	modern = function(c)
		-- MainMenuFrameTemplate: 260 wide, 200x36 buttons, 48 / 34 padding.
		local labels, back = MenuLabels()
		local frame = CreateFrame("Frame", nil, c)
		frame:SetSize(260, 48 + (#labels + 1) * 30 + 10 + 34)
		frame:SetPoint("TOP", c, "TOP", 0, -10)
		CreateFrame("Frame", nil, frame, "DialogBorderTemplate"):SetAllPoints(frame)
		local header = CreateFrame("Frame", nil, frame, "DialogHeaderTemplate")
		header:SetPoint("TOP", frame, "TOP", 0, 11)
		header:Setup(MAINMENU_BUTTON or "Main Menu")
		local y = -48
		for i, label in ipairs(labels) do
			local button = CreateFrame("Button", nil, frame, "MainMenuFrameButtonTemplate")
			button:SetSize(200, 30)
			button:SetPoint("TOP", frame, "TOP", 0, y)
			button:SetText(label)
			y = y - 30
		end
		local button = CreateFrame("Button", nil, frame, "MainMenuFrameButtonTemplate")
		button:SetSize(200, 30)
		button:SetPoint("TOP", frame, "TOP", 0, y - 10)
		button:SetText(back)
	end,
}

---------------------------------------------------------------------------
-- Window frames (the vendor window)
---------------------------------------------------------------------------

local MERCHANT_CELLS = { 0, 1, 2 } -- hammer, anvil, gold anvil
local MERCHANT_ATLASES = { "SpellIcon-256x256-Repair", "SpellIcon-256x256-RepairAll", "SpellIcon-256x256-RepairAllGuild" }
local BUYBACK_ICON = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"
local VENDOR_PORTRAIT = "Interface\\Icons\\INV_Misc_Bag_10"
local VENDOR_X, VENDOR_Y, VENDOR_WIDTH, VENDOR_HEIGHT = 18, -16, 262, 150
local VENDOR_TAB_WIDTH = 80

-- The vendor row inside the inset: Sell All Junk, the three repair buttons
-- and the buyback slot (MerchantFrame.lua: the 36px cells of
-- UI-Merchant-RepairIcons, whose bevel is in the art, the bundled junk cell
-- and a plain buyback item).
local function VendorIcons(parent, classic)
	local y = -74
	if classic then
		File(parent, T.MERCHANT_SELL_JUNK, 36, 36, 14, y, "ARTWORK", 0, { 0, 36 / 64, 0, 36 / 64 })
		for i, cell in ipairs(MERCHANT_CELLS) do
			File(parent, T.MERCHANT_REPAIR_ICONS, 36, 36, 14 + i * 42, y, "ARTWORK", 0, { cell * 36 / 128, (cell + 1) * 36 / 128, 0, 36 / 64 })
		end
	else
		local function Slot(x, atlas)
			File(parent, "Interface\\Buttons\\UI-EmptySlot", 64, 64, x - 13, y + 14, "BACKGROUND")
			At(Atlas(parent, atlas, "ARTWORK", 0, 36, 36), "TOPLEFT", x, y)
		end
		Slot(14, "SpellIcon-256x256-SellJunk")
		for i, atlas in ipairs(MERCHANT_ATLASES) do
			Slot(14 + i * 42, atlas)
		end
	end
	ClassicSlot(parent, BUYBACK_ICON, 36, 204, y)
	if not classic then
		local undo = Atlas(parent, "common-icon-undo", "OVERLAY", 1, 20, 20)
		undo:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", 204 + 38, y - 38)
	end
end

-- PanelTabButtonTemplate: the ends 3 / 7px out (the selected tab's 1 / 8px),
-- the text 2px above the middle (5px below it while selected).
local function ModernTab(parent, x, y, label, selected)
	local prefix = selected and "uiframe-activetab-" or "uiframe-tab-"
	local left = At(Atlas(parent, prefix .. "left", "BACKGROUND"), "TOPLEFT", x - (selected and 1 or 3), y)
	local right = At(Atlas(parent, prefix .. "right", "BACKGROUND"), "TOPRIGHT", x + VENDOR_TAB_WIDTH + (selected and 8 or 7), y, parent, "TOPLEFT")
	local middle = Atlas(parent, "_" .. prefix .. "center", "BACKGROUND")
	middle:SetHorizTile(true)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	middle:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)
	Text(parent, selected and "GameFontHighlightSmall" or "GameFontNormalSmall", label, "CENTER", x + VENDOR_TAB_WIDTH / 2, y - 16 + (selected and -3 or 2), "TOPLEFT")
end

-- ns.SkinPanelTab (flat, as Windows.lua uses it): UI-Character-InActiveTab
-- with 20px ends in both states; the selected tab only has white text.
local function ClassicTab(parent, x, y, label, selected)
	File(parent, T.TAB_INACTIVE, 20, 32, x, y, "BACKGROUND", 0, { 0, 0.15625, 0, 1 })
	File(parent, T.TAB_INACTIVE, VENDOR_TAB_WIDTH - 40, 32, x + 20, y, "BACKGROUND", 0, { 0.15625, 0.84375, 0, 1 })
	File(parent, T.TAB_INACTIVE, 20, 32, x + VENDOR_TAB_WIDTH - 20, y, "BACKGROUND", 0, { 0.84375, 1, 0, 1 })
	Text(parent, selected and "GameFontHighlightSmall" or "GameFontNormalSmall", label, "CENTER", x + VENDOR_TAB_WIDTH / 2, y - 14, "TOPLEFT")
end

-- The vendor's two tabs under the frame, on the frame itself so its border
-- covers their tops; the first one selected. Blizzard centres
-- MerchantFrameTab1 50px in and 15px below the bottom edge with the second
-- 16px into it; Windows.lua hangs them 12px in, 1px up, 19px into each other.
local function VendorTabs(frame, Tab, classic)
	local labels = { MERCHANT or "Merchant", BUYBACK or "Buyback" }
	local x, y, overlap = 50 - VENDOR_TAB_WIDTH / 2, -VENDOR_HEIGHT - 15 + 16, 16
	if classic then
		x, y, overlap = 12, -VENDOR_HEIGHT + 1, 19
	end
	for i, label in ipairs(labels) do
		Tab(frame, x + (i - 1) * (VENDOR_TAB_WIDTH - overlap), y, label, i == 1)
	end
end

local function VendorPortrait(parent)
	local texture = File(parent, VENDOR_PORTRAIT, 62, 62, -5, 7, "OVERLAY")
	Mask(parent, texture)
	return texture
end

Previews.windows = {
	width = VENDOR_X + VENDOR_WIDTH + 12, height = -VENDOR_Y + VENDOR_HEIGHT + 40,
	classic = function(c)
		-- Windows.lua: the rock and inset stay, the metal is the legacy
		-- UI-Frame-* border (ns.CreateClassicBorder) with the round close
		-- button 4px right of and 5px above the corner.
		local frame = CreateFrame("Frame", nil, c)
		frame:SetSize(VENDOR_WIDTH, VENDOR_HEIGHT)
		frame:SetPoint("TOPLEFT", c, "TOPLEFT", VENDOR_X, VENDOR_Y)
		RockBackground(frame)
		ModernInset(frame, 4, -60, -6, 26)
		VendorPortrait(Layer(frame, 20))
		ns.CreateClassicBorder(Layer(frame, 30), frame, true)
		local top = Layer(frame, 40)
		Text(top, "GameFontNormal", MERCHANT or "Merchant", "TOP", 17, -5)
		File(top, T.PANEL_CLOSE .. "Up", 32, 32, VENDOR_WIDTH + 4 - 32, 5, "OVERLAY")
		VendorIcons(top, true)
		VendorTabs(frame, ClassicTab, true)
	end,
	modern = function(c)
		local frame, top, border = ModernWindow(c, VENDOR_WIDTH, VENDOR_HEIGHT, MERCHANT or "Merchant", VendorPortrait)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", c, "TOPLEFT", VENDOR_X, VENDOR_Y)
		ModernInset(frame, 4, -60, -6, 26)
		-- UIPanelCloseButtonDefaultAnchors, over the nine-slice like Blizzard's.
		local buttons = CreateFrame("Frame", nil, frame)
		buttons:SetAllPoints(frame)
		buttons:SetFrameLevel(border:GetFrameLevel() + 10)
		At(Atlas(buttons, "RedButton-Exit", "OVERLAY", 0, 24, 24), "TOPRIGHT", 1, 0)
		VendorIcons(Layer(frame, 30), false)
		VendorTabs(frame, ModernTab)
	end,
}

---------------------------------------------------------------------------
-- Bank
---------------------------------------------------------------------------

-- A small bank window: three rows of slots from Blizzard's first row
-- (63px down), a few holding items, the rest empty.
local BANK_X, BANK_Y, BANK_WIDTH, BANK_HEIGHT = 18, -16, 395, 226
local BANK_FIRST_Y, BANK_ROWS, BANK_COLUMNS = -63, 3, 7
local BANK_PORTRAIT = "Interface\\Icons\\INV_Misc_Coin_02"
local BANK_ITEMS = {
	[1] = "Interface\\Icons\\INV_Fabric_Linen_01", [2] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
	[3] = "Interface\\Icons\\INV_Sword_04", [8] = "Interface\\Icons\\INV_Misc_Bag_10",
}

local function BankPortrait(parent)
	local texture = File(parent, BANK_PORTRAIT, 62, 62, -5, 7, "OVERLAY")
	Mask(parent, texture)
	return texture
end

-- BankFrameTemplate's stone over the portrait frame's rock.
local function BankStone(frame)
	RockBackground(frame)
	local stone = Tex(frame, "BACKGROUND", -5)
	if ns.SetAtlas(stone, "bank-frame-background") then
		stone:SetHorizTile(true)
		stone:SetVertTile(true)
		stone:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
		stone:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	else
		stone:Hide()
	end
end

-- Calls draw(index, x, y) for each slot, row by row.
local function BankSlots(pitchY, ColumnX, draw)
	for row = 0, BANK_ROWS - 1 do
		for column = 0, BANK_COLUMNS - 1 do
			draw(row * BANK_COLUMNS + column + 1, ColumnX(column), BANK_FIRST_Y - row * pitchY, column, row)
		end
	end
end

-- A modern bank window of `width`: the slots at ColumnX(column), 47px
-- apart down, on the `background` atlas under FrameAtlas(holdsItem) (or the
-- ItemButton's UI-Quickslot2 when nil). Forever's picture uses it too.
local function ModernBank(c, width, ColumnX, background, FrameAtlas)
	local frame, _, border = ModernWindow(c, width, BANK_HEIGHT, BANK or "Bank", BankPortrait)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", c, "TOPLEFT", BANK_X, BANK_Y)
	BankStone(frame)
	local slots = Layer(frame, 10)
	BankSlots(47, ColumnX, function(index, x, y)
		At(Atlas(slots, background, "BACKGROUND", 0, 37, 37), "TOPLEFT", x, y)
		if BANK_ITEMS[index] then
			File(slots, BANK_ITEMS[index], 37, 37, x, y, "ARTWORK")
		end
		if FrameAtlas then
			At(Atlas(slots, FrameAtlas(BANK_ITEMS[index] ~= nil), "OVERLAY", 0, 37, 37), "TOPLEFT", x, y)
		else
			local normal = Tex(slots, "OVERLAY")
			normal:SetTexture(T.QUICKSLOT2)
			normal:SetSize(64, 64)
			normal:SetPoint("CENTER", slots, "TOPLEFT", x + 18.5, y - 19.5)
		end
	end)
	local buttons = CreateFrame("Frame", nil, frame)
	buttons:SetAllPoints(frame)
	buttons:SetFrameLevel(border:GetFrameLevel() + 10)
	At(Atlas(buttons, "RedButton-Exit", "OVERLAY", 0, 24, 24), "TOPRIGHT", 1, 0)
end

Previews.bank = {
	width = BANK_X + BANK_WIDTH + 12, height = -BANK_Y + BANK_HEIGHT + 12,
	classic = function(c)
		-- BankFrame.lua: the vanilla UI-BankFrame (its own 7x4 grid here),
		-- the portrait under its ring, slots 49 x 44px apart from (40, -73)
		-- under UI-Quickslot2; the picture shows its top.
		local frame = CreateFrame("Frame", nil, c)
		frame:SetSize(400, 424)
		frame:SetPoint("TOPLEFT", c, "TOPLEFT", BANK_X - 10, BANK_Y + 13)
		local portrait = BankPortrait(frame)
		portrait:SetDrawLayer("BACKGROUND")
		portrait:SetSize(60, 60)
		portrait:ClearAllPoints()
		portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -6)
		File(frame, T.BANK_FRAME, 512, 512, 0, 0, "BORDER")
		local slots = Layer(frame, 10)
		for index = 1, 3 * 7 do
			local x, y = 40 + (index - 1) % 7 * 49, -73 - math.floor((index - 1) / 7) * 44
			if BANK_ITEMS[index] then
				File(slots, BANK_ITEMS[index], 37, 37, x, y, "ARTWORK")
			end
			local normal = Tex(slots, "OVERLAY")
			normal:SetTexture(T.QUICKSLOT2)
			normal:SetSize(64, 64)
			normal:SetPoint("CENTER", slots, "TOPLEFT", x + 18.5, y - 19.5)
		end
		Text(slots, "GameFontHighlight", BANK or "Bank", "CENTER", 220, -24, "TOPLEFT")
		Text(slots, "GameFontNormal", ITEMSLOTTEXT or "Item Slots", "CENTER", 202, -62, "TOPLEFT")
		File(slots, T.PANEL_CLOSE .. "Up", 32, 32, 400 - 12 - 16, -24 + 16, "OVERLAY")
	end,
	modern = function(c)
		-- Retail (Mainline\BankFrame.lua): pairs of columns 8px apart,
		-- 19px between pairs, from 26px in, on bags-item-slot64.
		ModernBank(c, BANK_WIDTH, function(column)
			return 26 + column * 45 + math.floor(column / 2) * 11
		end, "bags-item-slot64")
	end,
}

---------------------------------------------------------------------------
-- Quest log
---------------------------------------------------------------------------

local FALLBACK_QUESTS = {
	{ header = true, title = "Elwynn Forest" },
	{ title = "The Fargodeep Mine", level = 7 },
	{ title = "Princess Must Die!", level = 9 },
	{ title = "Bounty on Murlocs", level = 10 },
	{ header = true, title = "Westfall" },
	{ title = "The Defias Brotherhood", level = 14 },
}

-- The first rows of the player's own quest log, or stock quests.
local function QuestRows(count)
	local rows = {}
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
		for index = 1, C_QuestLog.GetNumQuestLogEntries() do
			if #rows >= count then break end
			local info = C_QuestLog.GetInfo(index)
			if info and not info.isHidden and not info.isTask and info.title then
				rows[#rows + 1] = { header = info.isHeader, title = info.title, level = info.difficultyLevel or info.level }
			end
		end
	end
	if #rows < 3 then
		rows = FALLBACK_QUESTS
	end
	return rows
end

local function QuestColor(row)
	local color = row.header and QuestDifficultyColors and QuestDifficultyColors.header
		or (GetQuestDifficultyColor and GetQuestDifficultyColor(row.level or 1))
	return color and { color.r, color.g, color.b } or WHITE
end

local QUESTLOG_X, QUESTLOG_Y, QUESTLOG_WIDTH, QUESTLOG_HEIGHT = 14, -14, 338, 452

Previews.questlog = {
	width = QUESTLOG_X + QUESTLOG_WIDTH + 12, height = -QUESTLOG_Y + QUESTLOG_HEIGHT + 10,
	classic = function(c)
		-- QuestLog.lua: Window Frames' metal frame with the book in the ring,
		-- the list box 58px down (98 high: six 16px title rows 15px apart, the
		-- first quest selected on the tinted bar), the parchment box 4px under
		-- it down to 28px above the bottom, and the three buttons below.
		local frame = CreateFrame("Frame", nil, c)
		frame:SetSize(QUESTLOG_WIDTH, QUESTLOG_HEIGHT)
		frame:SetPoint("TOPLEFT", c, "TOPLEFT", QUESTLOG_X, QUESTLOG_Y)
		RockBackground(frame)
		local listBox = ModernInset(frame, 6, -58, -6, QUESTLOG_HEIGHT - 58 - 98)
		listBox.Bg:SetColorTexture(0, 0, 0, 0.75)
		local detailBox = ModernInset(frame, 6, -58 - 98 - 4, -6, 28)
		detailBox.Bg:SetHorizTile(false)
		detailBox.Bg:SetVertTile(false)
		ns.SetAtlas(detailBox.Bg, "QuestBG-Parchment")
		local portrait = File(Layer(frame, 20), T.QUESTLOG_ICON, 62, 62, -5, 7, "ARTWORK")
		Mask(portrait:GetParent(), portrait)
		ns.CreateClassicBorder(Layer(frame, 30), frame, true)

		local top = Layer(frame, 40)
		Text(top, "GameFontNormal", QUEST_LOG or "Quest Log", "TOP", 17, -5)
		File(top, T.PANEL_CLOSE .. "Up", 32, 32, QUESTLOG_WIDTH + 4 - 32, 5, "OVERLAY")
		local selected
		for i, row in ipairs(QuestRows(6)) do
			if i > 6 then break end
			local y = -58 - 4 - (i - 1) * 15
			local color = QuestColor(row)
			if row.header then
				File(top, T.MINUS_BUTTON .. "Up", 16, 16, 10 + 3, y, "ARTWORK")
			elseif not selected then
				selected = row
				local bar = File(top, T.QUESTLOG_HIGHLIGHT, 293, 16, 10, y, "ARTWORK", 0)
				bar:SetBlendMode("ADD")
				bar:SetVertexColor(color[1], color[2], color[3])
				color = WHITE
			end
			local text = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
			text:SetText(row.header and row.title or ("  " .. row.title))
			text:SetTextColor(color[1], color[2], color[3])
			text:SetPoint("LEFT", top, "TOPLEFT", 10 + 20, y - 8)
		end
		if selected then
			local title = top:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
			title:SetText(selected.title)
			title:SetPoint("TOPLEFT", top, "TOPLEFT", 6 + 6 + 5, -58 - 98 - 4 - 6 - 5)
			local objectives = top:CreateFontString(nil, "OVERLAY", "QuestFont")
			objectives:SetText(QUEST_OBJECTIVES or "Quest Objectives")
			objectives:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
		end
		local buttonY = -(QUESTLOG_HEIGHT - 4 - 22)
		ClassicButtonArt(top, 120, 22, 4, buttonY, ABANDON_QUEST or "Abandon Quest")
		ClassicButtonArt(top, QUESTLOG_WIDTH - 4 - 120 - 2 - 2 - 90 - 6, 22, 4 + 120 + 2, buttonY, SHARE_QUEST or "Share Quest")
		ClassicButtonArt(top, 90, 22, QUESTLOG_WIDTH - 6 - 90, buttonY, EXIT or "Exit")
	end,
	modern = function(c)
		-- Retail has no quest log window: the quest list is the world map's
		-- side panel (QuestMapFrame, QuestLog-main-background), with the map
		-- beside it.
		local frame, top = ModernWindow(c, 340, 430, MAP_AND_QUEST_LOG or "Map & Quest Log", IconPortrait("Interface\\Icons\\INV_Misc_Map_01"))
		local panel = Atlas(frame, "QuestLog-main-background", "ARTWORK", 0, 290, 360)
		panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -45)
		local y = -60
		for i, row in ipairs(QuestRows(8)) do
			if i > 8 then break end
			local text = top:CreateFontString(nil, "OVERLAY", row.header and "GameFontNormalMed2" or "GameFontHighlight")
			text:SetText(row.title)
			text:SetPoint("TOPLEFT", top, "TOPLEFT", row.header and 44 or 58, y)
			if not row.header then
				local color = QuestColor(row)
				text:SetTextColor(0.9, 0.9, 0.9)
				local dot = Atlas(top, "questlog-icon-ticksquare", "OVERLAY", 0, 12, 12)
				dot:SetVertexColor(color[1], color[2], color[3])
				dot:SetPoint("RIGHT", text, "LEFT", -4, 0)
			end
			y = y - (row.header and 26 or 20)
		end
	end,
}

---------------------------------------------------------------------------
-- Quest tracker
---------------------------------------------------------------------------

local FALLBACK_TRACKED = {
	{ title = "Kobold Camp Cleanup", objectives = { { "Kobold Vermin slain: 10/10", true }, { "Kobold Worker slain: 4/10" } } },
	{ title = "Bounty on Murlocs", objectives = { { "Torn Murloc Fin: 3/8" } } },
}

-- The player's first tracked quests (two objectives each), or stock ones.
local function TrackedQuests(count)
	local quests = {}
	if C_QuestLog and C_QuestLog.GetNumQuestWatches then
		for i = 1, C_QuestLog.GetNumQuestWatches() do
			if #quests >= count then break end
			local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
			local title = questID and C_QuestLog.GetTitleForQuestID(questID)
			local objectives = questID and C_QuestLog.GetQuestObjectives(questID)
			if title and type(objectives) == "table" and #objectives > 0 then
				local quest = { title = title, complete = C_QuestLog.IsComplete(questID), objectives = {} }
				for j = 1, math.min(#objectives, 2) do
					quest.objectives[j] = { objectives[j].text or "", objectives[j].finished }
				end
				quests[#quests + 1] = quest
			end
		end
	end
	if #quests == 0 then
		quests = FALLBACK_TRACKED
	end
	return quests
end

local TRACKER_X, TRACKER_WIDTH = 12, 260
local TRACKER_TITLE = { 0.75, 0.61, 0 }      -- OBJECTIVE_TRACKER_COLOR Header
local TRACKER_LINE = { 0.8, 0.8, 0.8 }       -- Normal
local TRACKER_LINE_MET = { 0.6, 0.6, 0.6 }   -- Complete

-- Blizzard_ObjectiveTracker's layout: the 32px "All Objectives" header,
-- the first section 38px down with its 26px header, blocks 20px in and 10px
-- apart, lines 4px apart.
local function TrackerPicture(c, classic)
	local function Header(y, height, plate, label, buttonAtlas, buttonX)
		local centerY = y - height / 2
		if not classic then
			Atlas(c, plate, "BACKGROUND", 0):SetPoint("CENTER", c, "TOPLEFT", TRACKER_X + TRACKER_WIDTH / 2, centerY)
		end
		Text(c, "GameFontNormalMed2", label, "LEFT", TRACKER_X + 7, centerY, "TOPLEFT")
		local button
		if classic then
			button = File(c, T.MINUS_BUTTON .. "Up", 16, 16, 0, 0, "ARTWORK")
			button:ClearAllPoints()
		else
			button = Atlas(c, buttonAtlas, "ARTWORK", 0)
		end
		button:SetPoint("CENTER", c, "TOPLEFT", TRACKER_X + TRACKER_WIDTH + buttonX, centerY)
	end
	Header(0, 32, "ui-questtracker-primary-objective-header", TRACKER_ALL_OBJECTIVES or "All Objectives",
		"ui-questtrackerbutton-collapse-all", -10)
	Header(-38, 26, "UI-QuestTracker-Secondary-Objective-Header", TRACKER_HEADER_QUESTS or "Quests",
		"ui-questtrackerbutton-secondary-collapse", -7)

	-- QuestTracker.lua's vanilla spacing: no POI button, titles in line with
	-- the section name, objectives 1px apart, 4px between quests.
	local lineGap, blockGap = classic and 1 or 4, classic and 4 or 10
	local x, y = TRACKER_X + (classic and 7 or 20), -38 - 26 - 10
	for i, quest in ipairs(TrackedQuests(2)) do
		if i > 2 then break end
		local titleColor = (classic and quest.complete) and { 1, 0.82, 0 } or TRACKER_TITLE
		local title = Text(c, "GameFontHighlight", quest.title, "TOPLEFT", x, y, nil, titleColor)
		title:SetWidth(TRACKER_WIDTH - 20)
		title:SetJustifyH("LEFT")
		title:SetWordWrap(false)
		y = y - 12
		for _, objective in ipairs(quest.objectives) do
			y = y - lineGap
			local met = objective[2]
			local color = met and (classic and WHITE or TRACKER_LINE_MET) or TRACKER_LINE
			local dash = Text(c, "GameFontHighlight", QUEST_DASH or "- ", "TOPLEFT", x, y + 1, nil, color)
			if met and not classic then
				dash:SetAlpha(0)
				Atlas(c, "ui-questtracker-tracker-check", "ARTWORK", 0, 16, 16):SetPoint("TOPLEFT", c, "TOPLEFT", x - 10, y + 2)
			end
			local text = Text(c, "GameFontHighlight", objective[1], "TOPLEFT", 0, 0, nil, color)
			text:ClearAllPoints()
			text:SetPoint("TOPLEFT", dash, "TOPRIGHT", 0, -1)
			text:SetWidth(TRACKER_WIDTH - 20 - dash:GetStringWidth())
			text:SetJustifyH("LEFT")
			text:SetWordWrap(false)
			y = y - 12
		end
		y = y - blockGap
	end
end

Previews.questtracker = {
	width = TRACKER_X + TRACKER_WIDTH + 8, height = 172,
	classic = function(c) TrackerPicture(c, true) end,
	modern = function(c) TrackerPicture(c, false) end,
}

---------------------------------------------------------------------------
-- Loot window
---------------------------------------------------------------------------

local LOOT_ROWS = {
	{ "Interface\\Icons\\INV_Misc_Coin_02", "12 Copper", WHITE },
	{ "Interface\\Icons\\INV_Fabric_Linen_01", "Linen Cloth", WHITE },
	{ "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "Ruined Pelt", GREY },
}

Previews.lootframe = {
	width = 186, height = 256,
	classic = function(c)
		-- LootFrame.lua: the skull under the panel's ring, 37px icons 41px
		-- apart from (24, -80), the name frame 30px in.
		File(c, T.LOOT_SKULL, 58, 58, 10, -8, "BORDER")
		File(c, T.LOOT_PANEL, 256, 256, 0, 0, "ARTWORK")
		ClassicTitle(c, ITEMS or "Items", 116, -26)
		for i, row in ipairs(LOOT_ROWS) do
			local y = -80 - (i - 1) * 41
			File(c, row[1], 37, 37, 24, y, "ARTWORK", 1)
			File(c, T.LOOT_NAME_FRAME, 130, 62, 24 + 30, y + 12, "ARTWORK", 2)
			local text = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			text:SetText(row[2])
			text:SetTextColor(row[3][1], row[3][2], row[3][3])
			text:SetJustifyH("LEFT")
			text:SetSize(93, 38)
			text:SetPoint("LEFT", c, "TOPLEFT", 24 + 37 + 8, y - 18.5)
		end
	end,
	modern = function(c)
		-- Retail: a flat dark panel with its title bar and full-width rows.
		local frame = CreateFrame("Frame", nil, c)
		frame:SetSize(176, 180)
		frame:SetPoint("TOP", c, "TOP", 0, -20)
		local bg = Tex(frame, "BACKGROUND", -6)
		bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
		bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
		bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
		local border = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
		border:SetAllPoints(frame)
		NineSliceUtil.ApplyLayoutByName(border, "ButtonFrameTemplateNoPortrait")
		local top = Layer(frame, 20)
		Text(top, "GameFontNormal", LOOT or "Loot", "TOP", 0, -5)
		for i, row in ipairs(LOOT_ROWS) do
			local y = -34 - (i - 1) * 44
			Color(top, 0.15, 0.15, 0.15, 0.9, 156, 38, 10, y, "BACKGROUND")
			File(top, row[1], 34, 34, 12, y - 2, "ARTWORK")
			local text = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			text:SetText(row[2])
			text:SetTextColor(row[3][1], row[3][2], row[3][3])
			text:SetPoint("LEFT", top, "TOPLEFT", 52, y - 19)
		end
	end,
}

---------------------------------------------------------------------------
-- Panels: trainer, professions, auction house, character, spellbook, talents
---------------------------------------------------------------------------

-- The windows are tall; their pictures show the top part.
local WINDOW_HEIGHT = 330

local TRAINER_ROWS = {
	{ nil, "Frostbolt (Rank 3)", ORANGE }, { nil, "Arcane Intellect (Rank 2)", YELLOW },
	{ nil, "Fire Ward (Rank 1)", GREEN }, { nil, "Conjure Water (Rank 2)", GREEN },
	{ nil, "Blink", GREY }, { nil, "Frost Nova (Rank 2)", GREY },
}

Previews.trainer = {
	width = 384, height = WINDOW_HEIGHT,
	classic = function(c)
		Portrait(c, 60, 7, -6)
		ClassicWindow(c, "Interface\\ClassTrainerFrame\\UI-ClassTrainer-")
		ClassicTitle(c, "Trainer", 190, -17)
		ListRows(c, TRAINER_ROWS, 26, -100, 16, 14, "GameFontNormalSmall")
	end,
	modern = function(c)
		local frame = ModernWindow(c, 338, 424, "Trainer", PlayerPortrait)
		local inset = ModernInset(frame, 4, -80, -6, 26)
		ListRows(inset, TRAINER_ROWS, 10, -8, 22, 14, "GameFontNormal")
	end,
}

local PROFESSION_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local PROFESSION_NAME = "Blacksmithing"
local RECIPE_ROWS = {
	{ nil, "Copper Chain Belt", ORANGE }, { nil, "Rough Copper Vest", YELLOW },
	{ nil, "Copper Mace", YELLOW }, { nil, "Rough Sharpening Stone", GREEN },
	{ nil, "Copper Bracers", GREY }, { nil, "Rough Weightstone", GREY },
}

Previews.professions = {
	width = 384, height = WINDOW_HEIGHT,
	classic = function(c)
		RoundIcon(c, PROFESSION_ICON, 60, 7, -6)
		local botLeft = ns.HasTexture("Interface\\TradeSkillFrame\\UI-TradeSkill-BotLeft") and "Interface\\TradeSkillFrame\\UI-TradeSkill-BotLeft" or nil
		local pieces = {
			{ "TopLeft", 256, 256, 0, 0 }, { "TopRight", 128, 256, 256, 0 },
			{ "BotLeft", 256, 256, 0, -256, path = botLeft }, { "BotRight", 128, 256, 256, -256 },
		}
		ClassicWindow(c, "Interface\\ClassTrainerFrame\\UI-ClassTrainer-", pieces)
		ClassicTitle(c, PROFESSION_NAME, 190, -17)
		-- The rank bar under the title.
		Color(c, 0.25, 0.25, 0.75, 1, 190 * 0.6, 14, 75, -38, "ARTWORK", 1)
		ListRows(c, RECIPE_ROWS, 26, -100, 16, 14, "GameFontNormalSmall")
	end,
	modern = function(c)
		local frame = ModernWindow(c, 560, 420, PROFESSION_NAME, IconPortrait(PROFESSION_ICON))
		local list = ModernInset(frame, 8, -64, -372, 8)
		ListRows(list, RECIPE_ROWS, 10, -8, 20, 14, "GameFontHighlightSmall")
		local detail = ModernInset(frame, 196, -64, -8, 8)
		File(detail, PROFESSION_ICON, 40, 40, 12, -12, "ARTWORK")
		Text(detail, "GameFontNormalLarge", RECIPE_ROWS[1][2], "TOPLEFT", 60, -22)
	end,
}

local AH_ROWS = {
	{ "Interface\\Icons\\INV_Fabric_Linen_01", "Linen Cloth", WHITE },
	{ "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "Light Leather", WHITE },
	{ "Interface\\Icons\\INV_Sword_04", "Worn Shortsword", GREEN },
	{ "Interface\\Icons\\INV_Misc_Coin_02", "Copper Ore", WHITE },
}

Previews.auctionhouse = {
	width = 832, height = 447,
	classic = function(c)
		-- AuctionHouse.lua: the six Browse pieces, 256 / 320 / 256 wide.
		RoundIcon(c, "Interface\\Icons\\INV_Misc_Coin_02", 58, 8, -7)
		local prefix = "Interface\\AuctionFrame\\UI-AuctionFrame-Browse-"
		ClassicWindow(c, prefix, {
			{ "TopLeft", 256, 256, 0, 0 }, { "Top", 320, 256, 256, 0 }, { "TopRight", 256, 256, 576, 0 },
			{ "BotLeft", 256, 256, 0, -256 }, { "Bot", 320, 256, 256, -256 }, { "BotRight", 256, 256, 576, -256 },
		})
		ClassicTitle(c, "Auction House", 416, -18)
		ListRows(c, AH_ROWS, 195, -110, 37, 32, "GameFontNormal")
	end,
	modern = function(c)
		local frame = ModernWindow(c, 800, 420, "Auction House", IconPortrait("Interface\\Icons\\INV_Misc_Coin_02"))
		ModernInset(frame, 8, -64, -600, 8)
		local list = ModernInset(frame, 200, -64, -8, 8)
		ListRows(list, AH_ROWS, 12, -10, 40, 32, "GameFontHighlight")
	end,
}

-- The equipment slots down the paperdoll's sides (vanilla: 21 / 305 px in,
-- from 74 px down, 41 px apart).
local LEFT_SLOTS = { 1, 2, 3, 15, 5, 4, 19, 9 }
local RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 }

local function EquippedIcon(slot)
	return GetInventoryItemTexture("player", slot)
end

Previews.characterframe = {
	width = 384, height = WINDOW_HEIGHT,
	classic = function(c)
		Portrait(c, 60, 7, -6)
		ClassicWindow(c, "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-", {
			{ "L1", 256, 256, 0, 0 }, { "R1", 128, 256, 256, 0 },
			{ "BottomLeft", 256, 256, 0, -256 }, { "BottomRight", 128, 256, 256, -256 },
		})
		ClassicTitle(c, PlayerName(), 190, -17)
		for column, slots in ipairs({ LEFT_SLOTS, RIGHT_SLOTS }) do
			for i, slot in ipairs(slots) do
				local icon = EquippedIcon(slot)
				if icon then
					File(c, icon, 37, 37, column == 1 and 21 or 305, -74 - (i - 1) * 41, "ARTWORK")
				end
			end
		end
	end,
	modern = function(c)
		local frame = ModernWindow(c, 398, 484, PlayerName(), PlayerPortrait)
		local inset = ModernInset(frame, 4, -60, -6, 8)
		for column, slots in ipairs({ LEFT_SLOTS, RIGHT_SLOTS }) do
			for i, slot in ipairs(slots) do
				local x, y = column == 1 and 8 or 340, -8 - (i - 1) * 44
				File(inset, "Interface\\Buttons\\UI-EmptySlot", 64, 64, x - 13, y + 14, "BACKGROUND", 1)
				local icon = EquippedIcon(slot)
				if icon then File(inset, icon, 37, 37, x, y, "ARTWORK") end
			end
		end
	end,
}

Previews.spellbook = {
	width = 384, height = WINDOW_HEIGHT,
	classic = function(c)
		File(c, "Interface\\Spellbook\\Spellbook-Icon", 58, 58, 10, -8, "BACKGROUND")
		ClassicWindow(c, "Interface\\Spellbook\\UI-SpellbookPanel-")
		ClassicTitle(c, SPELLBOOK or "Spellbook", 190, -17)
		-- Twelve spells, two columns (vanilla SpellButton1 at 25,-75, the
		-- second column 157px over, rows 54px apart).
		for i, spell in ipairs(PlayerSpells(12)) do
			local column, row = (i - 1) % 2, math.floor((i - 1) / 2)
			local x, y = 25 + column * 157, -75 - row * 54
			File(c, "Interface\\Spellbook\\UI-Spellbook-SpellBackground", 64, 64, x - 3, y + 3, "ARTWORK", 1)
			File(c, spell[1], 37, 37, x, y, "ARTWORK", 2)
			local name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			name:SetText(spell[2])
			name:SetJustifyH("LEFT")
			name:SetWidth(100)
			name:SetPoint("LEFT", c, "TOPLEFT", x + 41, y - 12)
		end
	end,
	modern = function(c)
		local frame = ModernWindow(c, 800, 520, SPELLBOOK or "Spellbook", IconPortrait("Interface\\Spellbook\\Spellbook-Icon"))
		local page = ModernInset(frame, 8, -64, -8, 8)
		for i, spell in ipairs(PlayerSpells(12)) do
			local column, row = (i - 1) % 3, math.floor((i - 1) / 3)
			local x, y = 20 + column * 250, -20 - row * 60
			RoundIcon(page, spell[1], 44, x, y, "ARTWORK")
			Text(page, "GameFontNormal", spell[2], "LEFT", x + 52, y - 22, "TOPLEFT")
		end
	end,
}

-- The class's first talent tree background (1.12 file names).
local TALENT_TREES = {
	WARRIOR = "WarriorArms", PALADIN = "PaladinHoly", HUNTER = "HunterBeastMastery",
	ROGUE = "RogueAssassination", PRIEST = "PriestDiscipline", SHAMAN = "ShamanElementalCombat",
	MAGE = "MageArcane", WARLOCK = "WarlockCurses", DRUID = "DruidBalance",
}

Previews.talents = {
	width = 384, height = WINDOW_HEIGHT,
	classic = function(c)
		local _, class = UnitClass("player")
		local tree = TALENT_TREES[class or ""] or "MageArcane"
		local prefix = "Interface\\TalentFrame\\" .. tree .. "-"
		if ns.HasTexture(prefix .. "TopLeft") then
			File(c, prefix .. "TopLeft", 256, 256, 23, -77, "BACKGROUND")
			File(c, prefix .. "TopRight", 64, 256, 279, -77, "BACKGROUND")
		end
		Portrait(c, 60, 7, -6, "BACKGROUND", 1)
		ClassicWindow(c, "Interface\\", {
			{ "PaperDollInfoFrame\\UI-Character-General-TopLeft", 256, 256, 2, -1 },
			{ "PaperDollInfoFrame\\UI-Character-General-TopRight", 128, 256, 258, -1 },
			{ "TalentFrame\\UI-TalentFrame-BotLeft", 256, 256, 2, -257 },
			{ "TalentFrame\\UI-TalentFrame-BotRight", 128, 256, 258, -257 },
		})
		ClassicTitle(c, TALENTS or "Talents", 190, -17)
		-- Square talents on the 1.12 grid (63px apart from 35, 20 into the tree).
		local spells = PlayerSpells(8)
		for i = 1, 8 do
			local column, row = (i - 1) % 4, math.floor((i - 1) / 4)
			local x, y = 23 + 35 + column * 63, -77 - 20 - row * 63
			ClassicSlot(c, spells[i][1], 32, x, y)
			local rank = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			rank:SetText(i <= 3 and "5" or "0")
			rank:SetTextColor(i <= 3 and 1 or 0.1, i <= 3 and 0.82 or 1, i <= 3 and 0 or 0.1)
			rank:SetPoint("CENTER", c, "TOPLEFT", x + 32, y - 32)
		end
	end,
	modern = function(c)
		local frame = ModernWindow(c, 820, 520, TALENTS or "Talents", PlayerPortrait)
		local tree = ModernInset(frame, 8, -64, -8, 8)
		local spells = PlayerSpells(12)
		for i = 1, 12 do
			local column, row = (i - 1) % 6, math.floor((i - 1) / 6)
			local x, y = 30 + column * 128 + (row % 2) * 64, -30 - row * 90
			RoundIcon(tree, spells[i][1], 40, x, y, "ARTWORK")
			local ring = Color(tree, 1, 0.82, 0, i <= 5 and 0.9 or 0.3, 46, 46, x - 3, y + 3, "BORDER")
			Mask(tree, ring)
		end
	end,
}

-- Screenshots used instead of a drawing where one cannot be made faithful
-- (whole windows): key -> look -> { file, width, height, fileWidth,
-- fileHeight }, the image filling the top-left width x height pixels of a
-- fileWidth x fileHeight (power of two) file in Textures\Previews. These are
-- the retail screenshots; PreviewsForever.lua replaces the table.
local IMAGE_PATH = "Interface\\AddOns\\" .. ns.ADDON_NAME .. "\\Textures\\Previews\\"
ns.PreviewImages = {}

-- The drawing helpers, for the flavor-specific pictures (PreviewsForever.lua).
ns.PreviewKit = {
	Tex = Tex, At = At, File = File, Atlas = Atlas, Color = Color, Fill = Fill, Text = Text,
	Portrait = Portrait, EnemyPortrait = EnemyPortrait, Mask = Mask, RoundIcon = RoundIcon, Layer = Layer,
	MapDisc = MapDisc, ZoneText = ZoneText, ActionIcons = ActionIcons, BagIcon = BagIcon,
	PlayerName = PlayerName, PlayerLevel = PlayerLevel, PlayerSpells = PlayerSpells,
	ModernActionButton = ModernActionButton, EndCapBar = EndCapBar, StatusBarPictures = StatusBarPictures,
	ModernBank = ModernBank,
	ACTION_SIZE = ACTION_SIZE, ACTION_PADDING = ACTION_PADDING, ENDCAP_BAR_WIDTH = ENDCAP_BAR_WIDTH,
	NAMEPLATE_NAME = NAMEPLATE_NAME, MODERN_MICRO = MODERN_MICRO,
}

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

function ns.HasPreview(key)
	return Previews[key] ~= nil
end

local function DisableMouse(frame)
	frame:EnableMouse(false)
	frame:EnableMouseWheel(false)
	for _, child in ipairs({ frame:GetChildren() }) do
		DisableMouse(child)
	end
end

-- Draws the "classic" or "modern" picture of an option into a new frame on
-- `parent`, at the picture's own size (see ns.FitPreview). Returns nil when
-- the option has no picture.
function ns.CreatePreview(parent, key, look)
	local image = ns.PreviewImages[key] and ns.PreviewImages[key][look]
	if image then
		local canvas = CreateFrame("Frame", nil, parent)
		canvas:SetSize(image.width, image.height)
		local texture = canvas:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints(canvas)
		texture:SetTexture(IMAGE_PATH .. image.file, nil, nil, "TRILINEAR")
		texture:SetTexCoord(0, image.width / image.fileWidth, 0, image.height / image.fileHeight)
		return canvas
	end
	local spec = Previews[key]
	if not spec or not spec[look] then return nil end
	local canvas = CreateFrame("Frame", nil, parent)
	canvas:SetSize(spec.width, spec.height)
	canvas:SetClipsChildren(true)
	xpcall(spec[look], geterrorhandler(), canvas)
	DisableMouse(canvas)
	return canvas
end

-- Scales a picture to fit a width x height box centred in its parent.
function ns.FitPreview(canvas, width, height)
	local scale = math.min(width / canvas:GetWidth(), height / canvas:GetHeight(), MAX_SCALE)
	canvas:SetScale(scale)
	canvas:ClearAllPoints()
	canvas:SetPoint("CENTER", canvas:GetParent(), "CENTER", 0, 0)
end
