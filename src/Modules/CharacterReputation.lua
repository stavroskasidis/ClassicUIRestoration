--[[
	Forevermore Classic UI - Character window: Reputation tab (WoW Forever only)

	Restores the vanilla reputation page (1.12 ReputationFrame.xml) inside the
	vanilla character window (CharacterFrame.lua, whose option this is part
	of): the "Faction" / "Standing" column labels in the band under the
	title, one row per faction with the name on the left and the 137x13 bar
	on the right, in the UI-Character-ReputationBar row art with the
	standing on the bar (the progress on mouse over) and the additive row
	highlight while hovered or selected, the faction groups as the +/- header
	rows, and the list in the character window's scroll bar trough.

	Forever's page (Blizzard_UIPanels_Game\Camelot\ReputationFrame.*) lists
	the factions in a ScrollBox: header rows, sub-header rows and entry rows
	with a ColoredProgressBar (an atlas fill sized from the bar's width when
	Blizzard sets it). The rows are re-skinned in place (the list's layout,
	scaling and row callbacks: CharacterFrame.lua, CharacterList):

	  * the bar is resized to the vanilla bar and its atlas art faded; the
	    fill is redrawn under the bar's text (the vanilla
	    UI-Character-Skills-Bar, cut to the percentage), copied from
	    Blizzard's faded fill after each Initialize and on the bar's
	    SetFillPercent / UpdateBarColor; the row art is drawn on the row,
	    under the name (the bar frame draws over its row),
	  * the rows are 1.12's 23px apart: the list is scaled down from
	    Blizzard's 33px entry rows (ROW_SCALE) and each row's content back
	    up to full size,
	  * a faction at war gets its name in red (Blizzard's red row
	    background is faded with the other modern highlights; 1.12's
	    crossed swords do not fit the list's width).

	Forever ships a later redraw of UI-Character-ReputationBar (a short bar
	well, red at-war pieces); the 1.12 file is bundled in Textures\.

	Only widget state is touched; no Lua field is written on Blizzard's
	frames. Applied once at login with the Character Window option.
]]

local _, ns = ...
if not ns.IS_FOREVER then return end
local T = ns.T
local Point = ns.Point
local List = ns.CharacterList

-- T.SKILLS_BAR and the +/- buttons (CharacterFrame.lua) come from a file loaded earlier.
T.REPUTATION_BAR_VANILLA = "Interface\\AddOns\\" .. ns.ADDON_NAME .. "\\Textures\\UI-Character-ReputationBar" -- bundled (1.12 layout)
T.REPUTATION_HIGHLIGHT   = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar-Highlight"

local module = ns:RegisterModule({
	key = "characterreputation",
	name = "Character Window: Reputation",
	parent = "characterframe",
	live = false,
})

-- Vanilla geometry (1.12 ReputationFrame.xml), offsets from the character
-- frame's top-left corner.
local LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM = 20, -76, 318, -430 -- ReputationListScrollFrame (the rows start 10px in)
local FACTION_LABEL_X, FACTION_LABEL_Y = 70, -57
local STANDING_LABEL_X, STANDING_LABEL_Y = 215, -59
local BAR_WIDTH, BAR_HEIGHT = 137, 13
local BAR_RIGHT = 22          -- the bar's right end from the row's right end (the art runs 25px past the bar)
local ART_X, ART_Y = -126, 4  -- the row art's top left from the bar's top left
local HEADER_BUTTON_X, HEADER_TEXT_X = 3, 20 -- the header's +/- and its text
-- The list's scale: 1.12's row pitch (a 13px bar every 23px) over
-- Blizzard's (ReputationEntryTemplate, 30px, plus 3px spacing).
local ROW_SCALE = 23 / 33

local function Fade(region)
	if region then region:SetAlpha(0) end
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

-- The vanilla bar on Blizzard's ColoredProgressBar: resized, its atlas art
-- faded and the fill redrawn, with the row art on the row under it. The art
-- spans the name too, so it is the row's (the name is the row's text, over
-- it), not the bar's: the bar frame draws over its row.
local function SkinBar(bar, row)
	local skin = {}
	List.FadeAtlasRegions(bar)
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	bar.Text:SetFontObject(GameFontHighlightSmall)

	skin.fill = bar:CreateTexture(nil, "BACKGROUND")
	skin.fill:SetTexture(T.SKILLS_BAR)
	skin.fill:SetHeight(BAR_HEIGHT)
	skin.fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
	List.SetFill(skin.fill, BAR_WIDTH, 0) -- until Blizzard sets it

	local left = row:CreateTexture(nil, "BACKGROUND")
	ns.SetTexture(left, T.REPUTATION_BAR_VANILLA, 0, 1, 0, 0.34375)
	left:SetSize(256, 22)
	left:SetPoint("TOPLEFT", bar, "TOPLEFT", ART_X, ART_Y)
	local right = row:CreateTexture(nil, "BACKGROUND")
	ns.SetTexture(right, T.REPUTATION_BAR_VANILLA, 0, 0.0625, 0.34375, 0.71875)
	right:SetSize(16, 24)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	skin.art = { left, right }

	-- 1.12's row highlight (additive, over the row art).
	local glow = bar:CreateTexture(nil, "OVERLAY")
	ns.SetTexture(glow, T.REPUTATION_HIGHLIGHT, 0, 1, 0, 0.4375)
	glow:SetBlendMode("ADD")
	glow:SetSize(256, 28)
	glow:SetPoint("TOPLEFT", left, "TOPLEFT", -2, 3)
	local glowEnd = bar:CreateTexture(nil, "OVERLAY")
	ns.SetTexture(glowEnd, T.REPUTATION_HIGHLIGHT, 0, 0.06640625, 0.4375, 0.875)
	glowEnd:SetBlendMode("ADD")
	glowEnd:SetSize(17, 28)
	glowEnd:SetPoint("LEFT", glow, "RIGHT", 0, 0)
	skin.highlight = { glow, glowEnd }

	ns.Hook(bar, "SetFillPercent", function(_, value)
		List.SetFill(skin.fill, BAR_WIDTH, value)
	end)
	ns.Hook(bar, "UpdateBarColor", function(_, color)
		if color then skin.fill:SetVertexColor(color:GetRGB()) end
	end)
	return skin
end

-- Copies Blizzard's fill (faded) to the vanilla one: its percentage is the
-- right edge of the tex coords Blizzard cuts it with (SetFillPercent:
-- SetTexCoord(0, p, 1, 0)), readable before the row is laid out, and its
-- colour is its vertex colour: the colour only, since a texture's alpha is
-- its vertex alpha, which is the fade.
local function SyncFill(bar, skin)
	local _, _, _, _, right = bar.Fill:GetTexCoord()
	List.SetFill(skin.fill, BAR_WIDTH, right)
	local r, g, b = bar.Fill:GetVertexColor()
	skin.fill:SetVertexColor(r, g, b, 1)
end

-- Hovered or selected: the vanilla highlight. At war: the name in red. The
-- row art goes with the bar (a sub-header without a standing has none).
local function UpdateEntry(row, skin)
	local lit = row:IsSelected() or row:IsMouseOver()
	for _, texture in ipairs(skin.bar.highlight) do
		texture:SetShown(lit)
	end
	local hasBar = row.Content.ReputationBar:IsShown()
	for _, texture in ipairs(skin.bar.art) do
		texture:SetShown(hasBar)
	end
	if hasBar then
		SyncFill(row.Content.ReputationBar, skin.bar)
	end
	local color = row:IsAtWar() and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
	row.Content.Name:SetTextColor(color:GetRGB())
end

-- An entry row (and a sub-header row, which is an entry with a +/- button).
local function SkinEntry(row)
	local skin = { bar = SkinBar(row.Content.ReputationBar, row.Content) }
	-- Full size again in the scaled-down list; it spans its row.
	row.Content:SetScale(1 / ROW_SCALE)
	Point(row.Content.ReputationBar, "RIGHT", row.Content, "RIGHT", -BAR_RIGHT, 0)
	row.Content.Name:SetFontObject(GameFontHighlightSmall)
	-- Blizzard's modern row highlight (white, red at war) goes; its alpha is
	-- Blizzard's, the textures' own alpha is not.
	for _, texture in ipairs(row.Content.BackgroundHighlight.TextureRegions or {}) do
		Fade(texture)
	end
	ns.Hook(row, "RefreshBackgroundHighlight", function() UpdateEntry(row, skin) end)
	return skin
end

local function SkinRow(row)
	if row.StateIcon then
		local skin = List.SkinHeader(row, ROW_SCALE, GameFontNormal, HEADER_BUTTON_X, HEADER_TEXT_X)
		-- 1.12's header text lit up under the mouse (its highlight font).
		row:HookScript("OnEnter", function() row.Name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB()) end)
		row:HookScript("OnLeave", function() row.Name:SetTextColor(NORMAL_FONT_COLOR:GetRGB()) end)
		return skin
	elseif row.Content and row.Content.ReputationBar then
		local skin = SkinEntry(row)
		if row.ToggleCollapseButton then
			List.SkinToggle(row.ToggleCollapseButton, ROW_SCALE)
		end
		return skin
	end
end

local function UpdateRow(row, skin)
	if row.StateIcon then
		List.SetExpandTexture(skin.button, row:IsCollapsed(), "Up")
		row.Name:SetTextColor((row:IsMouseOver() and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR):GetRGB())
		return
	end
	if row.ToggleCollapseButton then
		List.UpdateToggle(row.ToggleCollapseButton, row:IsCollapsed())
	end
	UpdateEntry(row, skin)
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------

function module:Apply()
	local page = ReputationFrame
	if not (page and page.ScrollBox and page.ScrollBar and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback and ScrollUtil.AddInitializedFrameCallback) then
		return
	end
	-- Only inside the vanilla character window (CharacterFrame.lua, applied
	-- before this file's part).
	if not ns.characterWindowSkinned then return end

	local overlay = List.SkinList(page, LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM, ROW_SCALE)
	local faction = overlay:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	faction:SetPoint("TOPLEFT", ns.ArtOrigin(CharacterFrame), "TOPLEFT", FACTION_LABEL_X, FACTION_LABEL_Y)
	faction:SetText(FACTION or "Faction")
	local standing = overlay:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	standing:SetPoint("TOPLEFT", ns.ArtOrigin(CharacterFrame), "TOPLEFT", STANDING_LABEL_X, STANDING_LABEL_Y)
	standing:SetText(STANDING or "Standing")

	List.OnRows(page, module, SkinRow, UpdateRow)
end
